/// Table editing commands, ported from prosemirror-tables and adapted to this
/// package's schema (`table` > `tableRow` > `tableCell | tableHeader`).
///
/// Positions handed to the [TableMap] are relative to the table start. All
/// commands locate the table around the current text selection, so they work
/// with the native contenteditable selection without a dedicated
/// CellSelection class: a selection spanning several cells produces the
/// rectangle between the anchor cell and the head cell.
library;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';
import 'table_map.dart';

/// Everything a table command needs to know about the table around the
/// current selection.
class TableSelectionContext {
  /// The table node (from the current doc).
  final PMNode table;

  /// Absolute position of the table node itself.
  final int tablePos;

  /// Absolute position right after the table's opening token.
  int get tableStart => tablePos + 1;

  final TableMap map;

  /// Table-relative position of the cell containing the selection anchor.
  final int anchorCell;

  /// Table-relative position of the cell containing the selection head.
  final int headCell;

  TableSelectionContext({
    required this.table,
    required this.tablePos,
    required this.map,
    required this.anchorCell,
    required this.headCell,
  });

  /// Rectangle spanned by the selection.
  TableRect get rect => map.rectBetween(anchorCell, headCell);
}

/// Table-relative position of the innermost cell around [pos], or null.
int? _cellAround(ResolvedPos pos, int tableDepth) {
  for (var d = pos.depth; d > tableDepth; d--) {
    final name = pos.node(d).type.name;
    if (name == 'tableCell' || name == 'tableHeader') {
      return pos.before(d) - pos.before(tableDepth) - 1;
    }
  }
  return null;
}

/// Depth of the innermost table around [pos], or -1.
int _tableDepth(ResolvedPos pos) {
  for (var d = pos.depth; d > 0; d--) {
    if (pos.node(d).type.name == 'table') return d;
  }
  return -1;
}

/// Resolves the table context for [state]'s selection, or null when the
/// selection is not inside a single table.
TableSelectionContext? findTableContext(EditorState state) {
  final sel = state.selection;
  final anchorDepth = _tableDepth(sel.anchorRes);
  final headDepth = _tableDepth(sel.headRes);
  if (anchorDepth < 0 || headDepth < 0) return null;
  if (sel.anchorRes.before(anchorDepth) != sel.headRes.before(headDepth)) {
    return null;
  }
  final tablePos = sel.anchorRes.before(anchorDepth);
  final table = sel.anchorRes.node(anchorDepth);
  final anchorCell = _cellAround(sel.anchorRes, anchorDepth);
  final headCell = _cellAround(sel.headRes, headDepth);
  if (anchorCell == null || headCell == null) return null;
  return TableSelectionContext(
    table: table,
    tablePos: tablePos,
    map: TableMap.of(table),
    anchorCell: anchorCell,
    headCell: headCell,
  );
}

/// Whether the selection currently sits inside a table.
bool isInTable(EditorState state) => findTableContext(state) != null;

// --------------------------------------------------------------- colwidth

List<int>? _colwidthOf(PMNode cell) {
  final value = cell.attrs['colwidth'];
  if (value is! List) return null;
  final widths = value.whereType<num>().map((w) => w.round()).toList();
  return widths.isEmpty ? null : widths;
}

Map<String, dynamic> _addColSpan(PMNode cell, int at, [int n = 1]) {
  final attrs = Map<String, dynamic>.from(cell.attrs);
  attrs['colspan'] = cellColspan(cell) + n;
  final colwidth = _colwidthOf(cell);
  if (colwidth != null) {
    final widths = List<int>.from(colwidth);
    for (var i = 0; i < n; i++) {
      widths.insert(at, 0);
    }
    attrs['colwidth'] = widths;
  }
  return attrs;
}

Map<String, dynamic> _removeColSpan(PMNode cell, int at, [int n = 1]) {
  final attrs = Map<String, dynamic>.from(cell.attrs);
  attrs['colspan'] = cellColspan(cell) - n;
  final colwidth = _colwidthOf(cell);
  if (colwidth != null) {
    final widths = List<int>.from(colwidth)..removeRange(at, at + n);
    attrs['colwidth'] = widths.isEmpty ? null : widths;
  }
  return attrs;
}

