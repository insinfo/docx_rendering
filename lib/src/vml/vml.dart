
import '../document/common.dart';
import '../document/dom.dart';
import '../document_parser.dart';
import '../parser/xml_parser.dart';

class ImageHref {
  String? id;
  String? title;
  ImageHref({this.id, this.title});
}

/// A VML element.
class VmlElement extends OpenXmlElementBase {
  String? tagName;
  String? cssStyleText;
  Map<String, String> attrs = {};
  String? wrapType;
  ImageHref? imageHref;

  VmlElement() : super(type: DomType.vmlElement);
}

/// Parses a VML element.
VmlElement? parseVmlElement(dynamic elem, DocumentParser parser) {
  final xml = globalXmlParser;
  final result = VmlElement();

  switch (xml.localName(elem)) {
    case 'rect':
      result.tagName = 'rect';
      result.attrs['width'] = '100%';
      result.attrs['height'] = '100%';
      break;
    case 'oval':
      result.tagName = 'ellipse';
      result.attrs['cx'] = '50%';
      result.attrs['cy'] = '50%';
      result.attrs['rx'] = '50%';
      result.attrs['ry'] = '50%';
      break;
    case 'line':
      result.tagName = 'line';
      break;
    case 'shape':
      result.tagName = 'g';
      break;
    case 'textbox':
      result.tagName = 'foreignObject';
      result.attrs['width'] = '100%';
      result.attrs['height'] = '100%';
      break;
    default:
      return null;
  }

  for (final at in xml.attrs(elem)) {
    switch (at.localName) {
      case 'style':
        result.cssStyleText = at.value;
        break;
      case 'fillcolor':
        result.attrs['fill'] = at.value;
        break;
      case 'from':
        final pt = _parsePoint(at.value);
        if (pt.length >= 2) {
          result.attrs['x1'] = pt[0];
          result.attrs['y1'] = pt[1];
        }
        break;
      case 'to':
        final pt = _parsePoint(at.value);
        if (pt.length >= 2) {
          result.attrs['x2'] = pt[0];
          result.attrs['y2'] = pt[1];
        }
        break;
    }
  }

  for (final el in xml.elements(elem)) {
    switch (xml.localName(el)) {
      case 'stroke':
        result.attrs.addAll(_parseStroke(el, xml));
        break;
      case 'fill':
        result.attrs.addAll(_parseFill(el, xml));
        break;
      case 'imagedata':
        result.tagName = 'image';
        result.attrs['width'] = '100%';
        result.attrs['height'] = '100%';
        result.imageHref = ImageHref(
          id: xml.attr(el, 'id'),
          title: xml.attr(el, 'title'),
        );
        break;
      case 'txbxContent':
        final children = parser.parseBodyElements(el);
        if (result.children != null) {
          result.children!.addAll(children);
        }
        break;
      default:
        final child = parseVmlElement(el, parser);
        if (child != null && result.children != null) {
          result.children!.add(child);
        }
        break;
    }
  }

  return result;
}

Map<String, String> _parseStroke(dynamic el, XmlParser xml) {
  final res = <String, String>{};
  final color = xml.attr(el, 'color');
  if (color != null) res['stroke'] = color;

  final weight = xml.lengthAttr(el, 'weight', LengthUsage.emu) ?? '1px';
  res['stroke-width'] = weight;

  return res;
}

Map<String, String> _parseFill(dynamic el, XmlParser xml) {
  return {};
}

List<String> _parsePoint(String val) {
  return val.split(',');
}
