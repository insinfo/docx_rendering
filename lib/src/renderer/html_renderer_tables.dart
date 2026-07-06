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
  final children = _renderElements(self, table.children ?? [], self.hFunc({'tagName': 'tbody'}) as web.HTMLElement);
  return self.hFunc({
    'tagName': 'table',
    'className': _processStyleName(self, table.styleName),
    'style': table.cssStyle ?? {},
    'children': [
      if (table.columns != null)
        self.hFunc({
          'tagName': 'colgroup',
          'children': table.columns!.map((c) => self.hFunc({
            'tagName': 'col',
            'style': {'width': c.width ?? ''}
          })).toList()
        }),
      children[0] // tbody
    ]
  }) as web.Node;
}

web.Node _renderTableRow(HtmlRenderer self, WmlTableRow row) {
  self.currentCellPosition = CellPos(0, self.tableCellPositions.length);
  self.tableCellPositions.add(self.currentCellPosition!);

  final children = _renderElements(self, row.children ?? [], self.hFunc({'tagName': 'tr'}) as web.HTMLElement);
  final result = self.hFunc({
    'tagName': 'tr',
    'style': row.cssStyle ?? {},
    'children': children
  }) as web.Node;

  if (row.isHeader == true) {
    // Handling header logic if necessary
  }

  return result;
}

web.Node _renderTableCell(HtmlRenderer self, WmlTableCell cell) {
  final pos = self.currentCellPosition!;
  pos.col++;

  final children = _renderElements(self, cell.children ?? [], self.hFunc({'tagName': 'td'}) as web.HTMLElement);
  final td = self.hFunc({
    'tagName': 'td',
    'style': cell.cssStyle ?? {},
    'children': children
  }) as web.HTMLTableCellElement;

  if (cell.span != null && cell.span! > 1) {
    td.colSpan = cell.span!;
  }

  if (cell.verticalMerge == 'restart') {
    if (self.currentVerticalMerge == null) {
      self.currentVerticalMerge = {};
      self.tableVerticalMerges.add(self.currentVerticalMerge!);
    }
    self.currentVerticalMerge![pos.col] = td;
    td.rowSpan = 1;
  } else if (cell.verticalMerge == 'continue') {
    if (self.currentVerticalMerge != null && self.currentVerticalMerge!.containsKey(pos.col)) {
      self.currentVerticalMerge![pos.col]!.rowSpan++;
      td.style.display = 'none';
    }
  }

  return td;
}
