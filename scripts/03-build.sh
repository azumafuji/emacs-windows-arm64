#!/usr/bin/env bash
# Configure and build one variant.  usage: 03-build.sh portable|native
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"
require_msys2

VARIANT="${1:-portable}"
BD="$WORK/build-$VARIANT"

[ -d "$SRC" ] || die "no source tree; run 01-fetch-source.sh first"
[ -f "$SRC/configure" ] || die "no $SRC/configure; run 02-apply-patches.sh first"

echo "=== building $VARIANT ==="
echo "CFLAGS  : $(variant_cflags "$VARIANT")"
echo "CPPFLAGS: $(variant_cppflags "$VARIANT")"
echo "LDFLAGS : $(variant_ldflags)"

rm -rf "$BD"; mkdir -p "$BD"; cd "$BD"

CFLAGS="$(variant_cflags "$VARIANT")" \
CPPFLAGS="$(variant_cppflags "$VARIANT")" \
LDFLAGS="$(variant_ldflags)" \
  "$SRC/configure" $(common_configure_args) 2>&1 | tee configure.log

# shellcheck disable=SC2086
make -j"$JOBS"

[ -x src/emacs.exe ] || die "build finished but src/emacs.exe is missing"
echo
echo "=== $VARIANT built: $BD/src/emacs.exe ($(stat -c %s src/emacs.exe) bytes) ==="
