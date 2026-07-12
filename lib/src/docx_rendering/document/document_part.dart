/// Ported from docxjs src/document/document-part.ts
/// The document part (word/document.xml).

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../document_parser.dart';
import 'document.dart';

/// Part representing the main document body.
class DocumentPart extends Part {
  final DocumentParser _documentParser;

  DocumentElement? body;

  DocumentPart(OpenXmlPackage pkg, String path, this._documentParser)
      : super(pkg, path);

  @override
  Future<void> parseXml(web.Element root) async {
    body = await _documentParser.parseDocumentFileAsync(root);
  }
}
