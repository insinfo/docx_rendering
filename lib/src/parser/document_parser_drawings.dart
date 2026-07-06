part of '../document_parser.dart';

OpenXmlElement? _parseDrawingWrapper(DocumentParser self, dynamic node) {
  for (final n in globalXmlParser.elements(node)) {
    switch (globalXmlParser.localName(n)) {
      case 'simplePos':
      case 'positionH':
      case 'positionV':
      case 'extent':
      case 'effectExtent':
      case 'wrapNone':
      case 'wrapSquare':
      case 'wrapTight':
      case 'wrapThrough':
      case 'wrapTopAndBottom':
        // TODO: implement wrap formatting
        break;
      case 'graphic':
        final g = self.parseDrawing(n);
        if (g != null) return g;
        break;
    }
  }

  // Fallback to VML element parsing if it's not a graphic (e.g., <w:pict>)
  for (final n in globalXmlParser.elements(node)) {
    final vml = parseVmlElement(n, self);
    if (vml != null) return vml;
  }

  return null;
}

IDomImage? _parseDrawing(DocumentParser self, dynamic node) {
  for (final n in globalXmlParser.elements(node)) {
    if (globalXmlParser.localName(n) == 'graphicData') {
      for (final pic in globalXmlParser.elements(n)) {
        if (globalXmlParser.localName(pic) == 'pic') {
          final blipFill = globalXmlParser.element(pic, 'blipFill');
          final blip = blipFill != null ? globalXmlParser.element(blipFill, 'blip') : null;
          final spPr = globalXmlParser.element(pic, 'spPr');
          final xfrm = spPr != null ? globalXmlParser.element(spPr, 'xfrm') : null;
          final ext = xfrm != null ? globalXmlParser.element(xfrm, 'ext') : null;

          if (blip != null) {
            final img = IDomImage(
              globalXmlParser.attr(blip, 'embed') ?? '',
            )
              ..srcRect = _parseRect(globalXmlParser.element(pic, 'srcRect'))
              ..cssStyle = ext != null
                  ? {
                      'width': globalXmlParser.lengthAttr(ext, 'cx', LengthUsage.emu) ?? '',
                      'height': globalXmlParser.lengthAttr(ext, 'cy', LengthUsage.emu) ?? ''
                    }
                  : {};
            return img;
          }
        }
      }
    }
  }

  return null;
}

List<double>? _parseRect(web.Element? elem) {
  if (elem == null) return null;
  // Stub implementation
  return null;
}
