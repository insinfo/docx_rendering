import 'package:test/test.dart';

import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/tiptap/extensions/table_commands.dart';
import 'package:docx_rendering/src/tiptap/extensions/table_map.dart';

/// Schema equivalente ao do editor para tabelas, sem parseDOM/toDOM (VM-safe).
Schema buildSchema() {
  AttributeSpec nullable() =>
      AttributeSpec(defaultValue: null, hasDefault: true);
  Map<String, AttributeSpec> cellAttrs() => {
        'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
        'rowspan': AttributeSpec(defaultValue: 1, hasDefault: true),
        'colwidth': nullable(),
        'columnIndex': nullable(),
        'width': nullable(),
        'backgroundColor': nullable(),
        'borderTop': nullable(),
        'borderRight': nullable(),
        'borderBottom': nullable(),
        'borderLeft': nullable(),
        'paddingTop': nullable(),
        'paddingRight': nullable(),
        'paddingBottom': nullable(),
        'paddingLeft': nullable(),
      };
  return Schema(SchemaSpec(nodes: {
    'doc': NodeSpec(content: 'block+'),
    'paragraph': NodeSpec(content: 'inline*', group: 'block'),
    'table': NodeSpec(content: 'tableRow+', group: 'block', isolating: true, attrs: {
      'styleName': nullable(),
      'width': nullable(),
      'columnWidths': nullable(),
      'alignment': nullable(),
      'textBox': AttributeSpec(defaultValue: false, hasDefault: true),
    }),
    'tableRow': NodeSpec(content: '(tableCell | tableHeader)*', attrs: {
      'columnWidths': nullable(),
      'isHeader': AttributeSpec(defaultValue: false, hasDefault: true),
      'tableWidth': nullable(),
      'tableAlignment': nullable(),
      'height': nullable(),
      'heightRule': nullable(),
    }),
    'tableCell':
        NodeSpec(content: 'block+', isolating: true, attrs: cellAttrs()),
    'tableHeader':
        NodeSpec(content: 'block+', isolating: true, attrs: cellAttrs()),
    'text': NodeSpec(group: 'inline', inline: true),
  }));
}

final schema = buildSchema();

PMNode p(String text) => schema.nodes['paragraph']!.create(
    null, text.isEmpty ? null : Fragment.from(schema.text(text)));

PMNode cell(String text,
        {int colspan = 1, int rowspan = 1, String type = 'tableCell'}) =>
    schema.nodes[type]!.create(
        {'colspan': colspan, 'rowspan': rowspan}, Fragment.from(p(text)));

PMNode row(List<PMNode> cells, [Map<String, dynamic>? attrs]) =>
    schema.nodes['tableRow']!.create(attrs, Fragment.fromArray(cells));

PMNode table(List<PMNode> rows, [Map<String, dynamic>? attrs]) =>
    schema.nodes['table']!.create(attrs, Fragment.fromArray(rows));

PMNode doc(List<PMNode> blocks) =>
    schema.nodes['doc']!.create(null, Fragment.fromArray(blocks));

/// Posição absoluta dentro do parágrafo da célula na grade (row, col).
int posInCell(PMNode document, int rowIndex, int colIndex) {
  final tableNode = document.child(0);
  final map = TableMap.of(tableNode);
  final rel = map.map[rowIndex * map.width + colIndex];
  // tablePos = 0 → tableStart = 1; +1 entra na célula, +1 entra no parágrafo.
  return 1 + rel + 2;
}

EditorState stateWithSelection(PMNode document, int anchor, [int? head]) =>
    EditorState.create(EditorStateConfig(
      doc: document,
      selection: TextSelection.create(document, anchor, head),
    ));

/// Executa um comando e retorna o novo estado.
EditorState run(EditorState state, Command command) {
  EditorState next = state;
  final ok = command(state, (tr) => next = state.apply(tr));
  expect(ok, isTrue, reason: 'comando deveria ser aplicável');
  return next;
}

/// Dimensões da grade da tabela no índice 0 do doc.
(int, int) gridOf(PMNode document) {
  final map = TableMap.of(document.child(0));
  return (map.width, map.height);
}

String cellText(PMNode document, int rowIndex, int colIndex) {
  final tableNode = document.child(0);
  final map = TableMap.of(tableNode);
  final rel = map.map[rowIndex * map.width + colIndex];
  return tableNode.nodeAt(rel)!.textContent;
}

