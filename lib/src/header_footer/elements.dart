/// Ported from docxjs src/header-footer/elements.ts

import '../document/dom.dart';

/// Header element.
class WmlHeader extends OpenXmlElementBase {
  WmlHeader() : super(type: DomType.header);
}

/// Footer element.
class WmlFooter extends OpenXmlElementBase {
  WmlFooter() : super(type: DomType.footer);
}
