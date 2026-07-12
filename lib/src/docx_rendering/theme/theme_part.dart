/// Ported from docxjs src/theme/theme-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import 'theme.dart';

/// Part representing the theme.
class ThemePart extends Part {
  DmlTheme? theme;

  ThemePart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  Future<void> parseXml(web.Element root) async {
    theme = parseTheme(root, package_.xmlParser);
  }
}

