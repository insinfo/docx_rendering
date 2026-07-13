@TestOn('browser')
library;

import 'package:test/test.dart';

import 'package:docx_rendering/docx_rendering.dart';
import 'package:docx_rendering/src/tiptap/converters/docx_export.dart';
import 'package:docx_rendering/src/tiptap/converters/docx_import.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';

/// Round-trip do §5.1: PM → DocxExporter → bytes → parseAsync
/// (docx_rendering) → DocxImporter → PM.
void main() {
  final editor = TiptapEditor(EditorOptions(extensions: const [
    DocumentExtension(),
    ParagraphExtension(),
    TextExtension(),
    BoldExtension(),
    ItalicExtension(),
    UnderlineExtension(),
    StrikeExtension(),
    TextStyleExtension(),
    HeadingExtension(),
    BulletListExtension(),
    OrderedListExtension(),
    ListItemExtension(),
    TextAlignExtension(),
    ImageExtension(),
    TableExtension(),
    TableRowExtension(),
    TableCellExtension(),
    TableHeaderExtension(),
    HardBreakExtension(),
    HorizontalRuleExtension(),
  ]));
  final schema = editor.state.schema;

  test('exportar → reimportar preserva estrutura e texto', () async {
    final bold = schema.marks['bold']!;
    final original = schema.node('doc', null, [
      schema.node('heading', {'level': 2}, [schema.text('Título')]),
      schema.node('paragraph', null, [
        schema.text('Olá '),
        schema.text('negrito', [bold.create()]),
        schema.text(' final.'),
      ]),
      schema.node('paragraph', {'textAlign': 'center'},
          [schema.text('centralizado')]),
      schema.node('table', null, [
        schema.node('tableRow', null, [
          schema.node('tableCell', null, [
            schema.node('paragraph', null, [schema.text('c1')])
          ]),
          schema.node('tableCell', null, [
            schema.node('paragraph', null, [schema.text('c2')])
          ]),
        ]),
      ]),
    ]);

    final bytes = await DocxExporter().export(original);
    final wordDocument = await parseAsync(bytes);
    final reimported = DocxImporter(wordDocument, schema).importDocument();

    expect(reimported.child(0).type.name, 'heading',
        reason: reimported.toString());
    expect(reimported.child(0).attrs['level'], 2);
    expect(reimported.child(0).textContent, 'Título');

    expect(reimported.child(1).textContent, 'Olá negrito final.');
    var boldFound = false;
    for (final node in reimported.child(1).children) {
      if (node.isText && bold.isInSet(node.marks) != null) {
        boldFound = true;
        expect(node.text, 'negrito');
      }
    }
    expect(boldFound, isTrue, reason: 'marca bold deveria sobreviver');

    expect(reimported.child(2).attrs['textAlign'], 'center');

    final table = reimported.child(3);
    expect(table.type.name, 'table', reason: reimported.toString());
    expect(table.child(0).childCount, 2);
    expect(table.child(0).child(0).textContent, 'c1');
    expect(table.child(0).child(1).textContent, 'c2');
  });
}
