# Configuration
USER         := cuihtlauac
PKG_NAME     := libjson-rpc-cpp
VERSION      := 1.4.1
REV          ?= 2
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
	@echo "  make upload-<distro>   - Upload to Launchpad PPA (e.g., 'make upload-noble')"
	@echo "  make download-<distro> - Download sources for <distro> (e.g., 'make download-noble')"
	@echo "  make test              - Test for all distributions"
	@echo "  make upload            - Upload all to Launchpad PPA"
	@echo "  make download-distros  - Download sources for all distributions"
	@echo "  make download-upstream - Download upstream source tarball"
	@echo "  make clean             - Clean up source tree and artifacts"
	@echo ""
	@echo "OBS (Debian) commands:"
	@echo "  make obs-checkout          - Checkout OBS project (one-time setup)"
	@echo "  make obs-upload-<distro>   - Upload to OBS (e.g., 'make obs-upload-bookworm')"
	@echo "  make obs-upload            - Upload all Debian distros to OBS"

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
		/bin/bash -c "cleanup() { chown -R $(shell id -u):$(shell id -g) /build; }; trap cleanup EXIT; \
		apt-get update && \
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
		echo '✅ Integration tests passed'"

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

# OBS Configuration (for Debian distributions)
OBS_PROJECT  := home:$(USER)
OBS_PACKAGE  := $(PKG_NAME)
OBS_CHECKOUT := $(OUTPUT_DIR)/obs
OBS_DISTROS  := bookworm trixie sid
OBS_UPLOAD_DISTROS := $(addprefix obs-upload-,$(OBS_DISTROS))

.PHONY: obs-checkout obs-upload $(OBS_UPLOAD_DISTROS)

# One-time checkout of OBS project (creates package if it doesn't exist)
obs-checkout:
	@mkdir -p $(OBS_CHECKOUT)
	@if [ ! -d "$(OBS_CHECKOUT)/$(OBS_PROJECT)" ]; then \
		echo "📥 Checking out OBS project..."; \
		cd $(OBS_CHECKOUT) && osc checkout $(OBS_PROJECT) 2>/dev/null || \
			(echo "📁 Creating OBS project checkout..." && mkdir -p $(OBS_PROJECT)); \
	fi
	@if [ ! -d "$(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)" ]; then \
		echo "📦 Creating OBS package $(OBS_PACKAGE)..."; \
		cd $(OBS_CHECKOUT)/$(OBS_PROJECT) && osc mkpac $(OBS_PACKAGE); \
	else \
		echo "📂 OBS checkout already exists, updating..."; \
		cd $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE) && osc update; \
	fi

# Upload all Debian distributions to OBS
obs-upload: $(OBS_UPLOAD_DISTROS)

# Upload specific distribution to OBS
$(OBS_UPLOAD_DISTROS): obs-upload-%: artifacts/$(TARGET)%$(REV).dsc obs-checkout
	@echo "🚀 Uploading to OBS ($(OBS_PROJECT)/$(OBS_PACKAGE)) for $*..."
	@cp $(OUTPUT_DIR)/$(ORIG) $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)/
	@cp $(OUTPUT_DIR)/$(TARGET)$*$(REV).dsc $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)/
	@cp $(OUTPUT_DIR)/$(TARGET)$*$(REV).debian.tar.xz $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)/
	@cd $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE) && \
		osc add *.tar.gz *.dsc *.tar.xz 2>/dev/null || true && \
		osc commit -m "Update $* to $(VERSION)-0~$(USER)~$*$(REV)"
	@echo "✅ Uploaded to OBS for $*"
