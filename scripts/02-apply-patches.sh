#!/usr/bin/env bash
# Verify and apply the ARM64 patches, then regenerate configure.
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"
require_msys2

[ -d "$SRC/.git" ] || die "no source tree at $SRC; run 01-fetch-source.sh first"

cd "$SRC"
if [ -f nt/emacs-ARM64.manifest ]; then
  echo "patches already applied (nt/emacs-ARM64.manifest exists); skipping"
  exit 0
fi

echo "verifying patch checksums"
( cd "$PATCHES" && sha256sum -c SHA256SUMS ) || die "patch checksum verification FAILED"

for p in 001-clang-fixes.patch 002-aarch64-fixes.patch 003-libtree-sitter-0.27.patch; do
  echo "applying $p"
  patch -Np1 -i "$PATCHES/$p"
done
cp "$PATCHES/emacs-ARM64.manifest" nt/

echo "regenerating configure with autoconf only"
./autogen.sh autoconf
echo "patches applied and configure regenerated"
