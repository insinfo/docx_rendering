/// Ported from docxjs src/styles/styles-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../document/style.dart';
import '../document_parser.dart';

/// Part representing the styles definitions.
class StylesPart extends Part {
  final DocumentParser _documentParser;
  List<IDomStyle> styles = [];

  StylesPart(OpenXmlPackage pkg, String path, this._documentParser)
      : super(pkg, path);

  @override
  Future<void> parseXml(web.Element root) async {
    styles = _documentParser.parseStylesFile(root);
  }
}

