import 'dart:typed_data';

import 'zlib_codec.dart';

const List<int> pngSignature = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
];

const int pngColorTypeGrayscale = 0;
const int pngColorTypeTruecolor = 2;
const int pngColorTypeIndexed = 3;
const int pngColorTypeGrayscaleAlpha = 4;
const int pngColorTypeTruecolorAlpha = 6;

/// Dados PNG decodificados, compatível com o subset de `fast-png.decode`
/// usado pelo jsPDF.
class DecodedPng {
  final int width;
  final int height;
  final int channels;
  final int depth;
  final int colorType;
  final Uint8List data;
  final List<List<int>>? palette;
  final List<int>? transparentColor;

  const DecodedPng({
    required this.width,
    required this.height,
    required this.channels,
    required this.depth,
    required this.data,
    required this.colorType,
    this.palette,
    this.transparentColor,
  });
}

/// Decodifica bytes PNG brutos em pixels desfiltrados.
///
/// Suporta PNG não interlaçado com color types 0, 2, 3, 4 e 6, bit depths
/// definidos pela especificação, chunks PLTE/tRNS e múltiplos IDAT.
DecodedPng decodePng(Uint8List bytes, {bool checkCrc = true}) {
  if (bytes.length < pngSignature.length) {
    throw const FormatException('PNG data is too short.');
  }
  for (int i = 0; i < pngSignature.length; i++) {
    if (bytes[i] != pngSignature[i]) {
      throw const FormatException('Invalid PNG signature.');
    }
  }

  final BytesBuilder idatBuilder = BytesBuilder(copy: false);
  int? width;
  int? height;
  int? depth;
  int? colorType;
  List<List<int>>? palette;
  List<int>? transparentColor;
  List<int>? paletteAlpha;
  int offset = pngSignature.length;
  bool seenIend = false;

  while (offset + 8 <= bytes.length) {
    final int chunkLength = _readUint32(bytes, offset);
    final int typeOffset = offset + 4;
    final int dataOffset = offset + 8;
    final int crcOffset = dataOffset + chunkLength;
    final int nextOffset = crcOffset + 4;
    if (nextOffset > bytes.length) {
      throw const FormatException('Invalid PNG chunk length.');
    }

    final Uint8List chunkTypeBytes =
        Uint8List.sublistView(bytes, typeOffset, typeOffset + 4);
    final String chunkType = String.fromCharCodes(chunkTypeBytes);
    final Uint8List chunkData =
        Uint8List.sublistView(bytes, dataOffset, crcOffset);

    if (checkCrc) {
      final int expectedCrc = _readUint32(bytes, crcOffset);
      final int actualCrc = _crc32(chunkTypeBytes, chunkData);
      if (expectedCrc != actualCrc) {
        throw FormatException('Invalid PNG CRC for chunk $chunkType.');
      }
    }

    switch (chunkType) {
      case 'IHDR':
        if (chunkLength != 13) {
          throw const FormatException('Invalid PNG IHDR chunk.');
        }
        width = _readUint32(chunkData, 0);
        height = _readUint32(chunkData, 4);
        depth = chunkData[8];
        colorType = chunkData[9];
        _validatePngHeader(
          width: width,
          height: height,
          depth: depth,
          colorType: colorType,
          compressionMethod: chunkData[10],
          filterMethod: chunkData[11],
          interlaceMethod: chunkData[12],
        );
        break;
      case 'PLTE':
        if (chunkLength % 3 != 0) {
          throw const FormatException('Invalid PNG PLTE chunk.');
        }
        palette = <List<int>>[];
        for (int i = 0; i < chunkLength; i += 3) {
          palette.add(<int>[chunkData[i], chunkData[i + 1], chunkData[i + 2]]);
        }
        if (paletteAlpha != null) {
          _applyPaletteAlpha(palette, paletteAlpha);
        }
        break;
      case 'tRNS':
        if (colorType == pngColorTypeIndexed) {
          paletteAlpha = chunkData.toList(growable: false);
          if (palette != null) {
            _applyPaletteAlpha(palette, paletteAlpha);
          }
        } else if (colorType == pngColorTypeGrayscale && chunkLength >= 2) {
          transparentColor = <int>[_readUint16(chunkData, 0)];
        } else if (colorType == pngColorTypeTruecolor && chunkLength >= 6) {
          transparentColor = <int>[
            _readUint16(chunkData, 0),
            _readUint16(chunkData, 2),
            _readUint16(chunkData, 4),
          ];
        }
        break;
      case 'IDAT':
        idatBuilder.add(chunkData);
        break;
      case 'IEND':
        seenIend = true;
        break;
    }

    offset = nextOffset;
    if (seenIend) {
      break;
    }
  }

  if (!seenIend) {
    throw const FormatException('PNG is missing IEND.');
  }
  if (width == null || height == null || depth == null || colorType == null) {
    throw const FormatException('PNG is missing IHDR.');
  }
  if (idatBuilder.length == 0) {
    throw const FormatException('PNG is missing IDAT.');
  }
  if (colorType == pngColorTypeIndexed && palette == null) {
    throw const FormatException('Indexed PNG is missing PLTE.');
  }

  final int channels = channelsForPngColorType(colorType);
  final Uint8List inflated =
      Uint8List.fromList(ZLibCodec().decode(idatBuilder.takeBytes()));
  final Uint8List data = _unfilterPngData(
    inflated,
    width: width,
    height: height,
    channels: channels,
    depth: depth,
  );

  return DecodedPng(
    width: width,
    height: height,
    channels: channels,
    depth: depth,
    colorType: colorType,
    data: data,
    palette: palette,
    transparentColor: transparentColor,
  );
}

