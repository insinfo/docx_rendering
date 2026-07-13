import 'dart:typed_data';

/// BMP image decoder — Dart port.
///
/// Decodes BMP files (1-bit, 4-bit, 8-bit, 15-bit, 16-bit, 24-bit, 32-bit)
/// into raw RGBA pixel data.
///
/// Ported from libs/BMPDecoder.js (by shaozilee) of jsPDF.
class BmpDecoder {
  int _pos = 0;
  // ignore: unused_field
  late final Uint8List _buffer;
  late final ByteData _datav;
  final bool _isWithAlpha;
  bool _bottomUp = true;

  // ignore: unused_field
  late int _fileSize;
  late int _offset;
  // ignore: unused_field
  late int _headerSize;
  late int _width;
  late int _height;
  // ignore: unused_field
  late int _planes;
  late int _bitPP;
  // ignore: unused_field
  late int _compress;
  // ignore: unused_field
  late int _rawSize;
  // ignore: unused_field
  late int _hr;
  // ignore: unused_field
  late int _vr;
  late int _colors;
  // ignore: unused_field
  late int _importantColors;

  late List<_PaletteEntry> _palette;
  late Uint8List _data;

  /// Decodes the BMP [buffer].
  ///
  /// [isWithAlpha] – when true, 16-bit BMPs are treated as 15-bit RGBA.
  BmpDecoder(Uint8List buffer, {bool isWithAlpha = false})
      : _isWithAlpha = isWithAlpha {
    _buffer = buffer;
    _datav = ByteData.sublistView(buffer);

    // Validate magic bytes
    final String flag =
        String.fromCharCode(buffer[0]) + String.fromCharCode(buffer[1]);
    _pos += 2;
    if (!const ['BM', 'BA', 'CI', 'CP', 'IC', 'PT'].contains(flag)) {
      throw const FormatException('Invalid BMP file header.');
    }

    _parseHeader();
    _parseBGR();
  }

  /// Decoded width in pixels.
  int get width => _width;

  /// Decoded height in pixels.
  int get height => _height;

  /// Returns the decoded RGBA pixel data (4 bytes per pixel: R, G, B, A).
  Uint8List getData() => _data;

  // -------------------------------------------------------------------------
  // Header parsing
  // -------------------------------------------------------------------------

  void _parseHeader() {
    _fileSize = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _pos += 4; // reserved
    _offset = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _headerSize = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _width = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    final int rawHeight = _datav.getInt32(_pos, Endian.little);
    _pos += 4;
    _planes = _datav.getUint16(_pos, Endian.little);
    _pos += 2;
    _bitPP = _datav.getUint16(_pos, Endian.little);
    _pos += 2;
    _compress = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _rawSize = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _hr = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _vr = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _colors = _datav.getUint32(_pos, Endian.little);
    _pos += 4;
    _importantColors = _datav.getUint32(_pos, Endian.little);
    _pos += 4;

    if (_bitPP == 16 && _isWithAlpha) {
      _bitPP = 15;
    }

    if (_bitPP < 15) {
      final int len = _colors == 0 ? (1 << _bitPP) : _colors;
      _palette = List.generate(len, (_) {
        final int blue = _datav.getUint8(_pos++);
        final int green = _datav.getUint8(_pos++);
        final int red = _datav.getUint8(_pos++);
        _pos++; // quad/padding
        return _PaletteEntry(red: red, green: green, blue: blue);
      });
    } else {
      _palette = [];
    }

    if (rawHeight < 0) {
      _height = -rawHeight;
      _bottomUp = false;
    } else {
      _height = rawHeight;
      _bottomUp = true;
    }
  }

  // -------------------------------------------------------------------------
  // Pixel parsing
  // -------------------------------------------------------------------------

  void _parseBGR() {
    _pos = _offset;
    final int len = _width * _height * 4;
    if (len > 512 * 1024 * 1024) {
      throw const FormatException(
          'Image dimensions exceed 512 MB — too large to decode.');
    }
    _data = Uint8List(len);

    switch (_bitPP) {
      case 1:
        _bit1();
        break;
      case 4:
        _bit4();
        break;
      case 8:
        _bit8();
        break;
      case 15:
        _bit15();
        break;
      case 16:
        _bit16();
        break;
      case 24:
        _bit24();
        break;
      case 32:
        _bit32();
        break;
      default:
        throw FormatException('Unsupported BMP bit depth: $_bitPP.');
    }
  }

  // -------------------------------------------------------------------------
  // Bit-depth decoders
  // -------------------------------------------------------------------------