void main() {
  group('TableMap', () {
    test('tabela simples 3x3', () {
      final t = table([
        row([cell('a'), cell('b'), cell('c')]),
        row([cell('d'), cell('e'), cell('f')]),
        row([cell('g'), cell('h'), cell('i')]),
      ]);
      final map = TableMap.of(t);
      expect(map.width, 3);
      expect(map.height, 3);
      expect(map.map.length, 9);
      // Primeira célula fica logo após o token de abertura da linha.
      expect(map.map[0], 1);
      expect(map.colCount(map.map[4]), 1);
      final rect = map.findCell(map.map[8]);
      expect([rect.left, rect.top, rect.right, rect.bottom], [2, 2, 3, 3]);
    });

    test('colspan e rowspan ocupam múltiplos slots', () {
      final t = table([
        row([cell('a', colspan: 2), cell('b', rowspan: 2)]),
        row([cell('c'), cell('d')]),
      ]);
      final map = TableMap.of(t);
      expect(map.width, 3);
      expect(map.height, 2);
      // 'a' cobre os slots 0 e 1; 'b' cobre 2 e 5.
      expect(map.map[0], map.map[1]);
      expect(map.map[2], map.map[5]);
      final rectA = map.findCell(map.map[0]);
      expect([rectA.left, rectA.right], [0, 2]);
      final rectB = map.findCell(map.map[2]);
      expect([rectB.top, rectB.bottom], [0, 2]);
    });
  });

  group('linhas e colunas', () {
    PMNode doc2x2() => doc([
          table([
            row([cell('a'), cell('b')]),
            row([cell('c'), cell('d')]),
          ])
        ]);

    test('addColumnAfter insere coluna à direita', () {
      final d = doc2x2();
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, addColumnCommand(before: false));
      expect(gridOf(next.doc), (3, 2));
      expect(cellText(next.doc, 0, 1), '');
      expect(cellText(next.doc, 0, 2), 'b');
    });

    test('addColumnBefore insere coluna à esquerda', () {
      final d = doc2x2();
      final state = stateWithSelection(d, posInCell(d, 0, 1));
      final next = run(state, addColumnCommand(before: true));
      expect(gridOf(next.doc), (3, 2));
      expect(cellText(next.doc, 0, 0), 'a');
      expect(cellText(next.doc, 0, 1), '');
      expect(cellText(next.doc, 0, 2), 'b');
    });

    test('addColumn através de célula com colspan aumenta o span', () {
      final d = doc([
        table([
          row([cell('wide', colspan: 2)]),
          row([cell('c'), cell('d')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 1, 0));
      final next = run(state, addColumnCommand(before: false));
      expect(gridOf(next.doc), (3, 2));
      final wide = next.doc.child(0).child(0).child(0);
      expect(wide.attrs['colspan'], 3);
      expect(next.doc.child(0).child(1).childCount, 3);
    });

    test('addRowAfter insere linha abaixo', () {
      final d = doc2x2();
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, addRowCommand(before: false));
      expect(gridOf(next.doc), (2, 3));
      expect(cellText(next.doc, 1, 0), '');
      expect(cellText(next.doc, 2, 0), 'c');
    });

    test('addRow através de rowspan aumenta o span', () {
      final d = doc([
        table([
          row([cell('tall', rowspan: 2), cell('b')]),
          row([cell('d')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 0, 1));
      final next = run(state, addRowCommand(before: false));
      expect(gridOf(next.doc), (2, 3));
      final tall = next.doc.child(0).child(0).child(0);
      expect(tall.attrs['rowspan'], 3);
      // A nova linha tem apenas uma célula (a coluna 0 é coberta pelo span).
      expect(next.doc.child(0).child(1).childCount, 1);
    });

    test('deleteColumn remove a coluna do cursor', () {
      final d = doc2x2();
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, deleteColumnCommand());
      expect(gridOf(next.doc), (1, 2));
      expect(cellText(next.doc, 0, 0), 'b');
      expect(cellText(next.doc, 1, 0), 'd');
    });

    test('deleteColumn encolhe células com colspan', () {
      final d = doc([
        table([
          row([cell('wide', colspan: 2), cell('b')]),
          row([cell('c'), cell('d'), cell('e')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 1, 0));
      final next = run(state, deleteColumnCommand());
      expect(gridOf(next.doc), (2, 2));
      final wide = next.doc.child(0).child(0).child(0);
      expect(wide.attrs['colspan'], 1);
      expect(wide.textContent, 'wide');
    });

    test('deleteRow remove a linha e reancora rowspans', () {
      final d = doc([
        table([
          row([cell('tall', rowspan: 2), cell('b')]),
          row([cell('d')]),
          row([cell('e'), cell('f')]),
        ])
      ]);
      // Cursor na linha do meio (célula 'd', coluna 1).
      final state = stateWithSelection(d, posInCell(d, 1, 1));
      final next = run(state, deleteRowCommand());
      expect(gridOf(next.doc), (2, 2));
      final tall = next.doc.child(0).child(0).child(0);
      expect(tall.attrs['rowspan'], 1);
      expect(cellText(next.doc, 1, 0), 'e');
    });

    test('deleteRow em linha com âncora de rowspan move a célula para baixo',
        () {
      final d = doc([
        table([
          row([cell('tall', rowspan: 2), cell('b')]),
          row([cell('d')]),
          row([cell('e'), cell('f')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 0, 1));
      final next = run(state, deleteRowCommand());
      expect(gridOf(next.doc), (2, 2));
      expect(cellText(next.doc, 0, 0), 'tall');
      final tall = next.doc.child(0).child(0).child(0);
      expect(tall.attrs['rowspan'], 1);
      expect(cellText(next.doc, 0, 1), 'd');
    });

    test('deleteRow da única linha remove a tabela inteira', () {
      final d = doc([
        table([
          row([cell('a'), cell('b')]),
        ]),
        p('depois'),
      ]);
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, deleteRowCommand());
      expect(next.doc.childCount, 1);
      expect(next.doc.child(0).textContent, 'depois');
    });
  });

  group('mesclar e dividir', () {
    test('mergeCells une um retângulo 2x2', () {
      final d = doc([
        table([
          row([cell('a'), cell('b'), cell('x')]),
          row([cell('c'), cell('d'), cell('y')]),
        ])
      ]);
      final state = stateWithSelection(
          d, posInCell(d, 0, 0), posInCell(d, 1, 1));
      final next = run(state, mergeCellsCommand());
      expect(gridOf(next.doc), (3, 2));
      final merged = next.doc.child(0).child(0).child(0);
      expect(merged.attrs['colspan'], 2);
      expect(merged.attrs['rowspan'], 2);
      expect(merged.textContent, contains('a'));
      expect(merged.textContent, contains('d'));
      expect(cellText(next.doc, 0, 2), 'x');
      expect(cellText(next.doc, 1, 2), 'y');
    });

    test('mergeCells recusa retângulo sujo', () {
      final d = doc([
        table([
          row([cell('a'), cell('tall', rowspan: 2)]),
          row([cell('c')]),
        ])
      ]);
      // 'wide' cruza a borda direita do retângulo 'a'..'c' → sujo.
      final dirty = doc([
        table([
          row([cell('a'), cell('wide', colspan: 2)]),
          row([cell('b'), cell('c'), cell('d')]),
        ])
      ]);
      final state = stateWithSelection(
          dirty, posInCell(dirty, 0, 0), posInCell(dirty, 1, 1));
      final ok = mergeCellsCommand()(state, null);
      expect(ok, isFalse);
      // E o caso limpo funciona.
      final cleanState =
          stateWithSelection(d, posInCell(d, 0, 0), posInCell(d, 1, 0));
      final next = run(cleanState, mergeCellsCommand());
      final merged = next.doc.child(0).child(0).child(0);
      expect(merged.attrs['rowspan'], 2);
    });

    test('splitCell desfaz colspan+rowspan', () {
      final d = doc([
        table([
          row([cell('big', colspan: 2, rowspan: 2), cell('x')]),
          row([cell('y')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, splitCellCommand());
      expect(gridOf(next.doc), (3, 2));
      final first = next.doc.child(0).child(0).child(0);
      expect(first.attrs['colspan'], 1);
      expect(first.attrs['rowspan'], 1);
      expect(first.textContent, 'big');
      expect(next.doc.child(0).child(0).childCount, 3);
      expect(next.doc.child(0).child(1).childCount, 3);
    });
  });

  group('atributos', () {
    test('setCellAttrs aplica fundo a todas as células do retângulo', () {
      final d = doc([
        table([
          row([cell('a'), cell('b')]),
          row([cell('c'), cell('d')]),
        ])
      ]);
      final state =
          stateWithSelection(d, posInCell(d, 0, 0), posInCell(d, 1, 1));
      final next =
          run(state, setCellAttrsCommand({'backgroundColor': '#ffff00'}));
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          final t = next.doc.child(0);
          final map = TableMap.of(t);
          final cellNode = t.nodeAt(map.map[r * 2 + c])!;
          expect(cellNode.attrs['backgroundColor'], '#ffff00');
        }
      }
    });

    test('setCellBorders outer aplica só nas bordas externas', () {
      final d = doc([
        table([
          row([cell('a'), cell('b')]),
          row([cell('c'), cell('d')]),
        ])
      ]);
      final state =
          stateWithSelection(d, posInCell(d, 0, 0), posInCell(d, 1, 1));
      final next = run(
          state, setCellBordersCommand('outer', '2px solid #ff0000'));
      final t = next.doc.child(0);
      final map = TableMap.of(t);
      final a = t.nodeAt(map.map[0])!;
      expect(a.attrs['borderTop'], '2px solid #ff0000');
      expect(a.attrs['borderLeft'], '2px solid #ff0000');
      expect(a.attrs['borderBottom'], isNull);
      expect(a.attrs['borderRight'], isNull);
      final dCell = t.nodeAt(map.map[3])!;
      expect(dCell.attrs['borderBottom'], '2px solid #ff0000');
      expect(dCell.attrs['borderRight'], '2px solid #ff0000');
      expect(dCell.attrs['borderTop'], isNull);
    });

    test('toggleHeaderRow converte a primeira linha', () {
      final d = doc([
        table([
          row([cell('a'), cell('b')]),
          row([cell('c'), cell('d')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, toggleHeaderRowCommand());
      final firstRow = next.doc.child(0).child(0);
      expect(firstRow.child(0).type.name, 'tableHeader');
      expect(firstRow.attrs['isHeader'], true);
      final back = run(next, toggleHeaderRowCommand());
      expect(back.doc.child(0).child(0).child(0).type.name, 'tableCell');
    });

    test('setColumnWidths grava tabela e linhas', () {
      final d = doc([
        table([
          row([cell('a'), cell('b')]),
          row([cell('c'), cell('d')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 0, 0));
      final next = run(state, setColumnWidthsCommand([120, 240]));
      final t = next.doc.child(0);
      expect(t.attrs['columnWidths'], [120, 240]);
      expect(t.child(0).attrs['columnWidths'], [120, 240]);
      expect(t.child(1).attrs['columnWidths'], [120, 240]);
    });

    test('setRowHeight grava altura nas linhas selecionadas', () {
      final d = doc([
        table([
          row([cell('a')]),
          row([cell('b')]),
        ])
      ]);
      final state = stateWithSelection(d, posInCell(d, 1, 0));
      final next = run(state, setRowHeightCommand('48px'));
      final t = next.doc.child(0);
      expect(t.child(0).attrs['height'], isNull);
      expect(t.child(1).attrs['height'], '48px');
      expect(t.child(1).attrs['heightRule'], 'atLeast');
    });

    test('refreshGridAttrs mantém columnIndex após inserir coluna', () {
      final withIndex = doc([
        table([
          row(
            [
              schema.nodes['tableCell']!.create(
                  {'columnIndex': 0}, Fragment.from(p('a'))),
              schema.nodes['tableCell']!.create(
                  {'columnIndex': 1}, Fragment.from(p('b'))),
            ],
            {'columnWidths': [100, 100]},
          ),
        ])
      ]);
      final state = stateWithSelection(withIndex, posInCell(withIndex, 0, 0));
      final next = run(state, addColumnCommand(before: false));
      final t = next.doc.child(0);
      final r = t.child(0);
      expect(r.childCount, 3);
      expect(r.child(0).attrs['columnIndex'], 0);
      expect(r.child(1).attrs['columnIndex'], 1);
      expect(r.child(2).attrs['columnIndex'], 2);
      expect((r.attrs['columnWidths'] as List).length, 3);
    });
  });

  group('deleteTable', () {
    test('remove a tabela em volta do cursor', () {
      final d = doc([
        p('antes'),
        table([
          row([cell('a')]),
        ]),
        p('depois'),
      ]);
      final map = TableMap.of(d.child(1));
      final anchor = d.child(0).nodeSize + 1 + map.map[0] + 2;
      final state = stateWithSelection(d, anchor);
      final next = run(state, deleteTableCommand());
      expect(next.doc.childCount, 2);
      expect(next.doc.child(0).textContent, 'antes');
      expect(next.doc.child(1).textContent, 'depois');
    });
  });
}
