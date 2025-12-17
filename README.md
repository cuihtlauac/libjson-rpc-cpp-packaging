## Prerequisites

```shell
sudo apt install  ubuntu-dev-tools osc libargtable2-dev doxygen catch libdistro-info-perl
```

## Setup

Clean start in your home directory

```shell
mkdir -p ~/libjson-rpc-cpp-packaging && cd ~/libjson-rpc-cpp-packaging
export VERSION="1.4.1"
```

Download upstream 1.4.1

```shell
wget https://github.com/cinemast/libjson-rpc-cpp/archive/refs/tags/v$VERSION.tar.gz -O libjson-rpc-cpp_$VERSION.orig.tar.gz
```

Extract and pull the official metadata from Jammy (the most stable reference)

```shell
tar -xzf libjson-rpc-cpp_$VERSION.orig.tar.gz
cd libjson-rpc-cpp-$VERSION
```

Pull using the correct SOURCE name

```shell
pull-lp-source libjson-rpc-cpp noble
cp -r libjson-rpc-cpp-*/debian ./
rm -rf libjson-rpc-cpp-*/
```

# `SOVERSION` test

```shell
mkdir build_test && cd build_test
cmake .. -DREDIS_SERVER=NO -DREDIS_CLIENT=NO -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Check the SONAME
objdump -p lib/libjsonrpccpp-common.so | grep SONAME
```

# Update to ABI 1

```shell
cd ~/libjson-rpc-cpp-packaging/libjson-rpc-cpp-1.4.1/debian

sed -i 's/common0/common1/g' control
sed -i 's/client0/client1/g' control
sed -i 's/server0/server1/g' control
sed -i 's/stub0/stub1/g' control

for f in *0.install; do mv "$f" "${f%0.install}1.install"; done
for f in *0.lintian-overrides; do mv "$f" "${f%0.lintian-overrides}1.lintian-overrides"; done
```

Insert this in `debian/control` for each package with ABI compatibility
```
Breaks: libjsonrpccpp-common0 (<< 1.4.1)
Replaces: libjsonrpccpp-common0 (<< 1.4.1)
```

# Disable REDIS

Edit `debian/rules` adding this:

```
override_dh_auto_configure:
	dh_auto_configure -- \
		-DREDIS_SERVER=NO \
		-DREDIS_CLIENT=NO \
		-DCOMPILE_STUBGEN=YES \
		-DCOMPILE_EXAMPLES=NO
```

# Deploy to Launchpad for Ubuntu

```shell
# Update changelog for Noble
dch -v $VERSION-0~cuihtlauac~noble1 "Release v1.4.1 to fix Bug #2134911"
dch -r "" --distribution noble

# Build source and upload
debuild -S -sa
dput ppa:cuihtlauac/libjson-rpc-cpp ../libjson-rpc-cpp_$VERSION-0~cuihtlauac~noble1_source.changes
```

# Deploy to OBS for Debian


```shell
cd ~/libjson-rpc-cpp-packaging
osc checkout home:cuihtlauac
cd home:cuihtlauac
osc mkpac libjsonrpccpp
cd libjsonrpccpp

# Copy the source trio
cp ~/libjson-rpc-cpp-packaging/libjson-rpc-cpp_$VERSION.orig.tar.gz ./
cp ~/libjson-rpc-cpp-packaging/libjson-rpc-cpp_$VERSION-0~cuihtlauac~noble1.debian.tar.xz ./
cp ~/libjson-rpc-cpp-packaging/libjson-rpc-cpp_$VERSION-0~cuihtlauac~noble1.dsc ./

osc add *
osc commit -m "Initial 1.4.1 upload for cuihtlauac"
```

# Finalize to GitHub

```shell
cd ~/libjson-rpc-cpp-packaging/libjson-rpc-cpp-$VERSION
git init
git remote add origin https://github.com/cuihtlauac/libjson-rpc-cpp-debian.git
git add debian/
git commit -m "Modernized packaging for 1.4.1"
git push -u origin main
```
