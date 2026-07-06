part of '../html_renderer.dart';

List<web.HTMLElement> _renderSections(HtmlRenderer self, DocumentElement document) {
  final result = <web.HTMLElement>[];

  self.processElement(document);
  final sections = _splitBySection(self, document.children ?? [], document.sectionProps ?? SectionProperties());
  final pages = _groupByPageBreaks(self, sections);
  SectionProperties? prevProps;

  for (var i = 0; i < pages.length; i++) {
    self.currentFootnoteIds = [];

    final section = pages[i][0];
    var props = section.sectProps;
    final pageElement = _createPageElement(self, self.className, props, document.cssStyle ?? {});

    if (self.options.renderHeaders) {
      _renderHeaderFooter(self, props.headerRefs ?? [], props, result.length, prevProps != props, pageElement);
    }

    for (final sect in pages[i]) {
      final contentElement = _createSectionContent(self, sect.sectProps);
      _renderElements(self, sect.elements, contentElement);
      pageElement.appendChild(contentElement);
      props = sect.sectProps;
    }

    if (self.options.renderFootnotes) {
      final notes = _renderNotes(self, self.currentFootnoteIds, self.footnoteMap);
      if (notes != null) pageElement.appendChild(notes);
    }

    if (self.options.renderEndnotes && i == pages.length - 1) {
      final notes = _renderNotes(self, self.currentEndnoteIds, self.endnoteMap);
      if (notes != null) pageElement.appendChild(notes);
    }

    if (self.options.renderFooters) {
      _renderHeaderFooter(self, props.footerRefs ?? [], props, result.length, prevProps != props, pageElement);
    }

    result.add(pageElement);
    prevProps = props;
  }

  return result;
}

List<web.Node> _renderElements(HtmlRenderer self, List<OpenXmlElement> elements, web.HTMLElement into) {
  final result = <web.Node>[];

  for (final element in elements) {
    final node = self.renderElement(element);
    if (node != null) {
      into.appendChild(node);
      result.add(node);
    }
  }

  return result;
}

web.HTMLElement _createPageElement(HtmlRenderer self, String className, SectionProperties props, Map<String, String> docStyle) {
  final style = Map<String, String>.from(docStyle);

  if (props.pageMargins != null) {
    style['padding-left'] = props.pageMargins!.left ?? '';
    style['padding-right'] = props.pageMargins!.right ?? '';
    style['padding-top'] = props.pageMargins!.top ?? '';
    style['padding-bottom'] = props.pageMargins!.bottom ?? '';
  }

  if (props.pageSize != null) {
    if (!self.options.ignoreWidth) style['width'] = props.pageSize!.width ?? '';
    if (!self.options.ignoreHeight) style['min-height'] = props.pageSize!.height ?? '';
  }

  return self.hFunc({'tagName': 'section', 'className': className, 'style': style}) as web.HTMLElement;
}

web.HTMLElement _createSectionContent(HtmlRenderer self, SectionProperties props) {
  final style = <String, String>{};

  if (props.columns != null && props.columns!.numberOfColumns != null) {
    style['column-count'] = '${props.columns!.numberOfColumns}';
    style['column-gap'] = props.columns!.space ?? '';

    if (props.columns!.separator == true) {
      style['column-rule'] = '1px solid black';
    }
  }

  return self.hFunc({'tagName': 'article', 'style': style}) as web.HTMLElement;
}

web.HTMLElement _renderWrapper(HtmlRenderer self, List<web.HTMLElement> children) {
  final style = <String, String>{};
  if (self.options.ignoreWidth) {
    style['width'] = '100%';
  }
  return self.hFunc({
    'tagName': 'div',
    'className': '${self.className}-wrapper ${self.options.hideWrapperOnPrint ? 'hide-wrapper-on-print' : ''}',
    'style': style,
    'children': children
  }) as web.HTMLElement;
}

List<Section> _splitBySection(HtmlRenderer self, List<OpenXmlElement> elements, SectionProperties defaultProps) {
  final sections = <Section>[];
  var current = <OpenXmlElement>[];

  for (final el in elements) {
    if (el is WmlParagraph) {
      final props = el.props as ParagraphProperties?;
      if (props?.sectionProps != null) {
        current.add(el);
        sections.add(Section(props!.sectionProps!, current, false));
        current = [];
      } else {
        current.add(el);
      }
    } else {
      current.add(el);
    }
  }

  if (current.isNotEmpty) {
    sections.add(Section(defaultProps, current, false));
  }

  return sections;
}

