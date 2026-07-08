part of '../html_renderer.dart';

web.Node _renderParagraph(HtmlRenderer self, WmlParagraph paragraph) {
  final result = _toHTML(self, paragraph, HtmlNs.html, 'p');

  final style = self.findStyle(paragraph.styleName);
  paragraph.tabs ??= style?.paragraphProps?.tabs;

  final numbering = (paragraph.props as ParagraphProperties?)?.numbering ?? style?.paragraphProps?.numbering;

  if (numbering != null) {
    final existing = result.getAttribute('class') ?? '';
    final numClass = '${self.className}-num-${numbering.id}-${numbering.level}';
    result.setAttribute('class', '$existing $numClass'.trim());
  }

  return result;
}

web.Node _renderBookmarkStart(HtmlRenderer self, WmlBookmarkStart bookmark) {
  return self.hFunc({
    'tagName': 'span',
    'id': bookmark.name ?? '',
  }) as web.Node;
}

web.Node? _renderRun(HtmlRenderer self, WmlRun run) {
  // Skip field runs (instrText, fldChar)
  if (run.fieldRun == true) return null;

  var children = _renderElements(self, run.children ?? []);

  if (run.verticalAlign != null) {
    children = [
      self.hFunc({
        'tagName': run.verticalAlign,
        'children': _renderElements(self, run.children ?? [])
      }) as web.Node
    ];
  }

  final result = _toHTML(self, run, HtmlNs.html, 'span', children);

  if (run.id != null) {
    (result as web.HTMLElement).id = run.id!;
  }

  // Mark PAGE/NUMPAGES field results so the pagination pass can renumber them.
  if (run.fieldType != null) {
    result.setAttribute('data-docx-field', run.fieldType!);
  }

  return result;
}

web.Node _renderHyperlink(HtmlRenderer self, WmlHyperlink hyperlink) {
  var href = '';

  if (hyperlink.id != null && self.document.documentPart != null) {
    final rel = (self.document.documentPart!.rels ?? <Relationship>[]).cast<Relationship?>().firstWhere(
        (x) => x?.id == hyperlink.id && x?.targetMode == 'External', orElse: () => null);
    if (rel != null) {
      href = rel.target;
    }
  }

  if (hyperlink.anchor != null) {
    href += '#${hyperlink.anchor}';
  }

  // Use toHTML-style but set href manually
  final result = _toHTML(self, hyperlink, HtmlNs.html, 'a');
  (result as web.HTMLAnchorElement).href = href;
  return result;
}

web.Node _renderSmartTag(HtmlRenderer self, WmlSmartTag smartTag) {
  return _renderContainer(self, smartTag, 'span');
}

web.Node _renderDrawing(HtmlRenderer self, OpenXmlElement elem) {
  final result = _toHTML(self, elem, HtmlNs.html, 'div');

  result.style.display = 'inline-block';
  result.style.position = 'relative';
  result.style.textIndent = '0px';

  return result;
}

web.Node _renderText(HtmlRenderer self, WmlText text) {
  return web.Text(text.text);
}

web.Node? _renderDeletedText(HtmlRenderer self, WmlText text) {
  return self.options.renderChanges ? _renderText(self, text) : null;
}

web.Node _renderTab(HtmlRenderer self, OpenXmlElement tab) {
  final tabSpan = self.hFunc({
    'tagName': 'span',
    'children': ['\u2003'] // em space
  }) as web.HTMLElement;

  if (self.options.experimental) {
    tabSpan.className = '${self.className}-tab-stop';
    final stops = _findParent<WmlParagraph>(tab, DomType.paragraph)?.tabs;
    self.currentTabs.add({'stops': stops, 'span': tabSpan});
  }

  return tabSpan;
}

web.Node _renderSymbol(HtmlRenderer self, WmlSymbol symbol) {
  return self.hFunc({
    'tagName': 'span',
    'style': {'font-family': symbol.font},
    'children': [String.fromCharCode(symbol.char)]
  }) as web.Node;
}

web.Node? _renderBreak(HtmlRenderer self, WmlBreak breakEl) {
  // Only render textWrapping breaks as <br>, everything else returns null
  return breakEl.breakType == 'textWrapping'
      ? self.hFunc({'tagName': 'br'}) as web.Node
      : null;
}

web.Node _renderFootnoteReference(HtmlRenderer self, WmlNoteReference noteRef) {
  self.currentFootnoteIds.add(noteRef.id);
  return self.hFunc({
    'tagName': 'sup',
    'children': ['${self.currentFootnoteIds.length}']
  }) as web.Node;
}

web.Node _renderEndnoteReference(HtmlRenderer self, WmlNoteReference noteRef) {
  self.currentEndnoteIds.add(noteRef.id);
  return self.hFunc({
    'tagName': 'sup',
    'children': ['${self.currentEndnoteIds.length}']
  }) as web.Node;
}

web.Node? _renderImage(HtmlRenderer self, IDomImage image) {
  final result = _toHTML(self, image, HtmlNs.html, 'img') as web.HTMLImageElement;
  var transform = image.cssStyle?['transform'];

  if (image.srcRect != null && image.srcRect!.any((x) => x != 0)) {
    final left = image.srcRect![0];
    final top = image.srcRect![1];
    final right = image.srcRect![2];
    final bottom = image.srcRect![3];
    transform = 'scale(${1 / (1 - left - right)}, ${1 / (1 - top - bottom)})';
    result.style.setProperty('clip-path',
        'rect(${(100 * top).toStringAsFixed(2)}% ${(100 * (1 - right)).toStringAsFixed(2)}% ${(100 * (1 - bottom)).toStringAsFixed(2)}% ${(100 * left).toStringAsFixed(2)}%)');
  }

  if (image.rotation != null && image.rotation != 0) {
    transform = 'rotate(${image.rotation}deg) ${transform ?? ''}';
  }

  if (transform != null && transform.trim().isNotEmpty) {
    result.style.transform = transform.trim();
  }

  if (image.src.isNotEmpty) {
    self.tasks.add(self.document.loadDocumentImage(image.src, self.currentPart).then((url) {
      if (url != null) result.src = url;
    }));
  }

  return result;
}

web.Node _renderAltChunk(HtmlRenderer self, WmlAltChunk altChunk) {
  if (!self.options.renderAltChunks) return self.hFunc({'tagName': 'span'}) as web.HTMLElement;

  final result = self.hFunc({'tagName': 'iframe'}) as web.HTMLIFrameElement;

  self.tasks.add(self.document.loadAltChunk(altChunk.id ?? '', self.currentPart).then((html) {
    if (html != null) {
      result.setAttribute('srcdoc', html);
    }
  }));

  return result;
}

void _refreshTabStops(HtmlRenderer self) {
  // Tab stop refresh (experimental feature)
  if (!self.options.experimental) return;
  // Implementation would use setTimeout + computePixelToPoint + updateTabStop
}

/// Finds a parent element of a specific type.
T? _findParent<T extends OpenXmlElement>(OpenXmlElement elem, DomType type) {
  var parent = elem.parent;
  while (parent != null && parent.type != type) {
    parent = parent.parent;
  }
  return parent as T?;
}
