import 'dart:typed_data';

import 'addimage.dart';
import 'rgba_support.dart';
import '../libs/bmp_decoder.dart';

/// jsPDF BMP support module — Dart port.
///
/// Decodes BMP image bytes into a [PdfImage] by extracting RGBA pixels
/// with [BmpDecoder] and converting them via [processRGBA].
///
/// Unlike the original JS module (which re-encodes to JPEG via JPEGEncoder),
/// this Dart port uses raw RGB + optional alpha SMask, keeping the pipeline
/// within already-ported code and avoiding a large JPEG encoder dependency.
///
/// Ported from modules/bmp_support.js of jsPDF.

/// Processes BMP image bytes and returns a [PdfImage] for PDF embedding.
///
/// [imageData] — raw BMP file bytes.
/// [index] — 1-based image index in the document.
/// [alias] — optional cache alias.
PdfImage processBMP(Uint8List imageData, int index, [String? alias]) {
  final BmpDecoder reader = BmpDecoder(imageData);
  final Uint8List rgbaPixels = reader.getData();

  final RgbaImageData rgba = RgbaImageData(
    data: rgbaPixels,
    width: reader.width,
    height: reader.height,
  );

  final PdfImage result = processRGBA(rgba, index, alias);
  return result;
}