List<List<Section>> _groupByPageBreaks(HtmlRenderer self, List<Section> sections) {
  final result = <List<Section>>[];
  var current = <Section>[];

  for (final section in sections) {
    if (section.pageBreak && current.isNotEmpty) {
      result.add(current);
      current = [];
    }
    current.add(section);
  }

  if (current.isNotEmpty) {
    result.add(current);
  }

  return result;
}

void _renderHeaderFooter(HtmlRenderer self, List<FooterHeaderReference> refs, SectionProperties props, int page, bool firstOfSection, web.HTMLElement into) {
  if (refs.isEmpty) return;

  var ref = (props.titlePage == true && firstOfSection
      ? refs.cast<FooterHeaderReference?>().firstWhere((x) => x?.type == 'first', orElse: () => null)
      : null);
  ref ??= (page % 2 == 1
      ? refs.cast<FooterHeaderReference?>().firstWhere((x) => x?.type == 'even', orElse: () => null)
      : null);
  ref ??= refs.cast<FooterHeaderReference?>().firstWhere((x) => x?.type == 'default', orElse: () => null);

  if (ref == null) return;

  final part = self.document.findPartByRelId(ref.id ?? '', self.document.documentPart);
  if (part is BaseHeaderFooterPart) {
    self.currentPart = part;
    if (!self.usedHederFooterParts.contains(part.path)) {
      self.processElement(part.rootElement!);
      self.usedHederFooterParts.add(part.path);
    }

    final elList = _renderElements(self, [part.rootElement!], into);
    if (elList.isNotEmpty && props.pageMargins != null) {
      final el = elList[0] as web.HTMLElement;
      if (part.rootElement!.type == DomType.header) {
        el.style.marginTop = 'calc(${props.pageMargins!.header} - ${props.pageMargins!.top})';
        el.style.minHeight = 'calc(${props.pageMargins!.top} - ${props.pageMargins!.header})';
      } else if (part.rootElement!.type == DomType.footer) {
        el.style.marginBottom = 'calc(${props.pageMargins!.footer} - ${props.pageMargins!.bottom})';
        el.style.minHeight = 'calc(${props.pageMargins!.bottom} - ${props.pageMargins!.footer})';
      }
    }

    self.currentPart = null;
  }
}

web.HTMLElement? _renderNotes(HtmlRenderer self, List<String> noteIds, Map<String, WmlFootnote> notesMap) {
  if (noteIds.isEmpty) return null;

  final result = self.hFunc({'tagName': 'ol', 'className': '${self.className}-notes'}) as web.HTMLElement;
  final notes = noteIds.map((id) => notesMap[id]).where((x) => x != null).cast<WmlFootnote>().toList();

  for (final note in notes) {
    final li = self.hFunc({
      'tagName': 'li',
      'id': '${self.className}-${note.noteType}-${note.id}',
      'className': '${self.className}-note'
    }) as web.HTMLElement;
    _renderElements(self, note.children ?? [], li);
    result.appendChild(li);
  }

  return result;
}

extension on HtmlRenderer {
  void processElement(OpenXmlElement element) {
    if (element.children != null) {
      for (final e in element.children!) {
        e.parent = element;
        if (e.type == DomType.table) {
          _processTable(this, e as WmlTable);
        } else {
          processElement(e);
        }
      }
    }
  }

  web.Node? renderElement(OpenXmlElement element) {
    switch (element.type) {
      case DomType.paragraph:
        return _renderParagraph(this, element as WmlParagraph);
      case DomType.bookmarkStart:
        return _renderBookmarkStart(this, element as WmlBookmarkStart);
      case DomType.bookmarkEnd:
        return null;
      case DomType.run:
        return _renderRun(this, element as WmlRun);
      case DomType.table:
        return _renderTable(this, element as WmlTable);
      case DomType.row:
        return _renderTableRow(this, element as WmlTableRow);
      case DomType.cell:
        return _renderTableCell(this, element as WmlTableCell);
      case DomType.hyperlink:
        return _renderHyperlink(this, element as WmlHyperlink);
      case DomType.smartTag:
        return _renderSmartTag(this, element as WmlSmartTag);
      case DomType.text:
        return _renderText(this, element as WmlText);
      case DomType.tab:
        return _renderTab(this, element);
      case DomType.symbol:
        return _renderSymbol(this, element as WmlSymbol);
      case DomType.lineBreak:
        return _renderBreak(this, element as WmlBreak);
      case DomType.footnoteReference:
      case DomType.endnoteReference:
        return _renderNoteReference(this, element as WmlNoteReference);
      case DomType.image:
        return _renderImage(this, element as IDomImage);
      case DomType.altChunk:
        return _renderAltChunk(this, element as WmlAltChunk);
      default:
        return null;
    }
  }
}
