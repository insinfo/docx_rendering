part of '../html_renderer.dart';

web.Node _renderParagraph(HtmlRenderer self, WmlParagraph paragraph) {
  final style = <String, String>{};
  _copyStyleProperties(self, paragraph.cssStyle ?? {}, style);

  final numberingClass = paragraph.props?.numbering != null
      ? '${self.className}-num-${paragraph.props!.numbering!.id}-${paragraph.props!.numbering!.level}'
      : '';

  final children = _renderElements(self, paragraph.children ?? [], self.hFunc({'tagName': 'p'}) as web.HTMLElement);
  return self.hFunc({
    'tagName': 'p',
    'className': '${_processStyleName(self, paragraph.styleName)} ${paragraph.className ?? ''} $numberingClass',
    'style': style,
    'children': children
  }) as web.Node;
}

web.Node _renderBookmarkStart(HtmlRenderer self, WmlBookmarkStart bookmark) {
  return self.hFunc({
    'tagName': 'span',
    'id': bookmark.name ?? '',
  }) as web.Node;
}

web.Node _renderRun(HtmlRenderer self, WmlRun run) {
  if (run.children == null || run.children!.isEmpty) {
    return self.hFunc({'tagName': 'span'}) as web.Node;
  }



  final children = _renderElements(self, run.children!, self.hFunc({'tagName': 'span'}) as web.HTMLElement);
  return self.hFunc({
    'tagName': 'span',
    'className': run.id != null ? _processStyleName(self, run.id) : '',
    'style': run.cssStyle ?? {},
    'children': children
  }) as web.Node;
}

web.Node _renderHyperlink(HtmlRenderer self, WmlHyperlink hyperlink) {
  final children = _renderElements(self, hyperlink.children ?? [], self.hFunc({'tagName': 'a'}) as web.HTMLElement);
  var href = '';
  if (hyperlink.anchor != null) {
    href = '#${hyperlink.anchor}';
  } else if (hyperlink.id != null && self.document.documentPart != null) {
    final rel = (self.document.documentPart!.rels ?? <Relationship>[]).cast<Relationship?>().firstWhere(
        (x) => x?.id == hyperlink.id, orElse: () => null);
    if (rel != null) {
      href = rel.target;
    }
  }

  return self.hFunc({
    'tagName': 'a',
    'href': href,
    'children': children
  }) as web.Node;
}

web.Node _renderSmartTag(HtmlRenderer self, WmlSmartTag smartTag) {
  final children = _renderElements(self, smartTag.children ?? [], self.hFunc({'tagName': 'span'}) as web.HTMLElement);
  return self.hFunc({
    'tagName': 'span',
    'className': '${self.className}-smarttag',
    'children': children
  }) as web.Node;
}

web.Node _renderText(HtmlRenderer self, WmlText text) {
  return web.Text(text.text);
}

web.Node _renderTab(HtmlRenderer self, OpenXmlElement tab) {
  return self.hFunc({
    'tagName': 'span',
    'style': {'white-space': 'pre'},
    'children': ['\t']
  }) as web.Node;
}

web.Node _renderSymbol(HtmlRenderer self, WmlSymbol symbol) {
  return self.hFunc({
    'tagName': 'span',
    'style': {'font-family': symbol.font},
    'children': [String.fromCharCode(symbol.char)]
  }) as web.Node;
}

web.Node _renderBreak(HtmlRenderer self, WmlBreak breakEl) {
  if (breakEl.breakType == 'page' && self.options.breakPages) {
    return self.hFunc({
      'tagName': 'hr',
      'className': '${self.className}-page-break',
    }) as web.Node;
  }
  return self.hFunc({'tagName': 'br'}) as web.Node;
}

web.Node? _renderNoteReference(HtmlRenderer self, WmlNoteReference noteRef) {
  return self.hFunc({
    'tagName': 'sup',
    'children': [
      self.hFunc({
        'tagName': 'a',
        'href': '#${self.className}-${noteRef.type == DomType.footnoteReference ? 'footnote' : 'endnote'}-${noteRef.id}',
        'children': ['[${noteRef.id}]']
      })
    ]
  }) as web.Node;
}

web.Node? _renderImage(HtmlRenderer self, IDomImage image) {
  var src = image.src;
  if (src.startsWith('word/media/')) {
    // This is asynchronous, but render methods are mostly synchronous here to avoid breaking the recursive structure
    // Let's create a placeholder img element and load async
    final img = self.hFunc({
      'tagName': 'img',
      'style': image.cssStyle ?? {},
    }) as web.HTMLImageElement;

    self.tasks.add(self.document.loadDocumentImage(src, self.currentPart).then((url) {
      if (url != null) img.src = url;
    }));
    return img;
  }

  return self.hFunc({
    'tagName': 'img',
    'src': src,
    'style': image.cssStyle ?? {},
  }) as web.Node;
}

web.Node _renderAltChunk(HtmlRenderer self, WmlAltChunk altChunk) {
  final span = self.hFunc({'tagName': 'span'}) as web.HTMLElement;
  if (self.options.renderAltChunks) {
    self.tasks.add(self.document.loadAltChunk(altChunk.id ?? '').then((html) {
      if (html != null) {
        span.innerHTML = html.toJS;
      }
    }));
  }
  return span;
}

void _refreshTabStops(HtmlRenderer self) {
  // Ignored for now
}
