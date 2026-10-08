# shellcheck shell=bash
# Shared configuration. Sourced by the other scripts; every value can be
# overridden from the environment.

REPO_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"

: "${EMACS_VERSION:=31.1}"
: "${EMACS_TAG:=emacs-$EMACS_VERSION}"
: "${EMACS_GIT:=https://github.com/emacs-mirror/emacs.git}"        # savannah is unreliable
: "${EMACS_GIT_FALLBACK:=https://git.savannah.gnu.org/git/emacs.git}"
: "${EMACS_COMMIT:=}"            # optional: pin the exact commit
: "${WORK:=$REPO_ROOT/work}"
: "${DIST:=$REPO_ROOT/dist}"
: "${SRC:=$WORK/emacs}"
: "${JOBS:=$(nproc)}"
: "${PREFIX:=/opt/emacs}"
: "${TUNE_PORTABLE:=cortex-a76}"   # portable build: scheduling only, no ISA change
: "${TUNE_NATIVE:=native}"         # native build: this machine's own CPU features
: "${PATCHES:=$REPO_ROOT/patches}"

export EMACS_VERSION EMACS_TAG EMACS_GIT EMACS_GIT_FALLBACK EMACS_COMMIT WORK DIST SRC JOBS PREFIX TUNE_PORTABLE TUNE_NATIVE PATCHES

die() { echo "error: $*" >&2; exit 1; }

require_msys2() {
  [ "${MSYSTEM:-}" = "CLANGARM64" ] || die "run this from an MSYS2 CLANGARM64 shell (MSYSTEM=${MSYSTEM:-unset}); see https://www.msys2.org/docs/environments/"
  [ -n "${MINGW_PREFIX:-}" ] || die "MINGW_PREFIX is not set"
  command -v objdump >/dev/null || die "objdump not found (install mingw-w64-clang-aarch64-tools)"
}

# Configure options shared by both variants. See docs/BUILD.md for why each is here.
common_configure_args() {
  echo "--prefix=$PREFIX"
  echo "--host=$MINGW_CHOST"
  echo "--build=$MINGW_CHOST"
  echo "--without-native-compilation"   # libgccjit does not exist for clangarm64
  echo "--with-modules"
  echo "--with-harfbuzz"
  echo "--with-tree-sitter"
  echo "--with-gnutls"
  echo "--without-dbus"
  echo "--without-compress-install"
  echo "--disable-gc-mark-trace"        # removes the GC debug mark-trace buffer
}

variant_cflags() {
  case "$1" in
    portable) echo "-O2 -pipe -Wno-incompatible-pointer-types -fno-omit-frame-pointer -march=armv8-a -mtune=$TUNE_PORTABLE -flto=thin" ;;
    native)   echo "-O2 -pipe -Wno-incompatible-pointer-types -fno-omit-frame-pointer -mcpu=$TUNE_NATIVE -flto=thin" ;;
    *) die "unknown variant: $1" ;;
  esac
}

# The MSYS2 patch sets C_SWITCH_SYSTEM="-mtune=cortex-a53" and configure appends
# it to CPPFLAGS *after* CFLAGS, so setting the same tuning flag in both is what
# guarantees ours wins.
variant_cppflags() {
  case "$1" in
    portable) echo "-mtune=$TUNE_PORTABLE" ;;
    native)   echo "-mcpu=$TUNE_NATIVE -mtune=$TUNE_NATIVE" ;;
  esac
}

variant_ldflags() { echo "-flto=thin -fuse-ld=lld -lpthread"; }

variant_appname() {
  case "$1" in
    portable) echo "emacs-$EMACS_VERSION-aarch64" ;;
    native)   echo "emacs-$EMACS_VERSION-aarch64-native" ;;
    *) die "unknown variant: $1" ;;
  esac
}
