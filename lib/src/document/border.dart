/// Ported from docxjs src/document/border.ts
/// Border model and parsing.

import '../parser/xml_parser.dart';
import 'common.dart';

/// A single border edge.
class Border {
  String? color;
  String? type;
  CssLength? size;
  bool? frame;
  bool? shadow;
  CssLength? offset;

  Border({this.color, this.type, this.size, this.frame, this.shadow, this.offset});
}

/// Four-sided border.
class Borders {
  Border? top;
  Border? left;
  Border? right;
  Border? bottom;

  Borders({this.top, this.left, this.right, this.bottom});
}

/// Parses a single border element.
Border parseBorder(dynamic elem, XmlParser xml) {
  return Border(
    type: xml.attr(elem, 'val'),
    color: xml.attr(elem, 'color'),
    size: xml.lengthAttr(elem, 'sz', LengthUsage.border),
    offset: xml.lengthAttr(elem, 'space', LengthUsage.point),
    frame: xml.boolAttr(elem, 'frame'),
    shadow: xml.boolAttr(elem, 'shadow'),
  );
}

/// Parses a borders container element.
Borders parseBorders(dynamic elem, XmlParser xml) {
  final result = Borders();

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'left':
        result.left = parseBorder(e, xml);
        break;
      case 'top':
        result.top = parseBorder(e, xml);
        break;
      case 'right':
        result.right = parseBorder(e, xml);
        break;
      case 'bottom':
        result.bottom = parseBorder(e, xml);
        break;
    }
  }

  return result;
}
