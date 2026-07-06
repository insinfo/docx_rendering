/// Ported from docxjs src/document-props/core-props-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import 'core_props.dart';

/// Part containing core document properties.
class CorePropsPart extends Part {
  CorePropsDeclaration? props;

  CorePropsPart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    props = parseCoreProps(root, package_.xmlParser);
  }
}
