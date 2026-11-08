#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/spektralab"
COMMIT="${SPEKTRALAB_COMMIT:-445e314}"
SRC="$VENDOR/src"

mkdir -p "$VENDOR/include/spektrafilm"
if [ ! -f "$VENDOR/include/spektrafilm/spk_engine.h" ]; then
  curl -fsSL "https://raw.githubusercontent.com/JamesQiu2005/SpektraLab/main/engine/include/spektrafilm/spk_engine.h" \
    -o "$VENDOR/include/spektrafilm/spk_engine.h"
fi

if [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch --depth 1 origin "$COMMIT" || true
  git -C "$SRC" checkout --detach "$COMMIT" || git -C "$SRC" checkout "$COMMIT"
else
  rm -rf "$SRC"
  git clone --filter=blob:none --depth 1 https://github.com/JamesQiu2005/SpektraLab.git "$SRC"
  git -C "$SRC" fetch --depth 1 origin "$COMMIT" || true
  git -C "$SRC" checkout --detach "$COMMIT" || true
fi

if [ -d "$SRC/engine/resources" ]; then
  mkdir -p "$VENDOR/resources"
  rsync -a --delete "$SRC/engine/resources/" "$VENDOR/resources/"
fi

echo "SpektraLab at $SRC (commit $COMMIT)"
echo "Header: $VENDOR/include/spektrafilm/spk_engine.h"
echo "Resources: $VENDOR/resources"
echo "Build the iOS Metal engine next, then add SPEKTRA_ENGINE=1 and drop the stub."
