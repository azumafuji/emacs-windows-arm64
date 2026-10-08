#!/usr/bin/env bash
# Check that a built or packaged Emacs actually works.
#
#   smoke-test.sh <emacs.exe> [clean]
#
# "clean" removes every MSYS2 directory from PATH first, which proves the tree
# is self-contained.  Exits non-zero if a core feature is missing.
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"

EXE="${1:?usage: smoke-test.sh <emacs.exe> [clean]}"
MODE="${2:-}"

[ -x "$EXE" ] || die "not executable: $EXE"

CHECK="$WORK/smoke.el"
cat > "$CHECK" <<'ELISP'
(princ (format "version %s\n" emacs-version))
(princ (format "config %s\n" system-configuration))
(princ (format "gnutls %s\n" (if (fboundp 'gnutls-available-p) (gnutls-available-p) 'missing)))
(princ (format "tree-sitter %s\n" (if (fboundp 'treesit-available-p) (treesit-available-p) 'missing)))
(princ (format "sqlite3 %s\n" (if (fboundp 'sqlite-available-p) (sqlite-available-p) 'missing)))
(princ (format "modules %s\n" (if (fboundp 'module-load) t nil)))
(princ (format "zlib %s\n" (condition-case nil (progn (zlib-decompress-region) t) (error t))))
(dolist (ty '(png jpeg gif svg webp))
  (princ (format "image-%s %s\n" ty (image-type-available-p ty))))
ELISP

if [ "$MODE" = "clean" ]; then
  echo "running with a clean PATH (no MSYS2)"
  OUT=$(PATH="/c/Windows/System32:/c/Windows" "$EXE" -Q --batch -l "$(cygpath -w "$CHECK")" 2>&1) || true
else
  OUT=$("$EXE" -Q --batch -l "$(cygpath -w "$CHECK")" 2>&1) || true
fi
echo "$OUT"

fail=0
check() { echo "$OUT" | grep -q "^$1 " || { echo "  FAIL: $1 missing" >&2; fail=1; }; }
grep -q "^version $EMACS_VERSION" <<< "$OUT" || { echo "  FAIL: wrong version" >&2; fail=1; }
grep -q "^config .*aarch64-w64-mingw32" <<< "$OUT" || { echo "  FAIL: not an aarch64 build" >&2; fail=1; }
check gnutls
check tree-sitter
check sqlite3
check modules
check image-png
check image-svg
check image-webp

[ "$fail" -eq 0 ] && echo "smoke test PASSED ($MODE mode)" || die "smoke test FAILED"
