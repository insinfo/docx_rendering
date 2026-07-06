/// Ported from docxjs src/document/common.ts
/// Common types, namespaces, and conversion utilities for DOCX elements.

import '../parser/xml_parser.dart';
import '../utils.dart' show clamp;

/// OpenXML namespaces used throughout the document.
class Ns {
  static const wordml =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const drawingml =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const picture =
      'http://schemas.openxmlformats.org/drawingml/2006/picture';
  static const compatibility =
      'http://schemas.openxmlformats.org/markup-compatibility/2006';
  static const math =
      'http://schemas.openxmlformats.org/officeDocument/2006/math';
}

/// Length is a CSS length string like "12.50pt" or "50%".
typedef CssLength = String;

/// Font declaration.
class Font {
  String name;
  String family;

  Font({required this.name, required this.family});
}

/// Common properties shared by paragraph and run elements.
class CommonProperties {
  CssLength? fontSize;
  String? color;
}

/// Defines how to convert a raw OOXML integer value to a CSS length.
class LengthUsageType {
  final double mul;
  final String unit;
  final double? min;
  final double? max;

  const LengthUsageType(this.mul, this.unit, {this.min, this.max});
}

/// Standard length usage conversions.
class LengthUsage {
  static const dxa = LengthUsageType(0.05, 'pt'); // twips
  static const emu = LengthUsageType(1 / 12700, 'pt');
  static const fontSize = LengthUsageType(0.5, 'pt');
  static const border =
      LengthUsageType(0.125, 'pt', min: 0.25, max: 12); // http://officeopenxml.com/WPtextBorders.php
  static const point = LengthUsageType(1, 'pt');
  static const percent = LengthUsageType(0.02, '%');
  static const lineHeight = LengthUsageType(1 / 240, '');
  static const vmlEmu = LengthUsageType(1 / 12700, '');
}

/// Converts a raw OOXML value string to a CSS length string.
CssLength? convertLength(String? val,
    [LengthUsageType usage = LengthUsage.dxa]) {
  // "simplified" docx documents use pt's as units
  if (val == null || RegExp(r'.+(p[xt]|[%])$').hasMatch(val)) {
    return val;
  }

  var num = (int.tryParse(val) ?? 0) * usage.mul;

  if (usage.min != null && usage.max != null) {
    num = clamp(num, usage.min!, usage.max!).toDouble();
  }

  return '${num.toStringAsFixed(2)}${usage.unit}';
}

/// Converts a string to a boolean, handling OOXML conventions.
bool convertBoolean(String? v, [bool defaultValue = false]) {
  switch (v) {
    case '1':
      return true;
    case '0':
      return false;
    case 'on':
      return true;
    case 'off':
      return false;
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      return defaultValue;
  }
}

/// Converts a percentage string (e.g., "50000") to a fraction (e.g., 500.0).
double? convertPercentage(String? val) {
  return val != null ? (int.tryParse(val) ?? 0) / 100 : null;
}

/// Parses common run/paragraph properties (color, fontSize).
bool parseCommonProperty(
    dynamic elem, CommonProperties props, XmlParser xml) {
  if (xml.namespaceURI(elem) != Ns.wordml) return false;

  switch (xml.localName(elem)) {
    case 'color':
      props.color = xml.attr(elem, 'val');
      break;
    case 'sz':
      props.fontSize = xml.lengthAttr(elem, 'val', LengthUsage.fontSize);
      break;
    default:
      return false;
  }

  return true;
}
