import 'dart:typed_data';

/// Suporte a imagens para o jsPDF portado.
///
/// Fornece detecção de tipo de imagem por magic bytes,
/// e estrutura para inserir imagens JPEG/PNG no PDF.
///
/// Portado de modules/addimage.js do jsPDF.

/// Espaços de cor suportados.
class ColorSpaces {
  static const String deviceRGB = 'DeviceRGB';
  static const String deviceGray = 'DeviceGray';
  static const String deviceCMYK = 'DeviceCMYK';
  static const String indexed = 'Indexed';
}

/// Métodos de decodificação de imagens.
class DecodeMethod {
  static const String dctDecode = 'DCTDecode';
  static const String flateDecode = 'FlateDecode';
  static const String lzwDecode = 'LZWDecode';
  static const String jpxDecode = 'JPXDecode';
}

/// Níveis de compressão.
class ImageCompression {
  static const String none = 'NONE';
  static const String fast = 'FAST';
  static const String medium = 'MEDIUM';
  static const String slow = 'SLOW';
}

/// Dados de uma imagem para inserção no PDF.
class PdfImage {
  /// Dados binários da imagem.
  final Uint8List data;

  /// Largura em pixels.
  final int width;

  /// Altura em pixels.
  final int height;

  /// Espaço de cor (ex: 'DeviceRGB').
  final String colorSpace;

  /// Bits por componente (normalmente 8).
  final int bitsPerComponent;

  /// Filtro de compressão aplicado (ex: 'DCTDecode' para JPEG).
  final String? filter;

  /// Parâmetros de decodificação.
  final String? decodeParameters;

  /// Máscara de transparência.
  final Uint8List? sMask;

  /// Paleta (para imagens indexadas).
  final Uint8List? palette;

  /// Transparência.
  final List<int>? transparency;

  /// Alias para reutilização.
  final String? alias;

  /// Índice da imagem no documento.
  int index = 0;

  /// ID do objeto no PDF.
  int objectId = -1;

  /// ID do objeto SMask, quando há canal alfa separado.
  int sMaskObjectId = -1;

  /// Predictor para compressão.
  int predictor = 15;

  PdfImage({
    required this.data,
    required this.width,
    required this.height,
    this.colorSpace = ColorSpaces.deviceRGB,
    this.bitsPerComponent = 8,
    this.filter,
    this.decodeParameters,
    this.sMask,
    this.palette,
    this.transparency,
    this.alias,
  });
}

