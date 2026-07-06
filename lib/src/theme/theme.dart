/// Ported from docxjs src/theme/theme.ts
/// Theme model and parsing.

import '../parser/xml_parser.dart';

/// A DrawingML theme.
class DmlTheme {
  DmlColorScheme? colorScheme;
  DmlFontScheme? fontScheme;
}

/// Color scheme from the theme.
class DmlColorScheme {
  String? name;
  Map<String, String> colors;

  DmlColorScheme({this.name, Map<String, String>? colors})
      : colors = colors ?? {};
}

/// Font scheme from the theme.
class DmlFontScheme {
  String? name;
  DmlFontInfo? majorFont;
  DmlFontInfo? minorFont;

  DmlFontScheme({this.name, this.majorFont, this.minorFont});
}

/// Font info (latin/ea/cs typefaces).
class DmlFontInfo {
  String? latinTypeface;
  String? eaTypeface;
  String? csTypeface;

  DmlFontInfo({this.latinTypeface, this.eaTypeface, this.csTypeface});
}

/// Parses a <a:theme> element.
DmlTheme parseTheme(dynamic elem, XmlParser xml) {
  final result = DmlTheme();
  final themeElements = xml.element(elem, 'themeElements');
  if (themeElements == null) return result;

  for (final el in xml.elements(themeElements)) {
    switch (xml.localName(el)) {
      case 'clrScheme':
        result.colorScheme = parseColorScheme(el, xml);
        break;
      case 'fontScheme':
        result.fontScheme = parseFontScheme(el, xml);
        break;
    }
  }

  return result;
}

/// Parses a color scheme element.
DmlColorScheme parseColorScheme(dynamic elem, XmlParser xml) {
  final result = DmlColorScheme(name: xml.attr(elem, 'name'));

  for (final el in xml.elements(elem)) {
    final srgbClr = xml.element(el, 'srgbClr');
    final sysClr = xml.element(el, 'sysClr');

    if (srgbClr != null) {
      result.colors[xml.localName(el) ?? ''] = xml.attr(srgbClr, 'val') ?? '';
    } else if (sysClr != null) {
      result.colors[xml.localName(el) ?? ''] =
          xml.attr(sysClr, 'lastClr') ?? '';
    }
  }

  return result;
}

/// Parses a font scheme element.
DmlFontScheme parseFontScheme(dynamic elem, XmlParser xml) {
  final result = DmlFontScheme(name: xml.attr(elem, 'name'));

  for (final el in xml.elements(elem)) {
    switch (xml.localName(el)) {
      case 'majorFont':
        result.majorFont = parseFontInfo(el, xml);
        break;
      case 'minorFont':
        result.minorFont = parseFontInfo(el, xml);
        break;
    }
  }

  return result;
}

/// Parses font info (latin, ea, cs typefaces).
DmlFontInfo parseFontInfo(dynamic elem, XmlParser xml) {
  return DmlFontInfo(
    latinTypeface: xml.elementAttr(elem, 'latin', 'typeface'),
    eaTypeface: xml.elementAttr(elem, 'ea', 'typeface'),
    csTypeface: xml.elementAttr(elem, 'cs', 'typeface'),
  );
}
