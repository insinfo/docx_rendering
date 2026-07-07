/// Ported from docxjs src/document-parser.ts

import 'package:web/web.dart' as web;

import 'document/dom.dart';
import 'document/document.dart';
import 'document/paragraph.dart';
import 'document/section.dart';
import 'parser/xml_parser.dart';
import 'document/run.dart';
import 'document/bookmarks.dart';
import 'document/style.dart';
import 'document/fields.dart';
import 'vml/vml.dart';
import 'comments/elements.dart';
import 'notes/elements.dart';
import 'document/common.dart';
import 'utils.dart';

part 'parser/document_parser_core.dart';
part 'parser/document_parser_styles.dart';
part 'parser/document_parser_lists.dart';
part 'parser/document_parser_runs.dart';
part 'parser/document_parser_tables.dart';
part 'parser/document_parser_drawings.dart';

/// Options for the document parser.
class DocumentParserOptions {
  bool ignoreWidth;
  bool debug;

  DocumentParserOptions({
    this.ignoreWidth = false,
    this.debug = false,
  });
}

/// The document parser.
class DocumentParser {
  DocumentParserOptions options;

  DocumentParser([DocumentParserOptions? options])
      : options = options ?? DocumentParserOptions();

  // Core parsing
  List<T> parseNotes<T extends WmlBaseNote>(
          dynamic xmlDoc, String elemName, T Function() factory) =>
      _parseNotes(this, xmlDoc, elemName, factory);

  List<WmlComment> parseComments(dynamic xmlDoc) =>
      _parseComments(this, xmlDoc);

  DocumentElement parseDocumentFile(dynamic xmlDoc) =>
      _parseDocumentFile(this, xmlDoc);

  Map<String, String> parseBackground(dynamic elem) =>
      _parseBackground(this, elem);

  List<OpenXmlElement> parseBodyElements(dynamic element) =>
      _parseBodyElements(this, element);

  // Styles parsing
  List<IDomStyle> parseStylesFile(dynamic xstyles) =>
      _parseStylesFile(this, xstyles);

  IDomStyle parseDefaultStyles(dynamic node) =>
      _parseDefaultStyles(this, node);

  IDomStyle parseStyle(dynamic node) => _parseStyle(this, node);

  List<IDomSubStyle> parseTableStyle(dynamic node) =>
      _parseTableStyle(this, node);

  Map<String, String> parseDefaultProperties(
          dynamic node, Map<String, String>? style,
          [List<OpenXmlElement>? childs,
          bool Function(dynamic)? handler]) =>
      _parseDefaultProperties(this, node, style, childs, handler);

  // Numbering parsing
  List<IDomNumbering> parseNumberingFile(dynamic node) =>
      _parseNumberingFile(this, node);

  NumberingPicBullet? parseNumberingPicBullet(dynamic elem) =>
      _parseNumberingPicBullet(this, elem);

  List<IDomNumbering> parseAbstractNumbering(
          dynamic node, List<NumberingPicBullet?> bullets) =>
      _parseAbstractNumbering(this, node, bullets);

  IDomNumbering parseNumberingLevel(
          String? id, dynamic node, List<NumberingPicBullet?> bullets) =>
      _parseNumberingLevel(this, id, node, bullets);

  // Runs and Paragraphs
  List<OpenXmlElement> parseSdt(
          dynamic node, List<OpenXmlElement> Function(dynamic) parser) =>
      _parseSdt(this, node, parser);

  OpenXmlElement parseInserted(
          dynamic node, OpenXmlElement Function(dynamic) parentParser) =>
      _parseInserted(this, node, parentParser);

  OpenXmlElement parseDeleted(
          dynamic node, OpenXmlElement Function(dynamic) parentParser) =>
      _parseDeleted(this, node, parentParser);

  WmlAltChunk parseAltChunk(dynamic node) => _parseAltChunk(this, node);

  OpenXmlElement parseParagraph(dynamic node) => _parseParagraph(this, node);

  void parseParagraphProperties(dynamic elem, WmlParagraph paragraph) =>
      _parseParagraphProperties(this, elem, paragraph);

  void parseFrame(dynamic node, WmlParagraph paragraph) =>
      _parseFrame(this, node, paragraph);

  WmlHyperlink parseHyperlink(dynamic node, [OpenXmlElement? parent]) =>
      _parseHyperlink(this, node, parent);

  WmlSmartTag parseSmartTag(dynamic node, [OpenXmlElement? parent]) =>
      _parseSmartTag(this, node, parent);

  WmlRun parseRun(dynamic node, [OpenXmlElement? parent]) =>
      _parseRun(this, node, parent);

  OpenXmlElement parseMathElement(dynamic elem) =>
      _parseMathElement(this, elem);

  // Tables
  WmlTable parseTable(dynamic node) => _parseTable(this, node);

  void parseTableColumns(dynamic node, WmlTable table) =>
      _parseTableColumns(this, node, table);

  WmlTableRow parseTableRow(dynamic node) => _parseTableRow(this, node);

  WmlTableCell parseTableCell(dynamic node) => _parseTableCell(this, node);

  // Drawings
  OpenXmlElement? parseDrawingWrapper(dynamic node) =>
      _parseDrawingWrapper(this, node);

  IDomImage? parseDrawing(dynamic node) => _parseDrawing(this, node);

  OpenXmlElement parseVmlPicture(dynamic elem) =>
      _parseVmlPicture(this, elem);
}

final _mmlTagMap = {
  'oMath': DomType.mmlMath,
  'oMathPara': DomType.mmlMathParagraph,
  'f': DomType.mmlFraction,
  'func': DomType.mmlFunction,
  'fName': DomType.mmlFunctionName,
  'num': DomType.mmlNumerator,
  'den': DomType.mmlDenominator,
  'rad': DomType.mmlRadical,
  'deg': DomType.mmlDegree,
  'e': DomType.mmlBase,
  'sSup': DomType.mmlSuperscript,
  'sSub': DomType.mmlSubscript,
  'sPre': DomType.mmlPreSubSuper,
  'sup': DomType.mmlSuperArgument,
  'sub': DomType.mmlSubArgument,
  'd': DomType.mmlDelimiter,
  'nary': DomType.mmlNary,
  'eqArr': DomType.mmlEquationArray,
  'lim': DomType.mmlLimit,
  'limLow': DomType.mmlLimitLower,
  'm': DomType.mmlMatrix,
  'mr': DomType.mmlMatrixRow,
  'box': DomType.mmlBox,
  'bar': DomType.mmlBar,
  'groupChr': DomType.mmlGroupChar
};
