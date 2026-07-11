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

List<web.Node> _renderElements(HtmlRenderer self, List<OpenXmlElement> elements, [web.HTMLElement? into]) {
  final result = <web.Node>[];

  for (final element in elements) {
    final node = self.renderElement(element);
    if (node != null) {
      if (into != null) {
        into.appendChild(node);
      }
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
  return self.hFunc({
    'tagName': 'div',
    'className': '${self.className}-wrapper',
    'children': children
  }) as web.HTMLElement;
}

/// Checks if an element is a page break element.
bool _isPageBreakElement(HtmlRenderer self, OpenXmlElement elem) {
  if (elem.type != DomType.lineBreak) return false;
  final br = elem as WmlBreak;

  if (br.breakType == 'lastRenderedPageBreak') {
    return !self.options.ignoreLastRenderedPageBreak;
  }

  return br.breakType == 'page';
}

/// Checks if section properties change requires a page break.
bool _isPageBreakSection(SectionProperties? prev, SectionProperties? next) {
  if (prev == null || next == null) return false;
  return prev.pageSize?.orientation != next.pageSize?.orientation
      || prev.pageSize?.width != next.pageSize?.width
      || prev.pageSize?.height != next.pageSize?.height;
}

List<Section> _splitBySection(HtmlRenderer self, List<OpenXmlElement> elements, SectionProperties defaultProps) {
  var current = Section(SectionProperties(), [], false);
  final result = [current];

  for (final elem in elements) {
    if (elem.type == DomType.paragraph) {
      final p = elem as WmlParagraph;

      // Check pageBreakBefore style
      final s = self.findStyle(p.styleName);
      if (s?.paragraphProps?.pageBreakBefore == true) {
        current.sectProps = current.sectProps;
        current.pageBreak = true;
        current = Section(SectionProperties(), [], false);
        result.add(current);
      }
    }

    current.elements.add(elem);

    if (elem.type == DomType.paragraph) {
      final p = elem as WmlParagraph;
      final pProps = p.props as ParagraphProperties?;
      final sectProps = pProps?.sectionProps;
      var pBreakIndex = -1;
      var rBreakIndex = -1;

      if (self.options.breakPages && p.children != null) {
        for (var pi = 0; pi < p.children!.length; pi++) {
          final r = p.children![pi];
          if (r.children != null) {
            for (var ri = 0; ri < r.children!.length; ri++) {
              if (_isPageBreakElement(self, r.children![ri])) {
                pBreakIndex = pi;
                rBreakIndex = ri;
                break;
              }
            }
          }
          if (pBreakIndex != -1) break;
        }
      }

      if (sectProps != null || pBreakIndex != -1) {
        current.sectProps = sectProps ?? current.sectProps;
        current.pageBreak = pBreakIndex != -1;
        current = Section(SectionProperties(), [], false);
        result.add(current);
      }

      if (pBreakIndex != -1 && p.children != null) {
        final breakRun = p.children![pBreakIndex];
        final splitRun = breakRun.children != null && rBreakIndex < breakRun.children!.length - 1;

        if (pBreakIndex < p.children!.length - 1 || splitRun) {
          final children = p.children!;
          final newParagraph = WmlParagraph()
            ..type = p.type
            ..styleName = p.styleName
            ..className = p.className
            ..cssStyle = p.cssStyle != null ? Map.from(p.cssStyle!) : null
            ..props = p.props
            ..children = children.sublist(pBreakIndex);
          p.children = children.sublist(0, pBreakIndex);
          current.elements.add(newParagraph);

          if (splitRun && breakRun.children != null) {
            final runChildren = breakRun.children!;
            final newRun = WmlRun()
              ..type = breakRun.type
              ..cssStyle = breakRun.cssStyle != null ? Map.from(breakRun.cssStyle!) : null
              ..children = runChildren.sublist(0, rBreakIndex);
            p.children!.add(newRun);
            breakRun.children = runChildren.sublist(rBreakIndex);
          }
        }
      }
    }
  }

  // Back-fill sectProps from the end
  SectionProperties? currentSectProps;
  for (var i = result.length - 1; i >= 0; i--) {
    if (result[i].sectProps.pageSize == null && result[i].sectProps.pageMargins == null) {
      result[i].sectProps = currentSectProps ?? defaultProps;
    } else {
      currentSectProps = result[i].sectProps;
    }
  }

  return result;
}

List<List<Section>> _groupByPageBreaks(HtmlRenderer self, List<Section> sections) {
  var current = <Section>[];
  SectionProperties? prev;
  final result = <List<Section>>[current];

  for (final s in sections) {
    current.add(s);

    if (s.pageBreak || _isPageBreakSection(prev, s.sectProps)) {
      current = <Section>[];
      result.add(current);
    }

    prev = s.sectProps;
  }

  return result.where((x) => x.isNotEmpty).toList();
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

web.HTMLElement? _renderNotes(HtmlRenderer self, List<String> noteIds, Map<String, WmlBaseNote> notesMap) {
  final notes = noteIds.map((id) => notesMap[id]).where((x) => x != null).cast<WmlBaseNote>().toList();

  if (notes.isNotEmpty) {
    return self.hFunc({'tagName': 'ol', 'children': _renderElements(self, notes)}) as web.HTMLElement;
  }

  return null;
}

/// Creates an element from an OpenXmlElement using the toHTML pattern.
web.HTMLElement _toHTML(HtmlRenderer self, OpenXmlElement elem, String ns, String tagName, [List<web.Node>? children]) {
  final Map<String, String> style;
  String? lang;
  if (elem.cssStyle != null) {
    style = Map<String, String>.from(elem.cssStyle!);
    lang = style.remove('\$lang');
  } else {
    style = {};
  }

  final className = cx([elem.className, elem.styleName != null ? _processStyleName(self, elem.styleName) : null]);

  final props = <String, dynamic>{
    'ns': ns == HtmlNs.html ? null : ns,
    'tagName': tagName,
    'className': className.isNotEmpty ? className : null,
    'style': style.isNotEmpty ? style : null,
    'children': children ?? _renderElements(self, elem.children ?? []),
  };

  if (lang != null && lang.isNotEmpty) {
    props['lang'] = lang;
  }

  return self.hFunc(props) as web.HTMLElement;
}

/// Renders a container element.
web.Node _renderContainer(HtmlRenderer self, OpenXmlElement elem, String tagName) {
  return self.hFunc({
    'tagName': tagName,
    'children': _renderElements(self, elem.children ?? [])
  }) as web.Node;
}

/// Renders a container element with a namespace.
web.Node _renderContainerNS(HtmlRenderer self, OpenXmlElement elem, String ns, String tagName, [Map<String, dynamic>? extraProps]) {
  final props = <String, dynamic>{
    'ns': ns,
    'tagName': tagName,
    'children': _renderElements(self, elem.children ?? []),
  };
  if (extraProps != null) {
    props.addAll(extraProps);
  }
  return self.hFunc(props) as web.Node;
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
      case DomType.drawing:
        return _renderDrawing(this, element);
      case DomType.image:
        return _renderImage(this, element as IDomImage);
      case DomType.text:
        return _renderText(this, element as WmlText);
      case DomType.deletedText:
        return _renderDeletedText(this, element as WmlText);
      case DomType.tab:
        return _renderTab(this, element);
      case DomType.symbol:
        return _renderSymbol(this, element as WmlSymbol);
      case DomType.lineBreak:
        return _renderBreak(this, element as WmlBreak);
      case DomType.noBreakHyphen:
        return hFunc({'tagName': 'wbr'}) as web.Node;
      case DomType.footer:
        return _renderContainer(this, element, 'footer');
      case DomType.header:
        return _renderContainer(this, element, 'header');
      case DomType.footnote:
      case DomType.endnote:
        return _renderContainer(this, element, 'li');
      case DomType.footnoteReference:
        return _renderFootnoteReference(this, element as WmlNoteReference);
      case DomType.endnoteReference:
        return _renderEndnoteReference(this, element as WmlNoteReference);
      case DomType.altChunk:
        return _renderAltChunk(this, element as WmlAltChunk);
      case DomType.mmlMath:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'math', {'xmlns': HtmlNs.mathML});
      case DomType.mmlMathParagraph:
        return _renderContainer(this, element, 'span');
      case DomType.mmlFraction:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'mfrac');
      case DomType.mmlBase:
        final parentType = element.parent?.type;
        final tagName = parentType == DomType.mmlMatrixRow ? 'mtd' : 'mrow';
        return _renderContainerNS(this, element, HtmlNs.mathML, tagName);
      case DomType.mmlNumerator:
      case DomType.mmlDenominator:
      case DomType.mmlFunction:
      case DomType.mmlLimit:
      case DomType.mmlBox:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'mrow');
      case DomType.mmlLimitLower:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'munder');
      case DomType.mmlMatrix:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'mtable');
      case DomType.mmlMatrixRow:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'mtr');
      case DomType.mmlSuperscript:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'msup');
      case DomType.mmlSubscript:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'msub');
      case DomType.mmlDegree:
      case DomType.mmlSuperArgument:
      case DomType.mmlSubArgument:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'mn');
      case DomType.mmlFunctionName:
        return _renderContainerNS(this, element, HtmlNs.mathML, 'ms');
      case DomType.mmlRadical:
        return _renderMmlRadical(this, element);
      case DomType.mmlDelimiter:
        return _renderMmlDelimiter(this, element);
      case DomType.mmlNary:
        return _renderMmlNary(this, element);
      case DomType.mmlPreSubSuper:
        return _renderMmlPreSubSuper(this, element);
      case DomType.mmlGroupChar:
        return _renderMmlGroupChar(this, element);
      case DomType.mmlBar:
        return _renderMmlBar(this, element);
      case DomType.mmlRun:
        return _renderMmlRun(this, element);
      case DomType.mmlEquationArray:
        return _renderMllList(this, element);
      case DomType.vmlPicture:
        return _renderVmlPicture(this, element);
      case DomType.vmlElement:
        return _renderVmlElement(this, element as VmlElement);
      case DomType.inserted:
        return _renderInserted(this, element);
      case DomType.deleted:
        return _renderDeleted(this, element);
      default:
        return null;
    }
  }

  IDomStyle? findStyle(String? styleName) {
    return styleName != null && styleMap != null ? styleMap![styleName] : null;
  }
}

web.Node? _renderInserted(HtmlRenderer self, OpenXmlElement elem) {
  if (self.options.renderChanges) {
    return _renderContainer(self, elem, 'ins');
  }
  final elements = elem.children != null
      ? elem.children!.map((e) => self.renderElement(e)).whereType<web.Node>().toList()
      : <web.Node>[];
  final fragment = web.document.createDocumentFragment();
  for (final el in elements) {
    fragment.appendChild(el);
  }
  return fragment;
}

web.Node? _renderDeleted(HtmlRenderer self, OpenXmlElement elem) {
  if (self.options.renderChanges) {
    return _renderContainer(self, elem, 'del');
  }
  return null;
}