// ------------------------------------------------- grid attrs maintenance

/// Recomputes `columnIndex` on every cell and prunes/extends per-row
/// `columnWidths` after a structural change. Imported DOCX tables rely on
/// these attributes to render rows as CSS grid tracks; newly inserted editor
/// tables (all-null attributes) are left untouched.
void _refreshGridAttrs(Transaction tr, int tablePos) {
  final table = tr.doc.nodeAt(tablePos);
  if (table == null || table.type.name != 'table') return;
  final map = TableMap.of(table);
  final tableStart = tablePos + 1;

  var usesColumnIndex = false;
  var usesRowWidths = false;
  for (var r = 0; r < table.childCount && !(usesColumnIndex && usesRowWidths);
      r++) {
    final row = table.child(r);
    if (row.attrs['columnWidths'] is List) usesRowWidths = true;
    for (var c = 0; c < row.childCount; c++) {
      if (row.child(c).attrs['columnIndex'] is int) {
        usesColumnIndex = true;
        break;
      }
    }
  }
  if (!usesColumnIndex && !usesRowWidths) return;

  final tableWidths = table.attrs['columnWidths'];
  List<int>? tracks;
  if (tableWidths is List) {
    tracks = tableWidths.whereType<num>().map((w) => w.round()).toList();
  }
  if (tracks != null && tracks.length != map.width) {
    tracks = _fitTrackList(tracks, map.width);
    tr.setNodeMarkup(
      tablePos,
      null,
      Map<String, dynamic>.from(table.attrs)..['columnWidths'] = tracks,
    );
  }

  // Collect updates first: setNodeMarkup keeps node sizes stable, so the
  // original positions remain valid while we apply them.
  var rowPos = tableStart;
  for (var r = 0; r < table.childCount; r++) {
    final row = table.child(r);
    if (usesRowWidths) {
      final rowWidths = row.attrs['columnWidths'];
      List<int>? current;
      if (rowWidths is List) {
        current = rowWidths.whereType<num>().map((w) => w.round()).toList();
      }
      final target = tracks ?? current;
      if (target != null && (current == null || current.length != map.width)) {
        tr.setNodeMarkup(
          rowPos,
          null,
          Map<String, dynamic>.from(row.attrs)
            ..['columnWidths'] = _fitTrackList(target, map.width),
        );
      }
    }
    if (usesColumnIndex) {
      var cellPos = rowPos + 1;
      for (var c = 0; c < row.childCount; c++) {
        final cell = row.child(c);
        final relative = cellPos - tableStart;
        int? col;
        try {
          col = map.colCount(relative);
        } catch (_) {
          col = null;
        }
        if (col != null && cell.attrs['columnIndex'] != col) {
          tr.setNodeMarkup(
            cellPos,
            null,
            Map<String, dynamic>.from(cell.attrs)..['columnIndex'] = col,
          );
        }
        cellPos += cell.nodeSize;
      }
    }
    rowPos += row.nodeSize;
  }
}

/// Places the selection inside the cell nearest to grid slot ([row], [col])
/// of the table at [tablePos] in [tr]'s current doc. Keeps commands chainable
/// after structural deletions, which would otherwise leave the mapped
/// selection between nodes.
void _selectCellAt(Transaction tr, int tablePos, int row, int col) {
  final table = tr.doc.nodeAt(tablePos);
  if (table == null || table.type.name != 'table') return;
  final map = TableMap.of(table);
  if (map.width == 0 || map.height == 0) return;
  final r = row.clamp(0, map.height - 1);
  final c = col.clamp(0, map.width - 1);
  final cellPos = map.map[r * map.width + c];
  final inside = tablePos + 1 + cellPos + 1;
  if (inside < 0 || inside > tr.doc.content.size) return;
  tr.setSelection(Selection.near(tr.doc.resolve(inside)));
}

List<int> _fitTrackList(List<int> tracks, int width) {
  if (tracks.length == width) return tracks;
  final result = List<int>.from(tracks);
  if (result.length > width) {
    result.removeRange(width, result.length);
  } else {
    final fill = result.isEmpty ? 100 : result.last;
    while (result.length < width) {
      result.add(fill);
    }
  }
  return result;
}

