// Port of prosemirror-view/src/domcoords.ts (IE support dropped).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../state/index.dart';
import 'browser.dart' as browser;
import 'dom.dart';
import 'index.dart';

/// The TS `Rect` type `{left, right, top, bottom}`.
class Rect {
  final double left;
  final double right;
  final double top;
  final double bottom;

  const Rect({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });
}

/// The TS `{left, top}` coordinates parameter (e.g. of `posAtCoords`).
class ViewCoords {
  final double left;
  final double top;

  const ViewCoords({required this.left, required this.top});
}

/// Return type of [posAtCoords] (`{pos: number, inside: number}` in TS).
class PosAtCoordsResult {
  final int pos;
  final int inside;

  const PosAtCoordsResult({required this.pos, required this.inside});
}

Rect _toRect(web.DOMRect rect) => Rect(
    left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom);

Rect windowRect(web.Document doc) {
  final vp = doc.defaultView?.visualViewport;
  if (vp != null) {
    return Rect(left: 0, right: vp.width, top: 0, bottom: vp.height);
  }
  return Rect(
      left: 0,
      right: doc.documentElement!.clientWidth.toDouble(),
      top: 0,
      bottom: doc.documentElement!.clientHeight.toDouble());
}

/// `value` is either a `num` or a [Rect] (the TS `number | Rect` union used
/// by the `scrollThreshold`/`scrollMargin` props).
double getSide(Object value, String side) {
  if (value is num) return value.toDouble();
  final rect = value as Rect;
  switch (side) {
    case 'left':
      return rect.left;
    case 'right':
      return rect.right;
    case 'top':
      return rect.top;
    default:
      return rect.bottom;
  }
}

Rect clientRect(web.HTMLElement node) {
  final rect = node.getBoundingClientRect();
  // Adjust for elements with style "transform: scale()"
  double scaleX = rect.width / node.offsetWidth;
  if (scaleX.isNaN || scaleX == 0) scaleX = 1;
  double scaleY = rect.height / node.offsetHeight;
  if (scaleY.isNaN || scaleY == 0) scaleY = 1;
  // Make sure scrollbar width isn't included in the rectangle
  return Rect(
      left: rect.left,
      right: rect.left + node.clientWidth * scaleX,
      top: rect.top,
      bottom: rect.top + node.clientHeight * scaleY);
}

void scrollRectIntoView(EditorView view, Rect rect, web.Node? startDOM) {
  // Skip empty rects with all sides at 0, for example, when the element has
  // no CSS box (display: none)
  if (!nonZero(rect) && rect.left == 0) return;

  final Object scrollThreshold =
      (view.someProp('scrollThreshold') as Object?) ?? 0;
  final Object scrollMargin = (view.someProp('scrollMargin') as Object?) ?? 5;
  final doc = view.dom.ownerDocument!;
  for (web.Node? parent = startDOM ?? view.dom;;) {
    if (parent == null) break;
    if (parent.nodeType != 1) {
      parent = parentNode(parent);
      continue;
    }
    final elt = parent as web.HTMLElement;
    final atTop = elt == doc.body;
    final bounding = atTop ? windowRect(doc) : clientRect(elt);
    double moveX = 0, moveY = 0;
    if (rect.top < bounding.top + getSide(scrollThreshold, 'top')) {
      moveY = -(bounding.top - rect.top + getSide(scrollMargin, 'top'));
    } else if (rect.bottom >
        bounding.bottom - getSide(scrollThreshold, 'bottom')) {
      moveY = rect.bottom - rect.top > bounding.bottom - bounding.top
          ? rect.top + getSide(scrollMargin, 'top') - bounding.top
          : rect.bottom - bounding.bottom + getSide(scrollMargin, 'bottom');
    }
    if (rect.left < bounding.left + getSide(scrollThreshold, 'left')) {
      moveX = -(bounding.left - rect.left + getSide(scrollMargin, 'left'));
    } else if (rect.right >
        bounding.right - getSide(scrollThreshold, 'right')) {
      moveX = rect.right - bounding.right + getSide(scrollMargin, 'right');
    }
    if (moveX != 0 || moveY != 0) {
      if (atTop) {
        doc.defaultView!.scrollBy(moveX.toJS, moveY);
      } else {
        final startX = elt.scrollLeft, startY = elt.scrollTop;
        if (moveY != 0) elt.scrollTop += moveY;
        if (moveX != 0) elt.scrollLeft += moveX;
        final dX = elt.scrollLeft - startX, dY = elt.scrollTop - startY;
        rect = Rect(
            left: rect.left - dX,
            top: rect.top - dY,
            right: rect.right - dX,
            bottom: rect.bottom - dY);
      }
    }
    final String pos = atTop
        ? 'fixed'
        : web.window.getComputedStyle(elt).getPropertyValue('position');
    if (RegExp(r'^(fixed|sticky)$').hasMatch(pos)) break;
    parent = pos == 'absolute' ? elt.offsetParent : parentNode(parent);
  }
}

