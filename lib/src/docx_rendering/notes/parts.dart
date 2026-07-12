/// Ported from docxjs src/notes/parts.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../document_parser.dart';
import 'elements.dart';

/// Base part for footnotes/endnotes.
class BaseNotePart<T extends WmlBaseNote> extends Part {
  final DocumentParser _documentParser;
  List<T> notes = [];

  BaseNotePart(OpenXmlPackage pkg, String path, this._documentParser)
      : super(pkg, path);
}

/// Part containing footnotes.
class FootnotesPart extends BaseNotePart<WmlFootnote> {
  FootnotesPart(OpenXmlPackage pkg, String path, DocumentParser parser)
      : super(pkg, path, parser);

  @override
  Future<void> parseXml(web.Element root) async {
    notes = _documentParser.parseNotes<WmlFootnote>(
        root, 'footnote', () => WmlFootnote());
  }
}

/// Part containing endnotes.
class EndnotesPart extends BaseNotePart<WmlEndnote> {
  EndnotesPart(OpenXmlPackage pkg, String path, DocumentParser parser)
      : super(pkg, path, parser);

  @override
  Future<void> parseXml(web.Element root) async {
    notes = _documentParser.parseNotes<WmlEndnote>(
        root, 'endnote', () => WmlEndnote());
  }
}

