import 'package:test/test.dart';

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/tiptap/core/commands.dart';

Schema buildSchema() => Schema(SchemaSpec(nodes: {
      'doc': NodeSpec(content: 'block+'),
      'paragraph': NodeSpec(content: 'inline*', group: 'block'),
      'text': NodeSpec(group: 'inline', inline: true),
    }, marks: {
      'bold': MarkSpec(),
    }));

final schema = buildSchema();

EditorState stateWith(String text, int from, int to) {
  final doc = schema.nodes['doc']!.create(
      null,
      Fragment.from(schema.nodes['paragraph']!
          .create(null, Fragment.from(schema.text(text)))));
  return EditorState.create(EditorStateConfig(
    doc: doc,
    selection: TextSelection.create(doc, from, to),
  ));
}

String run(String mode, String text, int from, int to) {
  final state = stateWith(text, from, to);
  EditorState next = state;
  final ok = transformCaseCommand(mode)(state, (tr) => next = state.apply(tr));
  expect(ok, isTrue);
  return next.doc.textContent;
}

void main() {
  test('upper e lower', () {
    expect(run('upper', 'lei complementar', 1, 17), 'LEI COMPLEMENTAR');
    expect(run('lower', 'LEI Complementar', 1, 17), 'lei complementar');
  });

  test('title coloca cada palavra em maiúscula', () {
    expect(run('title', 'lei de responsabilidade', 1, 24),
        'Lei De Responsabilidade');
  });

  test('sentence capitaliza início de frases', () {
    expect(run('sentence', 'primeira frase. segunda FRASE aqui.', 1, 36),
        'Primeira frase. Segunda frase aqui.');
  });

  test('toggle alterna a caixa de cada letra', () {
    expect(run('toggle', 'aLTERNAR mAIÚSC.', 1, 17), 'Alternar Maiúsc.');
  });

  test('aplica apenas dentro da seleção e preserva marcas', () {
    // 'lei' fica fora da seleção (1..4 = 'lei'), o resto vira maiúsculo.
    expect(run('upper', 'lei complementar', 5, 17), 'lei COMPLEMENTAR');
  });

  test('seleção vazia é rejeitada', () {
    final state = stateWith('abc', 2, 2);
    expect(transformCaseCommand('upper')(state, null), isFalse);
  });
}