class ScrollStackEntry {
  final web.Element dom;
  final double top;
  final double left;

  const ScrollStackEntry(this.dom, this.top, this.left);
}

/// Result of [storeScrollPos] (`{refDOM, refTop, stack}` in TS; `refDOM` and
/// `refTop` stay unset there when no reference element is found, hence
/// nullable here).
class StoredScrollPos {
  final web.HTMLElement? refDOM;
  final double refTop;
  final List<ScrollStackEntry> stack;

  const StoredScrollPos(
      {required this.refDOM, required this.refTop, required this.stack});
}

/// Store the scroll position of the editor's parent nodes, along with the top
/// position of an element near the top of the editor, which will be used to
/// make sure the visible viewport remains stable even when the size of the
/// content above changes.
StoredScrollPos storeScrollPos(EditorView view) {
  final rect = view.dom.getBoundingClientRect();
  final startY = math.max(0, rect.top).toDouble();
  web.HTMLElement? refDOM;
  double refTop = 0;
  final x = (rect.left + rect.right) / 2;
  for (double y = startY + 1;
      y < math.min(web.window.innerHeight.toDouble(), rect.bottom);
      y += 5) {
    final dom = (view.root as dynamic).elementFromPoint(x, y) as web.Element?;
    if (dom == null || dom == view.dom || !view.dom.contains(dom)) continue;
    final localRect = dom.getBoundingClientRect();
    if (localRect.top >= startY - 20) {
      refDOM = dom as web.HTMLElement;
      refTop = localRect.top;
      break;
    }
  }
  return StoredScrollPos(
      refDOM: refDOM, refTop: refTop, stack: scrollStack(view.dom));
}

List<ScrollStackEntry> scrollStack(web.Node dom) {
  final stack = <ScrollStackEntry>[];
  final doc = dom.ownerDocument;
  for (web.Node? cur = dom; cur != null; cur = parentNode(cur)) {
    // The TS version pushes every ancestor (including the Document, whose
    // `scrollTop` is undefined and whose restore write is a no-op expando).
    // Only elements have a meaningful scrollTop/scrollLeft, so restrict the
    // stack to them.
    if (cur.isA<web.Element>()) {
      final elt = cur as web.Element;
      stack.add(ScrollStackEntry(elt, elt.scrollTop, elt.scrollLeft));
    }
    if (dom == doc) break;
  }
  return stack;
}

/// Reset the scroll position of the editor's parent nodes to that what it was
/// before, when storeScrollPos was called.
void resetScrollPos(StoredScrollPos stored) {
  final newRefTop =
      stored.refDOM != null ? stored.refDOM!.getBoundingClientRect().top : 0.0;
  restoreScrollStack(
      stored.stack, newRefTop == 0 ? 0 : newRefTop - stored.refTop);
}

