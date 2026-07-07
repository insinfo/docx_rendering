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

  final props = paragraph.props as ParagraphProperties;
  paragraph.styleName = props.styleName;
  paragraph.sectionProps = props.sectionProps;
  paragraph.tabs = props.tabs;
  paragraph.numbering = props.numbering;
  paragraph.border = props.border;
  paragraph.textAlignment = props.textAlignment;
  paragraph.lineSpacing = props.lineSpacing;
  paragraph.keepLines = props.keepLines;
  paragraph.keepNext = props.keepNext;
  paragraph.pageBreakBefore = props.pageBreakBefore;
  paragraph.outlineLevel = props.outlineLevel;
  paragraph.runProps = props.runProps;
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
    switch (globalXmlParser.localName(el)) {
      case 'r':
        result.children!.add(self.parseRun(el, result));
        break;
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
    switch (globalXmlParser.localName(el)) {
      case 'r':
        result.children!.add(self.parseRun(el, result));
        break;
      case 'smartTag':
        result.children!.add(self.parseSmartTag(el, result));
        break;
    }
  }

  return result;
}

WmlRun _parseRun(DocumentParser self, dynamic node, [OpenXmlElement? parent]) {
  final result = WmlRun()
    ..parent = parent
    ..children = [];

  for (var el in globalXmlParser.elements(node)) {
    el = _checkAlternateContent(el);

    switch (globalXmlParser.localName(el)) {
      case 'rPr':
        _parseRunProperties(self, el, result);
        break;
      case 't':
        result.children!.add(WmlText(globalXmlParser.textContent(el) ?? ''));
        break;
      case 'delText':
        final delText = WmlText(globalXmlParser.textContent(el) ?? '');
        delText.type = DomType.deletedText;
        result.children!.add(delText);
        break;
      case 'fldChar':
        result.fieldRun = true;
        final type = globalXmlParser.attr(el, 'fldCharType');
        if (type != null) {
          result.children!.add(WmlFieldChar(charType: type));
        }
        break;
      case 'instrText':
        result.fieldRun = true;
        result.children!.add(WmlInstructionText(text: globalXmlParser.textContent(el) ?? ''));
        break;
      case 'fldSimple':
        result.children!.add(WmlFieldSimple(
          instruction: globalXmlParser.attr(el, 'instr'),
        ));
        break;
      case 'noBreakHyphen':
        result.children!.add(OpenXmlElementBase(type: DomType.noBreakHyphen));
        break;
      case 'br':
        result.children!.add(WmlBreak(
          breakType: globalXmlParser.attr(el, 'type') ?? 'textWrapping',
        ));
        break;
      case 'lastRenderedPageBreak':
        result.children!.add(WmlBreak(
          breakType: 'lastRenderedPageBreak',
        ));
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
      case 'tab':
        result.children!.add(OpenXmlElementBase(type: DomType.tab));
        break;
      case 'drawing':
        final d = self.parseDrawingWrapper(el);
        if (d != null) result.children!.add(d);
        break;
      case 'pict':
        result.children!.add(self.parseVmlPicture(el));
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

/// Parses run properties from <rPr> following the TS pattern.
void _parseRunProperties(DocumentParser self, dynamic elem, WmlRun run) {
  run.cssStyle = self.parseDefaultProperties(elem, {}, null, (c) {
    switch (globalXmlParser.localName(c)) {
      case 'rStyle':
        run.styleName = globalXmlParser.attr(c, 'val');
        break;
      case 'vertAlign':
        run.verticalAlign = _valueOfVertAlign(c);
        break;
      default:
        return false;
    }
    return true;
  });
}

/// Returns the HTML tag name for vertical alignment.
String? _valueOfVertAlign(dynamic elem) {
  final val = globalXmlParser.attr(elem, 'val');
  switch (val) {
    case 'superscript':
      return 'sup';
    case 'subscript':
      return 'sub';
    default:
      return null;
  }
}

/// Handles AlternateContent elements by picking Choice or Fallback.
web.Element _checkAlternateContent(web.Element elem) {
  if (elem.localName != 'AlternateContent') return elem;

  final children = elem.childNodes;
  for (var i = 0; i < children.length; i++) {
    final c = children.item(i)!;
    if (c.nodeType == web.Node.ELEMENT_NODE) {
      final el = c as web.Element;
      if (el.localName == 'Fallback') {
        final first = el.firstElementChild;
        if (first != null) return first;
      }
    }
  }

  return elem;
}

OpenXmlElement _parseMathElement(DocumentParser self, dynamic elem) {
  final propsTag = '${globalXmlParser.localName(elem)}Pr';
  final result = OpenXmlElementBase(
      type: _mmlTagMap[globalXmlParser.localName(elem)] ?? DomType.mmlMath);
  result.children = [];

  for (final el in globalXmlParser.elements(elem)) {
    final childType = _mmlTagMap[globalXmlParser.localName(el)];

    if (childType != null) {
      result.children!.add(self.parseMathElement(el));
    } else if (globalXmlParser.localName(el) == 'r') {
      final run = self.parseRun(el);
      run.type = DomType.mmlRun;
      result.children!.add(run);
    } else if (globalXmlParser.localName(el) == propsTag) {
      result.props = _parseMathProperties(el);
    }
  }

  return result;
}

/// Parses math element properties.
Map<String, dynamic> _parseMathProperties(dynamic elem) {
  final result = <String, dynamic>{};

  for (final el in globalXmlParser.elements(elem)) {
    switch (globalXmlParser.localName(el)) {
      case 'chr':
        result['char'] = globalXmlParser.attr(el, 'val');
        break;
      case 'vertJc':
        result['verticalJustification'] = globalXmlParser.attr(el, 'val');
        break;
      case 'pos':
        result['position'] = globalXmlParser.attr(el, 'val');
        break;
      case 'degHide':
        result['hideDegree'] = globalXmlParser.boolAttr(el, 'val');
        break;
      case 'begChr':
        result['beginChar'] = globalXmlParser.attr(el, 'val');
        break;
      case 'endChr':
        result['endChar'] = globalXmlParser.attr(el, 'val');
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
