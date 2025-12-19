# Configuration
PKG_NAME     := libjson-rpc-cpp
VERSION      := 1.4.1
PPA          := ppa:cuihtlauac/libjson-rpc-cpp
ORIG         := $(PKG_NAME)_$(VERSION).orig.tar.gz
UPSTREAM_URL := https://github.com/cinemast/libjson-rpc-cpp/archive/refs/tags/v$(VERSION).tar.gz
SHA256_SUM   := 7a057e50d6203e4ea0a10ba5e4dbf344c48b177e5a3bf82e850eb3a783c11eb5
DEBIAN_DIR   := packaging
OUTPUT_DIR   := artifacts
DISTROS      := $(shell ls -d $(DEBIAN_DIR)/*/ 2>/dev/null | xargs -n 1 basename)

.PHONY: all clean $(DISTROS) help download-upstream

# Default target
help:
	@echo "Available commands:"
	@echo "  make all          - Build source packages for all distributions"
	@echo "  make <distro>     - Build only for <distro> (e.g., 'make noble')"
	@echo "  make upload       - Upload all built artifacts to Launchpad"
	@echo "  make clean        - Clean up source tree and artifacts"
	@echo "  make init-dirs    - Create directory structure"
	@echo "  make download-upstream - Download and verify upstream source tarball"

# Build everything
all: $(DISTROS)

# Dynamic target generation for each distro
$(DISTROS): $(OUTPUT_DIR)/$(ORIG)
	@echo "========================================"
	@echo "📦 Building for target: $@"
	@echo "========================================"

	# 1. Clean the source debian directory
	@rm -rf $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION)/debian

	# 2. Inject the PATCHED debian metadata
	@if [ ! -d "$(DEBIAN_DIR)/$@/debian" ]; then \
		echo "❌ Error: No patched debian directory found for $@"; \
		exit 1; \
	fi
	@cp -r $(DEBIAN_DIR)/$@/debian $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION)/

	# This ensures debuild looks for 1.4.1.orig.tar.gz, not 0.7.0
	@echo "📝 Updating changelog to version $(VERSION)-0~cuihtlauac~$@1"
	cd $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION) && \
		env DEBEMAIL="cuihtlauac.alvarado@gmail.com" DEBFULLNAME="cuihtlauac ALVARADO" \
		dch -v $(VERSION)-0~cuihtlauac~$@1 \
		--package $(PKG_NAME) \
		--distribution $@ \
		--force-distribution \
		"Automated build for $@"

	# 3. Build the Source Package
	# We use -sa (include orig) to ensure PPA accepts it easily.
	# We run inside the source dir but artifacts land in ../ (which is upstream/)
	@cd $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION) && debuild -S -sa > /dev/null
	@echo "✅ Built $@"

upload: artifacts/$(PKG_NAME)-$(VERSION)-0~cuihtlauac~jammy1_source.changes
	@echo "🚀 Uploading to $(PPA)..."
	@dput $(PPA) $(OUTPUT_DIR)/*.changes

clean:
	@rm -rf $(OUTPUT_DIR)
	@$(foreach dist,$(DISTROS),rm -rf $(DEBIAN_DIR)/$(dist)/$(PKG_NAME)*;)
	@echo "🧹 Cleaned up."

$(OUTPUT_DIR)/$(ORIG):
	@echo "🌎 Downloading $(VERSION)..."
	@mkdir -p $(OUTPUT_DIR)
	@wget -q -O $(OUTPUT_DIR)/$(ORIG) $(UPSTREAM_URL)
	@echo "🔐 Verifying SHA256 checksum..."
	@echo "$(SHA256_SUM) $(OUTPUT_DIR)/$(ORIG)" | sha256sum -c -
	@echo "✅ Upstream source downloaded and verified."
	@echo "📦 Unpacking tarball..."
	@mkdir -p $(OUTPUT_DIR)
	@tar -xzf $(OUTPUT_DIR)/$(ORIG) -C $(OUTPUT_DIR)

download-debian:
	@$(foreach dist,$(DISTROS), \
		( \
			echo "⬇️ Downloading debian directory for $(dist)..."; \
			cd $(DEBIAN_DIR)/$(dist) && pull-lp-source $(PKG_NAME) $(dist) 2>/dev/null; \
		); \
	)
