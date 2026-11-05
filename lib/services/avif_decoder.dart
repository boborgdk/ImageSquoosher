import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;

import 'image_pipeline_types.dart';

/// libavif のバイナリ境界。JPEG の生成には使用しない。
class AvifDecoder {
  /// 拡張子ではなく ISO BMFF の ftyp ブランドを検査する。
  static bool isAvif(Uint8List bytes) {
    if (bytes.length < 16 || String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') return false;
    final size = ByteData.sublistView(bytes).getUint32(0);
    if (size < 16 || size > bytes.length || size % 4 != 0) return false;
    for (var offset = 8; offset < size; offset += 4) {
      if (offset == 12) continue;
      final brand = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (brand == 'avif' || brand == 'avis') return true;
    }
    return false;
  }

  /// 配布物を優先し、開発時だけリポジトリ内の実行ファイルへ戻る。
  static File executable() {
    final name = Platform.isWindows ? 'squoosher_avif.exe' : 'squoosher_avif';
    final directory = path.dirname(Platform.resolvedExecutable);
    final override = Platform.environment['IMAGE_SQUOOSHER_AVIF'];
    final candidates = [
      if (override != null) File(override),
      File(path.join(directory, 'avif', name)),
      if (Platform.isMacOS) File(path.join(directory, '..', 'Resources', 'avif', name)),
      File(path.join('native', 'avif', 'bin', name)),
    ];
    for (final file in candidates) {
      if (file.existsSync()) return file;
    }
    throw const UnsupportedImageException('The bundled AVIF decoder was not found.');
  }

  /// 入力のスナップショットをデコードし、向きを画素へ反映する。
  static Future<({image.Image pixels, Uint8List? icc})> decode(Uint8List bytes) async {
    final process = await Process.start(executable().absolute.path, const []);
    final output = process.stdout.fold<BytesBuilder>(BytesBuilder(copy: false), (builder, data) => builder..add(data));
    final errors = process.stderr.drain<void>();
    try {
      process.stdin.add(bytes);
      await process.stdin.close();
      final code = await process.exitCode.timeout(const Duration(seconds: 60));
      await errors;
      if (code != 0) throw const UnsupportedImageException('Invalid, animated, HDR, or unsupported AVIF image.');
      return decodeOutput((await output).takeBytes());
    } finally {
      process.kill();
    }
  }

  /// ネイティブ出力も検証し、壊れた画素列を変換コアへ渡さない。
  static ({image.Image pixels, Uint8List? icc}) decodeOutput(Uint8List bytes) {
    if (bytes.length < 24) throw const UnsupportedImageException('Invalid AVIF decoder output.');
    final header = ByteData.sublistView(bytes);
    final width = header.getUint32(4, Endian.little);
    final height = header.getUint32(8, Endian.little);
    final rotation = header.getUint32(12, Endian.little);
    final mirror = header.getUint32(16, Endian.little);
    final iccLength = header.getUint32(20, Endian.little);
    final end = 24 + width * height * 4;
    if (header.getUint32(0, Endian.little) != 0x31464941 ||
        width == 0 ||
        height == 0 ||
        width * height > 64000000 ||
        rotation > 3 ||
        mirror > 2 ||
        end + iccLength != bytes.length) {
      throw const UnsupportedImageException('Invalid AVIF decoder output.');
    }
    var pixels = image.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      bytesOffset: bytes.offsetInBytes + 24,
      numChannels: 4,
      order: image.ChannelOrder.rgba,
    );
    if (rotation != 0) pixels = image.copyRotate(pixels, angle: -90 * rotation);
    if (mirror != 0) {
      pixels = image.flip(
        pixels,
        direction: mirror == 1 ? image.FlipDirection.vertical : image.FlipDirection.horizontal,
      );
    }
    return (pixels: pixels, icc: iccLength == 0 ? null : Uint8List.sublistView(bytes, end));
  }
}
