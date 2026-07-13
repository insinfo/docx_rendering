/// Ported from docxjs src/settings/settings.ts

import '../document/common.dart';
import '../parser/xml_parser.dart';

/// Document settings.
class WmlSettings {
  CssLength? defaultTabStop;
  NoteProperties? footnoteProps;
  NoteProperties? endnoteProps;
  bool? autoHyphenation;
  bool? evenAndOddHeaders;
}

/// Properties for notes (footnotes/endnotes).
class NoteProperties {
  String? numberingFormat;
  List<String> defaultNoteIds;

  NoteProperties({this.numberingFormat, List<String>? defaultNoteIds})
      : defaultNoteIds = defaultNoteIds ?? [];
}

/// Parses the <settings> element.
WmlSettings parseSettings(dynamic elem, XmlParser xml) {
  final result = WmlSettings();

  for (final el in xml.elements(elem)) {
    switch (xml.localName(el)) {
      case 'defaultTabStop':
        result.defaultTabStop = xml.lengthAttr(el, 'val');
        break;
      case 'footnotePr':
        result.footnoteProps = parseNoteProperties(el, xml);
        break;
      case 'endnotePr':
        result.endnoteProps = parseNoteProperties(el, xml);
        break;
      case 'autoHyphenation':
        result.autoHyphenation = xml.boolAttr(el, 'val');
        break;
      case 'evenAndOddHeaders':
        // An empty on/off element means true in WordprocessingML.
        result.evenAndOddHeaders = xml.boolAttr(el, 'val') ?? true;
        break;
    }
  }

  return result;
}

/// Parses a note properties element.
NoteProperties parseNoteProperties(dynamic elem, XmlParser xml) {
  final result = NoteProperties();

  for (final el in xml.elements(elem)) {
    switch (xml.localName(el)) {
      case 'numFmt':
        result.numberingFormat = xml.attr(el, 'val');
        break;
      case 'footnote':
      case 'endnote':
        final id = xml.attr(el, 'id');
        if (id != null) result.defaultNoteIds.add(id);
        break;
    }
  }

  return result;
}
