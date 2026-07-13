/// Parser TrueType Font (TTF) para embedding em PDF.
///
/// Decodifica o conteúdo binário de um arquivo TTF,
/// extrai tabelas (head, cmap, hhea, maxp, hmtx, post, OS/2, loca, glyf, name)
/// e prepara dados para embedding em documentos PDF.
///
/// Portado de libs/ttffont.js do jsPDF.

import 'dart:math';

// ============================================================================
// Data — Leitor/escritor de dados binários TTF
// ============================================================================

/// Classe de leitura/escrita de dados binários para parsing de TTF.
class TtfData {
  final List<int> data;
  int pos = 0;

  TtfData([List<int>? rawData]) : data = rawData ?? [];

  int get length => data.length;

  int readByte() {
    if (pos < 0 || pos >= data.length) {
      throw RangeError.range(
          pos, 0, data.length - 1, 'pos', 'Unexpected end of TTF data');
    }
    return data[pos++];
  }

  void writeByte(int byte) {
    if (pos < data.length) {
      data[pos++] = byte;
    } else {
      data.add(byte);
      pos++;
    }
  }

  int readUInt32() {
    final b1 = readByte() * 0x1000000;
    final b2 = readByte() << 16;
    final b3 = readByte() << 8;
    final b4 = readByte();
    return b1 + b2 + b3 + b4;
  }

  void writeUInt32(int val) {
    writeByte((val >> 24) & 0xFF);
    writeByte((val >> 16) & 0xFF);
    writeByte((val >> 8) & 0xFF);
    writeByte(val & 0xFF);
  }

  int readInt32() {
    final val = readUInt32();
    return val >= 0x80000000 ? val - 0x100000000 : val;
  }

  void writeInt32(int val) {
    if (val < 0) val += 0x100000000;
    writeUInt32(val);
  }

  int readUInt16() {
    final b1 = readByte() << 8;
    final b2 = readByte();
    return b1 | b2;
  }

  void writeUInt16(int val) {
    writeByte((val >> 8) & 0xFF);
    writeByte(val & 0xFF);
  }

  int readInt16() {
    final val = readUInt16();
    return val >= 0x8000 ? val - 0x10000 : val;
  }

  void writeInt16(int val) {
    if (val < 0) val += 0x10000;
    writeUInt16(val);
  }

  int readShort() => readInt16();
  void writeShort(int val) => writeInt16(val);

  int readInt() => readInt32();
  void writeInt(int val) => writeInt32(val);

  String readString(int length) {
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(String.fromCharCode(readByte()));
    }
    return sb.toString();
  }

  void writeString(String val) {
    for (var i = 0; i < val.length; i++) {
      writeByte(val.codeUnitAt(i));
    }
  }

  int readLongLong() {
    final b1 = readByte();
    final b2 = readByte();
    final b3 = readByte();
    final b4 = readByte();
    final b5 = readByte();
    final b6 = readByte();
    final b7 = readByte();
    final b8 = readByte();
    if (b1 & 0x80 != 0) {
      return ((b1 ^ 0xFF) * 0x100000000000000 +
              (b2 ^ 0xFF) * 0x1000000000000 +
              (b3 ^ 0xFF) * 0x10000000000 +
              (b4 ^ 0xFF) * 0x100000000 +
              (b5 ^ 0xFF) * 0x1000000 +
              (b6 ^ 0xFF) * 0x10000 +
              (b7 ^ 0xFF) * 0x100 +
              (b8 ^ 0xFF) +
              1) *
          -1;
    }
    return b1 * 0x100000000000000 +
        b2 * 0x1000000000000 +
        b3 * 0x10000000000 +
        b4 * 0x100000000 +
        b5 * 0x1000000 +
        b6 * 0x10000 +
        b7 * 0x100 +
        b8;
  }

  void writeLongLong(int val) {
    final high = val ~/ 0x100000000;
    final low = val & 0xFFFFFFFF;
    writeByte((high >> 24) & 0xFF);
    writeByte((high >> 16) & 0xFF);
    writeByte((high >> 8) & 0xFF);
    writeByte(high & 0xFF);
    writeByte((low >> 24) & 0xFF);
    writeByte((low >> 16) & 0xFF);
    writeByte((low >> 8) & 0xFF);
    writeByte(low & 0xFF);
  }

  List<int> read(int bytes) {
    if (bytes < 0) {
      throw ArgumentError.value(
          bytes, 'bytes', 'Read length must not be negative.');
    }
    if (pos + bytes > data.length) {
      throw RangeError.range(
          pos + bytes, 0, data.length, 'pos', 'Unexpected end of TTF data');
    }
    final buf = <int>[];
    for (var i = 0; i < bytes; i++) {
      buf.add(readByte());
    }
    return buf;
  }

  void write(List<int> bytes) {
    for (final b in bytes) {
      writeByte(b);
    }
  }
}

// ============================================================================
// Directory — Diretório de tabelas do arquivo TTF
// ============================================================================

class _TableEntry {
  final String tag;
  final int checksum;
  final int offset;
  final int length;
  _TableEntry(this.tag, this.checksum, this.offset, this.length);
}

