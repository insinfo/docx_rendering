@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../../web/tiptap_demo.dart' as demo;

void main() {
  test('demo monta editor rico e conecta shell interativo', () async {
    web.document.body!.innerHTML = '''
      <main id="editor-frame"><div id="toolbar">
        <button data-tiptap-command="bold"></button><button data-tiptap-action="zoom-in"></button>
        <select id="block-style" data-tiptap-control="block-style"><option value="paragraph">P</option><option value="heading-1">H1</option><option value="heading-2">H2</option><option value="heading-3">H3</option></select>
        <select id="font-family" data-tiptap-control="font-family"><option>Arial</option></select>
        <select id="font-size" data-tiptap-control="font-size"><option>12</option></select>
        <input id="text-color" data-tiptap-control="text-color" value="#2563eb"><i id="text-color-line" data-tiptap-color-indicator="text-color"></i>
        <input id="highlight-color" data-tiptap-control="highlight-color" value="#fef08a"><i id="highlight-color-line" data-tiptap-color-indicator="highlight-color"></i>
        <button id="zoom-value" data-tiptap-zoom-value></button>
      </div>
      <button id="open-docx-button"></button><input id="open-docx-input" type="file">
      <button id="open-delta-button"></button><input id="open-delta-input" type="file">
      <button id="insert-image-button"></button><input id="insert-image-input" type="file">
      <button id="export-docx"></button><button id="export-pdf"></button><button id="copy-delta"></button>
      <button id="export-menu-button"></button><div id="export-menu"></div>
      <button id="theme-toggle"></button>
      <input id="document-title" value="Documento sem título">
      <div id="save-state"></div><div id="progress-strip"><span></span></div>
      <div id="document-viewport"><div id="page-scale"><article id="page-sheet"><div id="editor"></div></article></div></div>
      </main>
      <span id="word-count"></span><span id="character-count"></span><span id="document-status"></span>
      <div id="toast"></div>
    '''
        .toJS;

    demo.main();
    await Future<void>.delayed(Duration.zero);

    final editor = web.document.querySelector('.ProseMirror');
    expect(editor, isNotNull);
    expect(editor!.textContent, contains('ACORDO DE CONFIDENCIALIDADE'));
    expect(web.document.getElementById('word-count')!.textContent,
        contains('palavras'));

    (web.document.getElementById('export-menu-button') as web.HTMLButtonElement)
        .click();
    expect(
        web.document.getElementById('export-menu')!.classList.contains('open'),
        isTrue);
    (web.document.getElementById('theme-toggle') as web.HTMLButtonElement)
        .click();
    expect(web.document.body!.classList.contains('dark'), isTrue);

    final jsonText = (web.window as JSObject)
        .callMethod<JSString>('getTiptapJSON'.toJS)
        .toDart;
    expect(jsonDecode(jsonText), isA<Map<String, dynamic>>());

    await demo.toolbarController.destroy();
    demo.editor.destroy();
    web.document.body!.innerHTML = ''.toJS;
  });
}
