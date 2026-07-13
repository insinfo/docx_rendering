import 'dart:typed_data';

import '../libs/zlib_codec.dart';

/// jsPDF Filters module — Dart port.
///
/// Provides ASCII85, ASCIIHex and Flate (zlib) encoding/decoding,
/// plus a generic [processDataByFilters] pipeline.
///
/// Ported from modules/filters.js of jsPDF.

// ---------------------------------------------------------------------------
// ASCII85
// ---------------------------------------------------------------------------

/// Encodes binary string [a] using ASCII85 (aka Base85).
///
/// Returns the encoded string terminated with `~>`.
String ascii85Encode(String a) {
  // Pad input so length is a multiple of 4
  final int mod = a.length % 4;
  final String padding = mod == 0 ? '' : '\x00\x00\x00\x00'.substring(mod);
  final String padded = a + padding;
  final List<int> result = [];

  for (int d = 0; d < padded.length; d += 4) {
    final int b0 = padded.codeUnitAt(d);
    final int b1 = padded.codeUnitAt(d + 1);
    final int b2 = padded.codeUnitAt(d + 2);
    final int b3 = padded.codeUnitAt(d + 3);
    // Use unsigned 32-bit arithmetic
    final int f = ((b0 & 0xFF) * 16777216 +
            (b1 & 0xFF) * 65536 +
            (b2 & 0xFF) * 256 +
            (b3 & 0xFF)) >>>
        0;

    if (f == 0) {
      result.add(122); // 'z'
    } else {
      int v = f;
      final int k4 = v % 85;
      v = (v - k4) ~/ 85;
      final int k3 = v % 85;
      v = (v - k3) ~/ 85;
      final int k2 = v % 85;
      v = (v - k2) ~/ 85;
      final int k1 = v % 85;
      v = (v - k1) ~/ 85;
      final int k0 = v % 85;
      result.addAll([k0 + 33, k1 + 33, k2 + 33, k3 + 33, k4 + 33]);
    }
  }

  // Remove the padding characters we added (one per padding byte)
  for (int i = 0; i < padding.length; i++) {
    result.removeLast();
  }

  return String.fromCharCodes(result) + '~>';
}

/// Decodes an ASCII85-encoded string.
String ascii85Decode(String a) {
  // Strip trailing '~>'
  if (a.endsWith('~>')) {
    a = a.substring(0, a.length - 2);
  }
  // Remove whitespace and expand 'z'→'!!!!!'
  a = a.replaceAll(RegExp(r'\s'), '').replaceAll('z', '!!!!!');

  // Pad to multiple of 5
  final int mod = a.length % 5;
  // 'uuuuu'.substring(mod) gives (5 - mod) 'u' chars when mod != 0
  final String padding = mod == 0 ? '' : 'uuuuu'.substring(mod);
  a = a + padding;

  final List<int> output = [];
  for (int f = 0; f < a.length; f += 5) {
    final int d = (a.codeUnitAt(f) - 33) * 52200625 +
        (a.codeUnitAt(f + 1) - 33) * 614125 +
        (a.codeUnitAt(f + 2) - 33) * 7225 +
        (a.codeUnitAt(f + 3) - 33) * 85 +
        (a.codeUnitAt(f + 4) - 33);
    output.addAll([
      (d >> 24) & 0xFF,
      (d >> 16) & 0xFF,
      (d >> 8) & 0xFF,
      d & 0xFF,
    ]);
  }

  // Remove padding bytes
  for (int i = 0; i < padding.length; i++) {
    output.removeLast();
  }

  return String.fromCharCodes(output);
}

// ---------------------------------------------------------------------------
// ASCIIHex
// ---------------------------------------------------------------------------

/// Encodes binary string [value] as ASCIIHex (hex dump + '>').
String asciiHexEncode(String value) {
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    sb.write(value.codeUnitAt(i).toRadixString(16).padLeft(2, '0'));
  }
  sb.write('>');
  return sb.toString();
}

/// Decodes an ASCIIHex-encoded string.
String asciiHexDecode(String value) {
  value = value.replaceAll(RegExp(r'\s'), '');
  final int endIdx = value.indexOf('>');
  if (endIdx != -1) {
    value = value.substring(0, endIdx);
  }
  if (value.length.isOdd) {
    value += '0';
  }
  final RegExp hexCheck = RegExp(r'^([0-9A-Fa-f]{2})+$');
  if (!hexCheck.hasMatch(value)) {
    return '';
  }
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < value.length; i += 2) {
    sb.writeCharCode(int.parse(value.substring(i, i + 2), radix: 16));
  }
  return sb.toString();
}

// ---------------------------------------------------------------------------
// Flate (zlib)
// ---------------------------------------------------------------------------

/// Deflates (zlib-compresses) binary string [data].
String flateEncode(String data) {
  final Uint8List input = Uint8List(data.length);
  for (int i = 0; i < data.length; i++) {
    input[i] = data.codeUnitAt(i) & 0xFF;
  }
  final Uint8List compressed = ZLibCodec().encode(input);
  return String.fromCharCodes(compressed);
}

/// Inflates (zlib-decompresses) binary string [data].
String flateDecode(String data) {
  final Uint8List input = Uint8List(data.length);
  for (int i = 0; i < data.length; i++) {
    input[i] = data.codeUnitAt(i) & 0xFF;
  }
  final Uint8List decompressed = ZLibCodec().decode(input);
  return String.fromCharCodes(decompressed);
}

// ---------------------------------------------------------------------------
// Filter pipeline
// ---------------------------------------------------------------------------

/// Result of a filter chain processing operation.
class FilterResult {
  /// The processed data string.
  final String data;

  /// The reverse filter chain needed to decode the data (space-separated PDF filter names).
  final String reverseChain;

  const FilterResult({required this.data, required this.reverseChain});
}

/// Processes [origData] through a chain of PDF filters.
///
/// [filterChain] may be a list of filter names such as:
/// - `'ASCII85Encode'`, `'/ASCII85Encode'`
/// - `'ASCII85Decode'`, `'/ASCII85Decode'`
/// - `'ASCIIHexEncode'`, `'/ASCIIHexEncode'`
/// - `'ASCIIHexDecode'`, `'/ASCIIHexDecode'`
/// - `'FlateEncode'`, `'/FlateEncode'`
///
/// Returns a [FilterResult] with the transformed data and the reverse
/// filter chain string (ready for the PDF stream dictionary `/Filter`).
FilterResult processDataByFilters(String origData, List<String> filterChain) {
  String data = origData;
  final List<String> reverseChain = [];

  for (final String filter in filterChain) {
    final String f = filter.startsWith('/') ? filter.substring(1) : filter;
    switch (f) {
      case 'ASCII85Decode':
        data = ascii85Decode(data);
        reverseChain.add('/ASCII85Encode');
        break;
      case 'ASCII85Encode':
        data = ascii85Encode(data);
        reverseChain.add('/ASCII85Decode');
        break;
      case 'ASCIIHexDecode':
        data = asciiHexDecode(data);
        reverseChain.add('/ASCIIHexEncode');
        break;
      case 'ASCIIHexEncode':
        data = asciiHexEncode(data);
        reverseChain.add('/ASCIIHexDecode');
        break;
      case 'FlateEncode':
        data = flateEncode(data);
        reverseChain.add('/FlateDecode');
        break;
      default:
        throw ArgumentError('The filter "$filter" is not implemented');
    }
  }

  return FilterResult(
    data: data,
    reverseChain: reverseChain.reversed.join(' '),
  );
}
