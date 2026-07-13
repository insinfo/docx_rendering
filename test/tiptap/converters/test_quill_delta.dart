import 'dart:math';

import 'package:test/test.dart';

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/quill_delta/index.dart';
import 'package:docx_rendering/src/tiptap/converters/quill_delta.dart';

/// Schema equivalente ao do editor, sem parseDOM/toDOM (VM-safe).
Schema buildSchema() {
  AttributeSpec nullable() => AttributeSpec(defaultValue: null, hasDefault: true);
  return Schema(SchemaSpec(nodes: {
    'doc': NodeSpec(content: 'block+'),
    'paragraph': NodeSpec(
        content: 'inline*', group: 'block', attrs: {'textAlign': nullable()}),
    'heading': NodeSpec(content: 'inline*', group: 'block', attrs: {
      'level': AttributeSpec(defaultValue: 1, hasDefault: true),
      'textAlign': nullable(),
    }),
    'bulletList': NodeSpec(content: 'listItem+', group: 'block'),
    'orderedList': NodeSpec(content: 'listItem+', group: 'block', attrs: {
      'start': AttributeSpec(defaultValue: 1, hasDefault: true),
    }),
    'listItem': NodeSpec(content: 'paragraph block*'),
    'image': NodeSpec(group: 'block', attrs: {
      'src': nullable(),
      'alt': nullable(),
      'title': nullable(),
      'width': nullable(),
      'height': nullable(),
    }),
    'horizontalRule': NodeSpec(group: 'block'),
    'hardBreak': NodeSpec(inline: true, group: 'inline'),
    'text': NodeSpec(group: 'inline', inline: true),
  }, marks: {
    'bold': MarkSpec(),
    'italic': MarkSpec(),
    'underline': MarkSpec(),
    'strike': MarkSpec(),
    'code': MarkSpec(code: true),
    'link': MarkSpec(inclusive: false, attrs: {
      'href': nullable(),
      'title': nullable(),
      'target': nullable(),
    }),
    'textStyle': MarkSpec(attrs: {
      'color': nullable(),
      'backgroundColor': nullable(),
      'fontFamily': nullable(),
      'fontSize': nullable(),
    }),
    'highlight': MarkSpec(attrs: {'color': nullable()}),
  }));
}

