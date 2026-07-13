part of '../document_parser.dart';

WmlTable _parseTable(DocumentParser self, dynamic node) {
  final result = WmlTable()..children = [];

  for (final el in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(el)) {
      case 'tr':
        result.children!.add(self.parseTableRow(el));
        break;
      case 'tblGrid':
        self.parseTableColumns(el, result);
        break;
      case 'tblPr':
        // Pass a cellStyle map so table-level borders land on every cell.
        self.parseDefaultProperties(
            el, result.cssStyle = {}, result.cellStyle = {});
        result.styleName = globalXmlParser.elementAttr(el, 'tblStyle', 'val');
        break;
    }
  }

  return result;
}

void _parseTableColumns(DocumentParser self, dynamic node, WmlTable table) {
  table.columns = [];

  for (final el in globalXmlParser.elements(node)) {
    if (globalXmlParser.localName(el) == 'gridCol') {
      table.columns!.add(WmlTableColumn(
          width: globalXmlParser.lengthAttr(el, 'w', LengthUsage.dxa)));
    }
  }
}

WmlTableRow _parseTableRow(DocumentParser self, dynamic node) {
  final result = WmlTableRow()..children = [];

  for (final el in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(el)) {
      case 'tc':
        result.children!.add(self.parseTableCell(el));
        break;
      case 'trPr':
        self.parseDefaultProperties(el, result.cssStyle = {});
        result.isHeader = globalXmlParser.element(el, 'tblHeader') != null;
        final rowHeight = globalXmlParser.element(el, 'trHeight');
        if (rowHeight != null) {
          result.height = globalXmlParser.lengthAttr(
            rowHeight,
            'val',
            LengthUsage.dxa,
          );
          final rule = globalXmlParser.attr(rowHeight, 'hRule');
          // ECMA-376 defines an omitted hRule as atLeast. Keeping the rule
          // explicit lets the editor distinguish it from exact clipping.
          result.heightRule = rule == 'exact' ? 'exact' : 'atLeast';
        }
        break;
    }
  }

  return result;
}

WmlTableCell _parseTableCell(DocumentParser self, dynamic node) {
  final result = WmlTableCell()..children = [];

  for (final el in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(el)) {
      case 'tbl':
        result.children!.add(self.parseTable(el));
        break;
      case 'p':
        result.children!.add(self.parseParagraph(el));
        break;
      case 'tcPr':
        self.parseDefaultProperties(el, result.cssStyle = {});
        final span = globalXmlParser.elementAttr(el, 'gridSpan', 'val');
        if (span != null) {
          result.span = int.tryParse(span) ?? 1;
        }

        final vMerge = globalXmlParser.element(el, 'vMerge');
        if (vMerge != null) {
          final val = globalXmlParser.attr(vMerge, 'val');
          result.verticalMerge = val ?? 'continue';
        }

        final tcW = globalXmlParser.element(el, 'tcW');
        if (tcW != null && !self.options.ignoreWidth) {
          final w = _valueOfWidth(tcW);
          if (w != null) result.cssStyle!['width'] = w;
        }
        break;
    }
  }

  return result;
}
