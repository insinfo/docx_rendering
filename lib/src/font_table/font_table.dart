/// Ported from docxjs src/font-table/font-table.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import 'fonts.dart';

/// Part containing the document's font table.
class FontTablePart extends Part {
  List<FontDeclaration> fonts = [];

  FontTablePart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    fonts = parseFonts(root, package_.xmlParser);
  }
}
