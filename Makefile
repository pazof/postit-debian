# Makefile for the postit Debian package.
#
# Targets:
#   make deb      : build a .deb in the parent directory (or
#                   $POSTIT_OUT_DIR if set). Equivalent to
#                   dpkg-buildpackage -us -uc -b.
#   make clean    : rm -rf build/ and the per-package staging tree
#                   under debian/postit.
#   make source   : fetch the upstream yavsc source tree under
#                   build/yavsc-src (no packaging step). Useful for
#                   debugging the publish step.
#
# Environment overrides (or pass on the make command line):
#   POSTIT_GIT_URL  default: https://github.com/pazof/yavsc.git
#   POSTIT_GIT_TAG  default: 1.0.0
#   POSTIT_OUT_DIR  default: $(CURDIR)/..    (artifacts land here)

POSTIT_GIT_URL ?= https://github.com/pazof/yavsc.git
POSTIT_GIT_TAG ?= 1.0.0
POSTIT_OUT_DIR ?= $(CURDIR)/..

.PHONY: deb clean source

deb:
	POSTIT_GIT_URL=$(POSTIT_GIT_URL) POSTIT_GIT_TAG=$(POSTIT_GIT_TAG) \
	    dpkg-buildpackage -us -uc -b
	mv ../postit_*$(POSTIT_GIT_TAG)*.deb $(POSTIT_OUT_DIR)/ 2>/dev/null || \
	    mv ../postit_*.deb $(POSTIT_OUT_DIR)/ || true

clean:
	rm -rf build debian/postit

source:
	mkdir -p build
	git clone --depth=1 --branch $(POSTIT_GIT_TAG) \
	    $(POSTIT_GIT_URL) build/yavsc-src
