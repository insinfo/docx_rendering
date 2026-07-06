/// Ported from docxjs src/document/section.ts
/// Section properties model and parsing.

import '../parser/xml_parser.dart';
import 'border.dart';
import 'common.dart';

/// A column definition within a section.
class Column {
  CssLength? space;
  CssLength? width;

  Column({this.space, this.width});
}

/// Multi-column layout settings.
class Columns {
  CssLength? space;
  int? numberOfColumns;
  bool? separator;
  bool? equalWidth;
  List<Column> columns;

  Columns({this.space, this.numberOfColumns, this.separator, this.equalWidth,
      List<Column>? columns})
      : columns = columns ?? [];
}

/// Page size.
class PageSize {
  CssLength? width;
  CssLength? height;
  String? orientation; // "landscape" or null for portrait

  PageSize({this.width, this.height, this.orientation});
}

/// Page number settings.
class PageNumber {
  int? start;
  String? chapSep;
  String? chapStyle;
  String? format;

  PageNumber({this.start, this.chapSep, this.chapStyle, this.format});
}

/// Page margins.
class PageMargins {
  CssLength? top;
  CssLength? right;
  CssLength? bottom;
  CssLength? left;
  CssLength? header;
  CssLength? footer;
  CssLength? gutter;

  PageMargins(
      {this.top,
      this.right,
      this.bottom,
      this.left,
      this.header,
      this.footer,
      this.gutter});
}

/// Section type enum.
enum SectionType {
  continuous('continuous'),
  nextPage('nextPage'),
  nextColumn('nextColumn'),
  evenPage('evenPage'),
  oddPage('oddPage');

  final String value;
  const SectionType(this.value);
}

/// Reference to a header or footer part.
class FooterHeaderReference {
  String? id;
  String? type; // "first" | "even" | "default"

  FooterHeaderReference({this.id, this.type});
}

/// Full section properties.
class SectionProperties {
  String? type;
  PageSize? pageSize;
  PageMargins? pageMargins;
  Borders? pageBorders;
  PageNumber? pageNumber;
  Columns? columns;
  List<FooterHeaderReference>? footerRefs;
  List<FooterHeaderReference>? headerRefs;
  bool? titlePage;

  SectionProperties();
}

/// Parses a <sectPr> element.
SectionProperties parseSectionProperties(dynamic elem,
    [XmlParser? xml]) {
  xml ??= globalXmlParser;
  final section = SectionProperties();

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'pgSz':
        section.pageSize = PageSize(
          width: xml.lengthAttr(e, 'w'),
          height: xml.lengthAttr(e, 'h'),
          orientation: xml.attr(e, 'orient'),
        );
        break;

      case 'type':
        section.type = xml.attr(e, 'val');
        break;

      case 'pgMar':
        section.pageMargins = PageMargins(
          left: xml.lengthAttr(e, 'left'),
          right: xml.lengthAttr(e, 'right'),
          top: xml.lengthAttr(e, 'top'),
          bottom: xml.lengthAttr(e, 'bottom'),
          header: xml.lengthAttr(e, 'header'),
          footer: xml.lengthAttr(e, 'footer'),
          gutter: xml.lengthAttr(e, 'gutter'),
        );
        break;

      case 'cols':
        section.columns = _parseColumns(e, xml);
        break;

      case 'headerReference':
        (section.headerRefs ??= []).add(_parseFooterHeaderReference(e, xml));
        break;

      case 'footerReference':
        (section.footerRefs ??= []).add(_parseFooterHeaderReference(e, xml));
        break;

      case 'titlePg':
        section.titlePage = xml.boolAttr(e, 'val', true);
        break;

      case 'pgBorders':
        section.pageBorders = parseBorders(e, xml);
        break;

      case 'pgNumType':
        section.pageNumber = _parsePageNumber(e, xml);
        break;
    }
  }

  return section;
}

Columns _parseColumns(dynamic elem, XmlParser xml) {
  return Columns(
    numberOfColumns: xml.intAttr(elem, 'num'),
    space: xml.lengthAttr(elem, 'space'),
    separator: xml.boolAttr(elem, 'sep'),
    equalWidth: xml.boolAttr(elem, 'equalWidth', true),
    columns: xml.elements(elem, 'col').map((e) => Column(
      width: xml.lengthAttr(e, 'w'),
      space: xml.lengthAttr(e, 'space'),
    )).toList(),
  );
}

PageNumber _parsePageNumber(dynamic elem, XmlParser xml) {
  return PageNumber(
    chapSep: xml.attr(elem, 'chapSep'),
    chapStyle: xml.attr(elem, 'chapStyle'),
    format: xml.attr(elem, 'fmt'),
    start: xml.intAttr(elem, 'start'),
  );
}

FooterHeaderReference _parseFooterHeaderReference(
    dynamic elem, XmlParser xml) {
  return FooterHeaderReference(
    id: xml.attr(elem, 'id'),
    type: xml.attr(elem, 'type'),
  );
}
