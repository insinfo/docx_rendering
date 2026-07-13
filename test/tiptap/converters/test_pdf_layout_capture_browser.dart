@TestOn('browser')
library;

import 'dart:js_interop';

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
}
