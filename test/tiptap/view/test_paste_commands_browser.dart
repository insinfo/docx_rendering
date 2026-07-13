@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:docx_rendering/src/prosemirror/model/from_dom.dart' as pm;
import 'package:docx_rendering/tiptap.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('DOMParser aceita texto cujo pai e DocumentFragment', () {
    web.document.body!.innerHTML = '<div id="fragment-parent-root"></div>'.toJS;
    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('fragment-parent-root')!
          as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    final fragment = web.document.createDocumentFragment()
      ..appendChild(web.document.createTextNode('texto no fragmento'));
    final parsed = pm.DOMParser.fromSchema(editor.state.schema).parseSlice(
      fragment,
    );

    expect(parsed.content.textBetween(0, parsed.content.size),
        'texto no fragmento');
  });

  test('paste de HTML com marcadores de fragmento entre textos nao falha',
      () async {
    web.document.body!.innerHTML = '<div id="paste-fragment-root"></div>'.toJS;

    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('paste-fragment-root')!
          as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        BoldExtension(),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    final editorDom =
        web.document.querySelector('.ProseMirror')! as web.HTMLElement;
    await _placeCaretAtEnd(editor, editorDom);
    _dispatchPaste(
      editorDom,
      text: 'ANTES DEPOIS',
      // Office/Chrome clipboards commonly put fragment/selection comments
      // between adjacent text runs. A Comment has no `tagName`.
      html: '<p>ANTES<!--StartSelection--> DEPOIS</p>',
    );
    await Future<void>.delayed(Duration.zero);

    expect(editor.state.doc.textContent, contains('ANTES DEPOIS'));
    expect(editorDom.textContent, contains('ANTES DEPOIS'));
  });

  test('paste de texto/HTML permanece após alinhamento e inserção de tabela',
      () async {
    web.document.body!.innerHTML = '''
      <section id="paste-regression-root">
        <button data-tiptap-command="align-center">Centralizar</button>
        <button data-tiptap-action="table">Tabela</button>
        <div class="mount"></div>
      </section>
    '''
        .toJS;

    final root = web.document.getElementById('paste-regression-root')!;
    final editor = TiptapEditor(EditorOptions(
      element: root.querySelector('.mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        BoldExtension(),
        TextAlignExtension(),
        TableExtension(),
        TableRowExtension(),
        TableCellExtension(),
        TableHeaderExtension(),
      ],
    ));
    final toolbar = TiptapToolbarController(editor: editor, root: root);
    addTearDown(() async {
      await toolbar.destroy();
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    editor
        .dispatchTransaction(editor.state.tr.insertText('CONTEUDO_INICIAL', 1));
    final editorDom = root.querySelector('.ProseMirror') as web.HTMLElement;

    await _placeCaretAtEnd(editor, editorDom.querySelector('p')!);
    _dispatchPaste(
      editorDom,
      text: ' TEXTO_COLADO_PLAIN',
    );
    await Future<void>.delayed(Duration.zero);

    expect(editor.state.doc.textContent, contains('CONTEUDO_INICIAL'));
    expect(editor.state.doc.textContent, contains('TEXTO_COLADO_PLAIN'));
    expect(editorDom.textContent, contains('TEXTO_COLADO_PLAIN'));

    await _placeCaretAtEnd(editor, editorDom);
    _dispatchPaste(
      editorDom,
      text: 'TEXTO_COLADO_HTML\nSEGUNDA_LINHA_COLADA',
      html: '<p><strong>TEXTO_COLADO_HTML</strong></p>'
          '<p>SEGUNDA_LINHA_COLADA</p>',
    );
    await Future<void>.delayed(Duration.zero);

    final contentAfterPaste = editor.state.doc.textContent;
    expect(contentAfterPaste, contains('TEXTO_COLADO_PLAIN'));
    expect(contentAfterPaste, contains('TEXTO_COLADO_HTML'));
    expect(contentAfterPaste, contains('SEGUNDA_LINHA_COLADA'));
    expect(editorDom.querySelector('strong')?.textContent, 'TEXTO_COLADO_HTML');

    final pastedStrong = editorDom.querySelector('strong')!;
    await _selectContents(editor, pastedStrong);
    _click(root.querySelector('[data-tiptap-command="align-center"]')!);
    await Future<void>.delayed(Duration.zero);

    expect(editor.state.doc.textContent, contentAfterPaste);
    expect(editorDom.textContent, contains('TEXTO_COLADO_PLAIN'));
    expect(editorDom.textContent, contains('TEXTO_COLADO_HTML'));
    expect(
      (editorDom.querySelector('strong')!.parentElement as web.HTMLElement)
          .style
          .textAlign,
      'center',
    );

    await _placeCaretAtEnd(editor, editorDom);
    _click(root.querySelector('[data-tiptap-action="table"]')!);
    await Future<void>.delayed(Duration.zero);

    expect(editor.state.doc.textContent, contains('TEXTO_COLADO_PLAIN'));
    expect(editor.state.doc.textContent, contains('TEXTO_COLADO_HTML'));
    expect(editor.state.doc.textContent, contains('SEGUNDA_LINHA_COLADA'));
    expect(editorDom.textContent, contains('TEXTO_COLADO_HTML'));
    expect(editorDom.querySelector('table'), isNotNull);

    var hasTable = false;
    editor.state.doc.nodesBetween(
      0,
      editor.state.doc.content.size,
      (node, pos, parent, index) {
        if (node.type.name == 'table') hasTable = true;
        return !hasTable;
      },
    );
    expect(hasTable, isTrue);
  });
}

void _dispatchPaste(
  web.HTMLElement target, {
  required String text,
  String? html,
}) {
  final clipboard = web.DataTransfer()..setData('text/plain', text);
  if (html != null) clipboard.setData('text/html', html);
  target.dispatchEvent(web.ClipboardEvent(
    'paste',
    web.ClipboardEventInit(
      bubbles: true,
      cancelable: true,
      composed: true,
      clipboardData: clipboard,
    ),
  ));
}

Future<void> _selectContents(TiptapEditor editor, web.Element element) async {
  final range = web.document.createRange()..selectNodeContents(element);
  web.document.getSelection()!
    ..removeAllRanges()
    ..addRange(range);
  web.document.dispatchEvent(web.Event('selectionchange'));
  await Future<void>.delayed(Duration.zero);
  editor.view?.domObserver.forceFlush();
}

Future<void> _placeCaretAtEnd(TiptapEditor editor, web.Element element) async {
  final range = web.document.createRange()
    ..selectNodeContents(element)
    ..collapse(false);
  web.document.getSelection()!
    ..removeAllRanges()
    ..addRange(range);
  web.document.dispatchEvent(web.Event('selectionchange'));
  await Future<void>.delayed(Duration.zero);
  editor.view?.domObserver.forceFlush();
}

void _click(web.Element element) {
  element.dispatchEvent(web.Event('pointerdown', web.EventInit(bubbles: true)));
  (element as web.HTMLButtonElement).click();
}
