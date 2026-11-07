#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/macos/Build/Products/Release/ImageSquoosher.app}"
SOURCE="$ROOT/native/avif/bin/squoosher_avif"
DEST="$APP/Contents/Resources/avif"
[[ -d "$APP" ]] || { echo "Missing app: $APP" >&2; exit 1; }
[[ -x "$SOURCE" ]] || { echo "Missing AVIF decoder: $SOURCE" >&2; exit 1; }
mkdir -p "$DEST"
install -m 755 "$SOURCE" "$DEST/squoosher_avif"
cp "$ROOT/native/avif/bin/libavif-LICENSE" "$DEST/libavif-LICENSE"
file "$DEST/squoosher_avif" | grep -q arm64
# Fail for missing non-system dynamic libraries, which would break the distributed app.
if otool -L "$DEST/squoosher_avif" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/Library/)' | grep -q .; then
  echo 'AVIF helper has non-system dynamic dependencies; bundle or link them statically first.' >&2
  otool -L "$DEST/squoosher_avif" >&2
  exit 1
fi
printf 'Bundled macOS AVIF decoder into %s\n' "$DEST"
