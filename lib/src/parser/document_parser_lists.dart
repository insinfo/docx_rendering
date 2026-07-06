part of '../document_parser.dart';

List<IDomNumbering> _parseNumberingFile(DocumentParser self, dynamic node) {
  final result = <IDomNumbering>[];
  final mapping = <String, String>{};
  final bullets = <NumberingPicBullet>[];

  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'abstractNum':
        result.addAll(self.parseAbstractNumbering(n, bullets));
        break;
      case 'numPicBullet':
        final b = self.parseNumberingPicBullet(n);
        if (b != null) bullets.add(b);
        break;
      case 'num':
        final numId = globalXmlParser.attr(n, 'numId');
        final abstractNumId = globalXmlParser.elementAttr(n, 'abstractNumId', 'val');
        if (numId != null && abstractNumId != null) {
          mapping[abstractNumId] = numId;
        }
        break;
    }
  }

  for (final x in result) {
    if (mapping.containsKey(x.id)) {
      x.id = mapping[x.id] ?? x.id;
    }
  }

  return result;
}

NumberingPicBullet? _parseNumberingPicBullet(
    DocumentParser self, dynamic elem) {
  final pict = globalXmlParser.element(elem, 'pict');
  final shape = pict != null ? globalXmlParser.element(pict, 'shape') : null;
  final imagedata =
      shape != null ? globalXmlParser.element(shape, 'imagedata') : null;

  if (imagedata != null) {
    return NumberingPicBullet(
      id: globalXmlParser.intAttr(elem, 'numPicBulletId') ?? 0,
      src: globalXmlParser.attr(imagedata, 'id') ?? '',
      style: shape != null ? globalXmlParser.attr(shape, 'style') : null,
    );
  }
  return null;
}

List<IDomNumbering> _parseAbstractNumbering(
    DocumentParser self, dynamic node, List<NumberingPicBullet?> bullets) {
  final result = <IDomNumbering>[];
  final id = globalXmlParser.attr(node, 'abstractNumId');

  for (final n in globalXmlParser.elements(node)) {
    if (globalXmlParser.localName(n) == 'lvl') {
      result.add(self.parseNumberingLevel(id, n, bullets));
    }
  }

  return result;
}

IDomNumbering _parseNumberingLevel(DocumentParser self, String? id,
    dynamic node, List<NumberingPicBullet?> bullets) {
  final result = IDomNumbering(
    id: id ?? '',
    level: globalXmlParser.intAttr(node, 'ilvl') ?? 0,
  )
    ..start = 1
    ..pStyle = {}
    ..rStyle = {}
    ..suff = 'tab';

  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'start':
        result.start = globalXmlParser.intAttr(n, 'val') ?? 0;
        break;
      case 'pPr':
        self.parseDefaultProperties(n, result.pStyle);
        break;
      case 'rPr':
        self.parseDefaultProperties(n, result.rStyle);
        break;
      case 'lvlPicBulletId':
        final bulletId = globalXmlParser.intAttr(n, 'val');
        result.bullet = bullets.cast<NumberingPicBullet?>().firstWhere(
            (x) => x?.id == bulletId,
            orElse: () => null);
        break;
      case 'lvlText':
        result.levelText = globalXmlParser.attr(n, 'val');
        break;
      case 'pStyle':
        result.pStyleName = globalXmlParser.attr(n, 'val');
        break;
      case 'numFmt':
        result.format = globalXmlParser.attr(n, 'val');
        break;
      case 'suff':
        result.suff = globalXmlParser.attr(n, 'val') ?? 'tab';
        break;
    }
  }

  return result;
}
