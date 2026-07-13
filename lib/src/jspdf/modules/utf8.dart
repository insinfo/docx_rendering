/// Módulo UTF-8 para renderização de texto com fontes embarcadas.
///
/// Converte texto para representação hexadecimal usando
/// Identity-H encoding (para fontes TTF embarcadas) ou
/// WinAnsiEncoding (para fontes padrão).
///
/// Portado de modules/utf8.js do jsPDF.

import '../libs/ttffont.dart';
import '../pdfname.dart';

/// Converte texto para representação hexadecimal PDF usando Identity-H.
///
/// [text] é o texto a converter.
/// [font] deve ser um TTFFont com metadata de cmap e Unicode.
/// Retorna a string em representação hexadecimal.
String pdfEscape16(String text, TTFFont font) {
  final padz = ['', '0', '00', '000', '0000'];
  final ar = <String>[''];

  for (final charCode in text.runes) {
    final glyphId = font.characterToGlyph(charCode);

    // Registra o glyph como usado
    font.glyIdsUsed.add(glyphId);
    font.toUnicode[glyphId] = charCode;

    // Adiciona largura se ainda não registrada
    final widths = font.unicodeData.widths;
    var found = false;
    for (var j = 0; j < widths.length; j += 2) {
      if (widths[j] == glyphId) {
        found = true;
        break;
      }
    }
    if (!found) {
      widths.add(glyphId);
      widths.add([font.widthOfGlyph(glyphId).toInt()]);
    }

    if (glyphId == 0) {
      // Espaços não são permitidos no cmap
      return ar.join('');
    } else {
      final hex = glyphId.toRadixString(16);
      ar.add(padz[4 - hex.length]);
      ar.add(hex);
    }
  }
  return ar.join('');
}

/// Gera um CMap ToUnicode para embedding no PDF.
///
/// [map] mapeia glyphID → Unicode code point.
/// Retorna a string CMap completa para o stream do PDF.
String toUnicodeCmap(Map<int, int> map) {
  final sb = StringBuffer();
  sb.write('/CIDInit /ProcSet findresource begin\n');
  sb.write('12 dict begin\n');
  sb.write('begincmap\n');
  sb.write('/CIDSystemInfo <<\n');
  sb.write('  /Registry (Adobe)\n');
  sb.write('  /Ordering (UCS)\n');
  sb.write('  /Supplement 0\n');
  sb.write('>> def\n');
  sb.write('/CMapName /Adobe-Identity-UCS def\n');
  sb.write('/CMapType 2 def\n');
  sb.write('1 begincodespacerange\n');
  sb.write('<0000><ffff>\n');
  sb.write('endcodespacerange');

  final codes = map.keys.toList()..sort();
  final range = <String>[];

  for (final code in codes) {
    if (range.length >= 100) {
      sb.write('\n${range.length} beginbfchar\n');
      sb.write(range.join('\n'));
      sb.write('\nendbfchar');
      range.clear();
    }

    final unicode = map[code];
    if (unicode != null) {
      final unicodeHex = _unicodeToUtf16BeHex(unicode);
      final codeHex = code.toRadixString(16).padLeft(4, '0');
      range.add('<$codeHex><$unicodeHex>');
    }
  }

  if (range.isNotEmpty) {
    sb.write('\n${range.length} beginbfchar\n');
    sb.write(range.join('\n'));
    sb.write('\nendbfchar\n');
  }

  sb.write('endcmap\n');
  sb.write('CMapName currentdict /CMap defineresource pop\n');
  sb.write('end\nend');

  return sb.toString();
}

String _unicodeToUtf16BeHex(int codePoint) {
  if (codePoint <= 0xffff) {
    return codePoint.toRadixString(16).padLeft(4, '0');
  }
  final value = codePoint - 0x10000;
  final high = 0xd800 + (value >> 10);
  final low = 0xdc00 + (value & 0x3ff);
  return high.toRadixString(16).padLeft(4, '0') +
      low.toRadixString(16).padLeft(4, '0');
}

/// Dados para embedding de uma fonte Identity-H no PDF.
class IdentityHFontData {
  /// ID do objeto da tabela da fonte.
  final int fontTableObjId;