void restoreScrollStack(List<ScrollStackEntry> stack, double dTop) {
  for (int i = 0; i < stack.length; i++) {
    final entry = stack[i];
    if (entry.dom.scrollTop != entry.top + dTop) {
      entry.dom.scrollTop = entry.top + dTop;
    }
    if (entry.dom.scrollLeft != entry.left) entry.dom.scrollLeft = entry.left;
  }
}

@JS('Object.defineProperty')
external void _objectDefineProperty(
    JSObject obj, JSString prop, JSObject descriptor);

// TS: `let preventScrollSupported: false | null | {preventScroll: boolean}`.
// Split into the detected options object plus a "known unsupported" flag.
web.FocusOptions? _preventScrollSupported;
bool _preventScrollKnownUnsupported = false;

/// Feature-detects support for .focus({preventScroll: true}), and uses a
/// fallback kludge when not supported.
void focusPreventScroll(web.HTMLElement dom) {
  if (_preventScrollSupported != null) {
    dom.focus(_preventScrollSupported!);
    return;
  }

  final stored = scrollStack(dom);
  if (!_preventScrollKnownUnsupported) {
    // Passing an options object whose `preventScroll` property is a getter
    // lets us detect whether the browser reads (i.e. supports) the option.
    final options = JSObject();
    final descriptor = JSObject()
      ..setProperty(
          'get'.toJS,
          (() {
            _preventScrollSupported = web.FocusOptions(preventScroll: true);
            return true.toJS;
          }).toJS);
    _objectDefineProperty(options, 'preventScroll'.toJS, descriptor);
    dom.focus(options as web.FocusOptions);
  } else {
    dom.focus();
  }
  if (_preventScrollSupported == null) {
    _preventScrollKnownUnsupported = true;
    restoreScrollStack(stored, 0);
  }
}

/// Returns the TS `{node, offset}` pair as a [CaretPosition] (from dom.dart).
CaretPosition findOffsetInNode(web.Element node, ViewCoords coords) {
  web.Node? closest;
  double dxClosest = 2e8;
  ViewCoords? coordsClosest;
  int offset = 0;
  double rowBot = coords.top, rowTop = coords.top;
  web.Node? firstBelow;
  ViewCoords? coordsBelow;
  int childIndex = 0;
  for (web.Node? child = node.firstChild;
      child != null;
      child = child.nextSibling, childIndex++) {
    web.DOMRectList rects;
    if (child.nodeType == 1) {
      rects = (child as web.Element).getClientRects();
    } else if (child.nodeType == 3) {
      rects = textRange(child as web.Text).getClientRects();
    } else {
      continue;
    }

    for (int i = 0; i < rects.length; i++) {
      final rect = _toRect(rects.item(i)!);
      if (rect.top <= rowBot && rect.bottom >= rowTop) {
        rowBot = math.max(rect.bottom, rowBot);
        rowTop = math.min(rect.top, rowTop);
        final dx = rect.left > coords.left
            ? rect.left - coords.left
            : rect.right < coords.left
                ? coords.left - rect.right
                : 0.0;
        if (dx < dxClosest) {
          closest = child;
          dxClosest = dx;
          coordsClosest = dx != 0 && closest.nodeType == 3
              ? ViewCoords(
                  left: rect.right < coords.left ? rect.right : rect.left,
                  top: coords.top)
              : coords;
          if (child.nodeType == 1 && dx != 0) {
            offset = childIndex +
                (coords.left >= (rect.left + rect.right) / 2 ? 1 : 0);
          }
          continue;
        }
      } else if (rect.top > coords.top &&
          firstBelow == null &&
          rect.left <= coords.left &&
          rect.right >= coords.left) {
        firstBelow = child;
        coordsBelow = ViewCoords(
            left: math.max(rect.left, math.min(rect.right, coords.left)),
            top: rect.top);
      }
      if (closest == null &&
          (coords.left >= rect.right && coords.top >= rect.top ||
              coords.left >= rect.left && coords.top >= rect.bottom)) {
        offset = childIndex + 1;
      }
    }
  }
  if (closest == null && firstBelow != null) {
    closest = firstBelow;
    coordsClosest = coordsBelow;
    dxClosest = 0;
  }
  if (closest != null && closest.nodeType == 3) {
    return findOffsetInText(closest as web.Text, coordsClosest!);
  }
  if (closest == null || (dxClosest != 0 && closest.nodeType == 1)) {
    return CaretPosition(node, offset);
  }
  return findOffsetInNode(closest as web.Element, coordsClosest!);
}

