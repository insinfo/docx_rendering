/// Captura, no browser, a geometria final das páginas DOM para exportação PDF.
///
/// A função lê as `<section>` já produzidas pela paginação e converte suas
/// coordenadas CSS em pontos PDF. Assim [PdfExporter] não recalcula word-wrap:
/// texto, células, imagens e linhas usam as posições efetivamente renderizadas.
library;

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

PdfLayoutPage _capturePage(web.HTMLElement section, PdfPageFormat format) {
  final page = section.getBoundingClientRect();
  if (page.width <= 0 || page.height <= 0) return const PdfLayoutPage([]);
  final scaleX = format.width / page.width;
  final scaleY = format.height / page.height;
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
    _captureTextNode(text, page, scaleX, scaleY, items);
  });

  return PdfLayoutPage(items);
}

void _walkText(web.Node node, void Function(web.Text text) visitor) {
  for (var child = node.firstChild; child != null; child = child.nextSibling) {
    if (child.nodeType == 3) {
      visitor(child as web.Text);
    } else if (child.nodeType == 1) {
      final element = child as web.Element;
      final tag = element.tagName.toLowerCase();
      if (tag != 'script' && tag != 'style' && tag != 'svg') {
        _walkText(element, visitor);
      }
    }
  }
}

void _captureTextNode(web.Text text, web.DOMRect page, double scaleX,
    double scaleY, List<PdfLayoutItem> items) {
  final value = text.data;
  final parent = text.parentElement;
  if (value.isEmpty || parent == null) return;
  final style = web.window.getComputedStyle(parent);
  if (style.getPropertyValue('display') == 'none' ||
      style.getPropertyValue('visibility') == 'hidden') {
    return;
  }

  final fontPx = _px(style.getPropertyValue('font-size'), fallback: 16);
  final fontSize = fontPx * scaleY;
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
      final baseline = rect.top + math.min(rect.height, fontPx) * .82;
      items.add(PdfTextItem(
        segment,
        (rect.left - page.left) * scaleX,
        (baseline - page.top) * scaleY,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        color: color,
        fontFamily: family,
      ));
    }
    start = best;
  }
}

bool _visible(web.DOMRectReadOnly rect) => rect.width > 0 && rect.height > 0;

double _px(String value, {double fallback = 0}) {
  final parsed = double.tryParse(value.trim().replaceFirst('px', ''));
  return parsed ?? fallback;
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
