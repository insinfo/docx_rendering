import 'dart:typed_data';

import 'addimage.dart';

/// jsPDF RGBA support module — Dart port.
///
/// Processes raw RGBA pixel data (as obtained from a canvas `getImageData` call)
/// into a [PdfImage] suitable for embedding in a PDF document.
///
/// Ported from modules/rgba_support.js of jsPDF.

/// Container for raw RGBA image data, analogous to the browser's `ImageData`.
class RgbaImageData {
  /// Raw pixel bytes: [R, G, B, A, R, G, B, A, ...].
  final Uint8List data;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  const RgbaImageData({
    required this.data,
    required this.width,
    required this.height,
  });
}

/// Processes raw RGBA pixel data and returns a [PdfImage] for PDF embedding.
///
/// The returned image uses [ColorSpaces.deviceRGB] with an optional alpha
/// channel stored as a separate grayscale `/SMask` image.
///
/// [imageData] — RGBA source pixels.
/// [index] — 1-based image index in the PDF.
/// [alias] — optional alias for image deduplication.
PdfImage processRGBA(RgbaImageData imageData, int index, [String? alias]) {
  final Uint8List pixels = imageData.data;
  final int length = pixels.length;
  final int pixelCount = length ~/ 4;

  final Uint8List rgbOut = Uint8List(pixelCount * 3);
  final Uint8List alphaOut = Uint8List(pixelCount);

  int rgbIndex = 0;
  int alphaIndex = 0;

  for (int i = 0; i < length; i += 4) {
    rgbOut[rgbIndex++] = pixels[i]; // R
    rgbOut[rgbIndex++] = pixels[i + 1]; // G
    rgbOut[rgbIndex++] = pixels[i + 2]; // B
    alphaOut[alphaIndex++] = pixels[i + 3]; // A
  }

  final String rgbData = uint8ArrayToBinaryString(rgbOut);
  final String alphaData = uint8ArrayToBinaryString(alphaOut);

  // Check whether alpha channel has any non-opaque pixels.
  final bool hasAlpha = alphaOut.any((int a) => a < 255);

  return PdfImage(
    data: binaryStringToUint8Array(rgbData),
    width: imageData.width,
    height: imageData.height,
    colorSpace: ColorSpaces.deviceRGB,
    bitsPerComponent: 8,
    alias: alias,
    sMask: hasAlpha ? binaryStringToUint8Array(alphaData) : null,
  )..index = index;
}