  void _bit1() {
    final int xlen = (_width + 7) ~/ 8;
    final int pad = xlen % 4;
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < xlen; x++) {
        final int b = _datav.getUint8(_pos++);
        final int loc = line * _width * 4 + x * 8 * 4;
        for (int i = 0; i < 8; i++) {
          if (x * 8 + i < _width) {
            final _PaletteEntry rgb = _palette[(b >> (7 - i)) & 0x1];
            _data[loc + i * 4] = rgb.blue;
            _data[loc + i * 4 + 1] = rgb.green;
            _data[loc + i * 4 + 2] = rgb.red;
            _data[loc + i * 4 + 3] = 0xFF;
          }
        }
      }
      if (pad != 0) {
        _pos += 4 - pad;
      }
    }
  }

  void _bit4() {
    final int xlen = (_width + 1) ~/ 2;
    final int pad = xlen % 4;
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < xlen; x++) {
        final int b = _datav.getUint8(_pos++);
        final int loc = line * _width * 4 + x * 2 * 4;

        final _PaletteEntry rgb1 = _palette[b >> 4];
        _data[loc] = rgb1.blue;
        _data[loc + 1] = rgb1.green;
        _data[loc + 2] = rgb1.red;
        _data[loc + 3] = 0xFF;

        if (x * 2 + 1 < _width) {
          final _PaletteEntry rgb2 = _palette[b & 0x0F];
          _data[loc + 4] = rgb2.blue;
          _data[loc + 4 + 1] = rgb2.green;
          _data[loc + 4 + 2] = rgb2.red;
          _data[loc + 4 + 3] = 0xFF;
        }
      }
      if (pad != 0) {
        _pos += 4 - pad;
      }
    }
  }

  void _bit8() {
    final int pad = _width % 4;
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < _width; x++) {
        final int b = _datav.getUint8(_pos++);
        final int loc = line * _width * 4 + x * 4;
        if (b < _palette.length) {
          final _PaletteEntry rgb = _palette[b];
          _data[loc] = rgb.red;
          _data[loc + 1] = rgb.green;
          _data[loc + 2] = rgb.blue;
          _data[loc + 3] = 0xFF;
        } else {
          _data[loc] = 0xFF;
          _data[loc + 1] = 0xFF;
          _data[loc + 2] = 0xFF;
          _data[loc + 3] = 0xFF;
        }
      }
      if (pad != 0) {
        _pos += 4 - pad;
      }
    }
  }

  void _bit15() {
    const int mask5 = 0x1F;
    final int pad = _width % 3;
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < _width; x++) {
        final int b = _datav.getUint16(_pos, Endian.little);
        _pos += 2;
        final int blue = ((b & mask5) / mask5 * 255).toInt();
        final int green = (((b >> 5) & mask5) / mask5 * 255).toInt();
        final int red = (((b >> 10) & mask5) / mask5 * 255).toInt();
        final int alpha = (b >> 15) != 0 ? 0xFF : 0x00;
        final int loc = line * _width * 4 + x * 4;
        _data[loc] = red;
        _data[loc + 1] = green;
        _data[loc + 2] = blue;
        _data[loc + 3] = alpha;
      }
      _pos += pad;
    }
  }

  void _bit16() {
    const int mask5 = 0x1F;
    const int mask6 = 0x3F;
    final int pad = _width % 3;
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < _width; x++) {
        final int b = _datav.getUint16(_pos, Endian.little);
        _pos += 2;
        final int blue = ((b & mask5) / mask5 * 255).toInt();
        final int green = (((b >> 5) & mask6) / mask6 * 255).toInt();
        final int red = ((b >> 11) / mask5 * 255).toInt();
        final int loc = line * _width * 4 + x * 4;
        _data[loc] = red;
        _data[loc + 1] = green;
        _data[loc + 2] = blue;
        _data[loc + 3] = 0xFF;
      }
      _pos += pad;
    }
  }

  void _bit24() {
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < _width; x++) {
        final int blue = _datav.getUint8(_pos++);
        final int green = _datav.getUint8(_pos++);
        final int red = _datav.getUint8(_pos++);
        final int loc = line * _width * 4 + x * 4;
        _data[loc] = red;
        _data[loc + 1] = green;
        _data[loc + 2] = blue;
        _data[loc + 3] = 0xFF;
      }
      _pos += _width % 4;
    }
  }

  void _bit32() {
    for (int y = _height - 1; y >= 0; y--) {
      final int line = _bottomUp ? y : _height - 1 - y;
      for (int x = 0; x < _width; x++) {
        final int blue = _datav.getUint8(_pos++);
        final int green = _datav.getUint8(_pos++);
        final int red = _datav.getUint8(_pos++);
        final int alpha = _datav.getUint8(_pos++);
        final int loc = line * _width * 4 + x * 4;
        _data[loc] = red;
        _data[loc + 1] = green;
        _data[loc + 2] = blue;
        _data[loc + 3] = alpha;
      }
    }
  }
}

// ignore: unused_element
class _PaletteEntry {
  final int red;
  final int green;
  final int blue;

  const _PaletteEntry({
    required this.red,
    required this.green,
    required this.blue,
  });
}
