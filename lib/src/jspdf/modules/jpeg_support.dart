import 'dart:typed_data';
import 'addimage.dart';

/// Plugin de suporte a JPEG para PDF.
///
/// Processa dados JPEG e retorna informações necessárias
/// para inserção no documento PDF.
///
/// Portado de modules/jpeg_support.js do jsPDF.

/// Marcadores SOF (Start of Frame) JPEG válidos.
const List<int> _sofMarkers = [
  0xC0,
  0xC1,
  0xC2,
  0xC3,
  0xC4,
  0xC5,
  0xC6,
  0xC7,
];

/// Informações de um JPEG processado para inserção no PDF.
class JpegProcessResult {
  final Uint8List data;
  final int width;
  final int height;
  final String colorSpace;
  final int bitsPerComponent;
  final String filter;
  final int index;
  final String? alias;

  const JpegProcessResult({
    required this.data,
    required this.width,
    required this.height,
    required this.colorSpace,
    this.bitsPerComponent = 8,
    this.filter = 'DCTDecode',
    this.index = 0,
    this.alias,
  });
}

/// Extrai dimensões e número de componentes de dados JPEG brutos.
///
/// Usa o algoritmo de leitura de marcadores SOF para encontrar
/// largura, altura e número de componentes de cor.
JpegInfo? getJpegInfoFromBinary(String binaryData) {
  if (binaryData.length < 6) return null;

  var blockLength = binaryData.codeUnitAt(4) * 256 + binaryData.codeUnitAt(5);
  final len = binaryData.length;

  for (var i = 4; i < len; i += 2) {
    i += blockLength;
    if (i + 9 >= len) break;

    if (_sofMarkers.contains(binaryData.codeUnitAt(i + 1))) {
      final height =
          binaryData.codeUnitAt(i + 5) * 256 + binaryData.codeUnitAt(i + 6);
      final width =
          binaryData.codeUnitAt(i + 7) * 256 + binaryData.codeUnitAt(i + 8);
      final numComponents = binaryData.codeUnitAt(i + 9);

      String colorSpace;
      switch (numComponents) {
        case 1:
          colorSpace = ColorSpaces.deviceGray;
          break;
        case 4:
          colorSpace = ColorSpaces.deviceCMYK;
          break;
        case 3:
        default:
          colorSpace = ColorSpaces.deviceRGB;
          break;
      }

      return JpegInfo(
        width: width,
        height: height,
        numComponents: numComponents,
        colorSpace: colorSpace,
      );
    } else {
      if (i + 3 >= len) break;
      blockLength =
          binaryData.codeUnitAt(i + 2) * 256 + binaryData.codeUnitAt(i + 3);
    }
  }

  return null;
}

/// Processa dados JPEG para inserção no PDF.
///
/// [data] pode ser Uint8List (bytes brutos) ou String (binary string).
/// Retorna um [JpegProcessResult] com os dados prontos para o PDF.
JpegProcessResult? processJpeg({
  required dynamic data,
  int index = 0,
  String? alias,
  String? colorSpace,
}) {
  Uint8List bytes;
  String binaryString;

  if (data is Uint8List) {
    bytes = data;
    binaryString = uint8ArrayToBinaryString(data);
  } else if (data is String) {
    binaryString = data;
    bytes = binaryStringToUint8Array(data);
  } else {
    return null;
  }

  final dims = getJpegInfoFromBinary(binaryString);
  if (dims == null) return null;

  // Determina o color space a partir dos dados JPEG
  final resolvedColorSpace = colorSpace ?? dims.colorSpace;

  return JpegProcessResult(
    data: bytes,
    width: dims.width,
    height: dims.height,
    colorSpace: resolvedColorSpace,
    bitsPerComponent: 8,
    filter: DecodeMethod.dctDecode,
    index: index,
    alias: alias,
  );
}
