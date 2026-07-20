/// Port of prosemirror-tables' `TableMap` adapted to this package's schema
/// (`table` > `tableRow` > `tableCell | tableHeader`).
///
/// The map describes the rectangular grid formed by a table, resolving
/// `colspan`/`rowspan` so commands can reason about columns and rows without
/// re-walking the node tree. All positions are relative to the table start
/// (the position right after the table's opening token).
library;

import '../../prosemirror/model/index.dart';

/// A rectangle of grid coordinates inside a table. `right`/`bottom` are
/// exclusive, matching prosemirror-tables.
class TableRect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const TableRect(this.left, this.top, this.right, this.bottom);

  int get width => right - left;
  int get height => bottom - top;

  @override
  String toString() => 'TableRect($left,$top,$right,$bottom)';
}

int cellColspan(PMNode cell) {
  final value = cell.attrs['colspan'];
  return value is int && value > 0 ? value : 1;
}

int cellRowspan(PMNode cell) {
  final value = cell.attrs['rowspan'];
  return value is int && value > 0 ? value : 1;
}

class TableMap {
  /// Number of grid columns.
  final int width;

  /// Number of grid rows.
  final int height;

  /// `width * height` entries; each entry is the table-relative position of
  /// the cell covering that grid slot.
  final List<int> map;

  const TableMap(this.width, this.height, this.map);

  static final Expando<TableMap> _cache = Expando<TableMap>();

  /// Computes (and caches per node instance) the map for [table].
  static TableMap of(PMNode table) {
    final cached = _cache[table];
    if (cached != null) return cached;
    final computed = _compute(table);
    _cache[table] = computed;
    return computed;
  }

  /// Grid rectangle covered by the cell at table-relative position [pos].
  TableRect findCell(int pos) {
    for (var i = 0; i < map.length; i++) {
      if (map[i] != pos) continue;
      final left = i % width, top = i ~/ width;
      var right = left + 1, bottom = top + 1;
      while (right < width && map[top * width + right] == pos) {
        right++;
      }
      while (bottom < height && map[bottom * width + left] == pos) {
        bottom++;
      }
      return TableRect(left, top, right, bottom);
    }
    throw ArgumentError('No cell with offset $pos found');
  }

  /// Leftmost grid column covered by the cell at [pos].
  int colCount(int pos) {
    for (var i = 0; i < map.length; i++) {
      if (map[i] == pos) return i % width;
    }
    throw ArgumentError('No cell with offset $pos found');
  }

  /// Position of the next cell when moving from the cell at [pos] along
  /// [axis] ('horiz' | 'vert') in direction [dir] (-1 | 1), or null at the
  /// table edge.
  int? nextCell(int pos, String axis, int dir) {
    final rect = findCell(pos);
    if (axis == 'horiz') {
      final col = dir < 0 ? rect.left - 1 : rect.right;
      if (col < 0 || col >= width) return null;
      return map[rect.top * width + col];
    }
    final row = dir < 0 ? rect.top - 1 : rect.bottom;
    if (row < 0 || row >= height) return null;
    return map[row * width + rect.left];
  }

  /// The smallest rectangle covering both cells [a] and [b].
  TableRect rectBetween(int a, int b) {
    final rectA = findCell(a), rectB = findCell(b);
    return TableRect(
      rectA.left < rectB.left ? rectA.left : rectB.left,
      rectA.top < rectB.top ? rectA.top : rectB.top,
      rectA.right > rectB.right ? rectA.right : rectB.right,
      rectA.bottom > rectB.bottom ? rectA.bottom : rectB.bottom,
    );
  }