/// Magic bytes para detecção de tipo de imagem.
const Map<String, List<List<int?>>> _imageFileTypeHeaders = {
  'PNG': [
    [0x89, 0x50, 0x4e, 0x47],
  ],
  'JPEG': [
    [0xff, 0xd8], // JPEG SOI
    [0xff, 0xd8, 0xff, 0xe0, null, null, 0x4a, 0x46, 0x49, 0x46, 0x00], // JFIF
    [
      0xff,
      0xd8,
      0xff,
      0xe1,
      null,
      null,
      0x45,
      0x78,
      0x69,
      0x66,
      0x00,
      0x00
    ], // Exif
    [0xff, 0xd8, 0xff, 0xdb], // JPEG RAW
    [0xff, 0xd8, 0xff, 0xee], // EXIF RAW
  ],
  'GIF87a': [
    [0x47, 0x49, 0x46, 0x38, 0x37, 0x61],
  ],
  'GIF89a': [
    [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
  ],
  'WEBP': [
    [0x52, 0x49, 0x46, 0x46, null, null, null, null, 0x57, 0x45, 0x42, 0x50],
  ],
  'BMP': [
    [0x42, 0x4d],
  ],
  'TIFF': [
    [0x4d, 0x4d, 0x00, 0x2a], // Motorola
    [0x49, 0x49, 0x2a, 0x00], // Intel
  ],
};

/// Detecta o tipo de imagem pelos magic bytes.
///
/// Retorna o tipo (ex: 'JPEG', 'PNG') ou 'UNKNOWN' se não reconhecer.
String getImageFileTypeByImageData(
  dynamic imageData, [
  String fallbackFormat = 'UNKNOWN',
]) {
  Uint8List bytes;

  if (imageData is Uint8List) {
    bytes = imageData;
  } else if (imageData is String) {
    bytes = Uint8List.fromList(
      imageData.codeUnits.take(20).toList(),
    );
  } else {
    return fallbackFormat;
  }

  for (final entry in _imageFileTypeHeaders.entries) {
    for (final schema in entry.value) {
      if (bytes.length < schema.length) continue;

      var matches = true;
      for (var j = 0; j < schema.length; j++) {
        if (schema[j] == null) continue; // wildcard
        if (schema[j] != bytes[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return entry.key;
    }
  }

  return fallbackFormat;
}

/// Hash simples para dados de imagem (para cache/alias).
int sHashCode(dynamic data) {
  var hash = 0;
  if (data is String) {
    for (var i = 0; i < data.length; i++) {
      hash = ((hash << 5) - hash + data.codeUnitAt(i)) & 0xFFFFFFFF;
    }
  } else if (data is Uint8List) {
    final len = data.length ~/ 2;
    for (var i = 0; i < len; i++) {
      hash = ((hash << 5) - hash + data[i]) & 0xFFFFFFFF;
    }
  }
  return hash;
}

/// Valida se uma string é Base64 válido.
bool validateStringAsBase64(String possibleBase64) {
  final s = possibleBase64.trim();
  if (s.isEmpty) return false;
  if (s.length % 4 != 0) return false;
  if (!RegExp(r'^[A-Za-z0-9+/]+$').hasMatch(s.substring(0, s.length - 2))) {
    return false;
  }
  return true;
}

/// Extrai dados de imagem de uma data URL.
///
/// Retorna a string base64 ou null se inválida.
String? extractImageFromDataUrl(String? dataUrl) {
  if (dataUrl == null) return null;
  final trimmed = dataUrl.trim();
  if (!trimmed.startsWith('data:')) return null;

  final commaIndex = trimmed.indexOf(',');
  if (commaIndex < 0) return null;

  final scheme = trimmed.substring(0, commaIndex).trim();
  if (!scheme.endsWith('base64')) return null;

  return trimmed.substring(commaIndex + 1);
}

/// Converte binary string para Uint8List.
Uint8List binaryStringToUint8Array(String binaryString) {
  final bytes = Uint8List(binaryString.length);
  for (var i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.codeUnitAt(i) & 0xFF;
  }
  return bytes;
}

/// Converte Uint8List para binary string.
String uint8ArrayToBinaryString(Uint8List buffer) {
  final sb = StringBuffer();
  for (final byte in buffer) {
    sb.writeCharCode(byte);
  }
  return sb.toString();
}

/// Informações extraídas de um JPEG.
class JpegInfo {
  final int width;
  final int height;
  final int numComponents;
  final String colorSpace;

  const JpegInfo({
    required this.width,
    required this.height,
    required this.numComponents,
    required this.colorSpace,
  });
}

/// Extrai informações básicas de um JPEG a partir dos seus bytes.
///
/// Lê os markers SOF para obter dimensões e número de componentes.
JpegInfo? extractJpegInfo(Uint8List data) {
  if (data.length < 4) return null;
  if (data[0] != 0xFF || data[1] != 0xD8) return null; // SOI marker

  var offset = 2;
  while (offset < data.length - 1) {
    if (data[offset] != 0xFF) break;

    final marker = data[offset + 1];

    // SOF markers (Start of Frame)
    if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xCC) {
      if (offset + 9 >= data.length) break;
      final height = (data[offset + 5] << 8) | data[offset + 6];
      final width = (data[offset + 7] << 8) | data[offset + 8];
      final numComponents = data[offset + 9];

      String colorSpace;
      switch (numComponents) {
        case 1:
          colorSpace = ColorSpaces.deviceGray;
          break;
        case 3:
          colorSpace = ColorSpaces.deviceRGB;
          break;
        case 4:
          colorSpace = ColorSpaces.deviceCMYK;
          break;
        default:
          colorSpace = ColorSpaces.deviceRGB;
      }

      return JpegInfo(
        width: width,
        height: height,
        numComponents: numComponents,
        colorSpace: colorSpace,
      );
    }

    // Skip marker segment
    if (offset + 3 >= data.length) break;
    final segmentLength = (data[offset + 2] << 8) | data[offset + 3];
    offset += segmentLength + 2;
  }

  return null;
}
