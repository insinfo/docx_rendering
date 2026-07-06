/// Ported from docxjs src/common/relationship.ts
/// OPC relationship model and parsing.

import '../parser/xml_parser.dart';

/// A single OPC relationship.
class Relationship {
  String? id;
  String type;
  String target;
  String? targetMode; // "" | "External"

  Relationship({
    this.id,
    required this.type,
    required this.target,
    this.targetMode,
  });
}

/// Standard relationship type URIs.
class RelationshipTypes {
  static const officeDocument =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument';
  static const fontTable =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable';
  static const image =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';
  static const numbering =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering';
  static const styles =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles';
  static const stylesWithEffects =
      'http://schemas.microsoft.com/office/2007/relationships/stylesWithEffects';
  static const theme =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme';
  static const settings =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings';
  static const webSettings =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/webSettings';
  static const hyperlink =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink';
  static const footnotes =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes';
  static const endnotes =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes';
  static const footer =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer';
  static const header =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header';
  static const extendedProperties =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties';
  static const coreProperties =
      'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties';
  static const customProperties =
      'http://schemas.openxmlformats.org/package/2006/relationships/metadata/custom-properties';
  static const comments =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments';
  static const commentsExtended =
      'http://schemas.microsoft.com/office/2011/relationships/commentsExtended';
  static const altChunk =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/aFChunk';
}

/// Parses a <Relationships> element into a list of [Relationship].
List<Relationship> parseRelationships(dynamic root, XmlParser xml) {
  return xml.elements(root).map((e) => Relationship(
    id: xml.attr(e, 'Id'),
    type: xml.attr(e, 'Type') ?? '',
    target: xml.attr(e, 'Target') ?? '',
    targetMode: xml.attr(e, 'TargetMode'),
  )).toList();
}
