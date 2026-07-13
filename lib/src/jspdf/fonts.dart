/// Definições de fontes padrão PDF (as 14 fontes base).
///
/// Cada fonte é definida como [postScriptName, familyName, style, encoding].
/// Essas fontes estão disponíveis em qualquer leitor PDF sem necessidade
/// de embutir os dados da fonte.

/// Informações de uma fonte padrão PDF.
class StandardFont {
  /// Nome PostScript da fonte (ex: "Helvetica-Bold").
  final String postScriptName;

  /// Nome da família (ex: "helvetica").
  final String fontName;

  /// Estilo: "normal", "bold", "italic", "bolditalic".
  final String fontStyle;

  /// Codificação (ex: "WinAnsiEncoding") ou null.
  final String? encoding;

  const StandardFont(
    this.postScriptName,
    this.fontName,
    this.fontStyle,
    this.encoding,
  );
}

/// As 14 fontes padrão do PDF.
const List<StandardFont> standardFonts = [
  StandardFont('Helvetica', 'helvetica', 'normal', 'WinAnsiEncoding'),
  StandardFont('Helvetica-Bold', 'helvetica', 'bold', 'WinAnsiEncoding'),
  StandardFont('Helvetica-Oblique', 'helvetica', 'italic', 'WinAnsiEncoding'),
  StandardFont(
    'Helvetica-BoldOblique',
    'helvetica',
    'bolditalic',
    'WinAnsiEncoding',
  ),
  StandardFont('Courier', 'courier', 'normal', 'WinAnsiEncoding'),
  StandardFont('Courier-Bold', 'courier', 'bold', 'WinAnsiEncoding'),
  StandardFont('Courier-Oblique', 'courier', 'italic', 'WinAnsiEncoding'),
  StandardFont(
    'Courier-BoldOblique',
    'courier',
    'bolditalic',
    'WinAnsiEncoding',
  ),
  StandardFont('Times-Roman', 'times', 'normal', 'WinAnsiEncoding'),
  StandardFont('Times-Bold', 'times', 'bold', 'WinAnsiEncoding'),
  StandardFont('Times-Italic', 'times', 'italic', 'WinAnsiEncoding'),
  StandardFont(
    'Times-BoldItalic',
    'times',
    'bolditalic',
    'WinAnsiEncoding',
  ),
  StandardFont('ZapfDingbats', 'zapfdingbats', 'normal', null),
  StandardFont('Symbol', 'symbol', 'normal', null),
];

/// Representação de uma fonte carregada no documento PDF.
class PdfFont {
  /// Chave interna (ex: "F1").
  final String key;

  /// Nome da família.
  final String fontName;

  /// Estilo da fonte.
  final String fontStyle;

  /// Codificação.
  final String? encoding;

  /// Nome PostScript.
  final String postScriptName;

  /// Número do objeto PDF.
  int objectNumber = -1;

  /// Indica se a fonte está sendo usada no documento.
  bool isUsed = false;

  /// Metadados adicionais da fonte (widths, kerning, etc.).
  Map<String, dynamic> metadata = {};

  PdfFont({
    required this.key,
    required this.fontName,
    required this.fontStyle,
    this.encoding,
    required this.postScriptName,
  });

  @override
  String toString() => 'PdfFont($postScriptName, key: $key)';
}

/// Combina estilo e peso da fonte.
///
/// Portado de combineFontStyleAndFontWeight do jsPDF.
String combineFontStyleAndFontWeight(String fontStyle, dynamic fontWeight) {
  if ((fontStyle == 'bold' && fontWeight == 'normal') ||
      (fontStyle == 'bold' && fontWeight == 400) ||
      (fontStyle == 'normal' && fontWeight == 'italic') ||
      (fontStyle == 'bold' && fontWeight == 'italic')) {
    throw ArgumentError('Invalid Combination of fontweight and fontstyle');
  }

  if (fontWeight != null) {
    if ((fontWeight == 400 || fontWeight == 'normal')) {
      fontStyle = fontStyle == 'italic' ? 'italic' : 'normal';
    } else if ((fontWeight == 700 || fontWeight == 'bold') &&
        fontStyle == 'normal') {
      fontStyle = 'bold';
    } else {
      fontStyle = '${fontWeight == 700 ? "bold" : fontWeight}$fontStyle';
    }
  }

  return fontStyle;
}
