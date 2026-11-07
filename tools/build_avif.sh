#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build/avif-macos"
OUTPUT="$ROOT/native/avif/bin"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'AVIF macOS build must run on macOS.' >&2; exit 1
fi
cmake -S "$ROOT/native/avif" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build "$BUILD" --config Release --target squoosher_avif --parallel 3
mkdir -p "$OUTPUT"
install -m 755 "$BUILD/squoosher_avif" "$OUTPUT/squoosher_avif"
file "$OUTPUT/squoosher_avif" | grep -q arm64
cp "$BUILD/_deps/libavif-src/LICENSE" "$OUTPUT/libavif-LICENSE"
echo "Built $OUTPUT/squoosher_avif"
