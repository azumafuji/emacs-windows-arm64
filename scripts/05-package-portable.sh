#!/usr/bin/env bash
# Stage an install, bundle the runtime libraries, and produce a portable zip.
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"
require_msys2

VARIANT="${1:-portable}"
BD="$WORK/build-$VARIANT"
APPNAME="$(variant_appname "$VARIANT")"
STAGE="$WORK/stage-$VARIANT"
PORT="$WORK/portable/$APPNAME"

[ -x "$BD/src/emacs.exe" ] || die "build $VARIANT first (03-build.sh $VARIANT)"

echo "=== staging $VARIANT install ==="
rm -rf "$STAGE" "$PORT"; mkdir -p "$STAGE"
( cd "$BD" && make install DESTDIR="$STAGE" )

INSTALLED="$STAGE$PREFIX"
[ -d "$INSTALLED" ] || die "expected the install tree at $INSTALLED"
mkdir -p "$(dirname "$PORT")"
cp -a "$INSTALLED/." "$PORT/"

# Linux-only extras are pointless in a Windows distribution
rm -rf "$PORT/lib/systemd" "$PORT/share/applications"
rmdir "$PORT/lib" 2>/dev/null || true

"$(dirname "$BASH_SOURCE")/04-collect-dlls.sh" "$PORT/bin" "$PORT"

if [ "$VARIANT" = "native" ]; then
  NOTE="TUNED FOR ONE MACHINE. This build uses -mcpu=$TUNE_NATIVE and therefore
uses instruction-set extensions that other Windows on ARM64 computers may not
have. It will run on this CPU generation only. For anything you share, use the
portable build."
else
  NOTE="Portable build: ARMv8-A instruction set (every Windows on ARM64 machine)
with scheduling tuned for $TUNE_PORTABLE."
fi

cat > "$PORT/README-portable.txt" <<EOF
GNU Emacs $EMACS_VERSION for Windows on ARM64 (aarch64) -- $VARIANT build
======================================================================

Self-contained: every library Emacs loads at run time is already in bin/, so
nothing else needs to be installed.

$NOTE

RUNNING
  bin\runemacs.exe    graphical Emacs (no console window)
  bin\emacs.exe        Emacs; also starts the GUI when run directly
  bin\emacs.exe -nw    terminal Emacs
  bin\emacsclient.exe  connect to a running server

Move the folder anywhere you like; Emacs finds its files relative to the
executable. Keep the layout (bin, libexec, share) intact.

NOTES
  - 64-bit ARM Windows only; it will not run on x86-64.
  - Native Lisp compilation is unavailable: libgccjit does not exist for the
    clangarm64 toolchain, so Lisp is byte-compiled only.
  - TIFF images use the Windows GDI+ backend; XPM images are unavailable.

LICENCE
  GNU Emacs is free software under the GNU General Public License version 3 or
  later; see share/emacs/$EMACS_VERSION/etc/COPYING. Corresponding source:
  see SOURCE-CODE.txt.
EOF

cat > "$PORT/SOURCE-CODE.txt" <<EOF
Corresponding source code
========================

This is GNU Emacs $EMACS_VERSION, licensed under the GNU General Public License
version 3 or later.

Upstream source: https://ftp.gnu.org/gnu/emacs/emacs-$EMACS_VERSION.tar.xz
                 $EMACS_GIT (tag $EMACS_TAG)

This build applies four unmodified patches published by the MSYS2 project,
which add Windows-on-ARM (aarch64-w64-mingw32) support:
  001-clang-fixes.patch, 002-aarch64-fixes.patch,
  003-libtree-sitter-0.27.patch, emacs-ARM64.manifest
from https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-emacs

Build configuration:
  $(common_configure_args | tr '\n' ' ')
  CFLAGS="$(variant_cflags "$VARIANT")"
  LDFLAGS="$(variant_ldflags)"

The complete corresponding source is the Emacs $EMACS_VERSION release above with
those four MSYS2 files applied. The scripts that produce this build, including
the exact patches and their checksums, are in the repository that built it.
EOF

mkdir -p "$DIST"
ZIP="$DIST/$APPNAME-portable.zip"
echo "=== writing $ZIP ==="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$(dirname "$BASH_SOURCE")/zip-dir.ps1")" -Source "$(cygpath -w "$PORT")" -Destination "$(cygpath -w "$ZIP")"
echo "portable zip: $ZIP"
