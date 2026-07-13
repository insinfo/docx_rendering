import 'dart:io' as io;
import 'dart:typed_data';

export 'zlib.dart' show adler32, zlibDecode, zlibEncode, zlibEncodeStored;

class ZLibCodec {
  final int level;
  final bool verifyChecksum;

  const ZLibCodec({this.level = -1, this.verifyChecksum = true});

  Uint8List encode(List<int> input) => Uint8List.fromList(
        io.ZLibCodec(level: level).encode(input),
      );

  Uint8List decode(List<int> input) => Uint8List.fromList(
        io.ZLibCodec().decode(input),
      );
}
