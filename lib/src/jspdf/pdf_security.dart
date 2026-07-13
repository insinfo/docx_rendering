/// PDF Standard Security Handler (revision 2, RC4 40-bit).
///
/// Implementado em Dart puro para manter zero dependências externas e
/// compatibilidade Web/VM.

const Map<String, int> pdfPermissionOptions = <String, int>{
  'print': 4,
  'modify': 8,
  'copy': 16,
  'annot-forms': 32,
};

class PdfEncryptionOptions {
  final List<String> userPermissions;
  final String userPassword;
  final String ownerPassword;

  const PdfEncryptionOptions({
    this.userPermissions = const <String>[],
    this.userPassword = '',
    this.ownerPassword = '',
  });
}

const String _passwordPadding =
    '\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08'
    '\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A';

class PdfSecurity {
  final int v = 1;
  final int r = 2;
  final List<String> permissions;
  final String userPassword;
  final String ownerPassword;
  final String fileId;
  late final String o;
  late final int p;
  late final String encryptionKey;
  late final String u;

  PdfSecurity({
    List<String> permissions = const <String>[],
    this.userPassword = '',
    this.ownerPassword = '',
    required this.fileId,
  }) : permissions = List<String>.unmodifiable(permissions) {
    int protection = 192;
    for (final permission in permissions) {
      final int? flag = pdfPermissionOptions[permission];
      if (flag == null) {
        throw ArgumentError.value(
            permission, 'permissions', 'Invalid PDF permission.');
      }
      protection += flag;
    }

    final String paddedUserPassword = padPassword(userPassword);
    final String paddedOwnerPassword = padPassword(ownerPassword);
    o = processOwnerPassword(paddedUserPassword, paddedOwnerPassword);
    p = -((protection ^ 255) + 1);
    encryptionKey = md5BinaryString(
      paddedUserPassword + o + lsbFirstWord(p) + hexToBytes(fileId),
    ).substring(0, 5);
    u = rc4(encryptionKey, _passwordPadding);
  }

  String encryptObject(int objectId, int generation, String data) {
    return encryptor(objectId, generation)(data);
  }

  String Function(String data) encryptor(int objectId, int generation) {
    final String key = md5BinaryString(
      encryptionKey +
          String.fromCharCodes(<int>[
            objectId & 0xff,
            (objectId >> 8) & 0xff,
            (objectId >> 16) & 0xff,
            generation & 0xff,
            (generation >> 8) & 0xff,
          ]),
    ).substring(0, 10);
    return (String data) => rc4(key, data);
  }

  String encryptionDictionary(int objectId) {
    return '<</Filter /Standard /V $v /R $r /O <${toHexString(o)}> /U <${toHexString(u)}> /P $p>>';
  }
}

String padPassword(String password) =>
    (password + _passwordPadding).substring(0, 32);

