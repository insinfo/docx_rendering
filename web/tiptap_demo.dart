import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:docx_rendering/tiptap.dart';
import 'package:web/web.dart' as web;

void main() {
  final element = web.document.getElementById('editor') as web.HTMLElement;
  final editor = TiptapEditor(EditorOptions(
    element: element,
    extensions: const [
      DocumentExtension(),
      ParagraphExtension(),
      TextExtension(),
      BoldExtension(),
      ItalicExtension(),
      DropcursorExtension(),
    ],
  ));
  final window = web.window as JSObject;
  window.setProperty('getTiptapHTML'.toJS, (() => editor.getHTML()).toJS);
  window.setProperty(
      'getTiptapJSON'.toJS, (() => editor.getJSON().toString()).toJS);
  window.setProperty('setTiptapEditable'.toJS,
      ((bool editable) => editor.setEditable(editable)).toJS);
}
