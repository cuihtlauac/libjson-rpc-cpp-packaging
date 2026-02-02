# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Debian/Ubuntu packaging repository for **libjson-rpc-cpp v1.4.1**, a C++ JSON-RPC 2.0 & 1.0 framework. The upstream project is at https://github.com/cinemast/libjson-rpc-cpp. This repo maintains packaging for multiple Ubuntu distributions (jammy, noble, questing) with deployment to Launchpad PPA.

## Build Commands

```bash
# Show all available commands
make help

# Download and verify upstream source (SHA256 checked)
make download-upstream

# Create source packages for all distributions
make all

# Create package for specific distribution with revision
make noble REV=2

# Build and test in Docker container
make test-noble
make test-jammy
make test-questing

# Upload to PPA
make upload-noble
make upload            # all distributions

# Clean artifacts
make clean
```

## Testing

Docker-based testing builds packages in isolated containers, installs them, compiles integration tests against the installed libraries, and runs them:

```bash
make test-noble
```

To run upstream unit tests directly (requires downloading upstream first):

```bash
cd artifacts/libjson-rpc-cpp-1.4.1
mkdir -p build && cd build
cmake .. -DREDIS_SERVER=NO -DREDIS_CLIENT=NO -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
./bin/unit_testsuite
```

## Code Formatting

Upstream uses clang-format (LLVM-based, 160 column limit, 2-space indent):

```bash
cd artifacts/libjson-rpc-cpp-1.4.1
make format        # Apply formatting
make check-format  # Verify formatting
```

## Architecture

```
├── Makefile              # Main build orchestration
├── packaging/
│   ├── jammy/debian/     # Ubuntu 22.04 packaging metadata
│   ├── noble/debian/     # Ubuntu 24.04 packaging metadata
│   └── questing/debian/  # Ubuntu Questing packaging metadata
└── artifacts/            # Downloaded upstream source (generated)
    └── libjson-rpc-cpp-1.4.1/
```

**Generated Binary Packages:**
- `libjsonrpccpp-common1t64` - Shared utilities, exceptions, validation
- `libjsonrpccpp-server1t64` - HTTP/TCP/Unix socket server connectors
- `libjsonrpccpp-client1t64` - HTTP/TCP/Unix socket client connectors
- `libjsonrpccpp-stub1t64` - Stub generation utilities
- `libjsonrpccpp-dev` - Development headers and static libs
- `libjsonrpccpp-tools` - jsonrpcstub command-line tool

## Key Configuration

- **Redis disabled** in packaging (`-DREDIS_SERVER=NO -DREDIS_CLIENT=NO`)
- **Coverage disabled** for release builds (`-DWITH_COVERAGE=NO`)
- **SOVERSION 1** - packages include `Breaks/Replaces` for ABI migration from version 0
- **Build type**: `RelWithDebInfo` for debugging symbols

## Prerequisites

```bash
sudo apt install ubuntu-dev-tools osc libargtable2-dev doxygen catch libdistro-info-perl
```

Docker is required for `make test-*` targets.