  /// Positions of all distinct cells whose top-left slot falls in [rect].
  List<int> cellsInRect(TableRect rect) {
    final result = <int>[];
    final seen = <int>{};
    for (var row = rect.top; row < rect.bottom; row++) {
      for (var col = rect.left; col < rect.right; col++) {
        final index = row * width + col;
        final pos = map[index];
        if (seen.contains(pos)) continue;
        seen.add(pos);
        // Skip cells that stick out past the rect's left/top edge: they are
        // anchored outside the rectangle.
        if ((col == rect.left && col > 0 && map[index - 1] == pos) ||
            (row == rect.top && row > 0 && map[index - width] == pos)) {
          continue;
        }
        result.add(pos);
      }
    }
    return result;
  }

  /// Whether every cell overlapping [rect] fits entirely inside it (the
  /// precondition for merging).
  bool isRectClean(TableRect rect) {
    for (var row = rect.top; row < rect.bottom; row++) {
      for (var col = rect.left; col < rect.right; col++) {
        final cellRect = findCell(map[row * width + col]);
        if (cellRect.left < rect.left ||
            cellRect.right > rect.right ||
            cellRect.top < rect.top ||
            cellRect.bottom > rect.bottom) {
          return false;
        }
      }
    }
    return true;
  }

  /// Table-relative position of the cell covering grid slot ([row], [col]) in
  /// [table]; when the slot belongs to a spanning cell whose anchor is above,
  /// returns the position where a new cell at that slot would be inserted.
  int positionAt(int row, int col, PMNode table) {
    for (var i = 0, rowStart = 0;; i++) {
      final rowEnd = rowStart + table.child(i).nodeSize;
      if (i == row) {
        var index = col + row * width;
        final rowEndIndex = (row + 1) * width;
        // Skip slots covered by cells from earlier rows.
        while (index < rowEndIndex && map[index] < rowStart) {
          index++;
        }
        return index == rowEndIndex ? rowEnd - 1 : map[index];
      }
      rowStart = rowEnd;
    }
  }

  static TableMap _compute(PMNode table) {
    final width = _findWidth(table);
    final height = table.childCount;
    final map = List<int>.filled(width * height, 0);
    var mapPos = 0;
    var pos = 0;
    for (var row = 0; row < height; row++) {
      final rowNode = table.child(row);
      pos++;
      for (var i = 0;; i++) {
        while (mapPos < map.length && map[mapPos] != 0) {
          mapPos++;
        }
        if (i == rowNode.childCount) break;
        final cellNode = rowNode.child(i);
        final colspan = cellColspan(cellNode);
        final rowspan = cellRowspan(cellNode);
        for (var h = 0; h < rowspan; h++) {
          if (h + row >= height) break;
          final start = mapPos + h * width;
          for (var w = 0; w < colspan; w++) {
            final index = start + w;
            if (index < map.length && map[index] == 0) {
              map[index] = pos;
            }
          }
        }
        mapPos += colspan;
        pos += cellNode.nodeSize;
      }
      final expectedPos = (row + 1) * width;
      while (mapPos < expectedPos) {
        mapPos++;
      }
      pos++;
    }
    return TableMap(width, height, map);
  }

  static int _findWidth(PMNode table) {
    var width = -1;
    var hasRowSpan = false;
    for (var row = 0; row < table.childCount; row++) {
      final rowNode = table.child(row);
      var rowWidth = 0;
      if (hasRowSpan) {
        for (var j = 0; j < row; j++) {
          final prevRow = table.child(j);
          for (var i = 0; i < prevRow.childCount; i++) {
            final cell = prevRow.child(i);
            if (j + cellRowspan(cell) > row) rowWidth += cellColspan(cell);
          }
        }
      }
      for (var i = 0; i < rowNode.childCount; i++) {
        final cell = rowNode.child(i);
        rowWidth += cellColspan(cell);
        if (cellRowspan(cell) > 1) hasRowSpan = true;
      }
      if (width == -1) {
        width = rowWidth;
      } else if (width != rowWidth) {
        width = width > rowWidth ? width : rowWidth;
      }
    }
    return width < 0 ? 0 : width;
  }
}
