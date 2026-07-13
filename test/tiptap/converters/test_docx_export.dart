import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:docx_rendering/src/docx_rendering/zip/zip_archive.dart';
import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/tiptap/converters/docx_export.dart';

Schema buildSchema() {
  AttributeSpec nullable() => AttributeSpec(defaultValue: null, hasDefault: true);
  return Schema(SchemaSpec(nodes: {
    'doc': NodeSpec(content: 'block+'),
    'paragraph': NodeSpec(
        content: 'inline*', group: 'block', attrs: {'textAlign': nullable()}),
    'heading': NodeSpec(content: 'inline*', group: 'block', attrs: {
      'level': AttributeSpec(defaultValue: 1, hasDefault: true),
      'textAlign': nullable(),
    }),
    'bulletList': NodeSpec(content: 'listItem+', group: 'block'),
    'orderedList': NodeSpec(content: 'listItem+', group: 'block'),
    'listItem': NodeSpec(content: 'paragraph block*'),
    'table': NodeSpec(content: 'tableRow+', group: 'block', isolating: true),
    'tableRow': NodeSpec(content: '(tableCell | tableHeader)*'),
    'tableCell': NodeSpec(content: 'block+', isolating: true, attrs: {
      'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
      'rowspan': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'tableHeader': NodeSpec(content: 'block+', isolating: true, attrs: {
      'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
      'rowspan': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'horizontalRule': NodeSpec(group: 'block'),
    'hardBreak': NodeSpec(inline: true, group: 'inline'),
    'image': NodeSpec(group: 'block', attrs: {
      'src': nullable(),
      'width': nullable(),
      'height': nullable(),
    }),
    'text': NodeSpec(group: 'inline', inline: true),
  }, marks: {
    'bold': MarkSpec(),
    'italic': MarkSpec(),
    'underline': MarkSpec(),
    'strike': MarkSpec(),
    'textStyle': MarkSpec(attrs: {
      'color': nullable(),
      'fontFamily': nullable(),
      'fontSize': nullable(),
    }),
    'highlight': MarkSpec(attrs: {'color': nullable()}),
  }));
}

// PNG 1x1 transparente.
const _pngDataUri = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  final schema = buildSchema();

  String documentXmlOf(List<int> bytes) {
    final archive = ZipArchive.decodeBytes(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    return archive.readString('word/document.xml')!;
  }

  test('gera pacote OPC válido com as partes obrigatórias', () async {
    final pmDoc = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('hello')])
    ]);
    final bytes = await DocxExporter().export(pmDoc);
    final archive = ZipArchive.decodeBytes(bytes);

    expect(archive.entryNames,
        containsAll(['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml', 'word/_rels/document.xml.rels']));
    expect(archive.readString('_rels/.rels'), contains('word/document.xml'));
    expect(documentXmlOf(bytes), contains('<w:t xml:space="preserve">hello</w:t>'));
  });

  test('exporta heading, alinhamento e marcas', () async {
    final bold = schema.marks['bold']!;
    final italic = schema.marks['italic']!;
    final textStyle = schema.marks['textStyle']!;

    final pmDoc = schema.node('doc', null, [
      schema.node('heading', {'level': 2}, [schema.text('Título')]),
      schema.node('paragraph', null, [
        schema.text('Olá '),
        schema.text('negrito', [bold.create()]),
        schema.text('itálico vermelho',
            [italic.create(), textStyle.create({'color': '#ff0000'})]),
      ]),
      schema.node('paragraph', {'textAlign': 'center'},
          [schema.text('centralizado')]),
    ]);

    final xml = documentXmlOf(await DocxExporter().export(pmDoc));
    expect(xml, contains('<w:pStyle w:val="Heading2"/>'));
    expect(xml, contains('Título'));
    expect(xml, contains('<w:b/>'));
    expect(xml, contains('<w:i/>'));
    expect(xml, contains('<w:color w:val="FF0000"/>'));
    expect(xml, contains('<w:jc w:val="center"/>'));
  });

  test('escapa caracteres especiais de XML', () async {
    final pmDoc = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('a < b & "c" > d')])
    ]);
    final xml = documentXmlOf(await DocxExporter().export(pmDoc));
    expect(xml, contains('a &lt; b &amp; &quot;c&quot; &gt; d'));
  });

  test('exporta listas com numbering.xml', () async {
    PMNode item(String text) => schema.node('listItem', null, [
          schema.node('paragraph', null, [schema.text(text)])
        ]);
    final pmDoc = schema.node('doc', null, [
      schema.node('bulletList', null, [item('um'), item('dois')]),
      schema.node('orderedList', null, [item('primeiro')]),
    ]);

    final bytes = await DocxExporter().export(pmDoc);
    final archive = ZipArchive.decodeBytes(bytes);
    final xml = archive.readString('word/document.xml')!;
    expect(xml, contains('<w:numId w:val="1"/>'));
    expect(xml, contains('<w:numId w:val="2"/>'));

    final numbering = archive.readString('word/numbering.xml')!;
    expect(numbering, contains('<w:numFmt w:val="bullet"/>'));
    expect(numbering, contains('<w:numFmt w:val="decimal"/>'));
    expect(archive.readString('word/_rels/document.xml.rels'),
        contains('numbering.xml'));
  });

  test('exporta tabela com gridSpan', () async {
    PMNode cell(String type, String text, [int colspan = 1]) =>
        schema.node(type, {'colspan': colspan}, [
          schema.node('paragraph', null, [schema.text(text)])
        ]);
    final pmDoc = schema.node('doc', null, [
      schema.node('table', null, [
        schema.node('tableRow', null,
            [cell('tableHeader', 'A'), cell('tableHeader', 'B')]),
        schema.node('tableRow', null, [cell('tableCell', 'wide', 2)]),
      ]),
    ]);

    final xml = documentXmlOf(await DocxExporter().export(pmDoc));
    expect(xml, contains('<w:tbl>'));
    expect('<w:gridCol/>'.allMatches(xml), hasLength(2));
    expect(xml, contains('<w:gridSpan w:val="2"/>'));
    expect(xml, contains('wide'));
  });

  test('exporta imagem de data URI com parte de mídia e rel', () async {
    final pmDoc = schema.node('doc', null, [
      schema.node('image',
          {'src': _pngDataUri, 'width': '100', 'height': '50'}),
    ]);

    final bytes = await DocxExporter().export(pmDoc);
    final archive = ZipArchive.decodeBytes(bytes);
    expect(archive.contains('word/media/image1.png'), isTrue);
    expect(archive.readBytes('word/media/image1.png')!.length, greaterThan(50));
    expect(archive.readString('word/_rels/document.xml.rels'),
        contains('media/image1.png'));
    final xml = archive.readString('word/document.xml')!;
    expect(xml, contains('r:embed="rIdImage1"'));
    // 100px * 9525 EMU.
    expect(xml, contains('cx="952500"'));
  });

  test('pipeline cooperativo emite progresso', () async {
    final pmDoc = schema.node('doc', null, [
      for (var i = 0; i < 120; i++)
        schema.node('paragraph', null, [schema.text('p$i')])
    ]);
    final progress = <int>[];
    final exporter = DocxExporter(
        chunkSize: 50, onProgress: (done, total) => progress.add(done));
    await exporter.export(pmDoc);
    expect(progress, [50, 100, 120]);
  });

  test('R2: documento de 200+ "páginas" exporta em < 3s', () async {
    // ~200 páginas ≈ 6000 parágrafos (30 por página).
    final bold = schema.marks['bold']!;
    final pmDoc = schema.node('doc', null, [
      for (var i = 0; i < 6000; i++)
        schema.node('paragraph', null, [
          schema.text('Parágrafo $i com texto razoavelmente comprido para '
              'simular conteúdo real de documento. '),
          schema.text('Trecho em negrito.', [bold.create()]),
        ])
    ]);

    final stopwatch = Stopwatch()..start();
    final bytes = await DocxExporter().export(pmDoc);
    stopwatch.stop();

    expect(bytes.length, greaterThan(10000));
    expect(stopwatch.elapsedMilliseconds, lessThan(3000),
        reason: 'levou ${stopwatch.elapsedMilliseconds}ms');

    // O pacote continua íntegro nesse tamanho.
    final archive = ZipArchive.decodeBytes(bytes);
    expect(archive.readString('word/document.xml'), contains('Parágrafo 5999'));
  });
}
