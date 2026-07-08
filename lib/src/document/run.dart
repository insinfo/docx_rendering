/// Ported from docxjs src/document/run.ts
/// Run (inline text) model and parsing.

import '../parser/xml_parser.dart';
import 'common.dart';
import 'dom.dart';

/// A run element (inline text with formatting).
class WmlRun extends OpenXmlElement {
  String? id;
  String? verticalAlign;
  bool? fieldRun;

  /// Non-null when this run holds the *result* of a PAGE/NUMPAGES field
  /// ('PAGE' or 'NUMPAGES'); the pagination pass rewrites its text per page.
  String? fieldType;

  // RunProperties
  CssLength? fontSize;
  String? color;
  RunProperties? runProps;

  WmlRun()
      : super(type: DomType.run, children: []);
}

/// Run-level properties.
class RunProperties extends CommonProperties {}

/// Parses run properties from a <rPr> element.
RunProperties parseRunProperties(dynamic elem, XmlParser xml) {
  final result = RunProperties();

  for (final el in xml.elements(elem)) {
    parseRunProperty(el, result, xml);
  }

  return result;
}

/// Parses a single run property element.
bool parseRunProperty(dynamic elem, RunProperties props, XmlParser xml) {
  if (parseCommonProperty(elem, props, xml)) return true;
  return false;
}
