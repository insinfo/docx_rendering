@TestOn('browser')
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/prosemirror/view/index.dart';

final testViewSchema = Schema(SchemaSpec(
  nodes: {
    'doc': NodeSpec(
      content: 'block+',
    ),
    'paragraph': NodeSpec(
      content: 'inline*',
      group: 'block',
      toDOM: (node) => ['p', 0],
    ),
    'text': NodeSpec(group: 'inline'),
  },
  marks: {},
));

PMNode p(String text) => testViewSchema.nodes['paragraph']!.create(null, [testViewSchema.text(text)]);
PMNode doc(List<PMNode> children) => testViewSchema.nodes['doc']!.create(null, children);

void main() {
  test('MutationObserver and ViewDesc localized re-render', () {
    EditorState? latestState;
    
    final docNode = doc([p('one'), p('two'), p('three')]);
    
    final state = EditorState.create(EditorStateConfig(
      doc: docNode,
      schema: testViewSchema,
    ));
    latestState = state;

    final place = web.document.createElement('div') as web.HTMLElement;
    web.document.body!.appendChild(place);

    late EditorView view;
    view = EditorView(place, DirectEditorProps(
      state: state,
      dispatchTransaction: (tr) {
        latestState = latestState!.apply(tr);
        view.updateState(latestState!);
      }
    ));

    final domOne = view.dom.childNodes.item(0)!;
    final domThree = view.dom.childNodes.item(2)!;

    // Test 1: State update localized re-render
    final tr = view.state.tr.insertText(' modified', 6, 6);
    view.dispatch(tr);

    expect(view.dom.childNodes.item(0), equals(domOne), reason: 'First paragraph DOM reused after state update');
    expect(view.dom.childNodes.item(2), equals(domThree), reason: 'Third paragraph DOM reused after state update');

    // Test 2: DOM mutation localized read
    // Manually mutate the DOM of the middle paragraph
    final domTwoUpdated = view.dom.childNodes.item(1)!;
    final textNode = domTwoUpdated.firstChild as web.Text;
    textNode.nodeValue = 'two modified again';

    // Flush observer to read the mutation
    view.domObserver.flush();

    expect(latestState!.doc.childCount, equals(3));
    expect(latestState!.doc.child(1).textContent, equals('two modified again'));
    expect(view.dom.childNodes.item(0), equals(domOne), reason: 'First paragraph DOM untouched by mutation read');
    expect(view.dom.childNodes.item(2), equals(domThree), reason: 'Third paragraph DOM untouched by mutation read');
    
    view.destroy();
    place.remove();
  });
}