class TtfDirectory {
  late int scalarType;
  late int tableCount;
  late int searchRange;
  late int entrySelector;
  late int rangeShift;
  final Map<String, _TableEntry> tables = {};

  TtfDirectory(TtfData data) {
    scalarType = data.readInt();
    if (scalarType != 0x00010000 && scalarType != 0x74727565) {
      throw FormatException(
          'Unsupported sfnt scalar type: 0x${scalarType.toRadixString(16)}.');
    }
    tableCount = data.readShort();
    searchRange = data.readShort();
    entrySelector = data.readShort();
    rangeShift = data.readShort();
    for (var i = 0; i < tableCount; i++) {
      final entry = _TableEntry(
        data.readString(4),
        data.readInt(),
        data.readInt(),
        data.readInt(),
      );
      if (entry.offset < 0 ||
          entry.length < 0 ||
          entry.offset + entry.length > data.length) {
        throw FormatException('Invalid TTF table bounds for ${entry.tag}.');
      }
      tables[entry.tag] = entry;
    }
  }

  List<int> encode(Map<String, List<int>> tables) {
    final tableCount = tables.length;
    final log2val = log(2);
    final sr = (log(tableCount) / log2val).floor() * 16;
    final es = (sr / log2val).floor();
    final rs = tableCount * 16 - sr;

    final directory = TtfData();
    directory.writeInt(scalarType);
    directory.writeShort(tableCount);
    directory.writeShort(sr);
    directory.writeShort(es);
    directory.writeShort(rs);

    final directoryLength = tableCount * 16;
    var offset = directory.pos + directoryLength;
    int? headOffset;
    var tableData = <int>[];

    for (final tag in tables.keys) {
      final table = tables[tag]!;
      directory.writeString(tag);
      directory.writeInt(_checksum(table));
      directory.writeInt(offset);
      directory.writeInt(table.length);
      tableData.addAll(table);
      if (tag == 'head') {
        headOffset = offset;
      }
      offset += table.length;
      while (offset % 4 != 0) {
        tableData.add(0);
        offset++;
      }
    }
    directory.write(tableData);

    final sum = _checksum(directory.data);
    final adjustment = 0xB1B0AFBA - sum;
    directory.pos = headOffset! + 8;
    directory.writeUInt32(adjustment & 0xFFFFFFFF);

    return directory.data;
  }

  static int _checksum(List<int> data) {
    final d = List<int>.from(data);
    while (d.length % 4 != 0) {
      d.add(0);
    }
    final tmp = TtfData(d);
    var sum = 0;
    for (var i = 0; i < d.length; i += 4) {
      sum += tmp.readUInt32();
    }
    return sum & 0xFFFFFFFF;
  }
}

// ============================================================================
// Table base class
// ============================================================================

abstract class _TtfTable {
  final TTFFont file;
  String get tag;
  bool exists = false;
  int offset = 0;
  int length = 0;

  _TtfTable(this.file) {
    final info = file.directory.tables[tag];
    exists = info != null;
    if (info != null) {
      offset = info.offset;
      length = info.length;
      parse(file.contents);
    }
  }

  void parse(TtfData data);

  List<int>? raw() {
    if (!exists) return null;
    file.contents.pos = offset;
    return file.contents.read(length);
  }
}

// ============================================================================
// HeadTable
// ============================================================================

class _HeadTable extends _TtfTable {
  @override
  String get tag => 'head';

  late int version, revision, checkSumAdjustment, magicNumber;
  late int flags, unitsPerEm;
  late int created, modified;
  late int xMin, yMin, xMax, yMax;
  late int macStyle, lowestRecPPEM, fontDirectionHint;
  late int indexToLocFormat, glyphDataFormat;

  _HeadTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    version = data.readInt();
    revision = data.readInt();
    checkSumAdjustment = data.readInt();
    magicNumber = data.readInt();
    flags = data.readShort();
    unitsPerEm = data.readShort();
    created = data.readLongLong();
    modified = data.readLongLong();
    xMin = data.readShort();
    yMin = data.readShort();
    xMax = data.readShort();
    yMax = data.readShort();
    macStyle = data.readShort();
    lowestRecPPEM = data.readShort();
    fontDirectionHint = data.readShort();
    indexToLocFormat = data.readShort();
    glyphDataFormat = data.readShort();
  }

  List<int> encode(int indexToLocFmt) {
    final table = TtfData();
    table.writeInt(version);
    table.writeInt(revision);
    table.writeInt(checkSumAdjustment);
    table.writeInt(magicNumber);
    table.writeShort(flags);
    table.writeShort(unitsPerEm);
    table.writeLongLong(created);
    table.writeLongLong(modified);
    table.writeShort(xMin);
    table.writeShort(yMin);
    table.writeShort(xMax);
    table.writeShort(yMax);
    table.writeShort(macStyle);
    table.writeShort(lowestRecPPEM);
    table.writeShort(fontDirectionHint);
    table.writeShort(indexToLocFmt);
    table.writeShort(glyphDataFormat);
    return table.data;
  }
}

// ============================================================================
// CmapEntry & CmapTable
// ============================================================================

