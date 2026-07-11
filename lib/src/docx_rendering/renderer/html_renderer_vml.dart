part of '../html_renderer.dart';



web.Node _renderVmlPicture(HtmlRenderer self, OpenXmlElement elem) {
  return _renderContainer(self, elem, 'div');
}

web.Node _renderVmlElement(HtmlRenderer self, VmlElement elem) {
  final Map<String, dynamic> containerProps = {
    'ns': HtmlNs.svg,
    'tagName': 'svg',
  };
  if (elem.cssStyleText != null) {
    // Browsers ignore VML `mso-*` positioning hints, so a raw VML style string
    // leaves floating shapes/textboxes mispositioned. Translate it to real CSS.
    final style = _translateVmlStyle(elem.cssStyleText!);
    if (elem.borderCss != null) {
      style['border'] = elem.borderCss!;
      _applyTextBoxInset(style);
    }
    containerProps['style'] = style;
  } else if (elem.borderCss != null) {
    containerProps['style'] = {'border': elem.borderCss!, 'padding': _boxPad};
  }
  
  final container = self.hFunc(containerProps) as web.SVGElement;
  final result = _renderVmlChildElement(self, elem);

  if (elem.imageHref?.id != null) {
    self.tasks.add(self.document.loadDocumentImage(elem.imageHref!.id!, self.currentPart).then((url) {
      if (url != null) {
        result.setAttribute('href', url);
      }
    }));
  }

  container.appendChild(result);

  web.window.requestAnimationFrame((double time) {
    final first = container.firstElementChild;
    if (first != null) {
      try {
        final dynamic bboxable = first;
        final bbox = bboxable.getBBox();
        final x = bbox.x as double;
        final width = bbox.width as double;
        final y = bbox.y as double;
        final height = bbox.height as double;
        container.setAttribute('width', '${(x + width).ceil()}');
        container.setAttribute('height', '${(y + height).ceil()}');
      } catch (e) {
        // ignore if getBBox is not available (e.g. headless tests)
      }
    }
  }.toJS);

  return container;
}

web.SVGElement _renderVmlChildElement(HtmlRenderer self, VmlElement elem) {
  final tagName = elem.tagName ?? 'g';
  final result = _createSvgElement(self, tagName);
  
  elem.attrs.forEach((k, v) {
    result.setAttribute(k, v);
  });

  for (final child in elem.children ?? <OpenXmlElement>[]) {
    if (child.type == DomType.vmlElement) {
      result.appendChild(_renderVmlChildElement(self, child as VmlElement));
    } else {
      final rendered = self.renderElement(child);
      if (rendered != null) {
        result.appendChild(rendered);
      }
    }
  }

  return result;
}

/// Translates a raw VML shape `style` string into browser-usable CSS.
///
/// VML positions floating shapes with `mso-position-horizontal/vertical`
/// (+ `-relative`) keywords that browsers ignore, so the raw string leaves the
/// shape mispositioned (e.g. a top-right process box overlapping the header).
/// This parses the declarations, drops the VML-only noise (`mso-*`, `v-*`,
/// `*-percent`) and turns the keyword alignments into real CSS offsets. The
/// offsets anchor to the nearest positioned ancestor — the header/footer is
/// made `position: relative` (see `_renderDefaultStyle`) so `right:0` aligns to
/// the content area (between margins), matching Word.
// Word's default text-box internal margin (inset): ~0.05in vertical (3.6pt).
const String _boxPad = '3.6pt 7.2pt';

/// Insets the text from a text-box border so it doesn't touch it (like Word).
///
/// Only *vertical* padding is applied. Padding on the `<svg>` sits between the
/// border and the `<foreignObject>` viewport, so the viewport keeps its authored
/// height (no clipping of the last line) and the box just grows downward a
/// little. Horizontal padding is intentionally skipped: the box is right-anchored
/// and our text renders a touch wider than Word's, so growing the width would
/// overlap the header, while shrinking the viewport would wrap a line and clip
/// the last one. Vertical-only is the safe inset that never loses content.
void _applyTextBoxInset(Map<String, String> style) {
  style['padding'] = '3.6pt 0';
}

Map<String, String> _translateVmlStyle(String raw) {
  final map = <String, String>{};
  for (final decl in raw.split(';')) {
    final i = decl.indexOf(':');
    if (i < 0) continue;
    final key = decl.substring(0, i).trim().toLowerCase();
    final value = decl.substring(i + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    map[key] = value;
  }

  final hPos = map['mso-position-horizontal'];
  final vPos = map['mso-position-vertical'];

  // Drop declarations the browser can't render.
  map.removeWhere((k, _) =>
      k.startsWith('mso-') || k.startsWith('v-') || k.endsWith('-percent'));

  // A shape carrying mso-position hints is a floating object.
  if (hPos != null || vPos != null) {
    map['position'] = 'absolute';
  }

  switch (hPos) {
    case 'right':
    case 'outside':
      map['right'] = '0';
      map.remove('left');
      map.remove('margin-left');
      break;
    case 'left':
    case 'inside':
      map['left'] = '0';
      map.remove('right');
      map.remove('margin-left');
      break;
    case 'center':
      map['left'] = '0';
      map['right'] = '0';
      map['margin-left'] = 'auto';
      map['margin-right'] = 'auto';
      break;
    // 'absolute' / null: keep margin-left as the horizontal offset.
  }

  switch (vPos) {
    case 'top':
    case 'inside':
      map['top'] = '0';
      map.remove('margin-top');
      break;
    case 'bottom':
    case 'outside':
      map['bottom'] = '0';
      map.remove('margin-top');
      break;
    case 'center':
      map['top'] = '0';
      map['bottom'] = '0';
      map['margin-top'] = 'auto';
      map['margin-bottom'] = 'auto';
      break;
    // 'absolute' / null: keep margin-top as the vertical offset.
  }

  return map;
}

web.SVGElement _createSvgElement(HtmlRenderer self, String tagName, [Map<String, dynamic>? props, List<dynamic>? children]) {
  final Map<String, dynamic> elementMap = {
    'ns': HtmlNs.svg,
    'tagName': tagName,
  };
  if (children != null) {
    elementMap['children'] = children;
  }
  if (props != null) {
    elementMap.addAll(props);
  }
  return self.hFunc(elementMap) as web.SVGElement;
}
