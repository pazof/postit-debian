# Makefile for the postit Debian package.
#
# Targets:
#   make deb      : build a .deb in the parent directory (or
#                   $POSTIT_OUT_DIR if set). Equivalent to
#                   dpkg-buildpackage -us -uc -b.
#   make test     : run the non-regression tests under tests/.
#                   The fetch test pins the upstream Git mechanics
#                   that previously regressed on tag-vs-branch
#                   handling (1.0.1-rc02). Set SKIP_NETWORK_TESTS=1
#                   to skip the GitHub-egress parts.
#   make clean    : rm -rf build/ and the per-package staging tree
#                   under debian/postit.
#   make source   : fetch the upstream yavsc source tree under
#                   build/yavsc-src (no packaging step). Useful for
#                   debugging the publish step.
#
# Environment overrides (or pass on the make command line):
#   POSTIT_GIT_URL   default: https://github.com/pazof/yavsc.git
#   POSTIT_GIT_TAG   default: 1.0.0
#   POSTIT_RUNTIME   default: linux-x64  (override to linux-arm64 etc.)
#   POSTIT_OUT_DIR   default: $(CURDIR)/..    (artifacts land here)

POSTIT_GIT_URL ?= https://github.com/pazof/yavsc.git
POSTIT_GIT_TAG ?= 1.0.6
POSTIT_RUNTIME ?= linux-x64
POSTIT_OUT_DIR ?= $(CURDIR)/..

.PHONY: deb clean source test

deb:
	@echo "  POSTIT_GIT_TAG=$(POSTIT_GIT_TAG)  POSTIT_RUNTIME=$(POSTIT_RUNTIME)  POSTIT_GIT_URL=$(POSTIT_GIT_URL)"
	# Render debian/changelog from debian/changelog.in so the package
	# version follows the upstream tag, not the version pinned in the
	# repo. dpkg-buildpackage reads debian/changelog before any rule
	# runs (in dpkg-source --before-build), so the template must be
	# expanded in the Makefile, not in debian/rules. Without this
	# step the .deb always comes out as the version hardcoded in
	# debian/changelog.in, regardless of POSTIT_GIT_TAG.
	sed 's/@VERSION@/$(POSTIT_GIT_TAG)/g' debian/changelog.in > debian/changelog
	# Remove any residual .deb from previous runs (same name
	# pattern would otherwise be re-used by dpkg-deb if the
	# previous run left it lying around).
	rm -f ../postit_*$(POSTIT_GIT_TAG)-1*.deb ../postit_*.buildinfo ../postit_*.changes
	# Use dpkg-architecture to set the target arch correctly for
	# cross-builds. For POSTIT_RUNTIME=linux-arm64, this exports
	# DEB_HOST_ARCH=arm64 (and friends) so dpkg-buildpackage names
	# the .deb postit_*_arm64.deb instead of postit_*_amd64.deb.
	# For linux-x64, it sets the host arch to amd64 explicitly
	# (which matches the runner — no-op, but keeps the call site
	# uniform). Other RIDs are rejected.
	# Compute DPKG_ARCH_ARGS, eval dpkg-architecture, then call
	# dpkg-buildpackage — all in ONE shell invocation so the
	# vars set by dpkg-architecture are visible to dpkg-buildpackage.
	# make runs each recipe line in its own shell, so we use
	# backslash continuation to glue everything together.
	# dpkg-architecture -c <cmd> sets up DEB_* vars and runs <cmd>
	# in the same shell, so the env is visible to dpkg-buildpackage.
	# Use -a (host arch) for cross-builds — it tells dpkg-architecture
	# to export DEB_HOST_ARCH=arm64 (and friends) even though we're
	# running on amd64. -c avoids the need for a separate eval.
	DPKG_ARCH_ARGS=$$(case "$(POSTIT_RUNTIME)" in linux-arm64) echo "-aarm64" ;; linux-x64) echo "-aamd64" ;; *) echo "unsupported POSTIT_RUNTIME=$(POSTIT_RUNTIME)" >&2; exit 1 ;; esac); dpkg-architecture $$DPKG_ARCH_ARGS -c "POSTIT_GIT_URL=$(POSTIT_GIT_URL) POSTIT_GIT_TAG=$(POSTIT_GIT_TAG) POSTIT_RUNTIME=$(POSTIT_RUNTIME) dpkg-buildpackage -us -uc -b"
	# dpkg-buildpackage already writes the produced .deb to
	# /src/_src/../ = $POSTIT_OUT_DIR (its default — there's no
	# flag to change it). So no 'mv' is needed. The old 'mv'
	# caused a 'same file' error when the destination was the
	# same as the source (which it always is). Just verify the
	# .deb was actually produced.
	if ! ls ../postit_*$(POSTIT_GIT_TAG)-1*.deb >/dev/null 2>&1; then \
	    echo "  ERROR: dpkg-buildpackage produced no .deb for POSTIT_GIT_TAG=$(POSTIT_GIT_TAG)" >&2; \
	    exit 1; \
	fi
	@echo "  ✓ artifacts in $(POSTIT_OUT_DIR)"

clean:
	rm -rf build debian/postit

source:
	mkdir -p build
	git clone --depth=1 --branch $(POSTIT_GIT_TAG) \
	    $(POSTIT_GIT_URL) build/yavsc-src

test:
	@bash tests/test-fetch-upstream.sh
