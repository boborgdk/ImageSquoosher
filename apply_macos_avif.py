#!/usr/bin/env python3
"""Apply ImageSquoosher macOS AVIF support to feature/avif-support checkout.

Run from project root: python3 apply_macos_avif.py
Does not touch Windows files. Stops if upstream anchors have changed.
"""
from pathlib import Path
import sys

root = Path.cwd()

def replace_once(path, old, new):
    file = root / path
    if not file.exists():
        raise RuntimeError(f"Missing file: {path}; run from ImageSquoosher root")
    content = file.read_text()
    if new in content:
        print(f"Already updated: {path}")
        return
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one match for {path}, found {count}; stopped to protect upstream file")
    file.write_text(content.replace(old, new))
    print(f"Updated {path}")

replace_once('macos/FinderSync/FinderSync.swift',
    '      "jpg",\n      "png",',
    '      "jpg",\n      "avif",\n      "png",')

p = '.github/workflows/build.yml'
replace_once(p,
    "  push:\n    branches:\n      - master\n      - feature/avif-support\n",
    "  push:\n    branches:\n      - master\n      - feature/avif-support\n      - feature/macos-avif-support\n")
replace_once(p,
    '      - name: Download MozJPEG cjpeg\n',
    '''      - name: Install native AVIF build dependencies
        shell: bash
        run: brew install cmake ninja nasm

      - name: Build macOS AVIF decoder
        shell: bash
        run: bash tools/build_avif.sh

      - name: Download MozJPEG cjpeg
''')
replace_once(p,
    '''      - name: Run macOS desktop integration test
        shell: bash
        run: |
          export IMAGE_SQUOOSHER_CJPEG="$PWD/native/mozjpeg/macos/arm64/cjpeg"
''',
    '''      - name: Run macOS desktop integration test
        shell: bash
        run: |
          export IMAGE_SQUOOSHER_AVIF="$PWD/native/avif/bin/squoosher_avif"
          export IMAGE_SQUOOSHER_CJPEG="$PWD/native/mozjpeg/macos/arm64/cjpeg"
''')
replace_once(p,
    '''      - name: Bundle MozJPEG cjpeg
        shell: bash
        run: bash tools/bundle_mozjpeg.sh "${{ env.MACOS_APP_PATH }}"
''',
    '''      - name: Bundle MozJPEG cjpeg
        shell: bash
        run: bash tools/bundle_mozjpeg.sh "${{ env.MACOS_APP_PATH }}"

      - name: Bundle AVIF decoder
        shell: bash
        run: bash tools/bundle_avif.sh "${{ env.MACOS_APP_PATH }}"

      - name: Test bundled macOS AVIF conversion
        shell: bash
        env:
          IMAGE_SQUOOSHER_REQUIRE_AVIF: '1'
        run: |
          IMAGE_SQUOOSHER_AVIF="$PWD/${{ env.MACOS_APP_PATH }}/Contents/Resources/avif/squoosher_avif" \\
          IMAGE_SQUOOSHER_CJPEG="$PWD/${{ env.MACOS_APP_PATH }}/Contents/Resources/mozjpeg/cjpeg" \\
          flutter test test/services/avif_decoder_test.dart
''')
replace_once(p,
    '''          cjpeg_executable="${{ env.MACOS_APP_PATH }}/Contents/Resources/mozjpeg/cjpeg"
          finder_extension="${{ env.MACOS_APP_PATH }}/Contents/PlugIns/ImageSquoosherFinderSync.appex"
''',
    '''          cjpeg_executable="${{ env.MACOS_APP_PATH }}/Contents/Resources/mozjpeg/cjpeg"
          avif_executable="${{ env.MACOS_APP_PATH }}/Contents/Resources/avif/squoosher_avif"
          finder_extension="${{ env.MACOS_APP_PATH }}/Contents/PlugIns/ImageSquoosherFinderSync.appex"
''')
replace_once(p,
    '''          test -x "$cjpeg_executable"
          test -d "$finder_extension"
''',
    '''          test -x "$cjpeg_executable"
          test -x "$avif_executable"
          test -d "$finder_extension"
''')
replace_once(p,
    '''          file "$cjpeg_executable" | grep -q 'arm64'
          "$cjpeg_executable" -version
''',
    '''          file "$cjpeg_executable" | grep -q 'arm64'
          file "$avif_executable" | grep -q 'arm64'
          "$cjpeg_executable" -version
''')

# decoder supports macOS lookup already; no change to AVIF decoding implementation needed.
print('Done. Commit on a new branch, then run GitHub Actions to verify.')
