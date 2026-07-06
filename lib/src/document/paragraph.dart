/// Ported from docxjs src/document/paragraph.ts
/// Paragraph model and parsing.

import '../parser/xml_parser.dart';
import 'border.dart';
import 'common.dart';
import 'dom.dart';
import 'line_spacing.dart';
import 'run.dart';
import 'section.dart';

/// A paragraph element.
class WmlParagraph extends OpenXmlElement {
  // ParagraphProperties
  SectionProperties? sectionProps;
  List<ParagraphTab>? tabs;
  ParagraphNumbering? numbering;
  Borders? border;
  String? textAlignment;
  LineSpacing? lineSpacing;
  bool? keepLines;
  bool? keepNext;
  bool? pageBreakBefore;
  int? outlineLevel;
  RunProperties? runProps;
  CssLength? fontSize;
  String? color;

  WmlParagraph()
      : super(type: DomType.paragraph, children: []);
}

/// Paragraph properties parsed from <pPr>.
class ParagraphProperties extends CommonProperties {
  SectionProperties? sectionProps;
  List<ParagraphTab>? tabs;
  ParagraphNumbering? numbering;
  Borders? border;
  String? textAlignment;
  LineSpacing? lineSpacing;
  bool? keepLines;
  bool? keepNext;
  bool? pageBreakBefore;
  int? outlineLevel;
  String? styleName;
  RunProperties? runProps;
}

/// A tab stop definition.
class ParagraphTab {
  String? style; // "bar"|"center"|"clear"|"decimal"|"end"|"num"|"start"|"left"|"right"
  String? leader; // "none"|"dot"|"heavy"|"hyphen"|"middleDot"|"underscore"
  CssLength? position;

  ParagraphTab({this.style, this.leader, this.position});
}

/// Paragraph numbering reference.
class ParagraphNumbering {
  String? id;
  int? level;

  ParagraphNumbering({this.id, this.level});
}

/// Parses a <pPr> element.
ParagraphProperties parseParagraphProperties(dynamic elem, XmlParser xml) {
  final result = ParagraphProperties();

  for (final el in xml.elements(elem)) {
    parseParagraphProperty(el, result, xml);
  }

  return result;
}

/// Parses a single paragraph property element.
bool parseParagraphProperty(
    dynamic elem, ParagraphProperties props, XmlParser xml) {
  if (xml.namespaceURI(elem) != Ns.wordml) return false;

  if (parseCommonProperty(elem, props, xml)) return true;

  switch (xml.localName(elem)) {
    case 'tabs':
      props.tabs = _parseTabs(elem, xml);
      break;

    case 'sectPr':
      props.sectionProps = parseSectionProperties(elem, xml);
      break;

    case 'numPr':
      props.numbering = _parseNumbering(elem, xml);
      break;

    case 'spacing':
      props.lineSpacing = parseLineSpacing(elem, xml);
      return false; // TODO
    case 'textAlignment':
      props.textAlignment = xml.attr(elem, 'val');
      return false; // TODO
    case 'keepLines':
      props.keepLines = xml.boolAttr(elem, 'val', true);
      break;

    case 'keepNext':
      props.keepNext = xml.boolAttr(elem, 'val', true);
      break;

    case 'pageBreakBefore':
      props.pageBreakBefore = xml.boolAttr(elem, 'val', true);
      break;

    case 'outlineLvl':
      props.outlineLevel = xml.intAttr(elem, 'val');
      break;

    case 'pStyle':
      props.styleName = xml.attr(elem, 'val');
      break;

    case 'rPr':
      props.runProps = parseRunProperties(elem, xml);
      break;

    default:
      return false;
  }

  return true;
}

List<ParagraphTab> _parseTabs(dynamic elem, XmlParser xml) {
  return xml.elements(elem, 'tab').map((e) => ParagraphTab(
    position: xml.lengthAttr(e, 'pos'),
    leader: xml.attr(e, 'leader'),
    style: xml.attr(e, 'val'),
  )).toList();
}

ParagraphNumbering _parseNumbering(dynamic elem, XmlParser xml) {
  final result = ParagraphNumbering();

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'numId':
        result.id = xml.attr(e, 'val');
        break;
      case 'ilvl':
        result.level = xml.intAttr(e, 'val');
        break;
    }
  }

  return result;
}
