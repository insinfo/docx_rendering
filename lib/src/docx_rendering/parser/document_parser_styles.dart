part of '../document_parser.dart';

List<IDomStyle> _parseStylesFile(DocumentParser self, dynamic xstyles) {
  final result = <IDomStyle>[];

  for (final n in globalXmlParser.elements(xstyles)) {
    switch (globalXmlParser.localName(n)) {
      case 'style':
        result.add(self.parseStyle(n));
        break;
      case 'docDefaults':
        result.add(self.parseDefaultStyles(n));
        break;
    }
  }

  return result;
}

IDomStyle _parseDefaultStyles(DocumentParser self, dynamic node) {
  final result = IDomStyle()
    ..id = 'default'
    ..name = 'default'
    ..styles = [];

  for (final c in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(c)) {
      case 'rPrDefault':
        final rPr = globalXmlParser.element(c, 'rPr');
        if (rPr != null) {
          result.styles.add(IDomSubStyle()
            ..target = 'span'
            ..values = self.parseDefaultProperties(rPr, {}));
        }
        break;
      case 'pPrDefault':
        final pPr = globalXmlParser.element(c, 'pPr');
        if (pPr != null) {
          result.styles.add(IDomSubStyle()
            ..target = 'p'
            ..values = self.parseDefaultProperties(pPr, {}));
        }
        break;
    }
  }

  return result;
}

IDomStyle _parseStyle(DocumentParser self, dynamic node) {
  final result = IDomStyle()
    ..id = globalXmlParser.attr(node, 'styleId')
    ..isDefault = globalXmlParser.boolAttr(node, 'default')
    ..styles = [];

  switch (globalXmlParser.attr(node, 'type')) {
    case 'paragraph':
      result.target = 'p';
      break;
    case 'table':
      result.target = 'table';
      break;
    case 'character':
      result.target = 'span';
      break;
  }

  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'basedOn':
        result.basedOn = globalXmlParser.attr(n, 'val');
        break;
      case 'name':
        result.name = globalXmlParser.attr(n, 'val');
        break;
      case 'link':
        result.linked = globalXmlParser.attr(n, 'val');
        break;
      case 'next':
        result.next = globalXmlParser.attr(n, 'val');
        break;
      case 'aliases':
        final val = globalXmlParser.attr(n, 'val');
        if (val != null) {
          result.aliases = val.split(',');
        }
        break;
      case 'pPr':
        result.styles.add(IDomSubStyle()
          ..target = 'p'
          ..values = self.parseDefaultProperties(n, {}));
        result.paragraphProps = parseParagraphProperties(n, globalXmlParser);
        break;
      case 'rPr':
        result.styles.add(IDomSubStyle()
          ..target = 'span'
          ..values = self.parseDefaultProperties(n, {}));
        result.runProps = parseRunProperties(n, globalXmlParser);
        break;
      case 'tblPr':
      case 'tcPr':
        result.styles.add(IDomSubStyle()
          ..target = 'td'
          ..values = self.parseDefaultProperties(n, {}));
        break;
      case 'tblStylePr':
        result.styles.addAll(self.parseTableStyle(n));
        break;
    }
  }

  return result;
}

List<IDomSubStyle> _parseTableStyle(DocumentParser self, dynamic node) {
  final result = <IDomSubStyle>[];
  final type = globalXmlParser.attr(node, 'type');
  String selector = '';
  String modificator = '';

  switch (type) {
    case 'firstRow':
      modificator = '.first-row';
      selector = 'tr.first-row td';
      break;
    case 'lastRow':
      modificator = '.last-row';
      selector = 'tr.last-row td';
      break;
    case 'firstCol':
      modificator = '.first-col';
      selector = 'td.first-col';
      break;
    case 'lastCol':
      modificator = '.last-col';
      selector = 'td.last-col';
      break;
    case 'band1Vert':
      modificator = ':not(.no-vband)';
      selector = 'td.odd-col';
      break;
    case 'band2Vert':
      modificator = ':not(.no-vband)';
      selector = 'td.even-col';
      break;
    case 'band1Horz':
      modificator = ':not(.no-hband)';
      selector = 'tr.odd-row';
      break;
    case 'band2Horz':
      modificator = ':not(.no-hband)';
      selector = 'tr.even-row';
      break;
    default:
      return [];
  }

  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'pPr':
        result.add(IDomSubStyle()
          ..target = '$selector p'
          ..mod = modificator
          ..values = self.parseDefaultProperties(n, {}));
        break;
      case 'rPr':
        result.add(IDomSubStyle()
          ..target = '$selector span'
          ..mod = modificator
          ..values = self.parseDefaultProperties(n, {}));
        break;
      case 'tblPr':
      case 'tcPr':
        result.add(IDomSubStyle()
          ..target = selector
          ..mod = modificator
          ..values = self.parseDefaultProperties(n, {}));
        break;
    }
  }

  return result;
}
