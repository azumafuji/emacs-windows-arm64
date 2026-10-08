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
echo "$commit" > "$WORK/.emacs-commit"
if [ -n "$EMACS_COMMIT" ]; then
  if [ "$commit" != "$EMACS_COMMIT" ]; then
    die "the source tree at $SRC is at $commit, but scripts/config.sh pins $EMACS_COMMIT.
  This tree is not the source this build is meant to use, so the build would be
  mislabelled. Either remove it and clone fresh:

      rm -rf '$SRC'

  or move it to the pinned commit:

      git -C '$SRC' fetch --depth 1 origin tag $EMACS_TAG
      git -C '$SRC' checkout --detach $EMACS_COMMIT"
  fi
  echo "commit matches the pin in scripts/config.sh"
else
  echo "warning: EMACS_COMMIT is not pinned; the build is only as fixed as the tag" >&2
fi
echo "$EMACS_VERSION" > "$WORK/.emacs-version"
