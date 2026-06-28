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
POSTIT_GIT_TAG ?= 1.0.0
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
	POSTIT_GIT_URL=$(POSTIT_GIT_URL) POSTIT_GIT_TAG=$(POSTIT_GIT_TAG) POSTIT_RUNTIME=$(POSTIT_RUNTIME) \
	    dpkg-buildpackage -us -uc -b
	# Move the produced .deb(s) into $POSTIT_OUT_DIR. The version
	# segment we match against is the rendered changelog version
	# (e.g. 1.0.1-rc01-1), not the bare tag.
	mv ../postit_*$(POSTIT_GIT_TAG)-1*.deb $(POSTIT_OUT_DIR)/ 2>/dev/null || \
	    mv ../postit_*.deb $(POSTIT_OUT_DIR)/ || true
	@echo "  ✓ artifacts moved to $(POSTIT_OUT_DIR)"

clean:
	rm -rf build debian/postit

source:
	mkdir -p build
	git clone --depth=1 --branch $(POSTIT_GIT_TAG) \
	    $(POSTIT_GIT_URL) build/yavsc-src

test:
	@bash tests/test-fetch-upstream.sh
