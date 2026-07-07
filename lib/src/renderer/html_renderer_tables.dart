part of '../html_renderer.dart';

void _processTable(HtmlRenderer self, WmlTable table) {
  for (final r in table.children ?? []) {
    for (final c in r.children ?? []) {
      c.cssStyle = _copyStyleProperties(self, table.cellStyle ?? {}, c.cssStyle ?? {}, [
        'border-left', 'border-right', 'border-top', 'border-bottom',
        'padding-left', 'padding-right', 'padding-top', 'padding-bottom'
      ]);

      self.processElement(c);
    }
  }
}

web.Node _renderTable(HtmlRenderer self, WmlTable table) {
  self.tableCellPositions.add(self.currentCellPosition ?? CellPos(0, 0));
  self.tableVerticalMerges.add(self.currentVerticalMerge ?? {});
  self.currentVerticalMerge = {};
  self.currentCellPosition = CellPos(0, 0);

  final children = <web.Node>[];

  if (table.columns != null) {
    children.add(_renderTableColumns(self, table.columns!));
  }

  children.addAll(_renderElements(self, table.children ?? []));

  self.currentVerticalMerge = self.tableVerticalMerges.removeLast();
  self.currentCellPosition = self.tableCellPositions.removeLast();

  return _toHTML(self, table, HtmlNs.html, 'table', children);
}

web.Node _renderTableColumns(HtmlRenderer self, List<WmlTableColumn> columns) {
  final children = columns.map((x) => self.hFunc({
    'tagName': 'col',
    'style': {'width': x.width ?? ''}
  })).toList();

  return self.hFunc({
    'tagName': 'colgroup',
    'children': children
  }) as web.Node;
}

web.Node _renderTableRow(HtmlRenderer self, WmlTableRow row) {
  self.currentCellPosition!.col = 0;

  final children = <web.Node>[];

  if (row.gridBefore != null) {
    children.add(self.hFunc({
      'tagName': 'td',
      'colSpan': '${row.gridBefore}',
      'style': {'border': 'none'}
    }) as web.Node);
  }

  children.addAll(_renderElements(self, row.children ?? []));

  if (row.gridAfter != null) {
    children.add(self.hFunc({
      'tagName': 'td',
      'colSpan': '${row.gridAfter}',
      'style': {'border': 'none'}
    }) as web.Node);
  }

  self.currentCellPosition!.row++;

  return _toHTML(self, row, HtmlNs.html, 'tr', children);
}

web.Node _renderTableCell(HtmlRenderer self, WmlTableCell cell) {
  final result = _toHTML(self, cell, HtmlNs.html, 'td') as web.HTMLTableCellElement;

  final key = self.currentCellPosition!.col;

  if (cell.verticalMerge != null) {
    if (cell.verticalMerge == 'restart') {
      self.currentVerticalMerge![key] = result;
      result.rowSpan = 1;
    } else if (self.currentVerticalMerge!.containsKey(key)) {
      self.currentVerticalMerge![key]!.rowSpan += 1;
      result.style.display = 'none';
    }
  } else {
    self.currentVerticalMerge![key] = null;
  }

  if (cell.span != null) {
    result.colSpan = cell.span!;
  }

  self.currentCellPosition!.col += result.colSpan;

  return result;
}
