# Configuration
USER         := cuihtlauac
PKG_NAME     := libjson-rpc-cpp
VERSION      := 1.4.1
REV          ?= 1
PPA          := ppa:$(USER)/libjson-rpc-cpp
TARGET       := ${PKG_NAME}_$(VERSION)-0~$(USER)~
ORIG         := $(PKG_NAME)_$(VERSION).orig.tar.gz
UPSTREAM_URL := https://github.com/cinemast/libjson-rpc-cpp/archive/refs/tags/v$(VERSION).tar.gz
SHA256_SUM   := 7a057e50d6203e4ea0a10ba5e4dbf344c48b177e5a3bf82e850eb3a783c11eb5
SOURCE_DIR   := packaging
OUTPUT_DIR   := artifacts
DISTROS      := $(shell ls -d $(SOURCE_DIR)/*/ 2>/dev/null | xargs -n 1 basename)

UPLOAD_DISTROS   := $(addprefix upload-,$(DISTROS))
TEST_DISTROS     := $(addprefix test-,$(DISTROS))
DOWNLOAD_DISTROS := $(addprefix download-,$(DISTROS))

.PHONY: clean help test upload download-distros download-upstream $(TEST_DISTROS) $(UPLOAD_DISTROS) $(DOWNLOAD_DISTROS)

# Default target
help:
	@echo "Available commands:"
	@echo "  make help              - Show this help message"
	@echo "  make all               - Create source packages for all distributions"
	@echo "  make <distro>          - Create only for <distro> (e.g., 'make noble')"
	@echo "  make <distro> REV=2    - Create with specific revision (e.g., ~noble2)"
	@echo "  make test-<distro>     - Test only for <distro> (e.g., 'make test-noble')"
	@echo "  make upload-<distro>   - Upload only for <distro> (e.g., 'make upload-noble')"
	@echo "  make download-<distro> - Download sources for <distro> (e.g., 'make download-noble')"
	@echo "  make test              - Test for all distributions"
	@echo "  make upload            - Upload for all distributions"
	@echo "  make download-distros  - Download sources for all distributions"
	@echo "  make download-upstream - Download upstream source tarball"
	@echo "  make clean             - Clean up source tree and artifacts"

# Create everything

upload: $(UPLOAD_DISTROS)

$(UPLOAD_DISTROS): upload-%: artifacts/$(TARGET)%$(REV)_source.changes
	@echo "🚀 Uploading to $(PPA)..."
	@dput $(PPA) $(<)

test: $(TEST_DISTROS)

$(TEST_DISTROS): test-%: artifacts/$(TARGET)%$(REV).dsc
	@echo "========================================"
	@echo "🧪 Creating test binaries for $*"
	@echo "========================================"

	@rm -rf $(OUTPUT_DIR)/test-$*
	@mkdir -p $(OUTPUT_DIR)/test-$*

	@echo " Building Docker image for $*..."
	@docker build -t libjson-rpc-cpp-test-$* -f $(SOURCE_DIR)/$*/Dockerfile .

	@echo "🚀 Running build in Docker container..."
	@docker run --rm \
		-v $(PWD)/$(OUTPUT_DIR):/artifacts \
		-v $(PWD)/$(OUTPUT_DIR)/test-$*:/build \
		-w /build \
		libjson-rpc-cpp-test-$* \
		/bin/bash -c "apt-get update && \
		apt-get install -y build-essential devscripts equivs dpkg-dev && \
		dpkg-source -x /artifacts/$(TARGET)$*$(REV).dsc && \
		cd $(PKG_NAME)-$(VERSION) && \
		mk-build-deps --install --remove --tool 'apt-get -y' debian/control && \
		debuild -b -uc -us && \
		echo '✅ Build successful' && \
		echo '📦 Installing packages...' && \
		apt-get install -y ../*.deb && \
		echo '🧪 Running integration tests against installed packages...' && \
		sed -i 's|catch2/catch.hpp|catch.hpp|g' src/test/*.cpp && \
		g++ src/test/*.cpp -o integration_test \
			-I src/test \
			-ljsonrpccpp-common \
			-ljsonrpccpp-server \
			-ljsonrpccpp-client \
			-ljsonrpccpp-stub \
			-lcurl \
			-ljsoncpp \
			-lmicrohttpd && \
		cp src/test/*.json . && \
		./integration_test && \
		echo '✅ Integration tests passed' && \
		chown -R $(shell id -u):$(shell id -g) ."

	@echo "✅ Test binaries for $* built, installed, and verified in Docker"

all: $(DISTROS)

$(DISTROS): %: artifacts/$(TARGET)%$(REV)_source.changes artifacts/$(TARGET)%$(REV)_source.build artifacts/$(TARGET)%$(REV)_source.buildinfo artifacts/$(TARGET)%$(REV).dsc artifacts/$(TARGET)%$(REV).debian.tar.xz

artifacts/$(TARGET)%$(REV)_source.changes artifacts/$(TARGET)%$(REV)_source.build artifacts/$(TARGET)%$(REV)_source.buildinfo artifacts/$(TARGET)%$(REV).dsc artifacts/$(TARGET)%$(REV).debian.tar.xz: $(OUTPUT_DIR)/$(ORIG)
	@echo "========================================"
	@echo "Creating artifacts for $*"
	@echo "========================================"

	@echo "🧹 Clean the source debian directory"
	@rm -rf $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION)/debian

	@echo "⬇️ Inject the debian directory for $*"
	@if [ ! -d "$(SOURCE_DIR)/$*/debian" ]; then \
		echo "❌ Error: No debian directory found for $*"; \
		exit 1; \
	fi
	@cp -r $(SOURCE_DIR)/$*/debian $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION)/

	@echo "🔐 Updating changelog to version $(VERSION)-0~$(USER)~$*$(REV)"
	@cd $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION) && \
		env DEBEMAIL="cuihtlauac.alvarado@gmail.com" DEBFULLNAME="cuihtlauac ALVARADO" \
		dch -v $(VERSION)-0~$(USER)~$*$(REV) \
		--package $(PKG_NAME) \
		--distribution $* \
		--force-distribution \
		"Automated packaging for $*"

	@echo "📦 Create and sign source package artifacts"
	@cd $(OUTPUT_DIR)/$(PKG_NAME)-$(VERSION) && debuild -S -sa > /dev/null
	@echo "✅ Packaged sources for $*"

clean:
	@rm -rf $(OUTPUT_DIR)
	@$(foreach dist,$(DISTROS),rm -rf $(SOURCE_DIR)/$(dist)/$(PKG_NAME)*;)
	@echo "🧹 Cleaned up."

download-upstream: $(OUTPUT_DIR)/$(ORIG)

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


download-distros: $(DOWNLOAD_DISTROS)

$(DOWNLOAD_DISTROS): download-%:
	@echo "⬇️ Downloading package source for $*..."
	@mkdir -p $(SOURCE_DIR)/$*
	@cd $(SOURCE_DIR)/$* && pull-lp-source $(PKG_NAME) $* 2>/dev/null; \
