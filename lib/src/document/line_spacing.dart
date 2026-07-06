/// Ported from docxjs src/document/line-spacing.ts
/// Line spacing model and parsing.

import '../parser/xml_parser.dart';
import 'common.dart';

/// Line spacing properties.
class LineSpacing {
  CssLength? after;
  CssLength? before;
  int? line;
  String? lineRule; // "atLeast" | "exactly" | "auto"

  LineSpacing({this.after, this.before, this.line, this.lineRule});
}

/// Parses a spacing element into LineSpacing.
LineSpacing parseLineSpacing(dynamic elem, XmlParser xml) {
  return LineSpacing(
    before: xml.lengthAttr(elem, 'before'),
    after: xml.lengthAttr(elem, 'after'),
    line: xml.intAttr(elem, 'line'),
    lineRule: xml.attr(elem, 'lineRule'),
  );
}