class _CmapEntry {
  late int platformID, encodingID;
  late int offset, format, entryLength, language;
  late bool isUnicode;
  final Map<int, int> codeMap = {};

  _CmapEntry(TtfData data, int tableOffset) {
    platformID = data.readUInt16();
    encodingID = data.readShort();
    offset = tableOffset + data.readInt();
    final saveOffset = data.pos;
    data.pos = offset;
    format = data.readUInt16();
    if (format == 12) {
      data.readUInt16(); // reserved
      entryLength = data.readUInt32();
      language = data.readUInt32();
    } else {
      entryLength = data.readUInt16();
      language = data.readUInt16();
    }
    isUnicode = (platformID == 3 && encodingID == 1 && format == 4) ||
        (platformID == 3 && encodingID == 10 && format == 12) ||
        (platformID == 0 && (format == 4 || format == 12));

    switch (format) {
      case 0:
        for (var i = 0; i < 256; i++) {
          codeMap[i] = data.readByte();
        }
        break;
      case 4:
        final segCountX2 = data.readUInt16();
        final segCount = segCountX2 ~/ 2;
        data.pos += 6;
        final endCode = [for (var i = 0; i < segCount; i++) data.readUInt16()];
        data.pos += 2;
        final startCode = [
          for (var i = 0; i < segCount; i++) data.readUInt16()
        ];
        final idDelta = [for (var i = 0; i < segCount; i++) data.readUInt16()];
        final idRangeOffset = [
          for (var i = 0; i < segCount; i++) data.readUInt16()
        ];
        final count = (entryLength - data.pos + offset) ~/ 2;
        final glyphIds = [for (var i = 0; i < count; i++) data.readUInt16()];

        for (var i = 0; i < endCode.length; i++) {
          final tail = endCode[i];
          final start = startCode[i];
          for (var code = start; code <= tail; code++) {
            int glyphId;
            if (idRangeOffset[i] == 0) {
              glyphId = code + idDelta[i];
            } else {
              final index =
                  idRangeOffset[i] ~/ 2 + (code - start) - (segCount - i);
              glyphId =
                  (index >= 0 && index < glyphIds.length) ? glyphIds[index] : 0;
              if (glyphId != 0) glyphId += idDelta[i];
            }
            codeMap[code] = glyphId & 0xFFFF;
          }
        }
        break;
      case 6:
        final firstCode = data.readUInt16();
        final entryCount = data.readUInt16();
        for (var i = 0; i < entryCount; i++) {
          codeMap[firstCode + i] = data.readUInt16();
        }
        break;
      case 12:
        final groupCount = data.readUInt32();
        for (var i = 0; i < groupCount; i++) {
          final startCharCode = data.readUInt32();
          final endCharCode = data.readUInt32();
          final startGlyphId = data.readUInt32();
          for (var code = startCharCode; code <= endCharCode; code++) {
            codeMap[code] = startGlyphId + (code - startCharCode);
          }
        }
        break;
    }
    data.pos = saveOffset;
  }

  static Map<String, dynamic> encodeUnicode(Map<int, int> charmap) {
    final subtable = TtfData();
    final codes = charmap.keys.toList()..sort();

    final startCodes = <int>[];
    final endCodes = <int>[];
    var nextID = 0;
    final mapObj = <int, int>{};
    final charMap = <int, Map<String, int>>{};
    int? last;
    int? diff;

    for (final code in codes) {
      final old = charmap[code]!;
      mapObj[old] ??= ++nextID;
      charMap[code] = {'old': old, 'new': mapObj[old]!};
      final delta = mapObj[old]! - code;
      if (last == null || delta != diff) {
        if (last != null) endCodes.add(last);
        startCodes.add(code);
        diff = delta;
      }
      last = code;
    }
    if (last != null) endCodes.add(last);
    endCodes.add(0xFFFF);
    startCodes.add(0xFFFF);

    final segCount = startCodes.length;
    final segCountX2 = segCount * 2;
    final searchRange = (pow(2, (log(segCount) / ln2).floor()) * 2).toInt();
    final entrySelectr = (log(searchRange / 2) / ln2).toInt();
    final rangeShift = 2 * segCount - searchRange;

    final deltas = <int>[];
    final rangeOffsets = <int>[];
    final glyphIDs = <int>[];

    for (var i = 0; i < startCodes.length; i++) {
      final startCode = startCodes[i];
      final endCode = endCodes[i];
      if (startCode == 0xFFFF) {
        deltas.add(0);
        rangeOffsets.add(0);
        break;
      }
      final startGlyph = charMap[startCode]!['new']!;
      if (startCode - startGlyph >= 0x8000) {
        deltas.add(0);
        rangeOffsets.add(2 * (glyphIDs.length + segCount - i));
        for (var code = startCode; code <= endCode; code++) {
          glyphIDs.add(charMap[code]!['new']!);
        }
      } else {
        deltas.add(startGlyph - startCode);
        rangeOffsets.add(0);
      }
    }

    subtable.writeUInt16(3);
    subtable.writeUInt16(1);
    subtable.writeUInt32(12);
    subtable.writeUInt16(4);
    subtable.writeUInt16(16 + segCount * 8 + glyphIDs.length * 2);
    subtable.writeUInt16(0);
    subtable.writeUInt16(segCountX2);
    subtable.writeUInt16(searchRange);
    subtable.writeUInt16(entrySelectr);
    subtable.writeUInt16(rangeShift);
    for (final code in endCodes) subtable.writeUInt16(code);
    subtable.writeUInt16(0);
    for (final code in startCodes) subtable.writeUInt16(code);
    for (final d in deltas) subtable.writeUInt16(d);
    for (final o in rangeOffsets) subtable.writeUInt16(o);
    for (final id in glyphIDs) subtable.writeUInt16(id);

    return {
      'charMap': charMap,
      'subtable': subtable.data,
      'maxGlyphID': nextID + 1,
    };
  }
}

