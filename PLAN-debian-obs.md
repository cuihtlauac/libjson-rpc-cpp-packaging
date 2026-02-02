# Plan: Add Debian Support via OBS

## Overview

Extend the packaging infrastructure to support Debian releases via Open Build Service (OBS), targeting the same C++17 compilation bug (LP #2134911) that affects Debian's 0.7.0 packages.

## Target Distributions

| Codename | Debian Version | Status |
|----------|----------------|--------|
| bookworm | 12 | stable |
| trixie | 13 | testing |
| sid | - | unstable |

## Key Differences from Ubuntu

1. **No `t64` suffix for bookworm** - The 64-bit time_t transition (`t64` package suffix) started in Debian trixie/Ubuntu noble. Bookworm packages use the original names (e.g., `libjsonrpccpp-common1` not `libjsonrpccpp-common1t64`)

2. **Different Breaks/Replaces** - Debian has different package history than Ubuntu

3. **OBS workflow** - Uses `osc` tool instead of `dput` for uploads

## Steps

### Phase 1: Create Debian Packaging Directories

1. **Create bookworm packaging** (no t64 transition)
   ```bash
   mkdir -p packaging/bookworm/debian
   cp -r packaging/jammy/debian/* packaging/bookworm/debian/
   ```
   - Remove `t64` suffixes from package names in `debian/control`
   - Remove `${t64:Provides}` lines
   - Update `Breaks/Replaces` for Debian package history
   - Rename `.install` files to match non-t64 package names

2. **Create trixie packaging** (has t64 transition)
   ```bash
   mkdir -p packaging/trixie/debian
   cp -r packaging/noble/debian/* packaging/trixie/debian/
   ```
   - Adjust `Breaks/Replaces` for Debian package history

3. **Create sid packaging** (same as trixie)
   ```bash
   mkdir -p packaging/sid/debian
   cp -r packaging/trixie/debian/* packaging/sid/debian/
   ```

### Phase 2: Create Dockerfiles for Testing

Create Dockerfiles for each Debian release:

```dockerfile
# packaging/bookworm/Dockerfile
FROM debian:bookworm
RUN apt-get update && apt-get install -y build-essential devscripts
```

```dockerfile
# packaging/trixie/Dockerfile
FROM debian:trixie
RUN apt-get update && apt-get install -y build-essential devscripts
```

```dockerfile
# packaging/sid/Dockerfile
FROM debian:sid
RUN apt-get update && apt-get install -y build-essential devscripts
```

### Phase 3: Add OBS Makefile Targets

Add to Makefile (mirroring the Launchpad upload pattern):

```makefile
# OBS Configuration
OBS_PROJECT  := home:cuihtlauac
OBS_PACKAGE  := libjson-rpc-cpp
OBS_CHECKOUT := $(OUTPUT_DIR)/obs

# Debian distributions for OBS
DEBIAN_DISTROS     := bookworm trixie sid
OBS_UPLOAD_DISTROS := $(addprefix obs-upload-,$(DEBIAN_DISTROS))

.PHONY: obs-checkout obs-upload $(OBS_UPLOAD_DISTROS)

# One-time checkout of OBS project
obs-checkout:
	@if [ ! -d "$(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)" ]; then \
		echo "📥 Checking out OBS project..."; \
		mkdir -p $(OBS_CHECKOUT); \
		cd $(OBS_CHECKOUT) && osc checkout $(OBS_PROJECT) $(OBS_PACKAGE); \
	fi

# Upload all Debian distributions to OBS
obs-upload: $(OBS_UPLOAD_DISTROS)

# Upload specific distribution to OBS
# Copies the source trio (.orig.tar.gz, .dsc, .debian.tar.xz) and commits
$(OBS_UPLOAD_DISTROS): obs-upload-%: artifacts/$(TARGET)%$(REV).dsc obs-checkout
	@echo "🚀 Uploading to OBS ($(OBS_PROJECT)/$(OBS_PACKAGE)) for $*..."
	@cp $(OUTPUT_DIR)/$(ORIG) $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)/
	@cp $(OUTPUT_DIR)/$(TARGET)$*$(REV).dsc $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)/
	@cp $(OUTPUT_DIR)/$(TARGET)$*$(REV).debian.tar.xz $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE)/
	@cd $(OBS_CHECKOUT)/$(OBS_PROJECT)/$(OBS_PACKAGE) && \
		osc add *.tar.gz *.dsc *.tar.xz 2>/dev/null || true && \
		osc commit -m "Update $* to $(VERSION)-0~$(USER)~$*$(REV)"
	@echo "✅ Uploaded to OBS for $*"
```

**Usage (mirrors Launchpad pattern):**
```bash
# Upload to Launchpad PPA (existing)
make upload-noble          # Single distro
make upload                # All Ubuntu distros

# Upload to OBS (new)
make obs-upload-bookworm   # Single distro
make obs-upload            # All Debian distros
```

### Phase 4: OBS Project Configuration

1. **Set up OBS account** at https://build.opensuse.org

2. **Create project** `home:cuihtlauac` (or use existing)

3. **Configure build targets** in OBS web UI or via `_meta`:
   ```xml
   <repository name="Debian_12">
     <path project="Debian:12" repository="standard"/>
     <arch>x86_64</arch>
     <arch>i586</arch>
   </repository>
   <repository name="Debian_Testing">
     <path project="Debian:Testing" repository="standard"/>
     <arch>x86_64</arch>
   </repository>
   <repository name="Debian_Unstable">
     <path project="Debian:Unstable" repository="standard"/>
     <arch>x86_64</arch>
   </repository>
   ```

### Phase 5: Update Makefile Help Target

Add OBS commands to the help output:

```makefile
help:
	@echo "Available commands:"
	# ... existing commands ...
	@echo ""
	@echo "OBS (Debian) commands:"
	@echo "  make obs-checkout        - Checkout OBS project (one-time setup)"
	@echo "  make obs-upload-<distro> - Upload to OBS for <distro> (e.g., 'make obs-upload-bookworm')"
	@echo "  make obs-upload          - Upload to OBS for all Debian distributions"
```

### Phase 6: Update Documentation

1. Update `CLAUDE.md` with OBS commands
2. Update `README.md` with Debian-specific instructions

## Workflow Summary

```bash
# Build source packages for Debian releases
make bookworm              # Single distro
make bookworm trixie sid   # Multiple distros

# Test builds in Docker
make test-bookworm

# Upload to OBS (like 'make upload-noble' for Launchpad)
make obs-upload-bookworm   # Single distro
make obs-upload            # All Debian distros
```

### Comparison: Launchpad vs OBS

| Action | Launchpad (Ubuntu) | OBS (Debian) |
|--------|-------------------|--------------|
| Build source | `make noble` | `make bookworm` |
| Test locally | `make test-noble` | `make test-bookworm` |
| Upload | `make upload-noble` | `make obs-upload-bookworm` |
| Upload all | `make upload` | `make obs-upload` |
| Tool | `dput` | `osc` |
| Account | Launchpad | build.opensuse.org |

## Notes

- OBS builds packages server-side, so local Docker testing is for validation only
- OBS can publish to download.opensuse.org for easy user access
- Consider adding `_service` file for automated upstream fetching in OBS
- The `osc` tool requires authentication setup: `osc ls` will prompt for credentials on first use

## Prerequisites

```bash
sudo apt install osc
```

Configure `~/.config/osc/oscrc` with OBS credentials.
