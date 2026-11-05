#include <avif/avif.h>
#include <cstdio>
#include <cstdint>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

// パスを渡さずバイナリの標準入出力を使い、Unicode パスとシェル解釈を避ける。
int main() {
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
#endif
  std::vector<uint8_t> bytes;
  uint8_t block[65536];
  size_t count;
  while ((count = fread(block, 1, sizeof(block), stdin)) != 0) {
    if (bytes.size() + count > 512u * 1024u * 1024u) return 1;
    bytes.insert(bytes.end(), block, block + count);
  }
  avifDecoder* decoder = avifDecoderCreate();
  if (!decoder) return 1;
  decoder->maxThreads = 2;
  decoder->imageSizeLimit = 64000000;
  avifResult result = avifDecoderSetIOMemory(decoder, bytes.data(), bytes.size());
  if (result == AVIF_RESULT_OK) result = avifDecoderParse(decoder);
  // 動画や HDR の暗黙の先頭フレーム化・色変換は行わない。
  if (result != AVIF_RESULT_OK || decoder->imageCount != 1) {
    fprintf(stderr, "Invalid or animated AVIF.\n");
    avifDecoderDestroy(decoder);
    return 1;
  }
  result = avifDecoderNextImage(decoder);
  avifImage* source = decoder->image;
  if (result != AVIF_RESULT_OK || source->transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084 ||
      source->transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_HLG ||
      (source->transformFlags & AVIF_TRANSFORM_CLAP)) {
    fprintf(stderr, "Unsupported HDR, clean aperture, or damaged AVIF.\n");
    avifDecoderDestroy(decoder);
    return 1;
  }
  avifRGBImage rgb;
  avifRGBImageSetDefaults(&rgb, source);
  rgb.depth = 8;
  rgb.format = AVIF_RGB_FORMAT_RGBA;
  rgb.alphaPremultiplied = AVIF_FALSE;
  result = avifRGBImageAllocatePixels(&rgb);
  if (result == AVIF_RESULT_OK) result = avifImageYUVToRGB(source, &rgb);
  if (result != AVIF_RESULT_OK) {
    avifRGBImageFreePixels(&rgb);
    avifDecoderDestroy(decoder);
    return 1;
  }
  // 固定長 little-endian ヘッダーの後に RGBA と ICC を並べる。
  const uint32_t header[] = {0x31464941, rgb.width, rgb.height,
    (source->transformFlags & AVIF_TRANSFORM_IROT) ? source->irot.angle : 0u,
    (source->transformFlags & AVIF_TRANSFORM_IMIR) ? uint32_t(source->imir.axis) + 1u : 0u,
    uint32_t(source->icc.size)};
  bool ok = true;
  for (uint32_t value : header) {
    for (int shift = 0; shift < 32; shift += 8) ok = (putchar((value >> shift) & 255) != EOF) && ok;
  }
  for (uint32_t y = 0; y < rgb.height; ++y)
    ok = (fwrite(rgb.pixels + y * rgb.rowBytes, 1, rgb.width * 4, stdout) == rgb.width * 4) && ok;
  if (source->icc.size) ok = (fwrite(source->icc.data, 1, source->icc.size, stdout) == source->icc.size) && ok;
  avifRGBImageFreePixels(&rgb);
  avifDecoderDestroy(decoder);
  return ok && fflush(stdout) == 0 ? 0 : 1;
}