  /// ID do objeto do CMap ToUnicode.
  final int cmapObjId;

  /// ID do FontDescriptor.
  final int fontDescriptorObjId;

  /// ID do DescendantFont (CIDFont).
  final int descendantFontObjId;

  /// ID do objeto font principal (Type 0).
  final int fontObjId;

  const IdentityHFontData({
    required this.fontTableObjId,
    required this.cmapObjId,
    required this.fontDescriptorObjId,
    required this.descendantFontObjId,
    required this.fontObjId,
  });
}

/// Dados de uma fonte para uso com Identity-H encoding.
class FontPutData {
  final TTFFont metadata;
  final String fontName;
  final String encoding;
  int? objectNumber;
  bool isAlreadyPutted;

  FontPutData({
    required this.metadata,
    required this.fontName,
    required this.encoding,
    this.objectNumber,
    this.isAlreadyPutted = false,
  });
}

/// Gera os objetos PDF para uma fonte Identity-H (Type 0 / CIDFont).
///
/// [font] contém os metadados da fonte TTF.
/// [out] callback para escrever uma linha no output PDF.
/// [newObject] callback que cria um novo objeto PDF e retorna o ID.
/// [putStream] callback para escrever um stream PDF.
void writeIdentityHFont({
  required FontPutData font,
  required void Function(String line) out,
  required int Function() newObject,
  required void Function({
    required String data,
    bool addLength1,
    required int objectId,
  }) putStream,
}) {
  if (font.encoding != 'Identity-H') return;

  final metadata = font.metadata;
  final widths = metadata.unicodeData.widths;

  // Codifica o subconjunto da fonte
  final encodedData = metadata.subset.encode(metadata.glyIdsUsed, 1);
  final pdfOutput = String.fromCharCodes(encodedData);

  // Font table stream
  final fontTable = newObject();
  putStream(data: pdfOutput, addLength1: true, objectId: fontTable);
  out('endobj');

  // CMap ToUnicode stream
  final cmap = newObject();
  final cmapData = toUnicodeCmap(metadata.toUnicode);
  putStream(data: cmapData, addLength1: true, objectId: cmap);
  out('endobj');

  // Font Descriptor
  final fontDescriptor = newObject();
  out('<<');
  out('/Type /FontDescriptor');
  out('/FontName /${toPDFName(font.fontName)}');
  out('/FontFile2 $fontTable 0 R');
  out('/FontBBox ${PDFObject.convert(metadata.bbox)}');
  out('/Flags ${metadata.flags}');
  out('/StemV ${metadata.stemV}');
  out('/ItalicAngle ${metadata.italicAngle}');
  out('/Ascent ${metadata.ascender}');
  out('/Descent ${metadata.decender}');
  out('/CapHeight ${metadata.capHeight}');
  out('>>');
  out('endobj');

  // Descendant Font (CIDFontType2)
  final descendantFont = newObject();
  out('<<');
  out('/Type /Font');
  out('/BaseFont /${toPDFName(font.fontName)}');
  out('/FontDescriptor $fontDescriptor 0 R');
  out('/W ${PDFObject.convert(widths)}');
  out('/CIDToGIDMap /Identity');
  out('/DW 1000');
  out('/Subtype /CIDFontType2');
  out('/CIDSystemInfo');
  out('<<');
  out('/Supplement 0');
  out('/Registry (Adobe)');
  out('/Ordering (${font.encoding})');
  out('>>');
  out('>>');
  out('endobj');

  // Type 0 font
  font.objectNumber = newObject();
  out('<<');
  out('/Type /Font');
  out('/Subtype /Type0');
  out('/ToUnicode $cmap 0 R');
  out('/BaseFont /${toPDFName(font.fontName)}');
  out('/Encoding /${font.encoding}');
  out('/DescendantFonts [$descendantFont 0 R]');
  out('>>');
  out('endobj');

  font.isAlreadyPutted = true;
}