int channelsForPngColorType(int colorType) {
  switch (colorType) {
    case pngColorTypeGrayscale:
    case pngColorTypeIndexed:
      return 1;
    case pngColorTypeTruecolor:
      return 3;
    case pngColorTypeGrayscaleAlpha:
      return 2;
    case pngColorTypeTruecolorAlpha:
      return 4;
    default:
      throw FormatException('Unsupported PNG color type: $colorType.');
  }
}

Uint8List _unfilterPngData(
  Uint8List filteredData, {
  required int width,
  required int height,
  required int channels,
  required int depth,
}) {
  final int bitsPerPixel = channels * depth;
  final int rowByteLength = ((width * bitsPerPixel) / 8).ceil();
  final int bytesPerPixel = (bitsPerPixel / 8).ceil().clamp(1, 0x7fffffff);
  final int expectedLength = height * (rowByteLength + 1);
  if (filteredData.length < expectedLength) {
    throw const FormatException('PNG image data is truncated.');
  }

  final Uint8List result = Uint8List(rowByteLength * height);
  Uint8List previousLine = Uint8List(rowByteLength);

  for (int row = 0; row < height; row++) {
    final int sourceOffset = row * (rowByteLength + 1);
    final int filterType = filteredData[sourceOffset];
    final Uint8List line = Uint8List.sublistView(
      filteredData,
      sourceOffset + 1,
      sourceOffset + 1 + rowByteLength,
    );
    final int destinationOffset = row * rowByteLength;
    final Uint8List reconstructed = Uint8List(rowByteLength);

    for (int i = 0; i < rowByteLength; i++) {
      final int raw = line[i];
      final int left =
          i >= bytesPerPixel ? reconstructed[i - bytesPerPixel] : 0;
      final int up = previousLine[i];
      final int upLeft =
          i >= bytesPerPixel ? previousLine[i - bytesPerPixel] : 0;

      int value;
      switch (filterType) {
        case 0:
          value = raw;
          break;
        case 1:
          value = raw + left;
          break;
        case 2:
          value = raw + up;
          break;
        case 3:
          value = raw + ((left + up) >> 1);
          break;
        case 4:
          value = raw + _paethPredictor(left, up, upLeft);
          break;
        default:
          throw FormatException('Unsupported PNG filter type: $filterType.');
      }
      reconstructed[i] = value & 0xff;
    }

    result.setRange(
        destinationOffset, destinationOffset + rowByteLength, reconstructed);
    previousLine = reconstructed;
  }

  return result;
}

void _validatePngHeader({
  required int width,
  required int height,
  required int depth,
  required int colorType,
  required int compressionMethod,
  required int filterMethod,
  required int interlaceMethod,
}) {
  if (width <= 0 || height <= 0) {
    throw const FormatException('PNG width and height must be positive.');
  }
  if (compressionMethod != 0 || filterMethod != 0) {
    throw const FormatException(
        'Unsupported PNG compression or filter method.');
  }
  if (interlaceMethod != 0) {
    throw const FormatException('Interlaced PNG images are not supported.');
  }
  final List<int> allowedDepths = _allowedDepthsForColorType(colorType);
  if (!allowedDepths.contains(depth)) {
    throw FormatException(
        'Unsupported PNG bit depth $depth for color type $colorType.');
  }
}

List<int> _allowedDepthsForColorType(int colorType) {
  switch (colorType) {
    case pngColorTypeGrayscale:
      return const <int>[1, 2, 4, 8, 16];
    case pngColorTypeTruecolor:
      return const <int>[8, 16];
    case pngColorTypeIndexed:
      return const <int>[1, 2, 4, 8];
    case pngColorTypeGrayscaleAlpha:
    case pngColorTypeTruecolorAlpha:
      return const <int>[8, 16];
    default:
      throw FormatException('Unsupported PNG color type: $colorType.');
  }
}

void _applyPaletteAlpha(List<List<int>> palette, List<int> paletteAlpha) {
  for (int i = 0; i < paletteAlpha.length && i < palette.length; i++) {
    final List<int> entry = palette[i];
    if (entry.length == 3) {
      entry.add(paletteAlpha[i]);
    } else {
      entry[3] = paletteAlpha[i];
    }
  }
}

int _paethPredictor(int left, int up, int upLeft) {
  if (left == up && up == upLeft) {
    return left;
  }
  final int pLeft = (up - upLeft).abs();
  final int pUp = (left - upLeft).abs();
  final int pUpLeft = (left + up - upLeft - upLeft).abs();
  if (pLeft <= pUp && pLeft <= pUpLeft) {
    return left;
  }
  if (pUp <= pUpLeft) {
    return up;
  }
  return upLeft;
}

int _readUint16(Uint8List bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];

int _readUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _crc32(Uint8List type, Uint8List data) {
  int crc = 0xffffffff;
  for (final int byte in type) {
    crc = _crc32Byte(crc, byte);
  }
  for (final int byte in data) {
    crc = _crc32Byte(crc, byte);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

int _crc32Byte(int crc, int byte) {
  int value = (crc ^ byte) & 0xff;
  for (int k = 0; k < 8; k++) {
    if ((value & 1) != 0) {
      value = 0xedb88320 ^ (value >> 1);
    } else {
      value >>= 1;
    }
  }
  return (crc >> 8) ^ value;
}