// ------------------------------------------------------------ add column

Command addColumnCommand({required bool before}) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final rect = ctx.rect;
    final col = before ? rect.left : rect.right;
    final tr = state.tr;
    _addColumn(tr, ctx, col);
    _refreshGridAttrs(tr, tr.mapping.map(ctx.tablePos, -1));
    dispatch(tr.scrollIntoView());
    return true;
  };
}

void _addColumn(Transaction tr, TableSelectionContext ctx, int col) {
  final map = ctx.map;
  final table = ctx.table;
  final cellType = tr.doc.type.schema.nodes['tableCell']!;

  // Collect operations against the original document, then apply them from
  // the bottom up so earlier positions stay valid without a mapping slice.
  final bumps = <int>[]; // table-relative cell positions to grow colspan
  final inserts = <(int, NodeType)>[]; // absolute insert positions
  for (var row = 0; row < map.height; row++) {
    final index = row * map.width + col;
    // A spanning cell crosses the insertion column: widen it instead.
    if (col > 0 && col < map.width && map.map[index - 1] == map.map[index]) {
      final pos = map.map[index];
      final cell = table.nodeAt(pos)!;
      if (!bumps.contains(pos)) bumps.add(pos);
      row += cellRowspan(cell) - 1;
    } else {
      NodeType type = cellType;
      final refIndex = index + (col > 0 ? -1 : 0);
      if (refIndex >= 0 && refIndex < map.map.length) {
        final refCell = table.nodeAt(map.map[refIndex]);
        if (refCell != null && refCell.type.name == 'tableHeader') {
          type = tr.doc.type.schema.nodes['tableHeader'] ?? cellType;
        }
      }
      inserts.add((ctx.tableStart + map.positionAt(row, col, table), type));
    }
  }
  inserts.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (pos, type) in inserts) {
    final cell = type.createAndFill();
    if (cell != null) tr.insert(pos, cell);
  }
  for (final pos in bumps) {
    final cell = table.nodeAt(pos)!;
    tr.setNodeMarkup(
      tr.mapping.map(ctx.tableStart + pos, -1),
      null,
      _addColSpan(cell, col - map.colCount(pos)),
    );
  }
}

// --------------------------------------------------------- delete column

Command deleteColumnCommand() {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    final rect = ctx.rect;
    if (rect.width >= ctx.map.width) return deleteTableCommand()(
        state, dispatch, view);
    if (dispatch == null) return true;
    final tr = state.tr;
    // Remove from the rightmost selected column to the leftmost so grid
    // coordinates from the original map stay valid per removal step.
    for (var col = rect.right - 1; col >= rect.left; col--) {
      final table = tr.doc.nodeAt(tr.mapping.map(ctx.tablePos, -1));
      if (table == null || table.type.name != 'table') break;
      _removeColumn(tr, table, tr.mapping.map(ctx.tablePos, -1), col);
    }
    final tablePos = tr.mapping.map(ctx.tablePos, -1);
    _refreshGridAttrs(tr, tablePos);
    _selectCellAt(tr, tablePos, rect.top, rect.left);
    dispatch(tr.scrollIntoView());
    return true;
  };
}

void _removeColumn(Transaction tr, PMNode table, int tablePos, int col) {
  final map = TableMap.of(table);
  final tableStart = tablePos + 1;
  final shrinks = <int>[]; // table-relative positions of cells to narrow
  final deletes = <(int, int)>[]; // absolute (from, to)
  for (var row = 0; row < map.height;) {
    final index = row * map.width + col;
    final pos = map.map[index];
    final cell = table.nodeAt(pos)!;
    if ((col > 0 && map.map[index - 1] == pos) ||
        (col < map.width - 1 && map.map[index + 1] == pos)) {
      if (!shrinks.contains(pos)) shrinks.add(pos);
    } else {
      deletes.add((tableStart + pos, tableStart + pos + cell.nodeSize));
    }
    row += cellRowspan(cell);
  }
  for (final pos in shrinks) {
    final cell = table.nodeAt(pos)!;
    tr.setNodeMarkup(
      tableStart + pos,
      null,
      _removeColSpan(cell, col - map.colCount(pos)),
    );
  }
  deletes.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (from, to) in deletes) {
    tr.delete(from, to);
  }
}

