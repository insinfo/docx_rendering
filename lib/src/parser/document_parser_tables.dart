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
        self.parseDefaultProperties(el, result.cssStyle = {});
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
          final w = globalXmlParser.lengthAttr(tcW, 'w', LengthUsage.dxa);
          if (w != null) result.cssStyle!['width'] = w;
        }
        break;
    }
  }

  return result;
}
