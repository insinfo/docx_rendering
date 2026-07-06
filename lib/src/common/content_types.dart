/// Ported from docxjs src/common/content-types.ts
/// OPC content type model and parsing.

import '../parser/xml_parser.dart';

/// A content type entry from [Content_Types].xml.
class ContentType {
  String? extension_;
  String? partName;
  String? contentType;

  ContentType({this.extension_, this.partName, this.contentType});
}

/// Parses a <Types> element into a list of [ContentType].
List<ContentType> parseContentTypes(dynamic root, XmlParser xml) {
  return xml.elements(root).map((e) => ContentType(
    extension_: xml.attr(e, 'Extension'),
    partName: xml.attr(e, 'PartName'),
    contentType: xml.attr(e, 'ContentType'),
  )).toList();
}