// --------------------------------------------------------------- add row

Command addRowCommand({required bool before}) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final rect = ctx.rect;
    final row = before ? rect.top : rect.bottom;
    final tr = state.tr;
    _addRow(tr, ctx, row);
    _refreshGridAttrs(tr, tr.mapping.map(ctx.tablePos, -1));
    dispatch(tr.scrollIntoView());
    return true;
  };
}

void _addRow(Transaction tr, TableSelectionContext ctx, int row) {
  final map = ctx.map;
  final table = ctx.table;
  final schema = tr.doc.type.schema;
  final rowType = schema.nodes['tableRow']!;
  final cellType = schema.nodes['tableCell']!;

  var rowPos = ctx.tableStart;
  for (var i = 0; i < row; i++) {
    rowPos += table.child(i).nodeSize;
  }
  final cells = <PMNode>[];
  final bumps = <int>[];
  for (var col = 0, index = map.width * row; col < map.width; col++, index++) {
    // Slot covered by a rowspan cell from above: grow it downward instead.
    if (row > 0 && row < map.height && map.map[index] == map.map[index - map.width]) {
      final pos = map.map[index];
      final cell = table.nodeAt(pos)!;
      if (!bumps.contains(pos)) bumps.add(pos);
      col += cellColspan(cell) - 1;
      index += cellColspan(cell) - 1;
    } else {
      NodeType type = cellType;
      final refRow = row > 0 ? row - 1 : (row < map.height ? row : -1);
      if (refRow >= 0 && refRow < map.height) {
        final refCell = table.nodeAt(map.map[refRow * map.width + col]);
        if (refCell != null &&
            refCell.type.name == 'tableHeader' &&
            row == 0) {
          type = schema.nodes['tableHeader'] ?? cellType;
        }
      }
      final cell = type.createAndFill();
      if (cell != null) cells.add(cell);
    }
  }
  // Grow spanning cells first (size-neutral), then insert the new row.
  for (final pos in bumps) {
    final cell = table.nodeAt(pos)!;
    tr.setNodeMarkup(
      ctx.tableStart + pos,
      null,
      Map<String, dynamic>.from(cell.attrs)
        ..['rowspan'] = cellRowspan(cell) + 1,
    );
  }
  final template = row > 0
      ? table.child(row - 1)
      : (table.childCount > 0 ? table.child(0) : null);
  final rowAttrs = template == null
      ? null
      : (Map<String, dynamic>.from(template.attrs)
        ..['isHeader'] = false
        ..['height'] = null
        ..['heightRule'] = null);
  tr.insert(rowPos, rowType.create(rowAttrs, Fragment.fromArray(cells)));
}

// ------------------------------------------------------------ delete row

Command deleteRowCommand() {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    final rect = ctx.rect;
    if (rect.height >= ctx.map.height) {
      return deleteTableCommand()(state, dispatch, view);
    }
    if (dispatch == null) return true;
    final tr = state.tr;
    for (var row = rect.bottom - 1; row >= rect.top; row--) {
      final tablePos = tr.mapping.map(ctx.tablePos, -1);
      final table = tr.doc.nodeAt(tablePos);
      if (table == null || table.type.name != 'table') break;
      _removeRow(tr, table, tablePos, row);
    }
    final tablePos = tr.mapping.map(ctx.tablePos, -1);
    _refreshGridAttrs(tr, tablePos);
    _selectCellAt(tr, tablePos, rect.top, rect.left);
    dispatch(tr.scrollIntoView());
    return true;
  };
}