CaretPosition findOffsetInText(web.Text node, ViewCoords coords) {
  final len = node.nodeValue!.length;
  final range = web.document.createRange();
  CaretPosition? result;
  for (int i = 0; i < len; i++) {
    range.setEnd(node, i + 1);
    range.setStart(node, i);
    final rect = singleRect(range, 1);
    if (rect.top == rect.bottom) continue;
    if (inRect(coords, rect)) {
      result = CaretPosition(
          node, i + (coords.left >= (rect.left + rect.right) / 2 ? 1 : 0));
      break;
    }
  }
  range.detach();
  return result ?? CaretPosition(node, 0);
}

bool inRect(ViewCoords coords, Rect rect) {
  return coords.left >= rect.left - 1 &&
      coords.left <= rect.right + 1 &&
      coords.top >= rect.top - 1 &&
      coords.top <= rect.bottom + 1;
}

web.Element targetKludge(web.Element dom, ViewCoords coords) {
  final parent = dom.parentNode;
  if (parent != null &&
      RegExp(r'^li$', caseSensitive: false).hasMatch(parent.nodeName) &&
      coords.left < dom.getBoundingClientRect().left) {
    return parent as web.Element;
  }
  return dom;
}

int posFromElement(EditorView view, web.Element elt, ViewCoords coords) {
  final found = findOffsetInNode(elt, coords);
  final node = found.node;
  final offset = found.offset;
  int bias = -1;
  if (node.nodeType == 1 && node.firstChild == null) {
    final rect = (node as web.Element).getBoundingClientRect();
    bias = rect.left != rect.right && coords.left > (rect.left + rect.right) / 2
        ? 1
        : -1;
  }
  return view.docView.posFromDOM(node, offset, bias);
}

int? posFromCaret(
    EditorView view, web.Node node, int offset, ViewCoords coords) {
  // Browser (in caretPosition/RangeFromPoint) will agressively normalize
  // towards nearby inline nodes. Since we are interested in positions between
  // block nodes too, we first walk up the hierarchy of nodes to see if there
  // are block nodes that the coordinates fall outside of. If so, we take the
  // position before/after that block. If not, we call `posFromDOM` on the raw
  // node/offset.
  int outsideBlock = -1;
  web.Node cur = node;
  bool sawBlock = false;
  for (;;) {
    if (cur == view.dom) break;
    final desc = view.docView.nearestDesc(cur, true);
    if (desc == null) return null;
    final descNode = desc.node;
    if (desc.dom.nodeType == 1 &&
        ((descNode?.isBlock == true) && desc.parent != null ||
            desc.contentDOM == null)) {
      final web.DOMRect rect =
          (desc.dom as web.HTMLElement).getBoundingClientRect();
      // Ignore elements with zero-size bounding rectangles
      if (rect.width != 0 || rect.height != 0) {
        if (descNode?.isBlock == true &&
            desc.parent != null &&
            !RegExp(r'^T(R|BODY|HEAD|FOOT)$').hasMatch(desc.dom.nodeName)) {
          // Only apply the horizontal test to the innermost block. Vertical
          // for any parent.
          if (!sawBlock && rect.left > coords.left || rect.top > coords.top) {
            outsideBlock = desc.posBefore;
          } else if (!sawBlock && rect.right < coords.left ||
              rect.bottom < coords.top) {
            outsideBlock = desc.posAfter;
          }
          sawBlock = true;
        }
        if (desc.contentDOM == null &&
            outsideBlock < 0 &&
            descNode?.isText != true) {
          // If we are inside a leaf, return the side of the leaf closer to
          // the coords
          final bool before = descNode?.isBlock == true
              ? coords.top < (rect.top + rect.bottom) / 2
              : coords.left < (rect.left + rect.right) / 2;
          return before ? desc.posBefore : desc.posAfter;
        }
      }
    }
    cur = desc.dom.parentNode!;
  }
  return outsideBlock > -1
      ? outsideBlock
      : view.docView.posFromDOM(node, offset, -1);
}

