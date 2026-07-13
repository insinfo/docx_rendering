/// Captura, no browser, a geometria final das páginas DOM para exportação PDF.
///
/// A função lê as `<section>` já produzidas pela paginação e converte suas
/// coordenadas CSS em pontos PDF. Assim [PdfExporter] não recalcula word-wrap:
/// texto, células, imagens e linhas usam as posições efetivamente renderizadas.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'pdf_export.dart';

Future<PdfLayoutPlan> capturePdfLayout(
  web.Element root, {
  String pageSelector = 'section.docx',
  PdfPageFormat pageFormat = const PdfPageFormat(),
}) async {
  final sections = root.querySelectorAll(pageSelector);
  final pages = <PdfLayoutPage>[];

  for (var i = 0; i < sections.length; i++) {
    final section = sections.item(i);
    if (section is! web.HTMLElement) continue;

    // content-visibility:auto pode manter páginas distantes apenas como
    // placeholders. Materializa uma página por vez e restaura o estilo logo
    // após a leitura para não explodir o custo de layout do documento inteiro.
    final oldVisibility = section.style.getPropertyValue('content-visibility');
    section.style.setProperty('content-visibility', 'visible');
    try {
      pages.add(_capturePage(section, pageFormat));
    } finally {
      if (oldVisibility.isEmpty) {
        section.style.removeProperty('content-visibility');
      } else {
        section.style.setProperty('content-visibility', oldVisibility);
      }
    }
    await Future<void>.delayed(Duration.zero);
  }
  return PdfLayoutPlan(pages);
}

/// Captures the continuous, float-paginated ProseMirror surface as physical
/// PDF pages.
///
/// Tiptap Pages does not create one editable DOM subtree per page. It keeps a
/// single contenteditable flow and inserts header/footer/gap floats. Falling
/// back to AST layout therefore loses every repeated header/footer, anchored
/// text box and the browser's real table wrapping. This function maps the
/// final DOM rectangles back into the physical page intervals instead.
Future<PdfLayoutPlan> capturePaginatedPdfLayout(
  web.HTMLElement root, {
  PdfPageFormat pageFormat = const PdfPageFormat(),
}) async {
  await _decodeImages(root);
  final pageCount = math.max(
    1,
    int.tryParse(root.getAttribute('data-page-count') ?? '') ?? 1,
  );
  final pageWidth = _customPx(
    root,
    '--tiptap-page-width',
    fallback: root.offsetWidth.toDouble(),
  );
  final pageHeight = _customPx(
    root,
    '--tiptap-page-height',
    fallback: pageWidth * 841.89 / 595.28,
  );
  final pageGap = _customPx(root, '--tiptap-page-gap', fallback: 0);
  final bounds = root.getBoundingClientRect();
  final visualScaleX =
      root.offsetWidth > 0 ? bounds.width / root.offsetWidth : 1.0;
  final visualScaleY =
      root.offsetHeight > 0 ? bounds.height / root.offsetHeight : visualScaleX;
  final physicalPages = _physicalPageAnchors(
    root,
    bounds: bounds,
    pageCount: pageCount,
    nominalPageHeight: pageHeight * visualScaleY,
    nominalPageGap: pageGap * visualScaleY,
  );
  final geometry = _PaginatedGeometry(
    bounds: bounds,
    pages: physicalPages,
    pageWidth: pageWidth,
    visualScaleX: visualScaleX,
    visualScaleY: visualScaleY,
    pdf: pageFormat,
  );
  final pages = List.generate(pageCount, (_) => <PdfLayoutItem>[]);

  // Cell backgrounds and borders must precede text and images.
  final cells = root.querySelectorAll('td, th');
  for (var index = 0; index < cells.length; index++) {
    final node = cells.item(index);
    if (node is! web.HTMLElement) continue;
    final rect = node.getBoundingClientRect();
    if (!_visible(rect)) continue;
    final style = web.window.getComputedStyle(node);
    final fill = _opaqueColor(style.getPropertyValue('background-color'));
    final stroke = _opaqueColor(style.getPropertyValue('border-top-color'));
    final borderPx = _px(
      style.getPropertyValue('border-top-width'),
      fallback: 1,
    );
    geometry.forEachElementIntersection(node, rect,
        (page, x, y, width, height) {
      pages[page].add(PdfRectItem(
        x,
        y,
        width,
        height,
        strokeWidth: math.max(.25, borderPx * geometry.scaleYForPage(page)),
        strokeColor: stroke,
        fillColor: fill,
      ));
    });
  }

  final rules = root.querySelectorAll('hr');
  for (var index = 0; index < rules.length; index++) {
    final node = rules.item(index);
    if (node is! web.Element) continue;
    final rect = node.getBoundingClientRect();
    final location = geometry.locationForElement(node, rect);
    if (location == null) continue;
    pages[location.page].add(PdfLineItem(
      location.x,
      location.y + rect.height * geometry.scaleYForPage(location.page) / 2,
      location.x + rect.width * geometry.scaleX,
      location.y + rect.height * geometry.scaleYForPage(location.page) / 2,
    ));
  }

  final images = root.querySelectorAll('img');
  for (var index = 0; index < images.length; index++) {
    final node = images.item(index);
    if (node is! web.HTMLImageElement) continue;
    final src = node.src;
    final rect = node.getBoundingClientRect();
    final location = geometry.locationForElement(node, rect);
    if (!src.startsWith('data:image/') || location == null) continue;
    pages[location.page].add(PdfImageItem(
      src,
      location.x,
      location.y,
      rect.width * geometry.scaleX,
      rect.height * geometry.scaleYForPage(location.page),
      // Repeated DOCX headers/footers reuse the same media relationship.
      // A source-stable alias makes jsPDF embed that image only once.
      alias: 'dom-image-${src.hashCode}',
    ));
  }

  _walkText(root, (text) {
    _capturePaginatedTextNode(text, geometry, pages);
  });
  _capturePaginatedListMarkers(root, geometry, pages);

  return PdfLayoutPlan([
    for (final items in pages) PdfLayoutPage(items),
  ]);
}