void _removeRow(Transaction tr, PMNode table, int tablePos, int row) {
  final map = TableMap.of(table);
  final tableStart = tablePos + 1;
  var rowPos = 0;
  for (var i = 0; i < row; i++) {
    rowPos += table.child(i).nodeSize;
  }
  final nextRowPos = rowPos + table.child(row).nodeSize;

  final seen = <int>{};
  // Phase 1 (size-neutral): shrink cells that span from above into this row.
  for (var col = 0, index = row * map.width; col < map.width; col++, index++) {
    final pos = map.map[index];
    if (seen.contains(pos)) continue;
    if (row > 0 && pos == map.map[index - map.width]) {
      seen.add(pos);
      final cell = table.nodeAt(pos)!;
      tr.setNodeMarkup(
        tableStart + pos,
        null,
        Map<String, dynamic>.from(cell.attrs)
          ..['rowspan'] = cellRowspan(cell) - 1,
      );
      col += cellColspan(cell) - 1;
      index += cellColspan(cell) - 1;
    }
  }
  // Phase 2: re-anchor cells that start in this row but span below, moving a
  // shortened copy into the next row. Insert bottom-up (higher positions
  // first) so unmapped positions stay valid.
  final moves = <(int, PMNode)>[];
  seen.clear();
  for (var col = 0, index = row * map.width; col < map.width; col++, index++) {
    final pos = map.map[index];
    if (seen.contains(pos)) continue;
    seen.add(pos);
    if (pos >= rowPos && row < map.height - 1 && pos == map.map[index + map.width]) {
      final cell = table.nodeAt(pos)!;
      final copy = cell.type.create(
        Map<String, dynamic>.from(cell.attrs)
          ..['rowspan'] = cellRowspan(cell) - 1,
        cell.content,
      );
      moves.add((tableStart + map.positionAt(row + 1, col, table), copy));
      col += cellColspan(cell) - 1;
      index += cellColspan(cell) - 1;
    }
  }
  moves.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (pos, node) in moves) {
    tr.insert(pos, node);
  }
  // Phase 3: delete the row itself (positions unaffected by later inserts).
  tr.delete(tableStart + rowPos, tableStart + nextRowPos);
}

// ---------------------------------------------------------- delete table

Command deleteTableCommand() {
  return (state, [dispatch, view]) {
    final sel = state.selection;
    final depth = _tableDepth(sel.anchorRes);
    if (depth < 0) return false;
    if (dispatch == null) return true;
    final from = sel.anchorRes.before(depth);
    final to = sel.anchorRes.after(depth);
    final tr = state.tr;
    tr.delete(from, to);
    dispatch(tr.scrollIntoView());
    return true;
  };
}

// ----------------------------------------------------------- merge/split

Command mergeCellsCommand() {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null || ctx.anchorCell == ctx.headCell) return false;
    final rect = ctx.rect;
    if (!ctx.map.isRectClean(rect)) return false;
    final cells = ctx.map.cellsInRect(rect);
    if (cells.length < 2) return false;
    if (dispatch == null) return true;

    final table = ctx.table;
    final first = cells.first;
    final firstCell = table.nodeAt(first)!;
    var content = Fragment.empty;
    for (final pos in cells) {
      final cell = table.nodeAt(pos)!;
      if (!_isCellEmpty(cell)) {
        content = content.append(cell.content);
      }
    }
    if (content.size == 0) content = firstCell.content;

    final attrs = Map<String, dynamic>.from(firstCell.attrs)
      ..['colspan'] = rect.width
      ..['rowspan'] = rect.height
      ..['colwidth'] = null;
    final merged = firstCell.type.create(attrs, content);

    final tr = state.tr;
    final deletes = cells.skip(1).map((pos) {
      final cell = table.nodeAt(pos)!;
      return (ctx.tableStart + pos, ctx.tableStart + pos + cell.nodeSize);
    }).toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (from, to) in deletes) {
      tr.delete(from, to);
    }
    tr.replaceWith(
      ctx.tableStart + first,
      ctx.tableStart + first + firstCell.nodeSize,
      merged,
    );
    _refreshGridAttrs(tr, tr.mapping.map(ctx.tablePos, -1));
    final cursor = tr.doc.resolve(tr.mapping.map(ctx.tableStart + first) + 1);
    tr.setSelection(Selection.near(cursor));
    dispatch(tr.scrollIntoView());
    return true;
  };
}

bool _isCellEmpty(PMNode cell) {
  if (cell.childCount != 1) return false;
  final child = cell.child(0);
  return child.type.name == 'paragraph' && child.childCount == 0;
}

