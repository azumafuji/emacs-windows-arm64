#!/usr/bin/env bash
# Fetch the Emacs source tree at the pinned release tag.
set -euo pipefail
source "$(dirname "$BASH_SOURCE")/config.sh"
require_msys2

if [ -d "$SRC/.git" ]; then
  echo "source tree already present: $SRC"
else
  mkdir -p "$WORK"
  echo "cloning $EMACS_GIT ($EMACS_TAG, shallow)"
  git clone --depth 1 --branch "$EMACS_TAG" "$EMACS_GIT" "$SRC"
fi

commit="$(git -C "$SRC" rev-parse HEAD)"
echo "source commit: $commit"
if [ -n "$EMACS_COMMIT" ] && [ "$commit" != "$EMACS_COMMIT" ]; then
  die "commit mismatch: expected $EMACS_COMMIT, got $commit"
fi
echo "$EMACS_VERSION" > "$WORK/.emacs-version"