web.Element elementFromPoint(web.Element element, ViewCoords coords, Rect box) {
  final len = element.childNodes.length;
  if (len > 0 && box.top < box.bottom) {
    final startI = math.max(
        0,
        math.min(
            len - 1,
            (len * (coords.top - box.top) / (box.bottom - box.top)).floor() -
                2));
    int i = startI;
    for (;;) {
      final child = element.childNodes.item(i)!;
      if (child.nodeType == 1) {
        final rects = (child as web.Element).getClientRects();
        for (int j = 0; j < rects.length; j++) {
          final rect = _toRect(rects.item(j)!);
          if (inRect(coords, rect)) {
            return elementFromPoint(child, coords, rect);
          }
        }
      }
      if ((i = (i + 1) % len) == startI) break;
    }
  }
  return element;
}

/// Given an x,y position on the editor, get the position in the document.
PosAtCoordsResult? posAtCoords(EditorView view, ViewCoords coords) {
  final doc = view.dom.ownerDocument!;
  web.Node? node;
  int offset = 0;
  final caret = caretFromPoint(doc, coords.left, coords.top);
  if (caret != null) {
    node = caret.node;
    offset = caret.offset;
  }

  final JSObject root = view.root as JSObject;
  final JSObject pointSource = root.has('elementFromPoint') ? root : doc;
  web.Element? elt = pointSource.callMethod<JSAny?>(
          'elementFromPoint'.toJS, coords.left.toJS, coords.top.toJS)
      as web.Element?;
  int? pos;
  if (elt == null ||
      !view.dom.contains(elt.nodeType != 1 ? elt.parentNode : elt)) {
    final box = _toRect(view.dom.getBoundingClientRect());
    if (!inRect(coords, box)) return null;
    elt = elementFromPoint(view.dom, coords, box);
  }
  // Safari's caretRangeFromPoint returns nonsense when on a draggable element
  if (browser.safari) {
    for (web.Node? p = elt; node != null && p != null; p = parentNode(p)) {
      if (p.isA<web.HTMLElement>() && (p as web.HTMLElement).draggable) {
        node = null;
      }
    }
  }
  elt = targetKludge(elt, coords);
  if (node != null) {
    if (browser.gecko && node.nodeType == 1) {
      // Firefox will sometimes return offsets into <input> nodes, which
      // have no actual children, from caretPositionFromPoint (#953)
      offset = math.min(offset, node.childNodes.length);
      // It'll also move the returned position before image nodes,
      // even if those are behind it.
      if (offset < node.childNodes.length) {
        final next = node.childNodes.item(offset)!;
        if (next.nodeName == 'IMG') {
          final box = (next as web.Element).getBoundingClientRect();
          if (box.right <= coords.left && box.bottom > coords.top) offset++;
        }
      }
    }
    // When clicking above the right side of an uneditable node, Chrome will
    // report a cursor position after that node.
    if (browser.webkit && offset > 0 && node.nodeType == 1) {
      final prev = node.childNodes.item(offset - 1);
      if (prev != null && prev.nodeType == 1) {
        final prevElt = prev as web.HTMLElement;
        if (prevElt.contentEditable == 'false' &&
            prevElt.getBoundingClientRect().top >= coords.top) {
          offset--;
        }
      }
    }
    // Suspiciously specific kludge to work around caret*FromPoint
    // never returning a position at the end of the document
    if (node == view.dom &&
        offset == node.childNodes.length - 1 &&
        node.lastChild!.nodeType == 1 &&
        coords.top >
            (node.lastChild as web.Element).getBoundingClientRect().bottom) {
      pos = view.state.doc.content.size;
    }
    // Ignore positions directly after a BR, since caret*FromPoint 'round up'
    // positions that would be more accurately placed before the BR node.
    else if (offset == 0 ||
        node.nodeType != 1 ||
        node.childNodes.item(offset - 1)!.nodeName != 'BR') {
      pos = posFromCaret(view, node, offset, coords);
    }
  }
  pos ??= posFromElement(view, elt, coords);

  final desc = view.docView.nearestDesc(elt, true);
  return PosAtCoordsResult(
      pos: pos, inside: desc != null ? desc.posAtStart - desc.border : -1);
}