Command splitCellCommand() {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    final cellPos = ctx.anchorCell;
    final cell = ctx.table.nodeAt(cellPos)!;
    final colspan = cellColspan(cell), rowspan = cellRowspan(cell);
    if (colspan == 1 && rowspan == 1) return false;
    if (dispatch == null) return true;

    final rect = ctx.map.findCell(cellPos);
    final attrs = Map<String, dynamic>.from(cell.attrs)
      ..['colspan'] = 1
      ..['rowspan'] = 1
      ..['colwidth'] = null;

    final tr = state.tr;
    // Insertion points per row, computed on the original table; applied from
    // the bottom row up so earlier positions stay valid.
    final inserts = <(int, int)>[]; // (absolute pos, cell count)
    for (var row = rect.top; row < rect.bottom; row++) {
      var pos = ctx.map.positionAt(row, rect.left, ctx.table);
      var count = rect.width;
      if (row == rect.top) {
        pos = cellPos + cell.nodeSize;
        count -= 1;
      }
      if (count > 0) inserts.add((ctx.tableStart + pos, count));
    }
    inserts.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (pos, count) in inserts) {
      for (var i = 0; i < count; i++) {
        final fresh = cell.type.createAndFill(attrs);
        if (fresh != null) tr.insert(pos, fresh);
      }
    }
    tr.setNodeMarkup(ctx.tableStart + cellPos, null, attrs);
    _refreshGridAttrs(tr, tr.mapping.map(ctx.tablePos, -1));
    dispatch(tr.scrollIntoView());
    return true;
  };
}

// ------------------------------------------------------- cell attributes

/// Applies [attrs] (merged over existing) to every cell in the selection
/// rectangle.
Command setCellAttrsCommand(Map<String, dynamic> attrs) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final tr = state.tr;
    for (final pos in ctx.map.cellsInRect(ctx.rect)) {
      final cell = ctx.table.nodeAt(pos)!;
      tr.setNodeMarkup(
        ctx.tableStart + pos,
        null,
        Map<String, dynamic>.from(cell.attrs)..addAll(attrs),
      );
    }
    dispatch(tr);
    return true;
  };
}

/// Sets border shorthand values (`1px solid #000`-style CSS strings) on the
/// selected cells. [sides] chooses which of the four sides to touch:
/// 'all' | 'outer' | 'inner' | 'none' | 'top' | 'bottom' | 'left' | 'right'.
Command setCellBordersCommand(String sides, String? css) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final rect = ctx.rect;
    final tr = state.tr;
    for (final pos in ctx.map.cellsInRect(rect)) {
      final cell = ctx.table.nodeAt(pos)!;
      final cellRect = ctx.map.findCell(pos);
      final attrs = Map<String, dynamic>.from(cell.attrs);
      void apply(String attr, bool touch) {
        if (touch) attrs[attr] = css;
      }

      switch (sides) {
        case 'all':
        case 'none':
          apply('borderTop', true);
          apply('borderRight', true);
          apply('borderBottom', true);
          apply('borderLeft', true);
        case 'outer':
          apply('borderTop', cellRect.top == rect.top);
          apply('borderBottom', cellRect.bottom == rect.bottom);
          apply('borderLeft', cellRect.left == rect.left);
          apply('borderRight', cellRect.right == rect.right);
        case 'inner':
          apply('borderTop', cellRect.top != rect.top);
          apply('borderBottom', cellRect.bottom != rect.bottom);
          apply('borderLeft', cellRect.left != rect.left);
          apply('borderRight', cellRect.right != rect.right);
        case 'top':
          apply('borderTop', cellRect.top == rect.top);
        case 'bottom':
          apply('borderBottom', cellRect.bottom == rect.bottom);
        case 'left':
          apply('borderLeft', cellRect.left == rect.left);
        case 'right':
          apply('borderRight', cellRect.right == rect.right);
        default:
          return false;
      }
      tr.setNodeMarkup(ctx.tableStart + pos, null, attrs);
    }
    dispatch(tr);
    return true;
  };
}

