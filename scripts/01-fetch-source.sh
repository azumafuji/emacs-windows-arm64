#!/usr/bin/env bash
# Fetch the Emacs source tree at the pinned release tag.
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"
require_msys2

if [ -d "$SRC/.git" ]; then
  echo "source tree already present: $SRC"
else
  mkdir -p "$WORK"
  clone_from() {
    echo "cloning $1 ($EMACS_TAG, shallow)"
    rm -rf "$SRC"
    git clone --depth 1 --branch "$EMACS_TAG" "$1" "$SRC"
  }
  if ! clone_from "$EMACS_GIT"; then
    [ -n "${EMACS_GIT_FALLBACK:-}" ] || die "clone failed"
    echo "clone from $EMACS_GIT failed; trying $EMACS_GIT_FALLBACK" >&2
    clone_from "$EMACS_GIT_FALLBACK" || die "clone failed from both URLs"
  fi
fi

commit="$(git -C "$SRC" rev-parse HEAD)"
echo "source commit: $commit"
if [ -n "$EMACS_COMMIT" ] && [ "$commit" != "$EMACS_COMMIT" ]; then
  die "commit mismatch: expected $EMACS_COMMIT, got $commit"
fi
echo "$EMACS_VERSION" > "$WORK/.emacs-version"
