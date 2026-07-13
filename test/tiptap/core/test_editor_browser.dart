@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/quill_delta/index.dart';
import 'package:docx_rendering/src/tiptap/converters/quill_delta.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';

const allExtensions = [
  DocumentExtension(),
  ParagraphExtension(),
  TextExtension(),
  BoldExtension(),
  ItalicExtension(),
  UnderlineExtension(),
  StrikeExtension(),
  CodeExtension(),
  LinkExtension(),
  TextStyleExtension(),
  HighlightExtension(),
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
  HistoryExtension(),
];

TiptapEditor buildEditor({web.HTMLElement? element, PMNode? content}) {
  return TiptapEditor(EditorOptions(
    extensions: allExtensions,
    element: element,
    content: content,
  ));
}

void main() {
  test('cria o schema completo com todas as extensões', () {
    final editor = buildEditor();
    final schema = editor.state.schema;
    for (final name in [
      'doc',
      'paragraph',
      'heading',
      'bulletList',
      'orderedList',
      'listItem',
      'image',
      'table',
      'tableRow',
      'tableCell',
      'tableHeader',
      'hardBreak',
      'horizontalRule',
    ]) {
      expect(schema.nodes.containsKey(name), isTrue, reason: 'node $name');
    }
    for (final name in [
      'bold',
      'italic',
      'underline',
      'strike',
      'code',
      'link',
      'textStyle',
      'highlight',
    ]) {
      expect(schema.marks.containsKey(name), isTrue, reason: 'mark $name');
    }
    editor.destroy();
  });

  test('monta a view, alterna heading e lista via chain', () {
    final host = web.document.createElement('div') as web.HTMLElement;
    web.document.body!.appendChild(host);
    final editor = buildEditor(element: host);

    editor.chain.toggleHeading(1).run();
    expect(editor.state.doc.child(0).type.name, 'heading');
    expect(editor.isActive('heading', {'level': 1}), isTrue);

    editor.chain.toggleHeading(1).run();
    expect(editor.state.doc.child(0).type.name, 'paragraph');

    editor.chain.toggleBulletList().run();
    expect(editor.state.doc.child(0).type.name, 'bulletList');
    expect(editor.getHTML(), contains('<ul>'));

    editor.chain.toggleBulletList().run();
    expect(editor.state.doc.child(0).type.name, 'paragraph');

    editor.destroy();
    host.remove();
  });

  test('setTextAlign e insertTable', () {
    final editor = buildEditor();
    editor.chain.setTextAlign('center').run();
    expect(editor.state.doc.child(0).attrs['textAlign'], 'center');

    editor.chain.insertTable(rows: 2, cols: 2).run();
    PMNode? table;
    editor.state.doc.nodesBetween(0, editor.state.doc.content.size,
        (node, pos, parent, index) {
      if (node.type.name == 'table') table = node;
      return true;
    });
    expect(table, isNotNull);
    expect(table!.childCount, 2);
    expect(table!.child(0).child(0).type.name, 'tableHeader');
    editor.destroy();
  });

  test('onUpdate e onSelectionUpdate são emitidos', () async {
    final editor = buildEditor();
    final updates = <Transaction>[];
    editor.onUpdate.listen(updates.add);

    final tr = editor.state.tr;
    tr.insertText('hello', 1);
    editor.dispatchTransaction(tr);

    await Future<void>.delayed(Duration.zero);
    expect(updates, hasLength(1));
    expect(editor.state.doc.textContent, 'hello');
    editor.destroy();
  });

  test('undo/redo via HistoryExtension sem plugin duplicado', () {
    final editor = buildEditor();
    final tr = editor.state.tr;
    tr.insertText('abc', 1);
    editor.dispatchTransaction(tr);
    expect(editor.state.doc.textContent, 'abc');

    editor.chain.undo().run();
    expect(editor.state.doc.textContent, '');

    editor.chain.redo().run();
    expect(editor.state.doc.textContent, 'abc');
    editor.destroy();
  });

  test('textStyle mescla fonte e tamanho sem apagar a cor', () {
    final editor = buildEditor();
    final schema = editor.state.schema;
    final colored = schema.mark('textStyle', {'color': '#ff0000'});
    final doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('texto', [colored])
      ])
    ]);
    final tr = editor.state.tr;
    tr.replaceWith(0, editor.state.doc.content.size, doc.content);
    tr.setSelection(TextSelection.create(tr.doc, 1, 6));
    editor.dispatchTransaction(tr);

    editor.chain.setFontFamily('Arial').setFontSize('18px').run();
    final mark = editor.state.doc
        .child(0)
        .child(0)
        .marks
        .firstWhere((mark) => mark.type.name == 'textStyle');
    expect(mark.attrs['color'], '#ff0000');
    expect(mark.attrs['fontFamily'], 'Arial');
    expect(mark.attrs['fontSize'], '18px');
    editor.destroy();
  });

  test('round-trip Delta com o schema real do editor', () {
    final editor = buildEditor();
    final converter = QuillDeltaConverter(editor.state.schema);
    final delta = Delta()
      ..insert('Title')
      ..insert('\n', {'header': 1})
      ..insert('Hello ')
      ..insert('bold', {'bold': true})
      ..insert('\n')
      ..insert('item')
      ..insert('\n', {'list': 'bullet'});
    final doc = converter.fromDelta(delta);
    expect(converter.toDelta(doc), delta);
    editor.destroy();
  });

  test('setDocument preserva atributos do documento na mesma transação',
      () async {
    final editor = buildEditor();
    final schema = editor.state.schema;
    final imported = schema.node('doc', {
      'pageWidth': '595.30pt',
      'headers': {
        'default': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'cabeçalho'},
            ],
          },
        ],
      },
    }, [
      schema.node('paragraph', null, [schema.text('corpo importado')]),
    ]);

    final updates = <Transaction>[];
    editor.onUpdate.listen(updates.add);
    editor.setDocument(imported);
    await Future<void>.delayed(Duration.zero);

    expect(editor.state.doc.textContent, 'corpo importado');
    expect(editor.state.doc.attrs['pageWidth'], '595.30pt');
    expect(editor.state.doc.attrs['headers'], imported.attrs['headers']);
    expect(updates, hasLength(1));
    editor.destroy();
  });
}
