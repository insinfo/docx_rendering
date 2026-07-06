/// Ported from docxjs src/document-props/core-props.ts

import '../parser/xml_parser.dart';

/// Core properties of the document.
class CorePropsDeclaration {
  String? title;
  String? description;
  String? subject;
  String? creator;
  String? keywords;
  String? language;
  String? lastModifiedBy;
  int? revision;

  CorePropsDeclaration({
    this.title,
    this.description,
    this.subject,
    this.creator,
    this.keywords,
    this.language,
    this.lastModifiedBy,
    this.revision,
  });
}

/// Parses the core properties element.
CorePropsDeclaration parseCoreProps(dynamic root, XmlParser xmlParser) {
  final result = CorePropsDeclaration();

  for (final el in xmlParser.elements(root)) {
    switch (xmlParser.localName(el)) {
      case 'title':
        result.title = xmlParser.textContent(el);
        break;
      case 'description':
        result.description = xmlParser.textContent(el);
        break;
      case 'subject':
        result.subject = xmlParser.textContent(el);
        break;
      case 'creator':
        result.creator = xmlParser.textContent(el);
        break;
      case 'keywords':
        result.keywords = xmlParser.textContent(el);
        break;
      case 'language':
        result.language = xmlParser.textContent(el);
        break;
      case 'lastModifiedBy':
        result.lastModifiedBy = xmlParser.textContent(el);
        break;
      case 'revision':
        final text = xmlParser.textContent(el);
        if (text != null && text.isNotEmpty) {
          result.revision = int.tryParse(text);
        }
        break;
    }
  }

  return result;
}
