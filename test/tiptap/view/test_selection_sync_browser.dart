@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';

const extensions = [
  DocumentExtension(),
  ParagraphExtension(),
  TextExtension(),
  BoldExtension(),
  PaginationExtension(),
  HistoryExtension(),
];

void main() {
  test(
      'seleção DOM volta a sincronizar após setDocument com seleção grande ativa',
      () async {
    final host = web.document.createElement('div') as web.HTMLElement;
    web.document.body!.appendChild(host);
    final editor = TiptapEditor(EditorOptions(
      extensions: extensions,
      element: host,
    ));
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    final schema = editor.state.schema;
    PMNode paragraph(String text) =>
        schema.node('paragraph', null, [schema.text(text)]);
    final bigDoc = schema.node('doc', null, [
      paragraph('Primeiro parágrafo da seleção.'),
      paragraph('Segundo parágrafo da seleção.'),
      paragraph('Terceiro parágrafo da seleção.'),
    ]);
    editor.setDocument(bigDoc);

    // Seleção grande cobrindo os três parágrafos (como Shift+setas).
    final selectTr = editor.state.tr;
    selectTr.setSelection(
        TextSelection.create(editor.state.doc, 1, bigDoc.content.size - 1));
    editor.view!.dispatch(selectTr);
    expect(editor.state.selection.to - editor.state.selection.from,
        greaterThan(40));

    // Documento menor substitui o atual (fluxo Abrir/Importar/setTiptapJSON).
    final smallDoc = schema.node('doc', null, [paragraph('Hit teste humano')]);
    editor.setDocument(smallDoc);

    // Clique/seleção nativa dentro do parágrafo: o estado do PM tem que
    // acompanhar via selectionchange.
    final textNode =
        editor.view!.dom.querySelector('p')!.firstChild as web.Node;
    web.window.getSelection()!.setPosition(textNode, 3);
    // selectionchange é assíncrono; dá tempo para o observer + microtasks.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    editor.view!.domObserver.forceFlush();

    final selection = editor.state.selection;
    expect(selection.from, 4,
        reason: 'a seleção do estado deveria seguir o caret DOM '
            '(ficou em ${selection.from}..${selection.to})');
  });
}
