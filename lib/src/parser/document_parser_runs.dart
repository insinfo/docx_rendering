part of '../document_parser.dart';

List<OpenXmlElement> _parseSdt(DocumentParser self, dynamic node,
    List<OpenXmlElement> Function(dynamic) parser) {
  final sdtContent = globalXmlParser.element(node, 'sdtContent');
  return sdtContent != null ? parser(sdtContent) : [];
}

OpenXmlElement _parseInserted(
    DocumentParser self, dynamic node, OpenXmlElement Function(dynamic) parentParser) {
  final children = parentParser(node).children ?? [];
  return OpenXmlElementBase(type: DomType.inserted)..children = children;
}

OpenXmlElement _parseDeleted(
    DocumentParser self, dynamic node, OpenXmlElement Function(dynamic) parentParser) {
  final children = parentParser(node).children ?? [];
  return OpenXmlElementBase(type: DomType.deleted)..children = children;
}

WmlAltChunk _parseAltChunk(DocumentParser self, dynamic node) {
  return WmlAltChunk()
    ..id = globalXmlParser.attr(node, 'id')
    ..children = [];
}

OpenXmlElement _parseParagraph(DocumentParser self, dynamic node) {
  final result = WmlParagraph()..children = [];

  for (final el in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(el)) {
      case 'pPr':
        self.parseParagraphProperties(el, result);
        break;
      case 'r':
        result.children!.add(self.parseRun(el, result));
        break;
      case 'hyperlink':
        result.children!.add(self.parseHyperlink(el, result));
        break;
      case 'smartTag':
        result.children!.add(self.parseSmartTag(el, result));
        break;
      case 'bookmarkStart':
        result.children!.add(parseBookmarkStart(el, globalXmlParser));
        break;
      case 'bookmarkEnd':
        result.children!.add(parseBookmarkEnd(el, globalXmlParser));
        break;
      case 'commentRangeStart':
        result.children!.add(WmlCommentRangeStart(id: globalXmlParser.attr(el, 'id')));
        break;
      case 'commentRangeEnd':
        result.children!.add(WmlCommentRangeEnd(id: globalXmlParser.attr(el, 'id')));
        break;
      case 'oMath':
      case 'oMathPara':
        result.children!.add(self.parseMathElement(el));
        break;
      case 'sdt':
        result.children!.addAll(self.parseSdt(el, (e) => self.parseParagraph(e).children ?? []));
        break;
      case 'ins':
        result.children!.add(self.parseInserted(el, (e) => self.parseParagraph(e)));
        break;
      case 'del':
        result.children!.add(self.parseDeleted(el, (e) => self.parseParagraph(e)));
        break;
    }
  }

  return result;
}

void _parseParagraphProperties(
    DocumentParser self, dynamic elem, WmlParagraph paragraph) {
  paragraph.cssStyle = {};
  paragraph.props ??= ParagraphProperties();
  self.parseDefaultProperties(elem, paragraph.cssStyle, null, (c) {
    if (parseParagraphProperty(c, paragraph.props as ParagraphProperties, globalXmlParser)) {
      return true;
    }

    switch (globalXmlParser.localName(c)) {
      case 'pStyle':
        paragraph.styleName = globalXmlParser.attr(c, 'val');
        break;
      case 'cnfStyle':
        paragraph.className = classNameOfCnfStyle(c);
        break;
      case 'framePr':
        self.parseFrame(c, paragraph);
        break;
      case 'rPr':
        // TODO ignore
        break;
      default:
        return false;
    }

    return true;
  });
}

void _parseFrame(DocumentParser self, dynamic node, WmlParagraph paragraph) {
  final dropCap = globalXmlParser.attr(node, 'dropCap');
  if (dropCap == 'drop') {
    paragraph.cssStyle ??= {};
    paragraph.cssStyle!['float'] = 'left';
  }
}