class _CmapTable extends _TtfTable {
  @override
  String get tag => 'cmap';

  late int version;
  final List<_CmapEntry> tables = [];
  _CmapEntry? unicode;

  _CmapTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    version = data.readUInt16();
    final tableCount = data.readUInt16();
    for (var i = 0; i < tableCount; i++) {
      final entry = _CmapEntry(data, offset);
      tables.add(entry);
      if (entry.isUnicode &&
          (unicode == null || _cmapPriority(entry) > _cmapPriority(unicode!))) {
        unicode = entry;
      }
    }
  }

  int _cmapPriority(_CmapEntry entry) {
    if (entry.format == 12 && entry.platformID == 3 && entry.encodingID == 10) {
      return 4;
    }
    if (entry.format == 12 && entry.platformID == 0) return 3;
    if (entry.format == 4 && entry.platformID == 3 && entry.encodingID == 1) {
      return 2;
    }
    if (entry.format == 4 && entry.platformID == 0) return 1;
    return 0;
  }

  static Map<String, dynamic> encode(Map<int, int> charmap,
      [String encoding = 'unicode']) {
    final result = _CmapEntry.encodeUnicode(charmap);
    final table = TtfData();
    table.writeUInt16(0);
    table.writeUInt16(1);
    result['table'] = table.data + (result['subtable'] as List<int>);
    return result;
  }
}

// ============================================================================
// HheaTable
// ============================================================================

class _HheaTable extends _TtfTable {
  @override
  String get tag => 'hhea';

  late int version, ascender, decender, lineGap;
  late int advanceWidthMax, minLeftSideBearing, minRightSideBearing, xMaxExtent;
  late int caretSlopeRise, caretSlopeRun, caretOffset;
  late int metricDataFormat, numberOfMetrics;

  _HheaTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    version = data.readInt();
    ascender = data.readShort();
    decender = data.readShort();
    lineGap = data.readShort();
    advanceWidthMax = data.readShort();
    minLeftSideBearing = data.readShort();
    minRightSideBearing = data.readShort();
    xMaxExtent = data.readShort();
    caretSlopeRise = data.readShort();
    caretSlopeRun = data.readShort();
    caretOffset = data.readShort();
    data.pos += 4 * 2;
    metricDataFormat = data.readShort();
    numberOfMetrics = data.readUInt16();
  }
}

// ============================================================================
// OS2Table
// ============================================================================

class _OS2Table extends _TtfTable {
  @override
  String get tag => 'OS/2';

  int version = 0;
  int ascender = 0, decender = 0, lineGap = 0;
  int familyClass = 0;
  int capHeight = 0, xHeight = 0;

  _OS2Table(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    version = data.readUInt16();
    data.readShort(); // averageCharWidth
    data.readUInt16(); // weightClass
    data.readUInt16(); // widthClass
    data.readShort(); // type
    for (var i = 0; i < 8; i++) data.readShort(); // subscript/superscript
    data.readShort(); // yStrikeoutSize
    data.readShort(); // yStrikeoutPosition
    familyClass = data.readShort();
    for (var i = 0; i < 10; i++) data.readByte(); // panose
    for (var i = 0; i < 4; i++) data.readInt(); // charRange
    data.readString(4); // vendorID
    data.readShort(); // selection
    data.readShort(); // firstCharIndex
    data.readShort(); // lastCharIndex
    if (version > 0) {
      ascender = data.readShort();
      decender = data.readShort();
      lineGap = data.readShort();
      data.readShort(); // winAscent
      data.readShort(); // winDescent
      for (var i = 0; i < 2; i++) data.readInt(); // codePageRange
      if (version > 1) {
        xHeight = data.readShort();
        capHeight = data.readShort();
      }
    }
  }
}

// ============================================================================
// PostTable
// ============================================================================

class _PostTable extends _TtfTable {
  @override
  String get tag => 'post';

  late int format;
  int italicAngle = 0;
  int isFixedPitch = 0;

  _PostTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    format = data.readInt();
    italicAngle = data.readInt();
    data.readShort(); // underlinePosition
    data.readShort(); // underlineThickness
    isFixedPitch = data.readInt();
  }
}

// ============================================================================
// NameTable
// ============================================================================

