@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:docx_rendering/tiptap.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('toolbar é isolada por raiz e libera listeners no destroy', () async {
    web.document.body!.innerHTML = '''
      <section id="one">
        <button data-tiptap-command="bold">B</button>
        <button data-tiptap-action="zoom-in">+</button>
        <span data-tiptap-zoom-value></span>
        <div class="mount"></div>
      </section>
      <section id="two">
        <button data-tiptap-command="bold">B</button>
        <span data-tiptap-zoom-value></span>
        <div class="mount"></div>
      </section>
    '''
        .toJS;

    final one = web.document.getElementById('one')!;
    final two = web.document.getElementById('two')!;
    final editorOne = _editor(one.querySelector('.mount') as web.HTMLElement);
    final editorTwo = _editor(two.querySelector('.mount') as web.HTMLElement);
    var zoom = 0.0;
    final toolbarOne = TiptapToolbarController(
      editor: editorOne,
      root: one,
      onZoomChanged: (value) => zoom = value,
    );
    final toolbarTwo = TiptapToolbarController(editor: editorTwo, root: two);

    (one.querySelector('[data-tiptap-command="bold"]') as web.HTMLButtonElement)
        .click();
    await Future<void>.delayed(Duration.zero);
    expect(editorOne.isActive('bold'), isTrue);
    expect(editorTwo.isActive('bold'), isFalse);
    expect(
        two
            .querySelector('[data-tiptap-command="bold"]')!
            .classList
            .contains('active'),
        isFalse);

    (one.querySelector('[data-tiptap-action="zoom-in"]')
            as web.HTMLButtonElement)
        .click();
    await Future<void>.delayed(Duration.zero);
    expect(zoom, closeTo(1.1, .001));
    expect(one.querySelector('[data-tiptap-zoom-value]')!.textContent, '110%');

    await toolbarOne.destroy();
    (one.querySelector('[data-tiptap-command="bold"]') as web.HTMLButtonElement)
        .click();
    await Future<void>.delayed(Duration.zero);
    expect(editorOne.isActive('bold'), isTrue);

    await toolbarTwo.destroy();
    editorOne.destroy();
    editorTwo.destroy();
    web.document.body!.innerHTML = ''.toJS;
  });

  test('seleção nativa é aplicada por bold, fonte, cor e alinhamento',
      () async {
    web.document.body!.innerHTML = '''
      <section id="root">
        <button data-tiptap-command="bold">B</button>
        <button data-tiptap-command="align-center">center</button>
        <select data-tiptap-control="font-family">
          <option value="Arial">Arial</option>
          <option value="Courier New">Courier New</option>
        </select>
        <input data-tiptap-control="text-color" type="color" value="#ff0000">
        <i data-tiptap-color-indicator="text-color"></i>
        <div class="mount"></div>
      </section>
    '''
        .toJS;

    final root = web.document.getElementById('root')!;
    final editor = _editor(root.querySelector('.mount') as web.HTMLElement);
    final schema = editor.state.schema;
    final doc = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('Texto selecionado')]),
    ]);
    final tr = editor.state.tr;
    tr.replaceWith(0, editor.state.doc.content.size, doc.content);
    editor.dispatchTransaction(tr);
    final toolbar = TiptapToolbarController(editor: editor, root: root);

    _selectContents(root.querySelector('.ProseMirror p')!);
    final bold = root.querySelector('[data-tiptap-command="bold"]')!;
    bold.dispatchEvent(web.Event('pointerdown', web.EventInit(bubbles: true)));
    (bold as web.HTMLButtonElement).click();
    await Future<void>.delayed(Duration.zero);
    expect(root.querySelector('.ProseMirror strong')?.textContent,
        'Texto selecionado');

    _selectContents(root.querySelector('.ProseMirror strong')!);
    final family = root.querySelector('[data-tiptap-control="font-family"]')
        as web.HTMLSelectElement;
    family
        .dispatchEvent(web.Event('pointerdown', web.EventInit(bubbles: true)));
    family.value = 'Courier New';
    family.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
    await Future<void>.delayed(Duration.zero);
    final fontStyle =
        root.querySelector('.ProseMirror span')?.getAttribute('style');
    expect(fontStyle, contains('font-family:'));
    expect(fontStyle, contains('Courier New'));

    _selectContents(root.querySelector('.ProseMirror span')!);
    final color = root.querySelector('[data-tiptap-control="text-color"]')
        as web.HTMLInputElement;
    color.dispatchEvent(web.Event('pointerdown', web.EventInit(bubbles: true)));
    color.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await Future<void>.delayed(Duration.zero);
    final colorStyle =
        root.querySelector('.ProseMirror span')?.getAttribute('style');
    expect(colorStyle, anyOf(contains('#ff0000'), contains('rgb(255, 0, 0)')));

    final align = root.querySelector('[data-tiptap-command="align-center"]')!;
    align.dispatchEvent(web.Event('pointerdown', web.EventInit(bubbles: true)));
    (align as web.HTMLButtonElement).click();
    await Future<void>.delayed(Duration.zero);
    expect(
        (root.querySelector('.ProseMirror p') as web.HTMLParagraphElement)
            .style
            .textAlign,
        'center');

    await toolbar.destroy();
    editor.destroy();
    web.document.body!.innerHTML = ''.toJS;
  });
}

void _selectContents(web.Element element) {
  final range = web.document.createRange();
  range.selectNodeContents(element);
  final selection = web.document.getSelection()!;
  selection.removeAllRanges();
  selection.addRange(range);
  web.document.dispatchEvent(web.Event('selectionchange'));
}

TiptapEditor _editor(web.HTMLElement mount) => TiptapEditor(EditorOptions(
      element: mount,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        BoldExtension(),
        TextStyleExtension(),
        TextAlignExtension(),
      ],
    ));
