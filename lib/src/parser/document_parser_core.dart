part of '../document_parser.dart';

List<T> _parseNotes<T extends WmlBaseNote>(
    DocumentParser self, dynamic xmlDoc, String elemName, T Function() factory) {
  final result = <T>[];

  for (final el in globalXmlParser.elements(xmlDoc, elemName)) {
    final node = factory();
    node.id = globalXmlParser.attr(el, 'id');
    node.noteType = globalXmlParser.attr(el, 'type');
    node.children = self.parseBodyElements(el);
    result.add(node);
  }

  return result;
}

List<WmlComment> _parseComments(DocumentParser self, dynamic xmlDoc) {
  final result = <WmlComment>[];

  for (final el in globalXmlParser.elements(xmlDoc, 'comment')) {
    final item = WmlComment();
    item.id = globalXmlParser.attr(el, 'id');
    item.author = globalXmlParser.attr(el, 'author');
    item.initials = globalXmlParser.attr(el, 'initials');
    item.date = globalXmlParser.attr(el, 'date');
    item.children = self.parseBodyElements(el);
    result.add(item);
  }

  return result;
}

DocumentElement _parseDocumentFile(DocumentParser self, dynamic xmlDoc) {
  final xbody = globalXmlParser.element(xmlDoc, 'body');
  final background = globalXmlParser.element(xmlDoc, 'background');
  final sectPr = xbody != null ? globalXmlParser.element(xbody, 'sectPr') : null;

  return DocumentElement()
    ..type = DomType.document
    ..children = xbody != null ? self.parseBodyElements(xbody) : []
    ..sectionProps = sectPr != null ? parseSectionProperties(sectPr, globalXmlParser) : SectionProperties()
    ..cssStyle = background != null ? self.parseBackground(background) : {};
}

Map<String, String> _parseBackground(DocumentParser self, dynamic elem) {
  final result = <String, String>{};
  final color = globalXmlParser.colorAttr(elem, 'color');

  if (color != null) {
    result['background-color'] = color;
  }

  return result;
}

List<OpenXmlElement> _parseBodyElements(DocumentParser self, dynamic element) {
  final children = <OpenXmlElement>[];

  for (final elem in globalXmlParser.elements(element)) {
    switch (globalXmlParser.localName(elem)) {
      case 'p':
        children.add(self.parseParagraph(elem));
        break;
      case 'altChunk':
        children.add(self.parseAltChunk(elem));
        break;
      case 'tbl':
        children.add(self.parseTable(elem));
        break;
      case 'sdt':
        children.addAll(self.parseSdt(elem, (e) => self.parseBodyElements(e)));
        break;
    }
  }

  return children;
}

