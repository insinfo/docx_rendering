import 'dart:typed_data';

Uint8List? extractImageBytes(dynamic imageData) => null;

Object createPdfBlob(ByteBuffer data) {
  throw UnsupportedError(
      'PDF Blob output is only available in a browser runtime.');
}

String createPdfBlobUrl(ByteBuffer data) {
  throw UnsupportedError(
      'PDF blob URL output is only available in a browser runtime.');
}

void savePdfBytes(ByteBuffer data, String filename) {
  throw UnsupportedError(
      'PDF download is only available in a browser runtime.');
}