class _NameEntry {
  final String raw;
  final int platformID, encodingID, languageID;
  int get length => raw.length;

  _NameEntry(this.raw, this.platformID, this.encodingID, this.languageID);
}

class _NameTable extends _TtfTable {
  @override
  String get tag => 'name';

  final Map<int, List<_NameEntry>> strings = {};
  String postscriptName = '';

  _NameTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    data.readShort(); // format
    final count = data.readShort();
    final stringOffset = data.readShort();
    final entries = <Map<String, int>>[];

    for (var i = 0; i < count; i++) {
      entries.add({
        'platformID': data.readShort(),
        'encodingID': data.readShort(),
        'languageID': data.readShort(),
        'nameID': data.readShort(),
        'length': data.readShort(),
        'offset': offset + stringOffset + data.readShort(),
      });
    }

    for (final entry in entries) {
      data.pos = entry['offset']!;
      final bytes = data.read(entry['length']!);
      final text = _decodeNameBytes(
        bytes,
        entry['platformID']!,
        entry['encodingID']!,
      );
      final name = _NameEntry(
        text,
        entry['platformID']!,
        entry['encodingID']!,
        entry['languageID']!,
      );
      strings.putIfAbsent(entry['nameID']!, () => []).add(name);
    }

    // postscriptName — nameID 6 ou fallback para 4
    try {
      postscriptName = _safePostScriptName(strings[6]![0].raw);
    } catch (_) {
      try {
        postscriptName = _safePostScriptName(strings[4]![0].raw);
      } catch (_) {
        postscriptName = 'Unknown';
      }
    }
  }

  String? getName(int nameId, {int? languageID}) {
    final values = strings[nameId];
    if (values == null || values.isEmpty) return null;
    if (languageID != null) {
      for (final value in values) {
        if (value.languageID == languageID) return value.raw;
      }
    }
    for (final value in values) {
      if (value.platformID == 3 && value.languageID == 0x0409) return value.raw;
    }
    return values.first.raw;
  }

  String _decodeNameBytes(List<int> bytes, int platformID, int encodingID) {
    if (platformID == 0 || platformID == 3) {
      final buffer = StringBuffer();
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        buffer.writeCharCode((bytes[i] << 8) | bytes[i + 1]);
      }
      return buffer.toString();
    }
    return String.fromCharCodes(bytes.map((byte) => byte & 0xff));
  }

  String _safePostScriptName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^!#-;=?-~]'), '');
    return cleaned.isEmpty ? 'Unknown' : cleaned;
  }
}

// ============================================================================
// MaxpTable
// ============================================================================

class _MaxpTable extends _TtfTable {
  @override
  String get tag => 'maxp';

  int numGlyphs = 0;

  _MaxpTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    data.readInt(); // version
    numGlyphs = data.readUInt16();
  }
}

// ============================================================================
// HmtxTable
// ============================================================================

class _HmtxMetric {
  final int advance;
  final int lsb;
  _HmtxMetric(this.advance, this.lsb);
}

class _HmtxTable extends _TtfTable {
  @override
  String get tag => 'hmtx';

  final List<_HmtxMetric> metrics = [];
  final List<int> leftSideBearings = [];
  final List<int> widths = [];

  _HmtxTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    for (var i = 0; i < file.hhea.numberOfMetrics; i++) {
      metrics.add(_HmtxMetric(data.readUInt16(), data.readInt16()));
    }
    final lsbCount = file.maxp.numGlyphs - file.hhea.numberOfMetrics;
    for (var i = 0; i < lsbCount; i++) {
      leftSideBearings.add(data.readInt16());
    }
    widths.addAll(metrics.map((m) => m.advance));
    if (widths.isNotEmpty) {
      final last = widths.last;
      for (var i = 0; i < lsbCount; i++) {
        widths.add(last);
      }
    }
  }

  _HmtxMetric forGlyph(int id) {
    if (id < metrics.length) return metrics[id];
    final lsbIndex = id - metrics.length;
    return _HmtxMetric(
      metrics.isEmpty ? 0 : metrics.last.advance,
      lsbIndex < leftSideBearings.length ? leftSideBearings[lsbIndex] : 0,
    );
  }
}

// ============================================================================
// LocaTable
// ============================================================================

class _LocaTable extends _TtfTable {
  @override
  String get tag => 'loca';

  final List<int> offsets = [];

  _LocaTable(super.file);

  @override
  void parse(TtfData data) {
    data.pos = offset;
    final format = file.head.indexToLocFormat;
    if (format == 0) {
      for (var i = 0; i < length; i += 2) {
        offsets.add(data.readUInt16() * 2);
      }
    } else {
      for (var i = 0; i < length; i += 4) {
        offsets.add(data.readUInt32());
      }
    }
  }

  int indexOf(int id) => id < offsets.length ? offsets[id] : 0;
  int lengthOf(int id) =>
      (id + 1 < offsets.length) ? offsets[id + 1] - offsets[id] : 0;