bool nonZero(Rect rect) {
  return rect.top < rect.bottom || rect.left < rect.right;
}

web.DOMRectList _clientRects(JSObject target) => target.isA<web.Range>()
    ? (target as web.Range).getClientRects()
    : (target as web.Element).getClientRects();

web.DOMRect _boundingClientRect(JSObject target) => target.isA<web.Range>()
    ? (target as web.Range).getBoundingClientRect()
    : (target as web.Element).getBoundingClientRect();

/// `target` is a `web.Element` or a `web.Range` (the TS
/// `HTMLElement | Range` union).
Rect singleRect(JSObject target, int bias) {
  final rects = _clientRects(target);
  if (rects.length > 0) {
    final first = _toRect(rects.item(bias < 0 ? 0 : rects.length - 1)!);
    if (nonZero(first)) return first;
  }
  for (int i = 0; i < rects.length; i++) {
    final rect = _toRect(rects.item(i)!);
    if (nonZero(rect)) return rect;
  }
  return _toRect(_boundingClientRect(target));
}

final RegExp _bidi = RegExp('[\u0590-\u05f4\u0600-\u06ff\u0700-\u08ac]');

/// Given a position in the document model, get a bounding box of the
/// character at that position, relative to the window.
Rect coordsAtPos(EditorView view, int pos, int side) {
  final dfp = view.docView.domFromPos(pos, side < 0 ? -1 : 1);
  final web.Node node = dfp.node;
  final int offset = dfp.offset;
  final int? atom = dfp.atom;

  final supportEmptyRange = browser.webkit || browser.gecko;
  if (node.nodeType == 3) {
    final text = node as web.Text;
    final value = text.nodeValue!;
    // These browsers support querying empty text ranges. Prefer that in bidi
    // context or when at the end of a node.
    if (supportEmptyRange &&
        (_bidi.hasMatch(value) ||
            (side < 0 ? offset == 0 : offset == value.length))) {
      final rect = singleRect(textRange(text, offset, offset), side);
      // Firefox returns bad results (the position before the space) when
      // querying a position directly after line-broken whitespace. Detect
      // this situation and and kludge around it
      if (browser.gecko &&
          offset > 0 &&
          RegExp(r'\s').hasMatch(value[offset - 1]) &&
          offset < value.length) {
        final rectBefore =
            singleRect(textRange(text, offset - 1, offset - 1), -1);
        if (rectBefore.top == rect.top) {
          final rectAfter = singleRect(textRange(text, offset, offset + 1), -1);
          if (rectAfter.top != rect.top) {
            return flattenV(rectAfter, rectAfter.left < rectBefore.left);
          }
        }
      }
      return rect;
    } else {
      int from = offset, to = offset, takeSide = side < 0 ? 1 : -1;
      if (side < 0 && offset == 0) {
        to++;
        takeSide = -1;
      } else if (side >= 0 && offset == value.length) {
        from--;
        takeSide = 1;
      } else if (side < 0) {
        from--;
      } else {
        to++;
      }
      return flattenV(
          singleRect(textRange(text, from, to), takeSide), takeSide < 0);
    }
  }

  final $dom = view.state.doc.resolve(pos - (atom ?? 0));
  // Return a horizontal line in block context
  if (!$dom.parent.inlineContent) {
    if (atom == null && offset > 0 && (side < 0 || offset == nodeSize(node))) {
      final before = node.childNodes.item(offset - 1)!;
      if (before.nodeType == 1) {
        return flattenH(
            _toRect((before as web.Element).getBoundingClientRect()), false);
      }
    }
    if (atom == null && offset < nodeSize(node)) {
      final after = node.childNodes.item(offset)!;
      if (after.nodeType == 1) {
        return flattenH(
            _toRect((after as web.Element).getBoundingClientRect()), true);
      }
    }
    return flattenH(
        _toRect((node as web.Element).getBoundingClientRect()), side >= 0);
  }

  // Inline, not in text node (this is not Bidi-safe)
  if (atom == null && offset > 0 && (side < 0 || offset == nodeSize(node))) {
    final before = node.childNodes.item(offset - 1)!;
    final JSObject? target = before.nodeType == 3
        ? textRange(
            before as web.Text, nodeSize(before) - (supportEmptyRange ? 0 : 1))
        // BR nodes tend to only return the rectangle before them. Only use
        // them if they are the last element in their parent
        : before.nodeType == 1 &&
                (before.nodeName != 'BR' || before.nextSibling == null)
            ? before
            : null;
    if (target != null) return flattenV(singleRect(target, 1), false);
  }
  if (atom == null && offset < nodeSize(node)) {
    web.Node? after = node.childNodes.item(offset);
    while (after != null &&
        after.pmViewDesc != null &&
        after.pmViewDesc!.ignoreForCoords) {
      after = after.nextSibling;
    }
    final JSObject? target = after == null
        ? null
        : after.nodeType == 3
            ? textRange(after as web.Text, 0, supportEmptyRange ? 0 : 1)
            : after.nodeType == 1
                ? after
                : null;
    if (target != null) return flattenV(singleRect(target, -1), true);
  }
  // All else failed, just try to get a rectangle for the target node
  return flattenV(
      singleRect(
          node.nodeType == 3 ? textRange(node as web.Text) : node, -side),
      side >= 0);
}