Future<void> _decodeImages(web.HTMLElement root) async {
  final images = root.querySelectorAll('img');
  for (var index = 0; index < images.length; index++) {
    final node = images.item(index);
    if (node is! web.HTMLImageElement || node.complete) continue;
    try {
      await node.decode().toDart;
    } catch (_) {
      // Broken optional media must not abort an otherwise valid PDF export.
    }
  }
}

PdfLayoutPage _capturePage(web.HTMLElement section, PdfPageFormat format) {
  final page = section.getBoundingClientRect();
  if (page.width <= 0 || page.height <= 0) return const PdfLayoutPage([]);
  final scaleX = format.width / page.width;
  final scaleY = format.height / page.height;
  // `getBoundingClientRect` includes CSS `zoom`/transforms, whereas computed
  // font sizes remain in the element's unscaled CSS coordinate space. Keep
  // that visual scale separate so display zoom changes neither the PDF font
  // size nor its baseline.
  final layoutHeight = section.offsetHeight.toDouble();
  final visualScaleY = layoutHeight > 0 ? page.height / layoutHeight : 1.0;
  final items = <PdfLayoutItem>[];

  // Bordas de tabela são vetoriais e ficam atrás do texto.
  final cells = section.querySelectorAll('td, th');
  for (var i = 0; i < cells.length; i++) {
    final node = cells.item(i);
    if (node is! web.Element) continue;
    final cell = node;
    final rect = cell.getBoundingClientRect();
    if (!_visible(rect)) continue;
    items.add(PdfRectItem(
      (rect.left - page.left) * scaleX,
      (rect.top - page.top) * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    ));
  }

  final rules = section.querySelectorAll('hr');
  for (var i = 0; i < rules.length; i++) {
    final node = rules.item(i);
    if (node is! web.Element) continue;
    final rule = node;
    final rect = rule.getBoundingClientRect();
    if (!_visible(rect)) continue;
    final y = (rect.top + rect.height / 2 - page.top) * scaleY;
    items.add(PdfLineItem((rect.left - page.left) * scaleX, y,
        (rect.right - page.left) * scaleX, y));
  }

  final images = section.querySelectorAll('img');
  for (var i = 0; i < images.length; i++) {
    final node = images.item(i);
    if (node is! web.Element) continue;
    final image = node;
    final src = image.getAttribute('src');
    final rect = image.getBoundingClientRect();
    if (src == null || !src.startsWith('data:image/') || !_visible(rect)) {
      continue;
    }
    items.add(PdfImageItem(
      src,
      (rect.left - page.left) * scaleX,
      (rect.top - page.top) * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
      alias: 'page-image-$i-${src.hashCode}',
    ));
  }

  _walkText(section, (text) {
    _captureTextNode(text, page, scaleX, scaleY, visualScaleY, items);
  });
  _capturePageListMarkers(
    section,
    page,
    scaleX,
    scaleY,
    visualScaleY,
    items,
  );

  return PdfLayoutPage(items);
}

