/// Ported from docxjs src/header-footer/parts.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../document/dom.dart';
import '../document_parser.dart';
import 'elements.dart';

/// Base part for header and footer.
abstract class BaseHeaderFooterPart<T extends OpenXmlElement> extends Part {
  T? rootElement;
  final DocumentParser _documentParser;

  BaseHeaderFooterPart(OpenXmlPackage pkg, String path, this._documentParser)
      : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    rootElement = createRootElement();
    rootElement!.children = _documentParser.parseBodyElements(root);
  }

  T createRootElement();
}

/// Part representing a document header.
class HeaderPart extends BaseHeaderFooterPart<WmlHeader> {
  HeaderPart(OpenXmlPackage pkg, String path, DocumentParser parser)
      : super(pkg, path, parser);

  @override
  WmlHeader createRootElement() {
    return WmlHeader();
  }
}

/// Part representing a document footer.
class FooterPart extends BaseHeaderFooterPart<WmlFooter> {
  FooterPart(OpenXmlPackage pkg, String path, DocumentParser parser)
      : super(pkg, path, parser);

  @override
  WmlFooter createRootElement() {
    return WmlFooter();
  }
}
