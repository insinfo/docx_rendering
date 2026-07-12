import 'package:test/test.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/prosemirror/inputrules/index.dart';
import 'package:docx_rendering/src/prosemirror/test_builder/index.dart';

void main() {
  group('InputRules', () {
    test('replaces double dash with emdash', () {
      final docNode = doc(p("<a>"));
      final pos = docNode.tag['a']!;

      final plugin = inputRules(rules: [emDash]);
      var state = EditorState.create(EditorStateConfig(
        schema: schema,
        doc: docNode,
        selection: TextSelection.create(docNode, pos),
        plugins: [plugin],
      ));

      final viewMock = _FakeView(state);

      // Typing '-' at pos
      var tr = state.tr.insertText("-", pos);
      state = state.apply(tr);
      viewMock.state = state;

      // Typing '-' at pos + 1
      final handled = run(viewMock, pos + 1, pos + 1, "-", [emDash], plugin);
      expect(handled, isTrue);
      expect(viewMock.lastDispatched!.doc.eq(doc(p("—"))), isTrue);
    });

    test('replaces with wrapping blockquote rule', () {
      final docNode = doc(p("<a>"));
      final pos = docNode.tag['a']!;
      final rule = wrappingInputRule(RegExp(r'^\s*>\s$'), schema.nodes['blockquote']!);

      final plugin = inputRules(rules: [rule]);
      var state = EditorState.create(EditorStateConfig(
        schema: schema,
        doc: docNode,
        selection: TextSelection.create(docNode, pos),
        plugins: [plugin],
      ));

      final viewMock = _FakeView(state);

      // User types '>'
      var tr = state.tr.insertText(">", pos);
      state = state.apply(tr);
      viewMock.state = state;

      // User types ' ' at pos + 1
      final handled = run(viewMock, pos + 1, pos + 1, " ", [rule], plugin);
      expect(handled, isTrue);
      expect(viewMock.lastDispatched!.doc.eq(doc(blockquote(p()))), isTrue);
    });
  });
}

class _FakeView {
  EditorState state;
  Transaction? lastDispatched;
  bool composing = false;

  _FakeView(this.state);

  void dispatch(Transaction tr) {
    lastDispatched = tr;
  }
}
