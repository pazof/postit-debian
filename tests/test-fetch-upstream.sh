#!/usr/bin/env bash
#
# Non-regression test for the POSTIT_GIT_TAG handling in debian/rules.
#
# Background: a previous version of override_dh_auto_build used
# `git clone --branch <tag>` to fetch upstream. That only works for
# branch names; feeding it an annotated tag (e.g. 1.0.1-rc02) failed
# with "La branche distante 1.0.1-rc02 n'a pas ete trouvee" and
# aborted the whole package build.
#
# This test pins the upstream-fetch logic against the *real*
# pazof/yavsc remote on GitHub: tags like 1.0.1-rc01 exist there,
# so we can verify both branches and tags resolve to the expected
# commit without spinning up a fake local server (the local Git
# transport handles shallow tag fetches differently from smart-http,
# so a local-only test would be misleading).
#
# Scope: deliberately does NOT run dpkg-buildpackage / dotnet
# publish / dh_install. Those stages are exercised manually per
# release; this test pins the Git mechanics which previously
# regressed silently until the next tag bump.

set -euo pipefail

TEST_NAME="$(basename "$0")"

# Skip on environments without network access (offline CI runners,
# dev sandboxes without GitHub egress). The test is a non-regression
# guard, not a connectivity test; failing because GitHub is down
# would mask the signal we actually care about.
if [ "${SKIP_NETWORK_TESTS:-0}" = "1" ]; then
    echo "$TEST_NAME: SKIP -- SKIP_NETWORK_TESTS=1"
    exit 0
fi

WORK="$(mktemp -d -t postit-fetch-test.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Real remote. The branch + tag values below MUST exist for the
# test to pass; if pazof retags the repo, bump them. Anchored on
# commits known to be immutable: 1.0.0 is the initial release,
# 1.0.1-rc01 is the rc Paul shipped after the OIDC fixes.
REMOTE_URL="https://github.com/pazof/yavsc.git"
TEST_BRANCH="main"
TEST_TAG="1.0.1-rc01"

# Expected commits from `git ls-remote`. Computed at test time so we
# don't have to update this script every time the repo moves; we
# just assert "whatever HEAD I end up on must match what `git
# ls-remote` says the ref points at".
EXPECTED_BRANCH_SHA="$(git ls-remote "$REMOTE_URL" "refs/heads/$TEST_BRANCH" | awk '{print $1}')"
EXPECTED_TAG_SHA="$(git ls-remote "$REMOTE_URL" "refs/tags/$TEST_TAG" | awk '{print $1}')"

if [ -z "$EXPECTED_BRANCH_SHA" ] || [ -z "$EXPECTED_TAG_SHA" ]; then
    echo "$TEST_NAME: SKIP -- refs not present on remote (branch=$EXPECTED_BRANCH_SHA tag=$EXPECTED_TAG_SHA)"
    exit 0
fi

# Helper copied verbatim from debian/rules. If debian/rules drifts,
# this copy must drift with it -- that is the point of pinning the
# logic in a test.
fetch_upstream() {
    local url="$1" ref="$2" dest="$3"
    mkdir -p "$(dirname "$dest")"
    if [ ! -d "$dest/.git" ]; then
        git init -q "$dest"
        git -C "$dest" remote add origin "$url"
    fi
    git -C "$dest" fetch --depth=1 origin "$ref"
    git -C "$dest" checkout -q FETCH_HEAD
}

# --- Case 1: POSTIT_GIT_TAG points at an annotated tag. ----------
# This is the regression case. Before the fix, this failed with
# "La branche distante <tag> n'a pas ete trouvee".
DEST="$WORK/yavsc-src-tag"
rm -rf "$DEST"
if ! fetch_upstream "$REMOTE_URL" "$TEST_TAG" "$DEST" 2> "$WORK/fetch-tag.err"; then
    echo "$TEST_NAME: FAIL -- fetch_upstream errored on tag '$TEST_TAG'"
    sed 's/^/    /' "$WORK/fetch-tag.err"
    exit 1
fi
GOT="$(git -C "$DEST" rev-parse HEAD)"
if [ "$GOT" != "$EXPECTED_TAG_SHA" ]; then
    echo "$TEST_NAME: FAIL -- tag '$TEST_TAG' resolved to '$GOT', expected '$EXPECTED_TAG_SHA'"
    exit 1
fi
# A shallow clone cannot always determine "exact tag match" because
# the tag-object might not have been fetched. The commit-hash match
# above is the authoritative check; the describe call is a softer
# sanity signal that we still log but do not gate on.
DESCRIBED="$(git -C "$DEST" describe --tags --exact-match HEAD 2>/dev/null || echo '<not exact>')"
echo "$TEST_NAME: tag '$TEST_TAG' -> $GOT (describe: $DESCRIBED)"

