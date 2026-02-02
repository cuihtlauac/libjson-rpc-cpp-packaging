# Plan: Add Ubuntu 26.04 Support

## Prerequisites

- Ubuntu 26.04's codename is not yet announced (following alphabetical convention after Questing, it will likely start with "P")
- Once the codename is known, proceed with these steps

## Steps

1. **Create the packaging directory**
   ```bash
   mkdir -p packaging/<codename>/debian
   ```

2. **Copy debian files from noble as a base** (Noble is the current LTS)
   ```bash
   cp -r packaging/noble/debian/* packaging/<codename>/debian/
   ```

3. **Update debian/changelog** - Change distribution name from `noble` to `<codename>`

4. **Review debian/control** - Check if any dependencies need version adjustments for the new release (library transitions, package renames)

5. **Create Dockerfile for testing**
   ```bash
   cp packaging/noble/Dockerfile packaging/<codename>/Dockerfile
   ```
   Update the `FROM` line to use `ubuntu:<codename>`

6. **Test the build**
   ```bash
   make download-upstream
   make <codename> REV=1
   make test-<codename>
   ```

7. **Upload to PPA**
   ```bash
   make upload-<codename>
   ```

## Notes

- The Makefile auto-discovers distributions from `packaging/*/` directories, so no Makefile changes needed
- May need to wait until Ubuntu 26.04 Docker images are available for testing
- Watch for ABI changes (the `t64` suffix for 64-bit time_t transition may change)
