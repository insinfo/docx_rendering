part of '../document_parser.dart';

/// Parses a <drawing> element — finds inline/anchor children.
OpenXmlElement? _parseDrawingWrapper(DocumentParser self, dynamic node) {
  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'inline':
      case 'anchor':
        return _parseDrawingInlineOrAnchor(self, n);
    }
  }

  // Fallback to VML element parsing if it's not a graphic (e.g., <w:pict>)
  for (final n in globalXmlParser.elements(node)) {
    final vml = parseVmlElement(n, self);
    if (vml != null) return vml;
  }

  return null;
}

/// Parses an inline or anchor drawing wrapper, creating a Drawing container
/// element with CSS positioning/wrapping.
OpenXmlElement? _parseDrawingInlineOrAnchor(DocumentParser self, dynamic node) {
  final result = OpenXmlElementBase(type: DomType.drawing)..cssStyle = {};
  final isAnchor = globalXmlParser.localName(node) == 'anchor';

  String? wrapType;
  String? frameWidth;
  String? frameHeight;
  IDomImage? picture;
  final simplePos = globalXmlParser.boolAttr(node, 'simplePos') ?? false;

  final posX = <String, String>{
    'relative': 'page',
    'align': 'left',
    'offset': '0'
  };
  final posY = <String, String>{
    'relative': 'page',
    'align': 'top',
    'offset': '0'
  };

  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'simplePos':
        if (simplePos) {
          posX['offset'] =
              globalXmlParser.lengthAttr(n, 'x', LengthUsage.emu) ?? '0';
          posY['offset'] =
              globalXmlParser.lengthAttr(n, 'y', LengthUsage.emu) ?? '0';
        }
        break;

      case 'extent':
        frameWidth = globalXmlParser.lengthAttr(n, 'cx', LengthUsage.emu) ?? '';
        frameHeight =
            globalXmlParser.lengthAttr(n, 'cy', LengthUsage.emu) ?? '';
        result.cssStyle!['width'] = frameWidth;
        result.cssStyle!['height'] = frameHeight;
        break;

      case 'positionH':
      case 'positionV':
        if (!simplePos) {
          final pos = globalXmlParser.localName(n) == 'positionH' ? posX : posY;
          final alignNode = globalXmlParser.element(n, 'align');
          final offsetNode = globalXmlParser.element(n, 'posOffset');

          final relFrom = globalXmlParser.attr(n, 'relativeFrom');
          if (relFrom != null) pos['relative'] = relFrom;

          if (alignNode != null) {
            pos['align'] =
                globalXmlParser.textContent(alignNode) ?? pos['align']!;
          }

          if (offsetNode != null) {
            pos['offset'] = convertLength(
                    globalXmlParser.textContent(offsetNode), LengthUsage.emu) ??
                '0';
          }
        }
        break;

      case 'wrapTopAndBottom':
        wrapType = 'wrapTopAndBottom';
        break;

      case 'wrapNone':
        wrapType = 'wrapNone';
        break;

      case 'graphic':
        final g = _parseGraphic(self, n);
        if (g != null) {
          result.children!.add(g);
          if (g is IDomImage) picture = g;
        }
        break;
    }
  }

  // wp:extent is the size Word uses for layout. pic:spPr/a:xfrm may carry
  // the bitmap's pre-crop or historical transform size and is frequently a
  // few percent different. The old parser exposed that inner size to the
  // importer, making header logos visibly wider than Word.
  if (picture != null) {
    if (frameWidth != null && frameWidth.isNotEmpty) {
      picture.cssStyle!['width'] = frameWidth;
    }
    if (frameHeight != null && frameHeight.isNotEmpty) {
      picture.cssStyle!['height'] = frameHeight;
    }
  }

  if (wrapType == 'wrapTopAndBottom') {
    result.cssStyle!['display'] = 'block';

    if (posX['align'] != null && posX['align']!.isNotEmpty) {
      result.cssStyle!['text-align'] = posX['align']!;
      result.cssStyle!['width'] = '100%';
    }
  } else if (wrapType == 'wrapNone') {
    result.cssStyle!['display'] = 'block';
    result.cssStyle!['position'] = 'relative';
    result.cssStyle!['width'] = '0px';
    result.cssStyle!['height'] = '0px';

    if (posX['offset'] != null && posX['offset'] != '0') {
      result.cssStyle!['left'] = posX['offset']!;
    }
    if (posY['offset'] != null && posY['offset'] != '0') {
      result.cssStyle!['top'] = posY['offset']!;
    }
  } else if (isAnchor &&
      (posX['align'] == 'left' || posX['align'] == 'right')) {
    result.cssStyle!['float'] = posX['align']!;
  }

  return result;
}

