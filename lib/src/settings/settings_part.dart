/// Ported from docxjs src/settings/settings-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import 'settings.dart';

/// Part containing document settings.
class SettingsPart extends Part {
  WmlSettings? settings;

  SettingsPart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    settings = parseSettings(root, package_.xmlParser);
  }
}