# --- Case 2: POSTIT_GIT_TAG points at a branch. ------------------
# Branches must keep working; this is the path the old code was
# originally written for and we don't want to break it.
DEST="$WORK/yavsc-src-branch"
rm -rf "$DEST"
if ! fetch_upstream "$REMOTE_URL" "$TEST_BRANCH" "$DEST" 2> "$WORK/fetch-branch.err"; then
    echo "$TEST_NAME: FAIL -- fetch_upstream errored on branch '$TEST_BRANCH'"
    sed 's/^/    /' "$WORK/fetch-branch.err"
    exit 1
fi
GOT="$(git -C "$DEST" rev-parse HEAD)"
if [ "$GOT" != "$EXPECTED_BRANCH_SHA" ]; then
    echo "$TEST_NAME: FAIL -- branch '$TEST_BRANCH' resolved to '$GOT', expected '$EXPECTED_BRANCH_SHA'"
    exit 1
fi
echo "$TEST_NAME: branch '$TEST_BRANCH' -> $GOT"

# --- Case 3: existing .git directory is reused (the second-build
# fast path). The build dir persists across builds, so the helper
# must not re-init when .git is already there. We populate the
# branch first, then refetch to the tag without nuking the
# existing origin remote.
DEST="$WORK/yavsc-src-reuse"
rm -rf "$DEST"
fetch_upstream "$REMOTE_URL" "$TEST_BRANCH" "$DEST" >/dev/null 2>&1
ORIG_REMOTE="$(git -C "$DEST" remote get-url origin)"
if ! fetch_upstream "$REMOTE_URL" "$TEST_TAG" "$DEST" >/dev/null 2> "$WORK/fetch-reuse.err"; then
    echo "$TEST_NAME: FAIL -- second fetch on existing .git errored"
    sed 's/^/    /' "$WORK/fetch-reuse.err"
    exit 1
fi
if [ "$(git -C "$DEST" remote get-url origin)" != "$ORIG_REMOTE" ]; then
    echo "$TEST_NAME: FAIL -- remote origin was clobbered on reuse"
    exit 1
fi
GOT="$(git -C "$DEST" rev-parse HEAD)"
if [ "$GOT" != "$EXPECTED_TAG_SHA" ]; then
    echo "$TEST_NAME: FAIL -- reuse case tag fetch landed on '$GOT', expected '$EXPECTED_TAG_SHA'"
    exit 1
fi
echo "$TEST_NAME: reuse case tag '$TEST_TAG' -> $GOT (remote preserved)"

# --- Case 4: POSTIT_GIT_TAG is a tag that exists only on a local
# repo, fetched via file://. This is the Paul workflow for staging
# an RC: `git tag 1.0.1-rc02` on ~/Workspace/yavsc, then
# `make POSTIT_GIT_URL=file:///home/paul/Workspace/yavsc
#       POSTIT_GIT_TAG=1.0.1-rc02` to build the .deb before
# pushing the tag to github.com/pazof/yavsc. The fix must support
# this without requiring the tag to be on a public remote first.
LOCAL_REPO="$WORK/local-repo"
LOCAL_TAG="test-local-rc-$$"
# Use ^{commit} to dereference the tag-object to the underlying
# commit; that's what git checkout FETCH_HEAD lands on.
LOCAL_TAG_SHA="$(mktemp -u XXXXXXXXXXXX)"
git init -q "$LOCAL_REPO"
git -C "$LOCAL_REPO" -c user.email=test@test.local -c user.name=test \
    commit --allow-empty -q -m "local seed"
git -C "$LOCAL_REPO" tag -a "$LOCAL_TAG" -m "local-only tag"
LOCAL_TAG_SHA="$(git -C "$LOCAL_REPO" rev-parse "$LOCAL_TAG^{commit}")"

DEST="$WORK/yavsc-src-local"
rm -rf "$DEST"
if ! fetch_upstream "file://$LOCAL_REPO" "$LOCAL_TAG" "$DEST" 2> "$WORK/fetch-local.err"; then
    echo "$TEST_NAME: FAIL -- fetch_upstream errored on local-only tag '$LOCAL_TAG'"
    sed 's/^/    /' "$WORK/fetch-local.err"
    exit 1
fi
GOT="$(git -C "$DEST" rev-parse HEAD)"
if [ "$GOT" != "$LOCAL_TAG_SHA" ]; then
    echo "$TEST_NAME: FAIL -- local tag '$LOCAL_TAG' resolved to '$GOT', expected '$LOCAL_TAG_SHA'"
    exit 1
fi
echo "$TEST_NAME: local tag '$LOCAL_TAG' via file:// -> $GOT"

echo "$TEST_NAME: PASS -- tag, branch, reuse, and local-only tag all resolve correctly"