String lsbFirstWord(int value) {
  return String.fromCharCodes(<int>[
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

String toHexString(String byteString) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < byteString.length; i++) {
    buffer.write(
        (byteString.codeUnitAt(i) & 0xff).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String hexToBytes(String hex) {
  final String normalized = hex.replaceAll(RegExp(r'\s+'), '');
  if (normalized.length.isOdd) {
    throw ArgumentError.value(
        hex, 'hex', 'Hex string must have an even length.');
  }
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < normalized.length; i += 2) {
    buffer.writeCharCode(int.parse(normalized.substring(i, i + 2), radix: 16));
  }
  return buffer.toString();
}

String processOwnerPassword(
    String paddedUserPassword, String paddedOwnerPassword) {
  final String key = md5BinaryString(paddedOwnerPassword).substring(0, 5);
  return rc4(key, paddedUserPassword);
}

String rc4(String key, String data) {
  if (key.isEmpty) {
    throw ArgumentError.value(key, 'key', 'RC4 key must not be empty.');
  }

  final List<int> state = List<int>.generate(256, (int index) => index);
  int j = 0;
  for (int i = 0; i < 256; i++) {
    final int t = state[i];
    j = (j + t + (key.codeUnitAt(i % key.length) & 0xff)) & 0xff;
    state[i] = state[j];
    state[j] = t;
  }

  int a = 0;
  int b = 0;
  final StringBuffer output = StringBuffer();
  for (int i = 0; i < data.length; i++) {
    a = (a + 1) & 0xff;
    final int t = state[a];
    b = (b + t) & 0xff;
    state[a] = state[b];
    state[b] = t;
    final int k = state[(state[a] + state[b]) & 0xff];
    output.writeCharCode((data.codeUnitAt(i) & 0xff) ^ k);
  }
  return output.toString();
}

String md5HexString(String input) => _md5Bytes(input)
    .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

String md5BinaryString(String input) => String.fromCharCodes(_md5Bytes(input));

List<int> _md5Bytes(String input) {
  final List<int> bytes =
      input.codeUnits.map((int codeUnit) => codeUnit & 0xff).toList();
  final int bitLength = bytes.length * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (int i = 0; i < 8; i++) {
    bytes.add((bitLength >> (8 * i)) & 0xff);
  }

  int a0 = 0x67452301;
  int b0 = 0xefcdab89;
  int c0 = 0x98badcfe;
  int d0 = 0x10325476;

  for (int offset = 0; offset < bytes.length; offset += 64) {
    final List<int> words = List<int>.filled(16, 0);
    for (int i = 0; i < 16; i++) {
      final int j = offset + i * 4;
      words[i] = bytes[j] |
          (bytes[j + 1] << 8) |
          (bytes[j + 2] << 16) |
          (bytes[j + 3] << 24);
    }

    int a = a0;
    int b = b0;
    int c = c0;
    int d = d0;

    for (int i = 0; i < 64; i++) {
      int f;
      int g;
      if (i < 16) {
        f = (b & c) | ((~b) & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | ((~d) & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | (~d));
        g = (7 * i) % 16;
      }

      final int temp = d;
      d = c;
      c = b;
      b = _add32(
        b,
        _leftRotate(
          _add32(_add32(a, f), _add32(_md5K[i], words[g])),
          _md5S[i],
        ),
      );
      a = temp;
    }

    a0 = _add32(a0, a);
    b0 = _add32(b0, b);
    c0 = _add32(c0, c);
    d0 = _add32(d0, d);
  }

  return <int>[
    ..._wordToBytes(a0),
    ..._wordToBytes(b0),
    ..._wordToBytes(c0),
    ..._wordToBytes(d0),
  ];
}

int _add32(int a, int b) => (a + b) & 0xffffffff;

int _leftRotate(int value, int amount) {
  final int unsigned = value & 0xffffffff;
  return ((unsigned << amount) | (unsigned >> (32 - amount))) & 0xffffffff;
}

List<int> _wordToBytes(int value) => <int>[
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];

const List<int> _md5S = <int>[
  7,
  12,
  17,
  22,
  7,
  12,
  17,
  22,
  7,
  12,
  17,
  22,
  7,
  12,
  17,
  22,
  5,
  9,
  14,
  20,
  5,
  9,
  14,
  20,
  5,
  9,
  14,
  20,
  5,
  9,
  14,
  20,
  4,
  11,
  16,
  23,
  4,
  11,
  16,
  23,
  4,
  11,
  16,
  23,
  4,
  11,
  16,
  23,
  6,
  10,
  15,
  21,
  6,
  10,
  15,
  21,
  6,
  10,
  15,
  21,
  6,
  10,
  15,
  21,
];

const List<int> _md5K = <int>[
  0xd76aa478,
  0xe8c7b756,
  0x242070db,
  0xc1bdceee,
  0xf57c0faf,
  0x4787c62a,
  0xa8304613,
  0xfd469501,
  0x698098d8,
  0x8b44f7af,
  0xffff5bb1,
  0x895cd7be,
  0x6b901122,
  0xfd987193,
  0xa679438e,
  0x49b40821,
  0xf61e2562,
  0xc040b340,
  0x265e5a51,
  0xe9b6c7aa,
  0xd62f105d,
  0x02441453,
  0xd8a1e681,
  0xe7d3fbc8,
  0x21e1cde6,
  0xc33707d6,
  0xf4d50d87,
  0x455a14ed,
  0xa9e3e905,
  0xfcefa3f8,
  0x676f02d9,
  0x8d2a4c8a,
  0xfffa3942,
  0x8771f681,
  0x6d9d6122,
  0xfde5380c,
  0xa4beea44,
  0x4bdecfa9,
  0xf6bb4b60,
  0xbebfbc70,
  0x289b7ec6,
  0xeaa127fa,
  0xd4ef3085,
  0x04881d05,
  0xd9d4d039,
  0xe6db99e5,
  0x1fa27cf8,
  0xc4ac5665,
  0xf4292244,
  0x432aff97,
  0xab9423a7,
  0xfc93a039,
  0x655b59c3,
  0x8f0ccc92,
  0xffeff47d,
  0x85845dd1,
  0x6fa87e4f,
  0xfe2ce6e0,
  0xa3014314,
  0x4e0811a1,
  0xf7537e82,
  0xbd3af235,
  0x2ad7d2bb,
  0xeb86d391,
];
