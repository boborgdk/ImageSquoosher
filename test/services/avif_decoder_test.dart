import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_squoosher/models/conversion_settings.dart';
import 'package:image_squoosher/services/avif_decoder.dart';
import 'package:image_squoosher/services/image_conversion_pipeline.dart';
import 'package:image_squoosher/services/image_pipeline_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.tsukumijima.image-squoosher/finder_sync');
  final canDecode = File(
    Platform.environment['IMAGE_SQUOOSHER_AVIF'] ??
        'native/avif/bin/${Platform.isWindows ? 'squoosher_avif.exe' : 'squoosher_avif'}',
  ).existsSync();
  final cjpeg = File(Platform.environment['IMAGE_SQUOOSHER_CJPEG'] ?? 'native/mozjpeg/windows/cjpeg.exe');

  if (Platform.environment['IMAGE_SQUOOSHER_REQUIRE_AVIF'] == '1') {
    test('CI requires both bundled codecs', () {
      expect(canDecode, isTrue, reason: 'AVIF tests must not be skipped in Windows CI.');
      expect(cjpeg.existsSync(), isTrue);
    });
  }

  test('AVIF brands are detected from content, including compatible brands', () {
    final bytes = Uint8List.fromList([0, 0, 0, 24, ...'ftypmif1'.codeUnits, 0, 0, 0, 0, ...'miafavif'.codeUnits]);
    expect(AvifDecoder.isAvif(bytes), isTrue);
    expect(AvifDecoder.isAvif(Uint8List.sublistView(bytes, 0, 20)), isFalse);
    bytes[20] = 0;
    expect(AvifDecoder.isAvif(bytes), isFalse);
    expect(AvifDecoder.isAvif(Uint8List.fromList(image.encodePng(image.Image(width: 1, height: 1)))), isFalse);
  });

  test('native protocol validates size and applies rotation before mirroring', () {
    final bytes = Uint8List(24 + 8);
    final header = ByteData.sublistView(bytes);
    for (final entry in {0: 0x31464941, 4: 2, 8: 1, 12: 1, 16: 1}.entries) {
      header.setUint32(entry.key, entry.value, Endian.little);
    }
    bytes.setAll(24, [255, 0, 0, 255, 0, 0, 255, 0]);
    final decoded = AvifDecoder.decodeOutput(bytes).pixels;
    expect((decoded.width, decoded.height), (1, 2));
    expect(decoded.getPixel(0, 0).r, 255);
    expect(decoded.getPixel(0, 1).a, 0);
    expect(
      () => AvifDecoder.decodeOutput(Uint8List.sublistView(bytes, 0, bytes.length - 1)),
      throwsA(isA<UnsupportedImageException>()),
    );
    header.setUint32(4, 0, Endian.little);
    expect(() => AvifDecoder.decodeOutput(bytes), throwsA(isA<UnsupportedImageException>()));
  });

  test('real still AVIF decodes; animation, HDR and damaged input fail', () async {
    final white = await AvifDecoder.decode(await File('test/fixtures/avif/white_1x1.avif').readAsBytes());
    expect((white.pixels.width, white.pixels.height), (1, 1));
    expect(white.pixels.getPixel(0, 0).r, greaterThan(245));
    for (final name in ['colors-animated-8bpc.avif', 'colors_hdr_rec2020.avif']) {
      await expectLater(
        AvifDecoder.decode(await File('test/fixtures/avif/$name').readAsBytes()),
        throwsA(isA<UnsupportedImageException>()),
      );
    }
    await expectLater(AvifDecoder.decode(Uint8List.fromList([1, 2, 3])), throwsA(isA<UnsupportedImageException>()));
  }, skip: !canDecode);

  test('AVIF reaches MozJPEG and preserves source and existing output on failure', () async {
    final directory = await Directory.systemTemp.createTemp('avif-pipeline-');
    if (Platform.isWindows) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments! as Map<Object?, Object?>;
        final destination = File(args['outputPath']! as String);
        await destination.delete();
        await File(args['stagedOutputPath']! as String).rename(destination.path);
        return null;
      });
    }
    try {
      final source = await File('test/fixtures/avif/colors_sdr_srgb.avif').copy('${directory.path}/æ 空白.AVIF');
      final before = await source.readAsBytes();
      final output = File('${directory.path}/out.jpg');
      final pipeline = ImageConversionPipeline();
      final request = ImageConversionRequest(
        inputFile: source,
        outputFile: output,
        cjpegExecutable: cjpeg,
        settings: const ConversionSettings(resizeEnabled: true, resizeValue: 32),
      );
      final result = await pipeline.convert(request);
      expect(result.sourceFormat, SourceImageFormat.avif);
      expect(result.outputWidth, 32);
      final jpeg = image.decodeJpg(await output.readAsBytes())!;
      expect((jpeg.width, jpeg.height), (result.outputWidth, result.outputHeight));
      final saved = await output.readAsBytes();
      await expectLater(pipeline.convert(request), throwsA(isA<FileSystemException>()));
      expect(await output.readAsBytes(), saved);
      expect(await source.readAsBytes(), before);
      final damaged = File('${directory.path}/damaged.avif');
      await damaged.writeAsBytes(before.sublist(0, 32));
      await expectLater(
        pipeline.convert(
          ImageConversionRequest(
            inputFile: damaged,
            outputFile: output,
            cjpegExecutable: cjpeg,
            settings: const ConversionSettings(),
          ),
        ),
        throwsA(isA<UnsupportedImageException>()),
      );
      expect(await output.readAsBytes(), saved);
      expect(await damaged.exists(), isTrue);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    }
  }, skip: !canDecode || !cjpeg.existsSync());
}