Rect flattenV(Rect rect, bool left) {
  if (rect.right - rect.left == 0) return rect;
  final x = left ? rect.left : rect.right;
  return Rect(top: rect.top, bottom: rect.bottom, left: x, right: x);
}

Rect flattenH(Rect rect, bool top) {
  if (rect.bottom - rect.top == 0) return rect;
  final y = top ? rect.top : rect.bottom;
  return Rect(top: y, bottom: y, left: rect.left, right: rect.right);
}

T withFlushedState<T>(EditorView view, EditorState state, T Function() f) {
  final viewState = view.state;
  final active = (view.root as dynamic).activeElement as web.HTMLElement?;
  if (viewState != state) view.updateState(state);
  if (active != view.dom) view.focus();
  try {
    return f();
  } finally {
    if (viewState != state) view.updateState(viewState);
    if (active != view.dom && active != null) active.focus();
  }
}

/// Whether vertical position motion in a given direction from a position
/// would leave a text block. `dir` is `"up"` or `"down"`.
bool endOfTextblockVertical(EditorView view, EditorState state, String dir) {
  final sel = state.selection;
  final $pos = dir == 'up' ? sel.$from : sel.$to;
  return withFlushedState(view, state, () {
    web.Node dom = view.docView.domFromPos($pos.pos, dir == 'up' ? -1 : 1).node;
    for (;;) {
      final nearest = view.docView.nearestDesc(dom, true);
      if (nearest == null) break;
      if (nearest.node?.isBlock == true) {
        dom = nearest.contentDOM ?? nearest.dom;
        break;
      }
      dom = nearest.dom.parentNode!;
    }
    final coords = coordsAtPos(view, $pos.pos, 1);
    for (web.Node? child = dom.firstChild;
        child != null;
        child = child.nextSibling) {
      web.DOMRectList boxes;
      if (child.nodeType == 1) {
        boxes = (child as web.Element).getClientRects();
      } else if (child.nodeType == 3) {
        boxes = textRange(child as web.Text, 0, child.nodeValue!.length)
            .getClientRects();
      } else {
        continue;
      }
      for (int i = 0; i < boxes.length; i++) {
        final box = boxes.item(i)!;
        if (box.bottom > box.top + 1 &&
            (dir == 'up'
                ? coords.top - box.top > (box.bottom - coords.top) * 2
                : box.bottom - coords.bottom > (coords.bottom - box.top) * 2)) {
          return false;
        }
      }
    }
    return true;
  });
}

