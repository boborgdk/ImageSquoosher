# AVIF input

Operation: add a still AVIF through the file picker, drag and drop, or Windows Explorer; convert to JPG with the existing crop, Lanczos scaling, white alpha composition, and bundled MozJPEG encoder.

Completion: a verified JPEG with the requested dimensions; source and existing output files remain protected by the existing staging and exclusive publication rules. AVIF overwrite uses a separate JPEG path and removes the source only after successful publication and timestamp transfer.

Decoder: libavif 1.3.0 with its pinned local libaom decoder, built as a separate helper. Binary standard input avoids filename encoding and shell quoting problems. Animated files, PQ/HLG HDR, clean aperture transforms, damaged data, and oversized images fail explicitly. Rotation and mirroring are applied before scaling. ICC is retained; AVIF EXIF/XMP transfer is not yet supported. 10/12-bit SDR is reduced to 8-bit for MozJPEG.

Windows scope: update all three Explorer filters (package manifest, IExplorerCommand, runner selection), picker and drop filters. Existing registrations need removal and re-registration to refresh the package manifest. Native shell tests cover uppercase AVIF and Unicode filenames.

macOS scope: existing JPEG/PNG/WebP behavior remains covered by existing tests. AVIF packaging and Finder registration are Windows-only in this change; the decoder reports a clear missing-binary error on unbundled platforms. No macOS AVIF support claim is made.

Build on Windows with Visual Studio C++ and CMake: run `tools/build_avif.ps1`, build the Flutter app, then run `tools/bundle_avif.ps1`. Runtime DLLs are supplied by the existing MozJPEG bundling step. CI builds and tests the helper and packaged decoder on `feature/avif-support`.
