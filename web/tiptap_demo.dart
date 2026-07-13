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
      DropcursorExtension(),
    ],
  ));
  final window = web.window as JSObject;
  window.setProperty('getTiptapHTML'.toJS, (() => editor.getHTML()).toJS);
  window.setProperty(
      'getTiptapJSON'.toJS, (() => editor.getJSON().toString()).toJS);
  window.setProperty('setTiptapEditable'.toJS,
      ((bool editable) => editor.setEditable(editable)).toJS);
  window.setProperty('getTiptapDelta'.toJS, (() {
    final converter = QuillDeltaConverter(editor.state.schema);
    return converter.toDelta(editor.state.doc).toJson().toString();
  }).toJS);
  window.setProperty('toggleTiptapBulletList'.toJS,
      (() => editor.chain.focus().toggleBulletList().run()).toJS);
  window.setProperty('toggleTiptapHeading'.toJS,
      ((int level) => editor.chain.focus().toggleHeading(level).run()).toJS);
}