final RegExp _maybeRTL = RegExp('[\u0590-\u08ac]');

/// `dir` is `"left"`, `"right"`, `"forward"` or `"backward"`.
bool endOfTextblockHorizontal(EditorView view, EditorState state, String dir) {
  final $head = state.selection.headRes;
  if (!$head.parent.isTextblock) return false;
  final offset = $head.parentOffset;
  final atStart = offset == 0;
  final atEnd = offset == $head.parent.content.size;
  final web.Selection? sel = view.domSelection();
  if (sel == null)
    return $head.pos == $head.start() || $head.pos == $head.end();
  // If the textblock is all LTR, or the browser doesn't support
  // Selection.modify (Edge), fall back to a primitive approach
  if (!_maybeRTL.hasMatch($head.parent.textContent) || !sel.has('modify')) {
    return dir == 'left' || dir == 'backward' ? atStart : atEnd;
  }

  return withFlushedState(view, state, () {
    // This is a huge hack, but appears to be the best we can currently do:
    // use `Selection.modify` to move the selection by one character, and see
    // if that moves the cursor out of the textblock (or doesn't move it at
    // all, when at the start/end of the document).
    final oldRange = view.domSelectionRange();
    final web.Node? oldNode = oldRange.focusNode;
    final int oldOff = oldRange.focusOffset;
    final web.Node? anchorNode = oldRange.anchorNode;
    final int anchorOffset = oldRange.anchorOffset;
    final JSAny? oldBidiLevel =
        sel.getProperty('caretBidiLevel'.toJS); // Only for Firefox
    sel.callMethod<JSAny?>(
        'modify'.toJS, 'move'.toJS, dir.toJS, 'character'.toJS);
    final parentDOM =
        $head.depth > 0 ? view.docView.domAfterPos($head.before()) : view.dom;
    final newRange = view.domSelectionRange();
    final web.Node? newNode = newRange.focusNode;
    final int newOff = newRange.focusOffset;
    final bool result = newNode != null &&
            !parentDOM.contains(
                newNode.nodeType == 1 ? newNode : newNode.parentNode) ||
        (oldNode == newNode && oldOff == newOff);
    // Restore the previous selection
    try {
      sel.collapse(anchorNode, anchorOffset);
      if (oldNode != null &&
          (oldNode != anchorNode || oldOff != anchorOffset) &&
          sel.has('extend')) {
        sel.extend(oldNode, oldOff);
      }
    } catch (_) {}
    if (oldBidiLevel != null && !oldBidiLevel.isUndefinedOrNull) {
      sel.setProperty('caretBidiLevel'.toJS, oldBidiLevel);
    }
    return result;
  });
}

/// `"up" | "down" | "left" | "right" | "forward" | "backward"` in TS.
typedef TextblockDir = String;

EditorState? cachedState;
TextblockDir? cachedDir;
bool cachedResult = false;

bool endOfTextblock(EditorView view, EditorState state, TextblockDir dir) {
  if (identical(cachedState, state) && cachedDir == dir) return cachedResult;
  cachedState = state;
  cachedDir = dir;
  return cachedResult = dir == 'up' || dir == 'down'
      ? endOfTextblockVertical(view, state, dir)
      : endOfTextblockHorizontal(view, state, dir);
}
