/// Ported from docxjs src/document/bookmarks.ts
/// Bookmark model and parsing.

import '../parser/xml_parser.dart';
import 'dom.dart';

/// Bookmark start element.
class WmlBookmarkStart extends OpenXmlElement {
  String? id;
  String? name;
  int? colFirst;
  int? colLast;

  WmlBookmarkStart({this.id, this.name, this.colFirst, this.colLast})
      : super(type: DomType.bookmarkStart);
}

/// Bookmark end element.
class WmlBookmarkEnd extends OpenXmlElement {
  String? id;

  WmlBookmarkEnd({this.id})
      : super(type: DomType.bookmarkEnd);
}

/// Parses a bookmarkStart element.
WmlBookmarkStart parseBookmarkStart(dynamic elem, XmlParser xml) {
  return WmlBookmarkStart(
    id: xml.attr(elem, 'id'),
    name: xml.attr(elem, 'name'),
    colFirst: xml.intAttr(elem, 'colFirst'),
    colLast: xml.intAttr(elem, 'colLast'),
  );
}

/// Parses a bookmarkEnd element.
WmlBookmarkEnd parseBookmarkEnd(dynamic elem, XmlParser xml) {
  return WmlBookmarkEnd(
    id: xml.attr(elem, 'id'),
  );
}
