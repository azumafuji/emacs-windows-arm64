#!/usr/bin/env bash
# Copy every runtime library Emacs needs into a directory (normally <app>/bin).
#
# Emacs links only libwinpthread and libgmp; everything else is loaded at run
# time, and the names it probes are listed in lisp/term/w32-nt.el
# (dynamic-library-alist).  So the set is:
#   1. the transitive import closure of every .exe in the staged tree, plus
#   2. the names from dynamic-library-alist that exist in the toolchain.
#
# Note: objdump prints a complete import table for some DLLs and still exits
# non-zero.  Never gate on its exit status, or whole subtrees silently vanish.
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"
require_msys2

DEST="${1:?usage: 04-collect-dlls.sh <destination-dir>}"
APP="${2:-$WORK/stage-portable$PREFIX}"
TOOLBIN="$MINGW_PREFIX/bin"
mkdir -p "$DEST"

deps_of() {
  objdump -p "$1" 2>/dev/null | sed -n 's/.*DLL Name: *\(.*\)\r*$/\1/p'
}

is_system_dll() {
  case "${1,,}" in
    api-ms-*|ext-ms-*|kernel32*|kernelbase*|user32*|advapi32*|shell32*|shlwapi*|ole32*|oleaut32*|gdi32*|\
    msimg32*|comctl32*|comdlg32*|winmm*|ws2_32*|wsock32*|mpr*|winspool*|bcrypt*|ncrypt*|dwmapi*|dwrite*|\
    imm32*|usp10*|uxtheme*|wtsapi32*|psapi*|iphlpapi*|msvcrt*|ucrtbase*|secur32*|crypt32*|cfgmgr32*|\
    version*|rpcrt4*|setupapi*|dbghelp*|winhttp*|wininet*|normaliz*|powrprof*|dnsapi*|netapi32*|wldap32*|\
    opengl32*|ntdll*|combase*|windowscodecs*|oleacc*|avrt*|hid*|userenv*|dbgcore*|wintrust*|gdiplus*)
      return 0 ;;
    *) return 1 ;;
  esac
}

declare -a QUEUE=()
declare -A SEEN=()
MISSING=""

enqueue_deps() {   # enqueue the imports of a PE file
  local d
  while IFS= read -r d; do
    [ -n "$d" ] && QUEUE+=("$d")
  done < <(deps_of "$1")
}

# 1) imports of every executable that will ship
while IFS= read -r exe; do enqueue_deps "$exe"; done < <(find "$APP" -type f -name '*.exe')

# 2) runtime-loaded library names from dynamic-library-alist
ALIST="$SRC/lisp/term/w32-nt.el"
if [ -f "$ALIST" ]; then
  while IFS= read -r name; do
    if [ -f "$TOOLBIN/$name" ]; then
      QUEUE+=("$name")
    else
      # %d placeholders become globs, e.g. libpng%d%d-%d%d.dll -> libpng*-*.dll
      pat="${name//%d/*}"
      for m in "$TOOLBIN"/$pat; do
        [ -f "$m" ] && QUEUE+=("$(basename "$m")")
      done
    fi
  done < <(grep -o '"[^"]*\.dll"' "$ALIST" | tr -d '"' | sort -u)
else
  echo "warning: $ALIST not found; runtime libraries will be missed" >&2
fi

# 3) transitive closure, copied as we go
i=0
while [ "$i" -lt "${#QUEUE[@]}" ]; do
  d="${QUEUE[$i]}"; i=$((i + 1))
  [ -n "${SEEN[$d]:-}" ] && continue
  SEEN[$d]=1
  if [ ! -f "$TOOLBIN/$d" ]; then
    is_system_dll "$d" || MISSING="$MISSING $d"
    continue
  fi
  cp -f "$TOOLBIN/$d" "$DEST/$d"
  enqueue_deps "$TOOLBIN/$d"
done

count=$(find "$DEST" -maxdepth 1 -name '*.dll' | wc -l)
bytes=$(find "$DEST" -maxdepth 1 -name '*.dll' -printf '%s\n' | awk '{s+=$1} END {print s+0}')
echo "bundled $count runtime libraries ($((bytes / 1048576)) MB) into $DEST"
if [ -n "$MISSING" ]; then
  echo "warning: non-system imports not found in $TOOLBIN:$MISSING" >&2
fi
