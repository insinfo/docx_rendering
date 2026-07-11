/// Ported from docxjs src/document-props/extended-props.ts

import '../parser/xml_parser.dart';

/// Extended properties of the document.
class ExtendedPropsDeclaration {
  String? template;
  int? totalTime;
  int? pages;
  int? words;
  int? characters;
  String? application;
  int? lines;
  int? paragraphs;
  String? company;
  String? appVersion;

  ExtendedPropsDeclaration({
    this.template,
    this.totalTime,
    this.pages,
    this.words,
    this.characters,
    this.application,
    this.lines,
    this.paragraphs,
    this.company,
    this.appVersion,
  });
}

/// Parses the extended properties element.
ExtendedPropsDeclaration parseExtendedProps(
    dynamic root, XmlParser xmlParser) {
  final result = ExtendedPropsDeclaration();

  for (final el in xmlParser.elements(root)) {
    switch (xmlParser.localName(el)) {
      case 'Template':
        result.template = xmlParser.textContent(el);
        break;
      case 'Pages':
        result.pages = _safeParseToInt(xmlParser.textContent(el));
        break;
      case 'Words':
        result.words = _safeParseToInt(xmlParser.textContent(el));
        break;
      case 'Characters':
        result.characters = _safeParseToInt(xmlParser.textContent(el));
        break;
      case 'Application':
        result.application = xmlParser.textContent(el);
        break;
      case 'Lines':
        result.lines = _safeParseToInt(xmlParser.textContent(el));
        break;
      case 'Paragraphs':
        result.paragraphs = _safeParseToInt(xmlParser.textContent(el));
        break;
      case 'Company':
        result.company = xmlParser.textContent(el);
        break;
      case 'AppVersion':
        result.appVersion = xmlParser.textContent(el);
        break;
    }
  }

  return result;
}

int? _safeParseToInt(String? value) {
  if (value == null || value.isEmpty) return null;
  return int.tryParse(value);
}
