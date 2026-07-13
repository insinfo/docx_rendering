import 'dart:convert';

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/tiptap/converters/pdf_export.dart';
import 'package:test/test.dart';

Schema _schema() {
  AttributeSpec nullable() =>
      AttributeSpec(defaultValue: null, hasDefault: true);
  return Schema(SchemaSpec(nodes: {
    'doc': NodeSpec(content: 'block+'),
    'paragraph': NodeSpec(content: 'inline*', group: 'block'),
    'heading': NodeSpec(content: 'inline*', group: 'block', attrs: {
      'level': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'bulletList': NodeSpec(content: 'listItem+', group: 'block'),
    'orderedList': NodeSpec(content: 'listItem+', group: 'block', attrs: {
      'start': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'listItem': NodeSpec(content: 'paragraph block*'),
    'hardBreak': NodeSpec(inline: true, group: 'inline'),
    'image': NodeSpec(group: 'block', attrs: {
      'src': nullable(),
      'width': nullable(),
      'height': nullable(),
    }),
    'table': NodeSpec(content: 'tableRow+', group: 'block'),
    'tableRow': NodeSpec(content: '(tableCell | tableHeader)+'),
    'tableCell': NodeSpec(content: 'paragraph+', attrs: {
      'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'tableHeader': NodeSpec(content: 'paragraph+', attrs: {
      'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'text': NodeSpec(group: 'inline', inline: true),
  }, marks: {
    'bold': MarkSpec(),
    'italic': MarkSpec(),
    'textStyle': MarkSpec(attrs: {
      'color': nullable(),
      'fontSize': nullable(),
      'fontFamily': nullable(),
    }),
  }));
}

void main() {
  final schema = _schema();
  const pngDataUri = 'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
      'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  test('gera PDF vetorial com xref, fontes e texto WinAnsi selecionável',
      () async {
    final doc = schema.node('doc', null, [
      schema.node('heading', {'level': 2}, [schema.text('Título')]),
      schema.node('paragraph', null, [
        schema.text('normal '),
        schema.text('forte', [schema.mark('bold')]),
        schema.text(' arial', [
          schema.mark('textStyle', {'fontFamily': 'Arial'})
        ]),
      ]),
    ]);
    final bytes = await const PdfExporter().export(doc);
    final pdf = latin1.decode(bytes);

    expect(pdf, startsWith('%PDF-1.3'));
    expect(pdf, contains('/BaseFont /Helvetica-Bold'));
    expect(pdf, isNot(contains('/BaseFont /Times')));
    expect(pdf, contains('(Título) Tj'));
    expect(pdf, contains('xref'));
    expect(pdf, endsWith('%%EOF'));
    final spaceX = double.parse(
        RegExp(r'([0-9.]+) [0-9.]+ Td\n/F1 11\. Tf\n\( \) Tj')
            .firstMatch(pdf)!
            .group(1)!);
    expect(spaceX, greaterThan(100),
        reason: 'métricas não podem sobrepor o trecho após "normal"');
  });

  test('consome plano de layout sem recalcular posições', () async {
    final doc = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('ignorado')])
    ]);
    const plan = PdfLayoutPlan([
      PdfLayoutPage([
        PdfTextItem('planejado', 12, 34, fontSize: 9, color: '#ff0000'),
        PdfLineItem(10, 50, 80, 50),
        PdfRectItem(10, 60, 70, 20),
      ])
    ]);
    final pdf =
        latin1.decode(await const PdfExporter().export(doc, layout: plan));

    expect(pdf, contains('(planejado) Tj'));
    expect(pdf, contains('1. 0. 0. rg'));
    expect(pdf, matches(RegExp(r'70\.\s+-20\.\s+re S')));
    expect(pdf, isNot(contains('(ignorado) Tj')));
  });

  test('pagina e reporta progresso uma vez por página', () async {
    final doc = schema.node('doc', null, [
      for (var i = 0; i < 20; i++)
        schema.node('paragraph', null, [schema.text('Linha $i')]),
    ]);
    final progress = <String>[];
    final exporter = PdfExporter(
      pageFormat: const PdfPageFormat(
          width: 200,
          height: 100,
          marginTop: 10,
          marginRight: 10,
          marginBottom: 10,
          marginLeft: 10),
      onProgress: (done, total) => progress.add('$done/$total'),
    );
    final pdf = latin1.decode(await exporter.export(doc));

    expect(progress.length, greaterThan(1));
    expect(progress.last, '${progress.length}/${progress.length}');
    expect(RegExp(r'/Type /Page\b').allMatches(pdf).length, progress.length);
  });

  test('desenha células de tabela como retângulos vetoriais', () async {
    PMNode cell(String type, String text, {int colspan = 1}) =>
        schema.node(type, {
          'colspan': colspan
        }, [
          schema.node('paragraph', null, [schema.text(text)])
        ]);
    final doc = schema.node('doc', null, [
      schema.node('table', null, [
        schema.node('tableRow', null,
            [cell('tableHeader', 'A'), cell('tableHeader', 'B')]),
        schema.node('tableRow', null, [cell('tableCell', 'AB', colspan: 2)]),
      ])
    ]);
    final pdf = latin1.decode(await const PdfExporter().export(doc));

    expect(RegExp(r' re S').allMatches(pdf).length, 3);
    expect(pdf, contains('(AB) Tj'));
  });

  test('preserva hardBreak, bullet CP1252 e início de lista ordenada',
      () async {
    PMNode item(String text) => schema.node('listItem', null, [
          schema.node('paragraph', null, [schema.text(text)])
        ]);
    final doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('antes'),
        schema.node('hardBreak'),
        schema.text('depois')
      ]),
      schema.node('bulletList', null, [item('marcador')]),
      schema.node('orderedList', {'start': 7}, [item('sete'), item('oito')]),
    ]);
    final pdf = latin1.decode(await const PdfExporter().export(doc));

    expect(pdf, contains('(antes) Tj'));
    expect(pdf, contains('(depois) Tj'));
    expect(pdf.codeUnits, contains(0x95)); // U+2022 convertido para WinAnsi.
    expect(pdf, contains('(7.) Tj'));
    expect(pdf, contains('(8.) Tj'));
  });

  test('incorpora PNG com alpha como XObject e SMask', () async {
    final doc = schema.node('doc', null, [
      schema.node('image', {'src': pngDataUri, 'width': '40', 'height': '20'})
    ]);
    final bytes = await const PdfExporter().export(doc);
    final pdf = latin1.decode(bytes);

    expect(pdf, contains('/Subtype /Image'));
    expect(pdf, contains('/SMask'));
    expect(pdf, contains('/XObject'));
    expect(bytes.length, greaterThan(1000));
  });

  test('R4: exporta aproximadamente 200 páginas em menos de 5s', () async {
    final doc = schema.node('doc', null, [
      for (var i = 0; i < 7800; i++)
        schema.node('paragraph', null,
            [schema.text('Parágrafo $i com conteúdo vetorial selecionável.')]),
    ]);
    var pages = 0;
    final watch = Stopwatch()..start();
    final bytes = await PdfExporter(
      onProgress: (done, total) => pages = total,
    ).export(doc);
    watch.stop();

    expect(pages, inInclusiveRange(180, 260));
    expect(bytes.length, greaterThan(100000));
    expect(watch.elapsedMilliseconds, lessThan(5000),
        reason: 'levou ${watch.elapsedMilliseconds}ms para $pages páginas');
  });
}
