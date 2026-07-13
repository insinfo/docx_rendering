/// Codec de stream zlib compartilhado pelo ZIP/DOCX e pelo jsPDF.
///
/// [Deflate] e [Inflate] operam no payload DEFLATE cru usado em entradas ZIP;
/// este adaptador acrescenta/remove o cabeçalho RFC 1950 e o Adler-32 exigidos
/// por PNG e streams PDF.
library;

import 'dart:typed_data';

import 'deflate.dart';
import 'inflate.dart';

class ZLibCodec {
  final int level;
  final bool verifyChecksum;

  const ZLibCodec({this.level = 6, this.verifyChecksum = true});

  Uint8List encode(List<int> input) => zlibEncode(input, level: level);

  Uint8List decode(List<int> input) => zlibDecode(
        input is Uint8List ? input : Uint8List.fromList(input),
        verifyChecksum: verifyChecksum,
      );
}

Uint8List zlibEncode(List<int> input, {int level = 6}) {
  if (level < 0 || level > 9) {
    throw RangeError.range(level, 0, 9, 'level');
  }
  final raw = Deflate(input, level: level).getBytes();
  final output = BytesBuilder(copy: false);

  const cmf = 0x78; // DEFLATE + janela de 32 KiB.
  final flevel = level <= 1
      ? 0
      : level <= 5
          ? 1
          : level <= 7
              ? 2
              : 3;
  var flg = flevel << 6;
  flg += (31 - (((cmf << 8) | flg) % 31)) % 31;
  output
    ..addByte(cmf)
    ..addByte(flg)
    ..add(raw);

  final checksum = adler32(input);
  output
    ..addByte((checksum >> 24) & 0xff)
    ..addByte((checksum >> 16) & 0xff)
    ..addByte((checksum >> 8) & 0xff)
    ..addByte(checksum & 0xff);
  return output.takeBytes();
}

/// Compatibilidade com o nome usado anteriormente pelo porte jsPDF.
Uint8List zlibEncodeStored(List<int> input) => zlibEncode(input, level: 0);

Uint8List zlibDecode(Uint8List input, {bool verifyChecksum = true}) {
  if (input.length < 6) {
    throw const FormatException('ZLib stream is too short.');
  }
  final cmf = input[0];
  final flg = input[1];
  if ((cmf & 0x0f) != 8) {
    throw const FormatException('Unsupported ZLib compression method.');
  }
  if ((cmf >> 4) > 7) {
    throw const FormatException('Invalid ZLib window size.');
  }
  if (((cmf << 8) + flg) % 31 != 0) {
    throw const FormatException('Invalid ZLib header check bits.');
  }
  if ((flg & 0x20) != 0) {
    throw const FormatException('Preset ZLib dictionaries are not supported.');
  }

  final raw = Uint8List.sublistView(input, 2, input.length - 4);
  final output = Inflate(raw).getBytes();
  if (verifyChecksum) {
    final expected = _uint32(input, input.length - 4);
    if (adler32(output) != expected) {
      throw const FormatException('Invalid ZLib Adler-32 checksum.');
    }
  }
  return output;
}

int adler32(List<int> input) {
  var a = 1;
  var b = 0;
  // Limita os acumuladores para evitar inteiros grandes no JavaScript.
  for (var offset = 0; offset < input.length; offset += 5552) {
    final end = (offset + 5552).clamp(0, input.length);
    for (var i = offset; i < end; i++) {
      a += input[i] & 0xff;
      b += a;
    }
    a %= 65521;
    b %= 65521;
  }
  return ((b << 16) | a) & 0xffffffff;
}

int _uint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