/// Gera os objetos PDF para uma fonte WinAnsiEncoding (TrueType).
///
/// Mesmo padrão de callbacks que [writeIdentityHFont].
void writeWinAnsiFFont({
  required FontPutData font,
  required void Function(String line) out,
  required int Function() newObject,
  required void Function({
    required String data,
    bool addLength1,
    required int objectId,
  }) putStream,
}) {
  if (font.encoding != 'WinAnsiEncoding') return;

  final metadata = font.metadata;

  // Font table stream (dados brutos)
  final pdfOutput = String.fromCharCodes(metadata.rawData);
  final fontTable = newObject();
  putStream(data: pdfOutput, addLength1: true, objectId: fontTable);
  out('endobj');

  // CMap ToUnicode
  final cmap = newObject();
  final cmapData = toUnicodeCmap(metadata.toUnicode);
  putStream(data: cmapData, addLength1: true, objectId: cmap);
  out('endobj');

  // Font Descriptor
  final fontDescriptor = newObject();
  out('<<');
  out('/Descent ${metadata.decender}');
  out('/CapHeight ${metadata.capHeight}');
  out('/StemV ${metadata.stemV}');
  out('/Type /FontDescriptor');
  out('/FontFile2 $fontTable 0 R');
  out('/Flags 96');
  out('/FontBBox ${PDFObject.convert(metadata.bbox)}');
  out('/FontName /${toPDFName(font.fontName)}');
  out('/ItalicAngle ${metadata.italicAngle}');
  out('/Ascent ${metadata.ascender}');
  out('>>');
  out('endobj');

  // Converte larguras para unidades de ponto
  final hmtxWidths = List<int>.from(metadata.hmtx.widths);
  for (var j = 0; j < hmtxWidths.length; j++) {
    hmtxWidths[j] = (hmtxWidths[j] * (1000 / metadata.head.unitsPerEm)).toInt();
  }

  // Font object (TrueType)
  font.objectNumber = newObject();
  out('<<'
      '/Subtype/TrueType'
      '/Type/Font'
      '/ToUnicode $cmap 0 R'
      '/BaseFont/${toPDFName(font.fontName)}'
      '/FontDescriptor $fontDescriptor 0 R'
      '/Encoding/${font.encoding}'
      ' /FirstChar 29 /LastChar 255'
      ' /Widths ${PDFObject.convert(hmtxWidths)}'
      '>>');
  out('endobj');

  font.isAlreadyPutted = true;
}

/// Processa texto para encoding UTF-8 (Identity-H ou WinAnsi).
///
/// Converte o texto de string para representação hexadecimal
/// quando a fonte usa Identity-H encoding.
///
/// [text] texto a processar.
/// [activeFontKey] chave da fonte ativa.
/// [fonts] mapa de fontes disponíveis.
/// [pdfEscapeFn] função de escape PDF padrão.
///
/// Retorna um mapa com:
/// - 'text': texto convertido (hex string)
/// - 'isHex': true se o resultado é hexadecimal
Map<String, dynamic> processUtf8Text({
  required String text,
  required String activeFontKey,
  required Map<String, FontPutData> fonts,
  required String Function(String, String) pdfEscapeFn,
}) {
  final font = fonts[activeFontKey];
  if (font == null || font.encoding != 'Identity-H') {
    return {'text': text, 'isHex': false};
  }

  // Filtra caracteres pelo cmap
  final sb = StringBuffer();
  for (var s = 0; s < text.length; s++) {
    final charCode = text.codeUnitAt(s);
    bool? cmapConfirm;
    if (font.metadata.cmap.unicode != null) {
      cmapConfirm = font.metadata.cmap.unicode!.codeMap.containsKey(charCode);
    }
    if (cmapConfirm == true) {
      sb.write(text[s]);
    } else if (charCode < 256) {
      sb.write(text[s]);
    }
  }

  final filteredText = sb.toString();
  String result;

  // Para fontes padrão (key < F14) ou WinAnsi, usa escape normal
  final keyNum = int.tryParse(activeFontKey.substring(1)) ?? 0;
  if (keyNum < 14 || font.encoding == 'WinAnsiEncoding') {
    result = pdfEscapeFn(filteredText, activeFontKey)
        .split('')
        .map((ch) => ch.codeUnitAt(0).toRadixString(16))
        .join('');
  } else {
    result = pdfEscape16(filteredText, font.metadata);
  }

  return {'text': result, 'isHex': true};
}
