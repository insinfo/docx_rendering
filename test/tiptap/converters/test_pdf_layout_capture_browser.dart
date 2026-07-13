@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/tiptap/converters/pdf_export.dart';
import 'package:docx_rendering/src/tiptap/converters/pdf_layout_capture.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('captura texto, tabela e páginas nas coordenadas renderizadas',
      () async {
    final root = web.document.createElement('div') as web.HTMLElement;
    root.innerHTML = '''
      <section class="docx" style="box-sizing:border-box;width:595pt;height:842pt;padding:72pt;content-visibility:auto">
        <article><p style="font: bold 12pt Arial;color:rgb(255,0,0)">linha medida pelo browser</p>
        <table style="border-collapse:collapse"><tr><td style="border:1px solid;width:100pt;height:20pt">célula</td></tr></table></article>
      </section>
      <section class="docx" style="box-sizing:border-box;width:595pt;height:842pt;padding:72pt;content-visibility:auto">
        <article><p>segunda página</p></article>
      </section>
    '''
        .toJS;
    web.document.body!.appendChild(root);
    try {
      final plan = await capturePdfLayout(root);
      expect(plan.pages, hasLength(2));
      final first = plan.pages.first.items;
      final text = first
          .whereType<PdfTextItem>()
          .firstWhere((item) => item.text.contains('linha medida'));
      expect(text.x, closeTo(72, 2));
      expect(text.y, greaterThan(72));
      expect(text.fontSize, closeTo(12, 1));
      expect(text.bold, isTrue);
      expect(text.color, '#ff0000');
      expect(first.whereType<PdfRectItem>(), isNotEmpty);
      expect(plan.pages[1].items.whereType<PdfTextItem>().single.text,
          contains('segunda página'));
    } finally {
      root.remove();
    }
  });

  test('zoom visual não altera tamanho nem coordenadas do texto no PDF',
      () async {
    Future<PdfTextItem> captureAt(double zoom) async {
      final root = web.document.createElement('div') as web.HTMLElement
        ..style.setProperty('zoom', '$zoom')
        ..innerHTML = '''
          <section class="docx" style="box-sizing:border-box;width:794px;height:1123px;padding:84px 96px">
            <p style="margin:0;font:16px/1.45 Arial">texto com zoom</p>
          </section>
        '''
            .toJS;
      web.document.body!.appendChild(root);
      try {
        final plan = await capturePdfLayout(root);
        return plan.pages.single.items.whereType<PdfTextItem>().single;
      } finally {
        root.remove();
      }
    }

    final at60 = await captureAt(.6);
    final at100 = await captureAt(1);
    final at150 = await captureAt(1.5);

    for (final text in [at60, at100, at150]) {
      expect(text.fontSize, closeTo(12, .15));
      expect(text.x, closeTo(72, .25));
    }
    // O rasterizador do Chrome arredonda a caixa de glifo em CSS zoom para
    // pixels inteiros; após converter para pontos isso pode variar até ~1pt.
    expect(at60.y, closeTo(at100.y, 1.25));
    expect(at150.y, closeTo(at100.y, 1.25));
  });

  test('captura paginação contínua com headers, footers, caixa e tabela',
      () async {
    final root = web.document.createElement('div') as web.HTMLElement
      ..setAttribute('data-page-count', '2')
      ..style.cssText = '''
        position:relative;width:200px;height:220px;
        --tiptap-page-width:200px;--tiptap-page-height:100px;
        --tiptap-page-gap:20px;font:10px Arial;
      '''
      ..innerHTML = '''
        <div class="tiptap-page-header" style="position:absolute;left:10px;top:4px">Cabeçalho 1</div>
        <div style="position:absolute;left:10px;top:30px">Corpo 1</div>
        <div class="tiptap-page-footer" style="position:absolute;left:10px;top:85px">Página 1 | 2</div>
        <div class="tiptap-page-header" style="position:absolute;left:10px;top:124px">Cabeçalho 2</div>
        <table style="position:absolute;left:10px;top:145px;border-collapse:collapse">
          <tr><td style="width:45px;height:20px;border:1px solid #333;background:#eee">A</td><td style="width:90px;border:1px solid #333">B</td></tr>
        </table>
        <div class="tiptap-page-footer" style="position:absolute;left:10px;top:205px">Página 2 | 2</div>
      '''
          .toJS;
    web.document.body!.appendChild(root);
    try {
      final plan = await capturePaginatedPdfLayout(
        root,
        pageFormat: const PdfPageFormat(width: 150, height: 75),
      );
      expect(plan.pages, hasLength(2));
      final firstText = plan.pages[0].items
          .whereType<PdfTextItem>()
          .map((item) => item.text)
          .join();
      final secondText = plan.pages[1].items
          .whereType<PdfTextItem>()
          .map((item) => item.text)
          .join();
      expect(firstText, contains('Cabeçalho 1'));
      expect(firstText, contains('Página 1 | 2'));
      expect(secondText, contains('Cabeçalho 2'));
      expect(secondText, contains('Página 2 | 2'));
      expect(plan.pages[1].items.whereType<PdfRectItem>(), hasLength(2));
      final cells = plan.pages[1].items.whereType<PdfRectItem>().toList();
      expect(cells[1].x, closeTo(cells[0].x + cells[0].width, 1));
      expect(cells.first.fillColor, '#eeeeee');

      final schema = Schema(SchemaSpec(nodes: {
        'doc': NodeSpec(content: 'paragraph+'),
        'paragraph': NodeSpec(content: 'text*'),
        'text': NodeSpec(inline: true),
      }));
      final doc = schema.node('doc', null, [schema.node('paragraph')]);
      final pdf = latin1.decode(await const PdfExporter(
        pageFormat: PdfPageFormat(width: 150, height: 75),
      ).export(doc, layout: plan));
      expect(RegExp(r'/Type /Page\b').allMatches(pdf).length, 2);
      expect(pdf, contains('(Cabeçalho 1) Tj'));
      expect(pdf, contains('(Página 2 | 2) Tj'));
    } finally {
      root.remove();
    }
  });

  test('materializa no PDF o rótulo hierárquico de lista vindo do DOCX',
      () async {
    final root = web.document.createElement('div') as web.HTMLElement
      ..setAttribute('data-page-count', '1')
      ..style.cssText = '''
        position:relative;width:200px;height:100px;
        --tiptap-page-width:200px;--tiptap-page-height:100px;
        --tiptap-page-gap:0px;font:12px Arial;
      '''
      ..innerHTML = '''
        <ol style="margin:0;padding-left:40px">
          <li data-docx-numbering-label="1.2." style="list-style:none">
            <p style="margin:0">Item numerado</p>
          </li>
        </ol>
      '''
          .toJS;
    web.document.body!.appendChild(root);
    try {
      final plan = await capturePaginatedPdfLayout(
        root,
        pageFormat: const PdfPageFormat(width: 150, height: 75),
      );
      final items = plan.pages.single.items.whereType<PdfTextItem>().toList();
      final marker = items.singleWhere((item) => item.text == '1.2.');
      final content = items.singleWhere(
        (item) => item.text.contains('Item numerado'),
      );
      expect(marker.x, lessThan(content.x));
      expect(marker.y, closeTo(content.y, 1));
      expect(marker.fontSize, closeTo(content.fontSize, .1));

      final schema = Schema(SchemaSpec(nodes: {
        'doc': NodeSpec(content: 'paragraph+'),
        'paragraph': NodeSpec(content: 'text*'),
        'text': NodeSpec(inline: true),
      }));
      final doc = schema.node('doc', null, [schema.node('paragraph')]);
      final pdf = latin1.decode(await const PdfExporter(
        pageFormat: PdfPageFormat(width: 150, height: 75),
      ).export(doc, layout: plan));
      expect(pdf, contains('(1.2.) Tj'));
    } finally {
      root.remove();
    }
  });

  test('usa âncoras DOM reais sem empurrar rodapé para a página seguinte',
      () async {
    const pageCount = 12;
    const nominalPageHeight = 100;
    const pageGap = 20;
    const measuredPageHeight = 110;
    final content = StringBuffer();
    for (var index = 0; index < pageCount; index++) {
      final page = index + 1;
      final top = index * (measuredPageHeight + pageGap);
      content
        ..write('<div class="tiptap-page-header" ')
        ..write('data-page-number="$page" ')
        ..write('style="position:absolute;left:10px;top:${top}px;')
        ..write('height:20px">Cabeçalho $page</div>')
        ..write('<div style="position:absolute;left:10px;')
        ..write('top:${top + 40}px">Corpo $page</div>')
        ..write('<div class="tiptap-page-footer" ')
        ..write('data-page-number="$page" ')
        ..write('style="position:absolute;left:10px;top:${top + 90}px;')
        ..write('height:20px">Página $page | $pageCount</div>');
    }
    final root = web.document.createElement('div') as web.HTMLElement
      ..setAttribute('data-page-count', '$pageCount')
      ..style.cssText = '''
        position:relative;width:200px;
        height:${pageCount * measuredPageHeight + (pageCount - 1) * pageGap}px;
        --tiptap-page-width:200px;
        --tiptap-page-height:${nominalPageHeight}px;
        --tiptap-page-gap:${pageGap}px;
        font:10px Arial;
      '''
      ..innerHTML = content.toString().toJS;
    web.document.body!.appendChild(root);
    try {
      final plan = await capturePaginatedPdfLayout(
        root,
        pageFormat: const PdfPageFormat(width: 150, height: 75),
      );
      expect(plan.pages, hasLength(pageCount));
      for (var index = 0; index < pageCount; index++) {
        final page = index + 1;
        final text = plan.pages[index].items
            .whereType<PdfTextItem>()
            .map((item) => item.text)
            .join();
        expect(text, contains('Cabeçalho $page'));
        expect(text, contains('Corpo $page'));
        expect(text, contains('Página $page | $pageCount'));
        if (page > 1) {
          expect(text, isNot(contains('Página ${page - 1} | $pageCount')));
        }
      }

      final eleventh = plan.pages[10].items.whereType<PdfTextItem>().toList();
      final header = eleventh.firstWhere(
        (item) => item.text.contains('Cabeçalho 11'),
      );
      final footer = eleventh.firstWhere(
        (item) => item.text.contains('Página 11 | 12'),
      );
      expect(header.y, lessThan(15));
      expect(footer.y, greaterThan(60));
    } finally {
      root.remove();
    }
  });
}
