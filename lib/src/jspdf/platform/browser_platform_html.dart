import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import '../libs/zlib_codec.dart';

Uint8List? extractImageBytes(dynamic imageData) {
  if (imageData is ImageData) {
    return _rgbaToPng(
      imageData.data,
      imageData.width,
      imageData.height,
    );
  }

  CanvasElement? canvas;
  if (imageData is CanvasElement) {
    canvas = imageData;
  } else if (imageData is ImageElement) {
    final int width = imageData.naturalWidth > 0
        ? imageData.naturalWidth
        : imageData.width ?? 0;
    final int height = imageData.naturalHeight > 0
        ? imageData.naturalHeight
        : imageData.height ?? 0;
    if (width <= 0 || height <= 0) return null;
    canvas = CanvasElement(width: width, height: height);
    canvas.context2D.drawImageScaled(imageData, 0, 0, width, height);
  }

  if (canvas == null || canvas.width == null || canvas.height == null) {
    return null;
  }
  final ImageData imageData2D = canvas.context2D.getImageData(
    0,
    0,
    canvas.width!,
    canvas.height!,
  );
  return _rgbaToPng(imageData2D.data, canvas.width!, canvas.height!);
}

Blob createPdfBlob(ByteBuffer data) => Blob(<Object>[data], 'application/pdf');

String createPdfBlobUrl(ByteBuffer data) =>
    Url.createObjectUrlFromBlob(createPdfBlob(data));

void savePdfBytes(ByteBuffer data, String filename) {
  final Blob blob = createPdfBlob(data);
  final String url = Url.createObjectUrlFromBlob(blob);
  final AnchorElement anchor = AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  document.body!.append(anchor);
  anchor.click();

  Future<void>.delayed(const Duration(milliseconds: 500), () {
    anchor.remove();
    Url.revokeObjectUrl(url);
  });
}

Uint8List _rgbaToPng(Uint8ClampedList rgba, int width, int height) {
  final BytesBuilder raw = BytesBuilder(copy: false);
  final int rowLength = width * 4;
  for (int y = 0; y < height; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * rowLength, (y + 1) * rowLength));
  }

  final BytesBuilder png = BytesBuilder(copy: false);
  png.add(const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  png.add(_pngChunk('IHDR', <int>[
    ..._uint32(width),
    ..._uint32(height),
    8,
    6,
    0,
    0,
    0,
  ]));
  png.add(_pngChunk('IDAT', ZLibCodec().encode(raw.takeBytes())));
  png.add(_pngChunk('IEND', const <int>[]));
  return png.takeBytes();
}

List<int> _pngChunk(String type, List<int> data) {
  final List<int> typeBytes = type.codeUnits;
  return <int>[
    ..._uint32(data.length),
    ...typeBytes,
    ...data,
    ..._uint32(_crc32(typeBytes, data)),
  ];
}

List<int> _uint32(int value) => <int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

int _crc32(List<int> type, List<int> data) {
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