Map<String, String> _parseDefaultProperties(
    DocumentParser self, dynamic node, Map<String, String>? style,
    [List<OpenXmlElement>? childs, bool Function(dynamic)? handler]) {
  style ??= {};

  for (final c in globalXmlParser.elements(node)) {
    if (handler != null && handler(c)) {
      continue;
    }

    switch (globalXmlParser.localName(c)) {
      case 'jc':
        final val = globalXmlParser.attr(c, 'val');
        if (val == 'both') {
          style['text-align'] = 'justify';
        } else if (val != null) {
          style['text-align'] = val;
        }
        break;
      case 'color':
        final color = globalXmlParser.colorAttr(c, 'val');
        if (color != null) {
          style['color'] = color == 'auto' ? 'black' : color;
        }
        break;
      case 'sz':
        final sz = globalXmlParser.lengthAttr(c, 'val', LengthUsage.fontSize);
        if (sz != null) style['font-size'] = sz;
        break;
      case 'shd':
        final shd = globalXmlParser.colorAttr(c, 'fill');
        if (shd != null) {
          style['background-color'] = shd == 'auto' ? 'transparent' : shd;
        }
        break;
      case 'highlight':
        final highlight = globalXmlParser.colorAttr(c, 'val');
        if (highlight != null) {
          style['background-color'] = highlight == 'auto' ? 'transparent' : highlight;
        }
        break;
      case 'tcW':
        if (self.options.ignoreWidth) break;
        final w = globalXmlParser.lengthAttr(c, 'w', LengthUsage.dxa);
        if (w != null) style['width'] = w;
        break;
      case 'ind':
      case 'tblInd':
        final start = globalXmlParser.lengthAttr(c, 'start', LengthUsage.dxa) ?? globalXmlParser.lengthAttr(c, 'left', LengthUsage.dxa);
        final end = globalXmlParser.lengthAttr(c, 'end', LengthUsage.dxa) ?? globalXmlParser.lengthAttr(c, 'right', LengthUsage.dxa);
        final firstLine = globalXmlParser.lengthAttr(c, 'firstLine', LengthUsage.dxa);
        final hanging = globalXmlParser.lengthAttr(c, 'hanging', LengthUsage.dxa);

        if (start != null) style['margin-left'] = start;
        if (end != null) style['margin-right'] = end;

        if (firstLine != null) {
          style['text-indent'] = firstLine;
        } else if (hanging != null) {
          style['text-indent'] = '-$hanging';
        }
        break;
      case 'rFonts':
        _parseFont(c, style);
        break;
      case 'tblBorders':
      case 'pBdr':
      case 'tcBorders':
        _parseBorderProperties(c, style);
        break;
      case 'tblCellSpacing':
        final spacing = _valueOfMargin(c);
        if (spacing != null) {
          style['border-spacing'] = spacing;
          style['border-collapse'] = 'separate';
        }
        break;
      case 'bdr':
        style['border'] = _valueOfBorder(c);
        break;
      case 'vanish':
        if (globalXmlParser.boolAttr(c, 'val', true) == true) {
          style['display'] = 'none';
        }
        break;
      case 'b':
        style['font-weight'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'bold' : 'normal';
        break;
      case 'i':
        style['font-style'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'italic' : 'normal';
        break;
      case 'caps':
        style['text-transform'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'uppercase' : 'none';
        break;
      case 'smallCaps':
        style['font-variant'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'small-caps' : 'none';
        break;
      case 'strike':
        style['text-decoration'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'line-through' : 'none';
        break;
      case 'dstrike':
        style['text-decoration'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'line-through' : 'none'; // dstrike is double strike, mapped to single
        break;
      case 'u':
        style['text-decoration'] = globalXmlParser.boolAttr(c, 'val', true) == true ? 'underline' : 'none';
        break;
      case 'vertAlign':
        final va = globalXmlParser.attr(c, 'val');
        if (va == 'superscript' || va == 'subscript') {
          style['vertical-align'] = va == 'superscript' ? 'super' : 'sub';
          style['font-size'] = 'smaller';
        }
        break;
      case 'spacing':
        final p = globalXmlParser.parent(c);
        if (p != null && globalXmlParser.localName(p) == 'pPr') {
          final before = globalXmlParser.lengthAttr(c, 'before', LengthUsage.dxa);
          final after = globalXmlParser.lengthAttr(c, 'after', LengthUsage.dxa);
          final line = globalXmlParser.attr(c, 'line');
          final lineRule = globalXmlParser.attr(c, 'lineRule');

          if (before != null) style['margin-top'] = before;
          if (after != null) style['margin-bottom'] = after;

          if (line != null) {
            if (lineRule == 'atLeast' || lineRule == 'exact') {
              style['line-height'] = globalXmlParser.lengthAttr(c, 'line', LengthUsage.dxa) ?? 'normal';
            } else if (lineRule == 'auto') {
              final val = double.tryParse(line) ?? 0.0;
              style['line-height'] = '${(val / 240).toStringAsFixed(2)}';
            }
          }
        } else if (p != null && globalXmlParser.localName(p) == 'rPr') {
          final sz = globalXmlParser.lengthAttr(c, 'val', LengthUsage.dxa);
          if (sz != null) style['letter-spacing'] = sz;
        }
        break;
    }
  }

  return style;
}

void _parseFont(dynamic elem, Map<String, String> style) {
  final ascii = globalXmlParser.attr(elem, 'ascii');
  final asciiTheme = _themeValue(elem, 'asciiTheme');
  final hAnsi = globalXmlParser.attr(elem, 'hAnsi');
  final eastAsia = globalXmlParser.attr(elem, 'eastAsia');
  final cs = globalXmlParser.attr(elem, 'cs');

  final fonts = [ascii, asciiTheme, hAnsi, eastAsia, cs].where((x) => x != null && x.isNotEmpty).map((x) => encloseFontFamily(x!)).toSet().join(', ');

  if (fonts.isNotEmpty) {
    style['font-family'] = fonts;
  }
}

String? _themeValue(dynamic c, String attr) {
  final val = globalXmlParser.attr(c, attr);
  return val != null ? 'var(--docx-$val-font)' : null;
}

String? _valueOfMargin(dynamic c) {
  return globalXmlParser.lengthAttr(c, 'w');
}

String _valueOfBorder(dynamic c) {
  final type = globalXmlParser.attr(c, 'val');
  if (type == 'nil') return 'none';
  final color = globalXmlParser.colorAttr(c, 'color') ?? 'black';
  final size = globalXmlParser.lengthAttr(c, 'sz', LengthUsage.border) ?? '1px';
  return '$size solid ${color == 'auto' ? 'black' : color}';
}

void _parseBorderProperties(dynamic node, Map<String, String> style) {
  for (final c in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(c)) {
      case 'start':
      case 'left':
        style['border-left'] = _valueOfBorder(c);
        break;
      case 'end':
      case 'right':
        style['border-right'] = _valueOfBorder(c);
        break;
      case 'top':
        style['border-top'] = _valueOfBorder(c);
        break;
      case 'bottom':
        style['border-bottom'] = _valueOfBorder(c);
        break;
    }
  }
}