WmlHyperlink _parseHyperlink(
    DocumentParser self, dynamic node, [OpenXmlElement? parent]) {
  final result = WmlHyperlink()
    ..parent = parent
    ..children = []
    ..anchor = globalXmlParser.attr(node, 'anchor')
    ..id = globalXmlParser.attr(node, 'id');

  for (final el in globalXmlParser.elements(node)) {
    if (globalXmlParser.localName(el) == 'r') {
      result.children!.add(self.parseRun(el, result));
    }
  }

  return result;
}

WmlSmartTag _parseSmartTag(
    DocumentParser self, dynamic node, [OpenXmlElement? parent]) {
  final result = WmlSmartTag()
    ..parent = parent
    ..children = []
    ..uri = globalXmlParser.attr(node, 'uri')
    ..element = globalXmlParser.attr(node, 'element');

  for (final el in globalXmlParser.elements(node)) {
    if (globalXmlParser.localName(el) == 'r') {
      result.children!.add(self.parseRun(el, result));
    }
  }

  return result;
}

WmlRun _parseRun(DocumentParser self, dynamic node, [OpenXmlElement? parent]) {
  final result = WmlRun()
    ..parent = parent
    ..children = [];

  for (final el in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(el)) {
      case 'rPr':
        result.cssStyle = self.parseDefaultProperties(el, {});
        result.id = globalXmlParser.elementAttr(el, 'rStyle', 'val');
        result.runProps = parseRunProperties(el, globalXmlParser);
        break;
      case 't':
        result.children!.add(WmlText(globalXmlParser.textContent(el) ?? ''));
        break;
      case 'fldChar':
        final type = globalXmlParser.attr(el, 'fldCharType');
        if (type != null) {
          result.children!.add(WmlFieldChar(charType: type));
        }
        break;
      case 'instrText':
        result.children!.add(WmlInstructionText(text: globalXmlParser.textContent(el) ?? ''));
        break;
      case 'noBreakHyphen':
        result.children!.add(WmlText('\u2011'));
        break;
      case 'softHyphen':
        result.children!.add(WmlText('\u00AD'));
        break;
      case 'sym':
        result.children!.add(WmlSymbol(
        globalXmlParser.attr(el, 'font') ?? '',
        globalXmlParser.hexAttr(el, 'char') ?? 0
      ));
        break;
      case 'br':
        result.children!.add(WmlBreak(
        breakType: globalXmlParser.attr(el, 'type') ?? 'textWrapping',
        clear: globalXmlParser.attr(el, 'clear') == 'all'
      ));
        break;
      case 'tab':
        result.children!.add(OpenXmlElementBase(type: DomType.tab));
        break;
      case 'drawing':
        final d = self.parseDrawingWrapper(el);
        if (d != null) result.children!.add(d);
        break;
      case 'pict':
        final pt = self.parseDrawingWrapper(el);
        if (pt != null) result.children!.add(pt);
        break;
      case 'ruby':
        final r = self.parseRuby(el);
        if (r != null) result.children!.add(r);
        break;
      case 'footnoteReference':
        result.children!.add(WmlNoteReference(globalXmlParser.attr(el, 'id') ?? '', DomType.footnoteReference));
        break;
      case 'endnoteReference':
        result.children!.add(WmlNoteReference(globalXmlParser.attr(el, 'id') ?? '', DomType.endnoteReference));
        break;
      case 'commentReference':
        result.children!.add(WmlCommentReference(id: globalXmlParser.attr(el, 'id')));
        break;
    }
  }

  return result;
}

OpenXmlElement _parseMathElement(DocumentParser self, dynamic elem) {
  final result = OpenXmlElementBase(
      type: _mmlTagMap[globalXmlParser.localName(elem)] ?? DomType.mmlMath);
  result.children = [];

  for (final el in globalXmlParser.elements(elem)) {
    switch (globalXmlParser.localName(el)) {
      case 'r':
        final run = self.parseRun(el);
        run.type = DomType.mmlRun;
        result.children!.add(run);
        break;
      default:
        result.children!.add(self.parseMathElement(el));
        break;
    }
  }

  return result;
}

extension on DocumentParser {
  OpenXmlElement? parseRuby(dynamic node) {
    return OpenXmlElementBase(type: DomType.ruby); // Stub
  }
}
