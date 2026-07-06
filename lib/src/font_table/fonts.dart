/// Ported from docxjs src/font-table/fonts.ts

import '../parser/xml_parser.dart';

const _embedFontTypeMap = {
  'embedRegular': 'regular',
  'embedBold': 'bold',
  'embedItalic': 'italic',
  'embedBoldItalic': 'boldItalic',
};

/// A font declaration.
class FontDeclaration {
  String? name;
  String? altName;
  String? family;
  List<EmbedFontRef> embedFontRefs;

  FontDeclaration({
    this.name,
    this.altName,
    this.family,
    List<EmbedFontRef>? embedFontRefs,
  }) : embedFontRefs = embedFontRefs ?? [];
}

/// A reference to an embedded font.
class EmbedFontRef {
  String? id;
  String? key;
  String? type; // 'regular' | 'bold' | 'italic' | 'boldItalic'

  EmbedFontRef({this.id, this.key, this.type});
}

/// Parses the <fonts> element.
List<FontDeclaration> parseFonts(dynamic root, XmlParser xml) {
  return xml.elements(root).map((el) => parseFont(el, xml)).toList();
}

/// Parses a single <font> element.
FontDeclaration parseFont(dynamic elem, XmlParser xml) {
  final result = FontDeclaration(
    name: xml.attr(elem, 'name'),
  );

  for (final el in xml.elements(elem)) {
    switch (xml.localName(el)) {
      case 'family':
        result.family = xml.attr(el, 'val');
        break;
      case 'altName':
        result.altName = xml.attr(el, 'val');
        break;
      case 'embedRegular':
      case 'embedBold':
      case 'embedItalic':
      case 'embedBoldItalic':
        result.embedFontRefs.add(parseEmbedFontRef(el, xml));
        break;
    }
  }

  return result;
}

/// Parses an embedded font reference element.
EmbedFontRef parseEmbedFontRef(dynamic elem, XmlParser xml) {
  return EmbedFontRef(
    id: xml.attr(elem, 'id'),
    key: xml.attr(elem, 'fontKey'),
    type: _embedFontTypeMap[xml.localName(elem)],
  );
}