/// Toggles the first row between header and normal cells.
Command toggleHeaderRowCommand() {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null || ctx.table.childCount == 0) return false;
    if (dispatch == null) return true;
    final schema = state.schema;
    final headerType = schema.nodes['tableHeader'];
    final cellType = schema.nodes['tableCell'];
    if (headerType == null || cellType == null) return false;
    final firstRow = ctx.table.child(0);
    final makeHeader = firstRow.childCount > 0 &&
        firstRow.child(0).type.name != 'tableHeader';
    final tr = state.tr;
    var cellPos = ctx.tableStart + 1;
    for (var c = 0; c < firstRow.childCount; c++) {
      final cell = firstRow.child(c);
      tr.setNodeMarkup(cellPos, makeHeader ? headerType : cellType, cell.attrs);
      cellPos += cell.nodeSize;
    }
    tr.setNodeMarkup(
      ctx.tableStart,
      null,
      Map<String, dynamic>.from(firstRow.attrs)..['isHeader'] = makeHeader,
    );
    dispatch(tr);
    return true;
  };
}

/// Sets a row height (CSS length, e.g. '32px') on all rows intersecting the
/// selection; null clears it.
Command setRowHeightCommand(String? height, {String rule = 'atLeast'}) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final rect = ctx.rect;
    final tr = state.tr;
    var rowPos = ctx.tableStart;
    for (var r = 0; r < ctx.table.childCount; r++) {
      final row = ctx.table.child(r);
      if (r >= rect.top && r < rect.bottom) {
        tr.setNodeMarkup(
          rowPos,
          null,
          Map<String, dynamic>.from(row.attrs)
            ..['height'] = height
            ..['heightRule'] = height == null ? null : rule,
        );
      }
      rowPos += row.nodeSize;
    }
    dispatch(tr);
    return true;
  };
}

/// Sets table-level attributes (alignment, width, …) on the table around the
/// selection.
Command setTableAttrsCommand(Map<String, dynamic> attrs) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final tr = state.tr;
    tr.setNodeMarkup(
      ctx.tablePos,
      null,
      Map<String, dynamic>.from(ctx.table.attrs)..addAll(attrs),
    );
    dispatch(tr);
    return true;
  };
}

/// Writes an explicit per-column width list to the table and all of its
/// rows. Used by the interactive resizer. [widths] must have one entry per
/// grid column, in CSS pixels.
Command setColumnWidthsCommand(List<int> widths) {
  return (state, [dispatch, view]) {
    final ctx = findTableContext(state);
    if (ctx == null) return false;
    if (dispatch == null) return true;
    final tr = state.tr;
    applyColumnWidths(tr, ctx.tablePos, widths);
    dispatch(tr);
    return true;
  };
}

/// Applies [widths] to the table node at [tablePos] and each of its rows.
/// Also drops stale per-cell `width` styles so the grid tracks win.
void applyColumnWidths(Transaction tr, int tablePos, List<int> widths) {
  final table = tr.doc.nodeAt(tablePos);
  if (table == null || table.type.name != 'table') return;
  final map = TableMap.of(table);
  final fitted = _fitTrackList(widths, map.width);
  final tableStart = tablePos + 1;
  tr.setNodeMarkup(
    tablePos,
    null,
    Map<String, dynamic>.from(table.attrs)..['columnWidths'] = fitted,
  );
  var rowPos = tableStart;
  for (var r = 0; r < table.childCount; r++) {
    final row = table.child(r);
    tr.setNodeMarkup(
      rowPos,
      null,
      Map<String, dynamic>.from(row.attrs)..['columnWidths'] = fitted,
    );
    var cellPos = rowPos + 1;
    for (var c = 0; c < row.childCount; c++) {
      final cell = row.child(c);
      if (cell.attrs['width'] != null || cell.attrs['columnIndex'] == null) {
        int? col;
        try {
          col = map.colCount(cellPos - tableStart);
        } catch (_) {
          col = null;
        }
        tr.setNodeMarkup(
          cellPos,
          null,
          Map<String, dynamic>.from(cell.attrs)
            ..['width'] = null
            ..['columnIndex'] = col,
        );
      }
      cellPos += cell.nodeSize;
    }
    rowPos += row.nodeSize;
  }
}