  List<int> encode(List<int> glyfOffsets, List<int> activeGlyphs) {
    final locaTable = List<int>.filled(offsets.length, 0);
    var glyfPtr = 0;
    var listGlyf = 0;
    for (var k = 0; k < locaTable.length; k++) {
      locaTable[k] = glyfPtr;
      if (listGlyf < activeGlyphs.length && activeGlyphs[listGlyf] == k) {
        listGlyf++;
        locaTable[k] = glyfPtr;
        final start = offsets[k];
        final len = (k + 1 < offsets.length) ? offsets[k + 1] - start : 0;
        if (len > 0) glyfPtr += len;
      }
    }
    final newLocaTable = List<int>.filled(locaTable.length * 4, 0);
    for (var j = 0; j < locaTable.length; j++) {
      newLocaTable[4 * j + 3] = locaTable[j] & 0xFF;
      newLocaTable[4 * j + 2] = (locaTable[j] & 0xFF00) >> 8;
      newLocaTable[4 * j + 1] = (locaTable[j] & 0xFF0000) >> 16;
      newLocaTable[4 * j] = (locaTable[j] & 0xFF000000) >> 24;
    }
    return newLocaTable;
  }
}

// ============================================================================
// GlyfTable & Glyphs
// ============================================================================

abstract class _Glyph {
  final TtfData raw;
  final int xMin, yMin, xMax, yMax;
  bool get compound;
  _Glyph(this.raw, this.xMin, this.yMin, this.xMax, this.yMax);
  List<int> encode([Map<int, int>? old2new]) => raw.data;
}

class _SimpleGlyph extends _Glyph {
  final int numberOfContours;
  @override
  bool get compound => false;
  _SimpleGlyph(super.raw, this.numberOfContours, super.xMin, super.yMin,
      super.xMax, super.yMax);
}

class _CompoundGlyph extends _Glyph {
  static const _moreComponents = 0x0020;
  static const _arg12AreWords = 0x0001;
  static const _weHaveAScale = 0x0008;
  static const _weHaveXAndYScale = 0x0040;
  static const _weHaveTwoByTwo = 0x0080;

  @override
  bool get compound => true;

  final List<int> glyphIDs = [];
  final List<int> glyphOffsets = [];

  _CompoundGlyph(TtfData raw, int xMin, int yMin, int xMax, int yMax)
      : super(raw, xMin, yMin, xMax, yMax) {
    final data = raw;
    while (true) {
      final flags = data.readShort();
      glyphOffsets.add(data.pos);
      glyphIDs.add(data.readUInt16());
      if (flags & _arg12AreWords != 0) {
        data.pos += 4;
      } else {
        data.pos += 2;
      }
      if (flags & _weHaveTwoByTwo != 0) {
        data.pos += 8;
      } else if (flags & _weHaveXAndYScale != 0) {
        data.pos += 4;
      } else if (flags & _weHaveAScale != 0) {
        data.pos += 2;
      }
      if (flags & _moreComponents == 0) break;
    }
  }

  @override
  List<int> encode([Map<int, int>? old2new]) {
    if (old2new == null || old2new.isEmpty) return raw.data;
    final encoded = List<int>.from(raw.data);
    for (var i = 0; i < glyphIDs.length; i++) {
      final newId = old2new[glyphIDs[i]] ?? glyphIDs[i];
      final offset = glyphOffsets[i];
      encoded[offset] = (newId >> 8) & 0xff;
      encoded[offset + 1] = newId & 0xff;
    }
    return encoded;
  }
}

class _GlyfTable extends _TtfTable {
  @override
  String get tag => 'glyf';

  final Map<int, _Glyph?> _cache = {};

  _GlyfTable(super.file);

  @override
  void parse(TtfData data) {
    // Lazy — parsing por demanda via glyphFor
  }

  _Glyph? glyphFor(int id) {
    if (_cache.containsKey(id)) return _cache[id];
    final loca = file.loca;
    final data = file.contents;
    final index = loca.indexOf(id);
    final len = loca.lengthOf(id);
    if (len == 0) {
      _cache[id] = null;
      return null;
    }
    data.pos = offset + index;
    final raw = TtfData(List<int>.from(data.read(len)));
    final numberOfContours = raw.readShort();
    final xMin = raw.readShort();
    final yMin = raw.readShort();
    final xMax = raw.readShort();
    final yMax = raw.readShort();
    if (numberOfContours == -1) {
      _cache[id] = _CompoundGlyph(raw, xMin, yMin, xMax, yMax);
    } else {
      _cache[id] = _SimpleGlyph(raw, numberOfContours, xMin, yMin, xMax, yMax);
    }
    return _cache[id];
  }

  Map<String, dynamic> encodeGlyphs(
      Map<int, _Glyph?> glyphs, List<int> mapping, Map<int, int> old2new) {
    var table = <int>[];
    final offsets = <int>[];
    for (final id in mapping) {
      final glyph = glyphs[id];
      offsets.add(table.length);
      if (glyph != null) {
        table = [...table, ...glyph.encode(old2new)];
      }
    }
    offsets.add(table.length);
    return {'table': table, 'offsets': offsets};
  }
}

// ============================================================================
// Subset
// ============================================================================

class _Subset {
  final TTFFont font;
  final Map<int, int> subset = {};
  final Map<int, int> unicodes = {};
  int next = 33;

