/// Ported from docxjs src/notes/elements.ts

import '../document/dom.dart';

/// Base class for footnotes and endnotes.
class WmlBaseNote extends OpenXmlElementBase {
  String? id;
  String? noteType;

  WmlBaseNote({required DomType type}) : super(type: type);
}

/// A footnote element.
class WmlFootnote extends WmlBaseNote {
  WmlFootnote() : super(type: DomType.footnote);
}

/// An endnote element.
class WmlEndnote extends WmlBaseNote {
  WmlEndnote() : super(type: DomType.endnote);
}