void main() {
  final schema = buildSchema();
  final converter = QuillDeltaConverter(schema);

  EditorState stateOf(PMNode doc) =>
      EditorState.create(EditorStateConfig(schema: schema, doc: doc));

  PMNode para(String text) =>
      schema.node('paragraph', null, text.isEmpty ? null : [schema.text(text)]);

  group('fromDelta', () {
    test('converte texto simples em parágrafos', () {
      final delta = Delta()..insert('Hello\nWorld\n');
      final doc = converter.fromDelta(delta);
      expect(doc.childCount, 2);
      expect(doc.child(0).type.name, 'paragraph');
      expect(doc.child(0).textContent, 'Hello');
      expect(doc.child(1).textContent, 'World');
    });

    test('aplica marcas inline', () {
      final delta = Delta()
        ..insert('Hello ')
        ..insert('bold', {'bold': true})
        ..insert(' and ')
        ..insert('red', {'color': 'red'})
        ..insert('\n');
      final doc = converter.fromDelta(delta);
      final blocks = doc.child(0);
      expect(blocks.childCount, 4);
      expect(blocks.child(1).marks.single.type.name, 'bold');
      expect(blocks.child(3).marks.single.type.name, 'textStyle');
      expect(blocks.child(3).marks.single.attrs['color'], 'red');
    });

    test('atributo de bloco vem do \\n que fecha a linha', () {
      final delta = Delta()
        ..insert('Title')
        ..insert('\n', {'header': 2})
        ..insert('body centered')
        ..insert('\n', {'align': 'center'});
      final doc = converter.fromDelta(delta);
      expect(doc.child(0).type.name, 'heading');
      expect(doc.child(0).attrs['level'], 2);
      expect(doc.child(1).type.name, 'paragraph');
      expect(doc.child(1).attrs['textAlign'], 'center');
    });

    test('agrupa linhas consecutivas de lista em um único nó de lista', () {
      final delta = Delta()
        ..insert('one')
        ..insert('\n', {'list': 'bullet'})
        ..insert('two')
        ..insert('\n', {'list': 'bullet'})
        ..insert('three')
        ..insert('\n', {'list': 'ordered'});
      final doc = converter.fromDelta(delta);
      expect(doc.childCount, 2);
      expect(doc.child(0).type.name, 'bulletList');
      expect(doc.child(0).childCount, 2);
      expect(doc.child(1).type.name, 'orderedList');
      expect(doc.child(1).child(0).child(0).textContent, 'three');
    });

    test('converte embeds de imagem e divider', () {
      final delta = Delta()
        ..insert('before\n')
        ..insert({'image': 'x.png'})
        ..insert('\n')
        ..insert({'divider': true})
        ..insert('\n');
      final doc = converter.fromDelta(delta);
      expect(doc.child(1).type.name, 'image');
      expect(doc.child(1).attrs['src'], 'x.png');
      expect(doc.child(2).type.name, 'horizontalRule');
    });
  });

  group('toDelta round-trip', () {
    void roundTrip(Delta delta) {
      final doc = converter.fromDelta(delta);
      final back = converter.toDelta(doc);
      expect(back, delta,
          reason: 'esperado: ${delta.toJson()}\nobtido: ${back.toJson()}');
    }

    test('texto simples', () {
      roundTrip(Delta()..insert('Hello\nWorld\n'));
    });

    test('marcas inline', () {
      roundTrip(Delta()
        ..insert('a ')
        ..insert('b', {'bold': true})
        ..insert('c', {'bold': true, 'italic': true})
        ..insert('link', {'link': 'https://x.dev'})
        ..insert('bg', {'background': 'yellow'})
        ..insert('\n'));
    });

    test('blocos com header, align e listas', () {
      roundTrip(Delta()
        ..insert('Title')
        ..insert('\n', {'header': 1})
        ..insert('centered')
        ..insert('\n', {'align': 'center'})
        ..insert('one')
        ..insert('\n', {'list': 'bullet'})
        ..insert('two')
        ..insert('\n', {'list': 'bullet'})
        ..insert('num')
        ..insert('\n', {'list': 'ordered'})
        ..insert('tail\n'));
    });

    test('embeds', () {
      roundTrip(Delta()
        ..insert('x\n')
        ..insert({'image': 'pic.png'})
        ..insert('\n')
        ..insert({'divider': true})
        ..insert('\n'));
    });

    test('propriedade: deltas aleatórios fazem round-trip', () {
      final random = Random(42);
      const words = ['lorem', 'ipsum', 'dolor', 'sit', 'amet', 'x', 'É já'];
      Map<String, dynamic>? randomInline() {
        final attrs = <String, dynamic>{};
        if (random.nextBool()) attrs['bold'] = true;
        if (random.nextInt(4) == 0) attrs['italic'] = true;
        if (random.nextInt(5) == 0) attrs['link'] = 'https://e.x/${random.nextInt(9)}';
        if (random.nextInt(5) == 0) attrs['color'] = '#ff000${random.nextInt(9)}';
        return attrs.isEmpty ? null : attrs;
      }

      Map<String, dynamic>? randomBlock() {
        switch (random.nextInt(6)) {
          case 0:
            return {'header': 1 + random.nextInt(3)};
          case 1:
            return {'align': 'center'};
          case 2:
            return {'list': 'bullet'};
          case 3:
            return {'list': 'ordered'};
          default:
            return null;
        }
      }

      for (var iteration = 0; iteration < 50; iteration++) {
        final delta = Delta();
        final lines = 1 + random.nextInt(6);
        for (var l = 0; l < lines; l++) {
          final runs = random.nextInt(4);
          for (var r = 0; r < runs; r++) {
            delta.insert(words[random.nextInt(words.length)], randomInline());
          }
          delta.insert('\n', randomBlock());
        }
        roundTrip(delta);
      }
    });
  });

  group('applyDelta incremental', () {
    test('insert no meio de um parágrafo', () {
      final state = stateOf(schema.node('doc', null, [para('Hello'), para('World')]));
      final delta = Delta()
        ..retain(3)
        ..insert('XX');
      final tr = converter.applyDelta(state, delta);
      final result = state.apply(tr);
      expect(result.doc.child(0).textContent, 'HelXXlo');
      expect(result.doc.child(1).textContent, 'World');
    });

    test('delete atravessando a fronteira de bloco junta parágrafos', () {
      final state = stateOf(schema.node('doc', null, [para('Hello'), para('World')]));
      final delta = Delta()
        ..retain(5)
        ..delete(1);
      final tr = converter.applyDelta(state, delta);
      final result = state.apply(tr);
      expect(result.doc.childCount, 1);
      expect(result.doc.child(0).textContent, 'HelloWorld');
    });

    test('insert de \\n divide o parágrafo', () {
      final state = stateOf(schema.node('doc', null, [para('Hello')]));
      final delta = Delta()
        ..retain(2)
        ..insert('\n');
      final tr = converter.applyDelta(state, delta);
      final result = state.apply(tr);
      expect(result.doc.childCount, 2);
      expect(result.doc.child(0).textContent, 'He');
      expect(result.doc.child(1).textContent, 'llo');
    });

    test('retain com atributo aplica marca', () {
      final state = stateOf(schema.node('doc', null, [para('Hello')]));
      final delta = Delta()
        ..retain(1)
        ..retain(3, {'bold': true});
      final tr = converter.applyDelta(state, delta);
      final result = state.apply(tr);
      final paragraph = result.doc.child(0);
      expect(paragraph.child(0).textContent, 'H');
      expect(paragraph.child(1).textContent, 'ell');
      expect(paragraph.child(1).marks.single.type.name, 'bold');
      expect(paragraph.child(2).textContent, 'o');
    });

    test('retain com atributo null remove marca', () {
      final bold = schema.marks['bold']!;
      final state = stateOf(schema.node('doc', null, [
        schema.node('paragraph', null, [
          schema.text('Hello', [bold.create()])
        ])
      ]));
      final delta = Delta()..retain(5, {'bold': null});
      final tr = converter.applyDelta(state, delta);
      final result = state.apply(tr);
      expect(result.doc.child(0).child(0).marks, isEmpty);
    });

    test('retain de \\n com header transforma o bloco em heading', () {
      final state = stateOf(schema.node('doc', null, [para('Title'), para('x')]));
      final delta = Delta()
        ..retain(5)
        ..retain(1, {'header': 1});
      final tr = converter.applyDelta(state, delta);
      final result = state.apply(tr);
      expect(result.doc.child(0).type.name, 'heading');
      expect(result.doc.child(0).attrs['level'], 1);
      expect(result.doc.child(1).type.name, 'paragraph');
    });
  });

  group('performance (R3)', () {
    test('delta de 50k+ ops convertido e aplicado < 1s em uma transação', () {
      final delta = Delta();
      for (var i = 0; i < 25000; i++) {
        delta
          ..insert('word$i ')
          ..insert('bold', {'bold': true})
          ..insert('\n', i % 10 == 0 ? {'header': 1} : null);
      }
      expect(delta.length, greaterThan(50000));

      final state = stateOf(schema.node('doc', null, [para('old content')]));
      final stopwatch = Stopwatch()..start();
      final tr = converter.applyDeltaAsDocument(state, delta);
      final result = state.apply(tr);
      stopwatch.stop();

      expect(result.doc.childCount, 25000);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'levou ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
