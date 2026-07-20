@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';

const allExtensions = [
  DocumentExtension(),
  ParagraphExtension(),
  TextExtension(),
  BoldExtension(),
  HeadingExtension(),
  TextAlignExtension(),
  TableExtension(),
  TableRowExtension(),
  TableCellExtension(),
  TableHeaderExtension(),
  TableResizingExtension(),
  TableOfContentsExtension(),
  HistoryExtension(),
];

TiptapEditor buildEditor(web.HTMLElement element) => TiptapEditor(
    EditorOptions(extensions: allExtensions, element: element));

web.HTMLElement mount() {
  final host = web.document.createElement('div') as web.HTMLElement;
  host.className = 'tiptap-ui';
  web.document.body!.appendChild(host);
  return host;
}

/// Posição de texto dentro da célula (linha, coluna) da primeira tabela.
int cellTextPos(TiptapEditor editor, int row, int col) {
  int? tablePos;
  editor.state.doc.descendants((node, pos, parent, index) {
    if (node.type.name == 'table' && tablePos == null) {
      tablePos = pos;
      return false;
    }
    return true;
  });
  expect(tablePos, isNotNull, reason: 'documento deveria conter uma tabela');
  final table = editor.state.doc.nodeAt(tablePos!)!;
  var rowStart = tablePos! + 1;
  for (var r = 0; r < row; r++) {
    rowStart += table.child(r).nodeSize;
  }
  var cellStart = rowStart + 1;
  final rowNode = table.child(row);
  for (var c = 0; c < col; c++) {
    cellStart += rowNode.child(c).nodeSize;
  }
  return cellStart + 2;
}

void selectText(TiptapEditor editor, int anchor, [int? head]) {
  final tr = editor.state.tr;
  tr.setSelection(
      TextSelection.create(editor.state.doc, anchor, head ?? anchor));
  editor.view!.dispatch(tr);
}

void main() {
  test('inserir tabela, adicionar/remover linhas e colunas no DOM real', () {
    final host = mount();
    final editor = buildEditor(host);
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    expect(editor.chain.insertTable(rows: 2, cols: 2, withHeaderRow: false).run(),
        isTrue);
    selectText(editor, cellTextPos(editor, 0, 0));
    expect(editor.chain.addRowAfter().run(), isTrue);
    expect(editor.chain.addColumnAfter().run(), isTrue);

    var rows = host.querySelectorAll('.ProseMirror tr');
    expect(rows.length, 3);
    var firstRowCells =
        (rows.item(0) as web.Element).querySelectorAll('td, th');
    expect(firstRowCells.length, 3);

    selectText(editor, cellTextPos(editor, 1, 1));
    expect(editor.chain.deleteRow().run(), isTrue);
    expect(editor.chain.deleteColumn().run(), isTrue);
    rows = host.querySelectorAll('.ProseMirror tr');
    expect(rows.length, 2);
    firstRowCells = (rows.item(0) as web.Element).querySelectorAll('td, th');
    expect(firstRowCells.length, 2);
  });

  test('mesclar e dividir células reflete colspan/rowspan no DOM', () {
    final host = mount();
    final editor = buildEditor(host);
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    editor.chain.insertTable(rows: 2, cols: 3, withHeaderRow: false).run();
    selectText(
        editor, cellTextPos(editor, 0, 0), cellTextPos(editor, 1, 1));
    expect(editor.chain.mergeCells().run(), isTrue);

    var merged = host.querySelector('.ProseMirror td[colspan="2"]');
    expect(merged, isNotNull);
    expect(merged!.getAttribute('rowspan'), '2');

    selectText(editor, cellTextPos(editor, 0, 0));
    expect(editor.chain.splitCell().run(), isTrue);
    merged = host.querySelector('.ProseMirror td[colspan="2"]');
    expect(merged, isNull);
    final cells = host.querySelectorAll('.ProseMirror td');
    expect(cells.length, 6);
  });

  test('sombreamento e bordas viram estilos inline nas células', () {
    final host = mount();
    final editor = buildEditor(host);
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    editor.chain.insertTable(rows: 2, cols: 2, withHeaderRow: false).run();
    selectText(
        editor, cellTextPos(editor, 0, 0), cellTextPos(editor, 1, 1));
    expect(editor.chain.setCellBackground('#ffcc00').run(), isTrue);
    expect(
        editor.chain.setCellBorders('outer', '2px solid #ff0000').run(),
        isTrue);

    final cells = host.querySelectorAll('.ProseMirror td');
    expect(cells.length, 4);
    for (var i = 0; i < cells.length; i++) {
      final cell = cells.item(i) as web.HTMLElement;
      expect(cell.style.backgroundColor, isNotEmpty,
          reason: 'célula $i deveria ter sombreamento');
    }
    final first = cells.item(0) as web.HTMLElement;
    expect(first.style.borderTop, contains('2px'));
    expect(first.style.borderLeft, contains('2px'));
    expect(first.style.borderBottom, isEmpty);
  });

  test('setColumnWidths escreve grid tracks nas linhas', () {
    final host = mount();
    final editor = buildEditor(host);
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    editor.chain.insertTable(rows: 2, cols: 2, withHeaderRow: false).run();
    selectText(editor, cellTextPos(editor, 0, 0));
    expect(editor.chain.setColumnWidths([150, 250]).run(), isTrue);

    final rows = host.querySelectorAll('.ProseMirror tr');
    for (var i = 0; i < rows.length; i++) {
      final row = rows.item(i) as web.HTMLElement;
      expect(row.getAttribute('data-column-widths'), '150,250');
    }
  });

  test('sumário automático coleta títulos e atualiza', () {
    final host = mount();
    final editor = buildEditor(host);
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    // Documento com um título e um parágrafo vazio no fim.
    editor.chain.setHeading(1).run();
    editor.view!.dispatch(editor.state.tr.insertText('Objeto'));
    final paragraph = editor.state.schema.nodes['paragraph']!.create();
    final insertTr = editor.state.tr;
    insertTr.insert(editor.state.doc.content.size, paragraph);
    editor.view!.dispatch(insertTr);
    selectText(editor, editor.state.doc.content.size - 1);

    expect(
        editor.chain
            .command(insertTableOfContentsCommand(contentWidth: 400))
            .run(),
        isTrue);
    final toc = host.querySelector('.ProseMirror div[data-docx-toc]');
    expect(toc, isNotNull);
    expect(toc!.textContent, contains('Sumário'));
    expect(toc.textContent, contains('Objeto'));

    // O sumário substituiu o parágrafo vazio final; o título permanece.
    expect(editor.state.doc.child(0).type.name, 'heading');
    expect(
        editor.chain.command(updateTableOfContentsCommand()).run(), isTrue);
    expect(host.querySelectorAll('.ProseMirror div[data-docx-toc]').length, 1);
  });
}