/// Parses a <graphic> element.
OpenXmlElement? _parseGraphic(DocumentParser self, dynamic elem) {
  final graphicData = globalXmlParser.element(elem, 'graphicData');
  if (graphicData == null) return null;

  for (final n in globalXmlParser.elements(graphicData)) {
    switch (globalXmlParser.localName(n)) {
      case 'pic':
        return _parsePicture(self, n);
    }
  }

  return null;
}

/// Parses a <pic:pic> element into an IDomImage.
IDomImage? _parsePicture(DocumentParser self, dynamic elem) {
  final blipFill = globalXmlParser.element(elem, 'blipFill');
  final blip =
      blipFill != null ? globalXmlParser.element(blipFill, 'blip') : null;
  final srcRect =
      blipFill != null ? globalXmlParser.element(blipFill, 'srcRect') : null;

  final result = IDomImage(
    blip != null ? (globalXmlParser.attr(blip, 'embed') ?? '') : '',
  )..cssStyle = {'position': 'relative'};

  if (srcRect != null) {
    result.srcRect = [
      (globalXmlParser.intAttr(srcRect, 'l', 0) ?? 0) / 100000,
      (globalXmlParser.intAttr(srcRect, 't', 0) ?? 0) / 100000,
      (globalXmlParser.intAttr(srcRect, 'r', 0) ?? 0) / 100000,
      (globalXmlParser.intAttr(srcRect, 'b', 0) ?? 0) / 100000,
    ];
  }

  final spPr = globalXmlParser.element(elem, 'spPr');
  final xfrm = spPr != null ? globalXmlParser.element(spPr, 'xfrm') : null;

  if (xfrm != null) {
    result.rotation = (globalXmlParser.intAttr(xfrm, 'rot', 0) ?? 0) / 60000;

    for (final n in globalXmlParser.elements(xfrm)) {
      switch (globalXmlParser.localName(n)) {
        case 'ext':
          result.cssStyle!['width'] =
              globalXmlParser.lengthAttr(n, 'cx', LengthUsage.emu) ?? '';
          result.cssStyle!['height'] =
              globalXmlParser.lengthAttr(n, 'cy', LengthUsage.emu) ?? '';
          break;
        case 'off':
          result.cssStyle!['left'] =
              globalXmlParser.lengthAttr(n, 'x', LengthUsage.emu) ?? '';
          result.cssStyle!['top'] =
              globalXmlParser.lengthAttr(n, 'y', LengthUsage.emu) ?? '';
          break;
      }
    }
  }

  return result;
}

/// Parses a <drawing> element for use from parseRun (finds inline/anchor within).
IDomImage? _parseDrawing(DocumentParser self, dynamic node) {
  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'graphicData':
        for (final pic in globalXmlParser.elements(n)) {
          if (globalXmlParser.localName(pic) == 'pic') {
            return _parsePicture(self, pic);
          }
        }
        break;
    }
  }
  return null;
}

OpenXmlElement _parseVmlPicture(DocumentParser self, dynamic elem) {
  final result = OpenXmlElementBase(type: DomType.vmlPicture)..children = [];

  for (final el in globalXmlParser.elements(elem)) {
    final child = parseVmlElement(el, self);
    if (child != null) result.children!.add(child);
  }

  return result;
}
