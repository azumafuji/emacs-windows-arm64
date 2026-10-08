#!/usr/bin/env bash
# Fetch, patch, build, package and smoke-test everything.
#
#   bash scripts/build-all.sh                 # both variants
#   bash scripts/build-all.sh portable        # one variant
#
# Environment overrides: see scripts/config.sh (WORK, DIST, JOBS, TUNE_*).
set -euo pipefail
HERE="$(dirname "$BASH_SOURCE")"
source "$HERE/config.sh"
require_msys2

VARIANTS="${*:-portable native}"

mkdir -p "$DIST"
{
  echo "Emacs $EMACS_VERSION ($EMACS_TAG)"
  echo "toolchain: $(${CC:-clang} --version 2>/dev/null | head -1)"
  echo "MSYSTEM=$MSYSTEM MINGW_CHOST=$MINGW_CHOST"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$DIST/BUILD-INFO.txt"

bash "$HERE/01-fetch-source.sh"
bash "$HERE/02-apply-patches.sh"

for v in $VARIANTS; do
  bash "$HERE/03-build.sh" "$v"
  bash "$HERE/smoke-test.sh" "$WORK/build-$v/src/emacs.exe"
  bash "$HERE/05-package-portable.sh" "$v"
  bash "$HERE/smoke-test.sh" "$WORK/portable/$(variant_appname "$v")/bin/emacs.exe" clean

  if [ -n "$(powershell_exe)" ]; then
    "$(powershell_exe)" -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$HERE/build-installer.ps1")" -Variant "$v" -Root "$(cygpath -w "$(cd "$HERE/.." && pwd)")"
  else
    echo "warning: powershell.exe not found; skipping the installer" >&2
  fi
done

# Record the exact toolchain so a later rebuild can be compared.
pacman -Q > "$DIST/PACKAGES.txt" 2>/dev/null || true

echo
echo "=== artifacts in $DIST ==="
ls -l "$DIST" | sed 's/^/  /'
