/// Ported from docxjs src/document-props/custom-props-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import 'custom_props.dart';

/// Part containing custom document properties.
class CustomPropsPart extends Part {
  List<CustomProperty> props = [];

  CustomPropsPart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  Future<void> parseXml(web.Element root) async {
    props = parseCustomProps(root, package_.xmlParser);
  }
}

