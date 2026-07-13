import 'dart:convert';

import 'package:docx_rendering/src/docx_rendering/zip/codecs/zlib/zlib_codec.dart';
import 'package:test/test.dart';

void main() {
  test('stream zlib compartilhado comprime e faz round-trip', () {
    final input = utf8.encode(List.filled(1000, 'conteúdo repetido ').join());
    final encoded = const ZLibCodec().encode(input);
    final decoded = const ZLibCodec().decode(encoded);

    expect(decoded, input);
    expect(encoded.length, lessThan(input.length ~/ 5));
    expect(((encoded[0] << 8) + encoded[1]) % 31, 0);
  });

  test('checksum Adler-32 inválido é rejeitado', () {
    final encoded = const ZLibCodec().encode(utf8.encode('integridade'));
    encoded[encoded.length - 1] ^= 1;

    expect(() => const ZLibCodec().decode(encoded), throwsFormatException);
  });
}