  _Subset(this.font);

  Map<int, int> generateCmap() {
    final unicodeCmap = font.cmap.unicode?.codeMap ?? <int, int>{};
    final mapping = <int, int>{};
    if (font.toUnicode.isNotEmpty) {
      for (final entry in font.toUnicode.entries) {
        final glyphId = entry.key;
        final unicode = entry.value;
        if (unicodeCmap[unicode] == glyphId) {
          mapping[unicode] = glyphId;
        }
      }
      return mapping;
    }
    for (final glyphId in font.glyIdsUsed.toSet()) {
      for (final entry in unicodeCmap.entries) {
        if (entry.value == glyphId) {
          mapping[entry.key] = glyphId;
          break;
        }
      }
    }
    return mapping;
  }

  Map<int, _Glyph?> glyphsFor(List<int> glyphIDs) {
    final glyphs = <int, _Glyph?>{};
    for (final id in glyphIDs) {
      glyphs[id] = font.glyf.glyphFor(id);
    }
    final additionalIDs = <int>[];
    for (final glyph in glyphs.values) {
      if (glyph != null && glyph.compound) {
        additionalIDs.addAll((glyph as _CompoundGlyph).glyphIDs);
      }
    }
    if (additionalIDs.isNotEmpty) {
      final extra = glyphsFor(additionalIDs);
      glyphs.addAll(extra);
    }
    return glyphs;
  }

  List<int> encode(List<int> glyIDs, int indexToLocFormat) {
    final normalizedGlyphIds = <int>{0, ...glyIDs}.toList()..sort();
    final cmap = _CmapTable.encode(generateCmap(), 'unicode');
    final glyphs = glyphsFor(normalizedGlyphIds);
    final old2new = <int, int>{0: 0};
    final charMapData = cmap['charMap'] as Map<int, Map<String, int>>;
    for (final ids in charMapData.values) {
      old2new[ids['old']!] = ids['new']!;
    }
    var nextGlyphID = cmap['maxGlyphID'] as int;
    for (final oldID in glyphs.keys.toList()..sort()) {
      if (!old2new.containsKey(oldID)) {
        old2new[oldID] = nextGlyphID++;
      }
    }
    final new2old = <int, int>{};
    for (final e in old2new.entries) {
      new2old[e.value] = e.key;
    }
    final newIDs = new2old.keys.toList()..sort();
    final oldIDs = newIDs.map((id) => new2old[id]!).toList();
    final glyf = font.glyf.encodeGlyphs(glyphs, oldIDs, old2new);
    final loca = font.loca.encode(
      glyf['offsets'] as List<int>,
      oldIDs,
    );

    final tables = <String, List<int>>{
      'cmap': font.cmap.raw()!,
      'glyf': glyf['table'] as List<int>,
      'loca': loca,
      'hmtx': font.hmtx.raw()!,
      'hhea': font.hhea.raw()!,
      'maxp': font.maxp.raw()!,
      'post': font.post.raw()!,
      'name': font.nameTable.raw()!,
      'head': font.head.encode(indexToLocFormat),
    };
    if (font.os2.exists) {
      tables['OS/2'] = font.os2.raw()!;
    }
    return font.directory.encode(tables);
  }
}

// ============================================================================
// PDFObject converter
// ============================================================================

/// Converte valores Dart para formato PDF inline.
class PDFObject {
  static String convert(dynamic object) {
    if (object is List) {
      final items = object.map((e) => convert(e)).join(' ');
      return '[$items]';
    } else if (object is String) {
      return '/$object';
    } else if (object is DateTime) {
      final y = object.toUtc().year.toString().padLeft(4, '0');
      final m = object.toUtc().month.toString().padLeft(2, '0');
      final d = object.toUtc().day.toString().padLeft(2, '0');
      final h = object.toUtc().hour.toString().padLeft(2, '0');
      final mn = object.toUtc().minute.toString().padLeft(2, '0');
      final s = object.toUtc().second.toString().padLeft(2, '0');
      return '(D:$y$m$d$h$mn${s}Z)';
    } else if (object is Map) {
      final out = <String>['<<'];
      for (final key in object.keys) {
        out.add('/$key ${convert(object[key])}');
      }
      out.add('>>');
      return out.join('\n');
    } else {
      return '$object';
    }
  }
}

// ============================================================================
// TTFFont — Classe principal
// ============================================================================

/// Parser de fontes TrueType.
///
/// Decodifica o conteúdo binário de um arquivo .ttf,
/// extrai tabelas e prepara dados para embedding em PDF.
class TTFFont {
  /// Dados brutos do arquivo TTF.
  final List<int> rawData;

  /// Leitor de dados.
  late TtfData contents;

  /// Diretório de tabelas.
  late TtfDirectory directory;

  // Tabelas
  late _HeadTable head;
  late _NameTable nameTable;
  late _CmapTable cmap;
  late _HheaTable hhea;
  late _MaxpTable maxp;
  late _HmtxTable hmtx;
  late _PostTable post;
  late _OS2Table os2;
  late _LocaTable loca;
  late _GlyfTable glyf;

