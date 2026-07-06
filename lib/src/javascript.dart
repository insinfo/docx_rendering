/// Ported from docxjs src/javascript.ts

import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'document/paragraph.dart';

class _TabStop {
  double pos;
  String leader;
  String style;

  _TabStop({required this.pos, required this.leader, required this.style});
}

final _defaultTab = _TabStop(pos: 0, leader: 'none', style: 'left');
const _maxTabs = 50;

/// Computes the pixel to point ratio.
double computePixelToPoint([web.HTMLElement? container]) {
  container ??= web.document.body;
  if (container == null) return 72 / 96;

  final temp = web.document.createElement('div') as web.HTMLElement;
  temp.style.width = '100pt';

  container.appendChild(temp);
  final result = 100 / temp.offsetWidth;
  container.removeChild(temp);

  return result;
}

/// Updates tab stop width dynamically.
void updateTabStop(web.HTMLElement elem, List<ParagraphTab>? tabs,
    String? defaultTabSize,
    [double pixelToPoint = 72 / 96]) {
  final p = elem.closest('p');
  if (p == null) return;

  final ebb = elem.getBoundingClientRect();
  final pbb = p.getBoundingClientRect();
  final pcs = web.window.getComputedStyle(p);

  final tabStops = <_TabStop>[];
  if (tabs != null && tabs.isNotEmpty) {
    for (final t in tabs) {
      tabStops.add(_TabStop(
        pos: _lengthToPoint(t.position),
        leader: t.leader ?? 'none',
        style: t.style ?? 'left',
      ));
    }
    tabStops.sort((a, b) => a.pos.compareTo(b.pos));
  } else {
    tabStops.add(_defaultTab);
  }

  final lastTab = tabStops.last;
  final pWidthPt = pbb.width * pixelToPoint;
  final size = _lengthToPoint(defaultTabSize);
  var pos = lastTab.pos + size;

  if (pos < pWidthPt) {
    for (; pos < pWidthPt && tabStops.length < _maxTabs; pos += size) {
      tabStops.add(_TabStop(pos: pos, leader: _defaultTab.leader, style: _defaultTab.style));
    }
  }

  final marginLeft = double.tryParse(pcs.marginLeft.replaceAll(RegExp(r'[a-zA-Z]+$'), '')) ?? 0;
  final pOffset = pbb.left + marginLeft;
  final left = (ebb.left - pOffset) * pixelToPoint;

  _TabStop? tab;
  for (final t in tabStops) {
    if (t.style != 'clear' && t.pos > left) {
      tab = t;
      break;
    }
  }

  if (tab == null) return;

  double width = 1;

  if (tab.style == 'right' || tab.style == 'center') {
    final elements = p.querySelectorAll('.${elem.className}');
    final tabStopsElements = <web.Element>[];
    for (var i = 0; i < elements.length; i++) {
      tabStopsElements.add(elements.item(i) as web.Element);
    }

    final nextIdx = tabStopsElements.indexOf(elem) + 1;
    final range = web.document.createRange();
    range.setStart(elem, 1);

    if (nextIdx < tabStopsElements.length) {
      range.setEndBefore(tabStopsElements[nextIdx]);
    } else {
      range.setEndAfter(p);
    }

    final mul = tab.style == 'center' ? 0.5 : 1;
    final nextBB = range.getBoundingClientRect();
    final offset = nextBB.left + mul * nextBB.width - (pbb.left - marginLeft);

    width = tab.pos - offset * pixelToPoint;
  } else {
    width = tab.pos - left;
  }

  elem.innerHTML = '&nbsp;'.toJS;
  elem.style.textDecoration = 'inherit';
  elem.style.wordSpacing = '${width.toStringAsFixed(0)}pt';

  switch (tab.leader) {
    case 'dot':
    case 'middleDot':
      elem.style.textDecoration = 'underline';
      // Note: textDecorationStyle is not standard in package:web, so we use setProperty
      elem.style.setProperty('text-decoration-style', 'dotted');
      break;
    case 'hyphen':
    case 'heavy':
    case 'underscore':
      elem.style.textDecoration = 'underline';
      break;
  }
}

double _lengthToPoint(String? length) {
  if (length == null) return 0;
  return double.tryParse(length.replaceAll(RegExp(r'[a-zA-Z]+$'), '')) ?? 0;
}