void _walkText(web.Node node, void Function(web.Text text) visitor) {
  for (var child = node.firstChild; child != null; child = child.nextSibling) {
    if (child.nodeType == 3) {
      visitor(child as web.Text);
    } else if (child.nodeType == 1) {
      final element = child as web.Element;
      final tag = element.tagName.toLowerCase();
      if (tag != 'script' &&
          tag != 'style' &&
          tag != 'svg' &&
          !element.hasAttribute('data-page-editor-ui')) {
        _walkText(element, visitor);
      }
    }
  }
}

void _captureTextNode(web.Text text, web.DOMRect page, double scaleX,
    double scaleY, double visualScaleY, List<PdfLayoutItem> items) {
  final value = text.data;
  final parent = text.parentElement;
  if (value.isEmpty || parent == null) return;
  final style = web.window.getComputedStyle(parent);
  if (style.getPropertyValue('display') == 'none' ||
      style.getPropertyValue('visibility') == 'hidden') {
    return;
  }

  final fontPx = _px(style.getPropertyValue('font-size'), fallback: 16);
  final visualFontPx = fontPx * visualScaleY;
  final fontSize = visualFontPx * scaleY;
  final weight = style.getPropertyValue('font-weight');
  final bold = weight == 'bold' || (int.tryParse(weight) ?? 400) >= 600;
  final italic = style.getPropertyValue('font-style') == 'italic';
  final family = _fontFamily(style.getPropertyValue('font-family'));
  final color = _color(style.getPropertyValue('color'));
  final range = web.document.createRange();
  var start = 0;

  while (start < value.length) {
    range
      ..setStart(text, start)
      ..setEnd(text, value.length);
    final remainingRects = range.getClientRects();
    if (remainingRects.length == 0) break;
    final first = remainingRects.item(0)!;

    var low = start + 1;
    var high = value.length;
    var best = low;
    while (low <= high) {
      final middle = (low + high) >> 1;
      range
        ..setStart(text, start)
        ..setEnd(text, middle);
      final rects = range.getClientRects();
      final oneLine =
          rects.length == 1 && (rects.item(0)!.top - first.top).abs() < 1;
      if (oneLine) {
        best = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    range
      ..setStart(text, start)
      ..setEnd(text, best);
    final rects = range.getClientRects();
    if (rects.length == 0) break;
    final rect = rects.item(0)!;
    final segment = value.substring(start, best);
    if (segment.isNotEmpty && _visible(rect)) {
      // DOMRect não expõe baseline. A aproximação pela métrica CSS é estável
      // e mantém o texto dentro da mesma linha medida pelo browser.
      final baseline = rect.top + math.min(rect.height, visualFontPx) * .82;
      items.add(PdfTextItem(
        segment,
        (rect.left - page.left) * scaleX,
        (baseline - page.top) * scaleY,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        color: color,
        fontFamily: family,
        letterSpacing: _letterSpacing(style) * scaleY * visualScaleY,
      ));
    }
    start = best;
  }
}

void _capturePaginatedTextNode(
  web.Text text,
  _PaginatedGeometry geometry,
  List<List<PdfLayoutItem>> pages,
) {
  final value = text.data;
  final parent = text.parentElement;
  if (value.isEmpty || parent == null) return;
  final style = web.window.getComputedStyle(parent);
  if (style.getPropertyValue('display') == 'none' ||
      style.getPropertyValue('visibility') == 'hidden') {
    return;
  }

  final fontPx = _px(style.getPropertyValue('font-size'), fallback: 16);
  final visualFontPx = fontPx * geometry.visualScaleY;
  final weight = style.getPropertyValue('font-weight');
  final bold = weight == 'bold' || (int.tryParse(weight) ?? 400) >= 600;
  final italic = style.getPropertyValue('font-style') == 'italic';
  final family = _fontFamily(style.getPropertyValue('font-family'));
  final color = _color(style.getPropertyValue('color'));
  final range = web.document.createRange();
  var start = 0;

  // A text node can wrap across several physical pages. Binary-search each
  // browser line so every segment receives its own measured page and x/y.
  while (start < value.length) {
    range
      ..setStart(text, start)
      ..setEnd(text, value.length);
    final remainingRects = range.getClientRects();
    if (remainingRects.length == 0) break;
    final first = remainingRects.item(0)!;
    var low = start + 1;
    var high = value.length;
    var best = low;
    while (low <= high) {
      final middle = (low + high) >> 1;
      range
        ..setStart(text, start)
        ..setEnd(text, middle);
      final rects = range.getClientRects();
      final oneLine =
          rects.length == 1 && (rects.item(0)!.top - first.top).abs() < 1;
      if (oneLine) {
        best = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    range
      ..setStart(text, start)
      ..setEnd(text, best);
    final rects = range.getClientRects();
    if (rects.length == 0) break;
    final rect = rects.item(0)!;
    final location = geometry.locationForElement(parent, rect);
    final segment = value.substring(start, best);
    if (location != null && segment.isNotEmpty) {
      final baseline = rect.top + math.min(rect.height, visualFontPx) * .82;
      final baselineLocation = geometry.pointForElement(
        parent,
        rect.left,
        baseline,
      );
      if (baselineLocation != null) {
        pages[baselineLocation.page].add(PdfTextItem(
          segment,
          baselineLocation.x,
          baselineLocation.y,
          fontSize:
              visualFontPx * geometry.scaleYForPage(baselineLocation.page),
          bold: bold,
          italic: italic,
          color: color,
          fontFamily: family,
          letterSpacing: _letterSpacing(style) *
              geometry.visualScaleY *
              geometry.scaleYForPage(baselineLocation.page),
        ));
      }
    }
    start = best;
  }
}

/// CSS list markers and `::before` counters do not create DOM text nodes.
/// Imported Word lists therefore expose their already-resolved label through
/// `data-docx-numbering-label`, which is captured explicitly for vector PDF.
void _capturePaginatedListMarkers(
  web.HTMLElement root,
  _PaginatedGeometry geometry,
  List<List<PdfLayoutItem>> pages,
) {
  final markers = root.querySelectorAll('li[data-docx-numbering-label]');
  for (var index = 0; index < markers.length; index++) {
    final element = markers.item(index);
    if (element is! web.HTMLElement) continue;
    final label = element.getAttribute('data-docx-numbering-label')?.trim();
    if (label == null || label.isEmpty) continue;
    final anchor = _firstVisibleText(element);
    if (anchor == null) continue;
    final style = web.window.getComputedStyle(anchor.text.parentElement!);
    final fontPx = _px(style.getPropertyValue('font-size'), fallback: 16);
    final visualFontPx = fontPx * geometry.visualScaleY;
    final markerWidth = _measureTextCss(label, style) * geometry.visualScaleX;
    final markerGap = fontPx * .4 * geometry.visualScaleX;
    final baseline =
        anchor.rect.top + math.min(anchor.rect.height, visualFontPx) * .82;
    final location = geometry.pointForElement(
      element,
      anchor.rect.left - markerWidth - markerGap,
      baseline,
    );
    if (location == null) continue;
    final weight = style.getPropertyValue('font-weight');
    pages[location.page].add(PdfTextItem(
      label,
      location.x,
      location.y,
      fontSize: visualFontPx * geometry.scaleYForPage(location.page),
      bold: weight == 'bold' || (int.tryParse(weight) ?? 400) >= 600,
      italic: style.getPropertyValue('font-style') == 'italic',
      color: _color(style.getPropertyValue('color')),
      fontFamily: _fontFamily(style.getPropertyValue('font-family')),
      letterSpacing: _letterSpacing(style) *
          geometry.visualScaleY *
          geometry.scaleYForPage(location.page),
    ));
  }
}

void _capturePageListMarkers(
  web.HTMLElement section,
  web.DOMRect page,
  double scaleX,
  double scaleY,
  double visualScaleY,
  List<PdfLayoutItem> items,
) {
  final visualScaleX =
      section.offsetWidth > 0 ? page.width / section.offsetWidth : visualScaleY;
  final markers = section.querySelectorAll('li[data-docx-numbering-label]');
  for (var index = 0; index < markers.length; index++) {
    final element = markers.item(index);
    if (element is! web.HTMLElement) continue;
    final label = element.getAttribute('data-docx-numbering-label')?.trim();
    if (label == null || label.isEmpty) continue;
    final anchor = _firstVisibleText(element);
    if (anchor == null) continue;
    final style = web.window.getComputedStyle(anchor.text.parentElement!);
    final fontPx = _px(style.getPropertyValue('font-size'), fallback: 16);
    final visualFontPx = fontPx * visualScaleY;
    final markerWidth = _measureTextCss(label, style) * visualScaleX;
    final markerGap = fontPx * .4 * visualScaleX;
    final weight = style.getPropertyValue('font-weight');
    items.add(PdfTextItem(
      label,
      (anchor.rect.left - markerWidth - markerGap - page.left) * scaleX,
      (anchor.rect.top +
              math.min(anchor.rect.height, visualFontPx) * .82 -
              page.top) *
          scaleY,
      fontSize: visualFontPx * scaleY,
      bold: weight == 'bold' || (int.tryParse(weight) ?? 400) >= 600,
      italic: style.getPropertyValue('font-style') == 'italic',
      color: _color(style.getPropertyValue('color')),
      fontFamily: _fontFamily(style.getPropertyValue('font-family')),
      letterSpacing: _letterSpacing(style) * visualScaleY * scaleY,
    ));
  }
}

({web.Text text, web.DOMRect rect})? _firstVisibleText(web.Node root) {
  for (var child = root.firstChild; child != null; child = child.nextSibling) {
    if (child.nodeType == 3) {
      final text = child as web.Text;
      if (text.data.trim().isEmpty) continue;
      final range = web.document.createRange()
        ..setStart(text, 0)
        ..setEnd(text, math.min(1, text.data.length));
      final rects = range.getClientRects();
      if (rects.length == 0) continue;
      final rect = rects.item(0)!;
      if (_visible(rect)) return (text: text, rect: rect);
    } else if (child.nodeType == 1) {
      final element = child as web.Element;
      if (element.hasAttribute('data-page-editor-ui')) continue;
      final result = _firstVisibleText(element);
      if (result != null) return result;
    }
  }
  return null;
}

double _measureTextCss(String text, web.CSSStyleDeclaration source) {
  final body = web.document.body;
  if (body == null) {
    return text.length *
        _px(source.getPropertyValue('font-size'), fallback: 16) *
        .55;
  }
  final span = web.document.createElement('span') as web.HTMLElement
    ..setAttribute('data-page-editor-ui', 'true')
    ..textContent = text
    ..style.setProperty('position', 'fixed')
    ..style.setProperty('left', '-10000px')
    ..style.setProperty('top', '-10000px')
    ..style.setProperty('visibility', 'hidden')
    ..style.setProperty('white-space', 'pre');
  for (final property in [
    'font-family',
    'font-size',
    'font-weight',
    'font-style',
    'font-stretch',
    'font-variant',
    'letter-spacing',
  ]) {
    final value = source.getPropertyValue(property);
    if (value.isNotEmpty) span.style.setProperty(property, value);
  }
  body.appendChild(span);
  try {
    return span.getBoundingClientRect().width;
  } finally {
    span.remove();
  }
}

class _PhysicalPage {
  final double top;
  final double bottom;

  const _PhysicalPage(this.top, this.bottom);

  double get height => bottom - top;
}

List<_PhysicalPage> _physicalPageAnchors(
  web.HTMLElement root, {
  required web.DOMRect bounds,
  required int pageCount,
  required double nominalPageHeight,
  required double nominalPageGap,
}) {
  final pages = <_PhysicalPage>[];
  for (var index = 0; index < pageCount; index++) {
    final number = index + 1;
    final header = root.querySelector(
      '.tiptap-page-header[data-page-number="$number"]',
    );
    final footer = root.querySelector(
      '.tiptap-page-footer[data-page-number="$number"]',
    );
    final expectedTop =
        index == 0 ? bounds.top : pages.last.bottom + nominalPageGap;
    final measuredTop = header?.getBoundingClientRect().top;
    final top = measuredTop != null &&
            measuredTop.isFinite &&
            (index == 0 || measuredTop >= pages.last.bottom - .5)
        ? measuredTop
        : expectedTop;
    final measuredBottom = footer?.getBoundingClientRect().bottom;
    final bottom = measuredBottom != null &&
            measuredBottom.isFinite &&
            measuredBottom > top + 1
        ? measuredBottom
        : top + nominalPageHeight;
    pages.add(_PhysicalPage(top, bottom));
  }
  return pages;
}

class _PageLocation {
  final int page;
  final double x;
  final double y;
  const _PageLocation(this.page, this.x, this.y);
}

class _PaginatedGeometry {
  final web.DOMRect bounds;
  final List<_PhysicalPage> pages;
  final double pageWidth;
  final double visualScaleX;
  final double visualScaleY;
  final PdfPageFormat pdf;

  const _PaginatedGeometry({
    required this.bounds,
    required this.pages,
    required this.pageWidth,
    required this.visualScaleX,
    required this.visualScaleY,
    required this.pdf,
  });

  double get scaleX => pdf.width / (pageWidth * visualScaleX);
  double scaleYForPage(int page) => pdf.height / pages[page].height;

  _PageLocation? location(web.DOMRectReadOnly rect) =>
      point(rect.left, rect.top + rect.height / 2, yAtTop: rect.top);

  _PageLocation? locationForElement(
    web.Element element,
    web.DOMRectReadOnly rect,
  ) {
    final explicitPage = _explicitPageForElement(element);
    if (explicitPage == null) return location(rect);
    return _pointOnPage(
      explicitPage,
      rect.left,
      rect.top + rect.height / 2,
      yAtTop: rect.top,
    );
  }

  _PageLocation? pointForElement(
    web.Element element,
    double x,
    double y, {
    double? yAtTop,
  }) {
    final explicitPage = _explicitPageForElement(element);
    return explicitPage == null
        ? point(x, y, yAtTop: yAtTop)
        : _pointOnPage(explicitPage, x, y, yAtTop: yAtTop);
  }

  _PageLocation? point(double x, double y, {double? yAtTop}) {
    final page = _pageForY(y);
    if (page == null) return null;
    return _pointOnPage(page, x, y, yAtTop: yAtTop);
  }

  _PageLocation? _pointOnPage(
    int page,
    double x,
    double y, {
    double? yAtTop,
  }) {
    if (page < 0 || page >= pages.length) return null;
    final physical = pages[page];
    final coordinate = yAtTop ?? y;
    if (coordinate < physical.top - .5 || coordinate > physical.bottom + .5) {
      return null;
    }
    final localY =
        coordinate.clamp(physical.top, physical.bottom) - physical.top;
    return _PageLocation(
      page,
      (x - bounds.left) * scaleX,
      localY * scaleYForPage(page),
    );
  }

  int? _explicitPageForElement(web.Element element) {
    final region = element.closest(
      '.tiptap-page-header[data-page-number], '
      '.tiptap-page-footer[data-page-number]',
    );
    if (region == null) return null;
    final number = int.tryParse(region.getAttribute('data-page-number') ?? '');
    if (number == null || number < 1 || number > pages.length) return null;
    return number - 1;
  }

  int? _pageForY(double y) {
    var low = 0;
    var high = pages.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final page = pages[middle];
      if (y < page.top - .5) {
        high = middle - 1;
      } else if (y > page.bottom + .5) {
        low = middle + 1;
      } else {
        return middle;
      }
    }
    return null;
  }

  int _firstPageEndingAfter(double y) {
    var low = 0;
    var high = pages.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (pages[middle].bottom <= y) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  void forEachElementIntersection(
    web.Element element,
    web.DOMRectReadOnly rect,
    void Function(int page, double x, double y, double width, double height)
        visitor,
  ) {
    final explicitPage = _explicitPageForElement(element);
    if (explicitPage == null) {
      forEachIntersection(rect, visitor);
      return;
    }
    _visitIntersection(explicitPage, rect, visitor);
  }

  void forEachIntersection(
    web.DOMRectReadOnly rect,
    void Function(int page, double x, double y, double width, double height)
        visitor,
  ) {
    for (var page = _firstPageEndingAfter(rect.top);
        page < pages.length;
        page++) {
      final physical = pages[page];
      if (physical.top >= rect.bottom) break;
      _visitIntersection(page, rect, visitor);
    }
  }

  void _visitIntersection(
    int page,
    web.DOMRectReadOnly rect,
    void Function(int page, double x, double y, double width, double height)
        visitor,
  ) {
    final physical = pages[page];
    final top = math.max(rect.top, physical.top);
    final bottom = math.min(rect.bottom, physical.bottom);
    if (bottom <= top || rect.width <= 0) return;
    final scaleY = scaleYForPage(page);
    visitor(
      page,
      (rect.left - bounds.left) * scaleX,
      (top - physical.top) * scaleY,
      rect.width * scaleX,
      (bottom - top) * scaleY,
    );
  }
}

bool _visible(web.DOMRectReadOnly rect) => rect.width > 0 && rect.height > 0;

double _px(String value, {double fallback = 0}) {
  final parsed = double.tryParse(value.trim().replaceFirst('px', ''));
  return parsed ?? fallback;
}

double _letterSpacing(web.CSSStyleDeclaration style) {
  final value = style.getPropertyValue('letter-spacing').trim();
  return value == 'normal' ? 0 : _px(value);
}

double _customPx(web.HTMLElement element, String name,
    {required double fallback}) {
  final inline = element.style.getPropertyValue(name);
  final computed = inline.isEmpty
      ? web.window.getComputedStyle(element).getPropertyValue(name)
      : inline;
  return _px(computed, fallback: fallback);
}

String? _fontFamily(String value) {
  final family =
      value.split(',').first.trim().replaceAll(RegExp(r'''["']'''), '');
  return family.isEmpty ? null : family;
}

String? _color(String value) {
  final values = RegExp(r'[0-9]+').allMatches(value).take(3).map((m) {
    final n = int.parse(m.group(0)!).clamp(0, 255);
    return n.toRadixString(16).padLeft(2, '0');
  }).toList();
  return values.length == 3 ? '#${values.join()}' : null;
}

String? _opaqueColor(String value) {
  final alpha =
      RegExp(r'rgba?\([^)]*,\s*([0-9.]+)\s*\)\s*$').firstMatch(value)?.group(1);
  if (alpha != null && double.tryParse(alpha) == 0) return null;
  if (value == 'transparent') return null;
  return _color(value);
}