  /// Subset encoder.
  late _Subset subset;

  /// Mapa de glyph IDs usados.
  final List<int> glyIdsUsed = [];

  /// Mapa glyphID → unicode.
  final Map<int, int> toUnicode = {};

  /// Bounding box escalada.
  late List<int> bbox;

  /// Fator de escala (1000/unitsPerEm).
  late double scaleFactor;

  /// Métricas escaladas.
  late int ascender, decender, lineGapScaled;
  late int capHeight, xHeight;
  late int stemV;
  late double italicAngle;
  late int flags;

  /// Unicode data (para pdf encoding).
  late TtfUnicodeData unicodeData;

  String get postScriptName => nameTable.postscriptName;
  String? get fullName => nameTable.getName(4);
  String? get familyName => nameTable.getName(1);
  String? get subfamilyName => nameTable.getName(2);

  /// Abre/decodifica um arquivo TTF.
  factory TTFFont.open(List<int> rawData) => TTFFont(rawData);

  TTFFont(this.rawData) {
    contents = TtfData(List<int>.from(rawData));
    contents.pos = 4;
    if (contents.readString(4) == 'ttcf') {
      throw UnsupportedError('TTCF (TrueType Collection) not supported.');
    }
    contents.pos = 0;
    _parse();
    subset = _Subset(this);
    _registerTTF();
  }

  void _parse() {
    directory = TtfDirectory(contents);
    head = _HeadTable(this);
    nameTable = _NameTable(this);
    cmap = _CmapTable(this);
    hhea = _HheaTable(this);
    maxp = _MaxpTable(this);
    hmtx = _HmtxTable(this);
    post = _PostTable(this);
    os2 = _OS2Table(this);
    loca = _LocaTable(this);
    glyf = _GlyfTable(this);

    ascender = (os2.exists && os2.ascender != 0) ? os2.ascender : hhea.ascender;
    decender = (os2.exists && os2.decender != 0) ? os2.decender : hhea.decender;
    lineGapScaled =
        (os2.exists && os2.lineGap != 0) ? os2.lineGap : hhea.lineGap;
    bbox = [head.xMin, head.yMin, head.xMax, head.yMax];
  }

  void _registerTTF() {
    scaleFactor = 1000.0 / head.unitsPerEm;
    bbox = bbox.map((e) => (e * scaleFactor).round()).toList();
    stemV = 0;

    if (post.exists) {
      final raw = post.italicAngle;
      var hi = raw >> 16;
      final low = raw & 0xFF;
      if (hi & 0x8000 != 0) {
        hi = -((hi ^ 0xFFFF) + 1);
      }
      italicAngle = double.parse('$hi.$low');
    } else {
      italicAngle = 0;
    }

    ascender = (ascender * scaleFactor).round();
    decender = (decender * scaleFactor).round();
    lineGapScaled = (lineGapScaled * scaleFactor).round();
    capHeight = (os2.exists && os2.capHeight != 0)
        ? (os2.capHeight * scaleFactor).round()
        : ascender;
    xHeight = (os2.exists && os2.xHeight != 0)
        ? (os2.xHeight * scaleFactor).round()
        : 0;

    final familyClass = (os2.exists ? os2.familyClass : 0) >> 8;
    final isSerif = [1, 2, 3, 4, 5, 7].contains(familyClass);
    final isScript = familyClass == 10;

    flags = 0;
    if (post.isFixedPitch != 0) flags |= 1 << 0;
    if (isSerif) flags |= 1 << 1;
    if (isScript) flags |= 1 << 3;
    if (italicAngle != 0) flags |= 1 << 6;
    flags |= 1 << 5;

    if (cmap.unicode == null) {
      throw StateError('No unicode cmap for font');
    }

    // Inicializa dados Unicode para uso do módulo utf8
    unicodeData = TtfUnicodeData(widths: []);
  }

  /// Mapeia character code para glyph ID.
  int characterToGlyph(int character) {
    return cmap.unicode?.codeMap[character] ?? 0;
  }

  /// Mapeia uma string Dart para code points Unicode, incluindo pares surrogate.
  List<int> codePoints(String text) => text.runes.toList(growable: false);

  /// Largura de um glyph em milésimos.
  double widthOfGlyph(int glyph) {
    final scale = 1000.0 / head.unitsPerEm;
    return hmtx.forGlyph(glyph).advance * scale;
  }

  /// Largura de uma string em pontos.
  double widthOfString(String str, double size, [double charSpace = 0]) {
    var width = 0.0;
    for (final charCode in str.runes) {
      width +=
          widthOfGlyph(characterToGlyph(charCode)) + charSpace * (1000 / size);
    }
    return width * (size / 1000);
  }

  /// Altura da linha.
  double lineHeight(double size, {bool includeGap = false}) {
    final gap = includeGap ? lineGapScaled : 0;
    return (ascender + gap - decender) / 1000 * size;
  }
}

/// Dados Unicode para uma fonte TTF (widths para PDF /W entry).
class TtfUnicodeData {
  final List<dynamic> widths;
  TtfUnicodeData({required this.widths});
}
