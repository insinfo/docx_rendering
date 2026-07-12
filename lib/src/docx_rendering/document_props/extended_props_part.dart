/// Ported from docxjs src/document-props/extended-props-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import 'extended_props.dart';

/// Part containing extended document properties.
class ExtendedPropsPart extends Part {
  ExtendedPropsDeclaration? props;

  ExtendedPropsPart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  Future<void> parseXml(web.Element root) async {
    props = parseExtendedProps(root, package_.xmlParser);
  }
}

