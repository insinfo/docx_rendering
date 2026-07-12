// Port of prosemirror-view/src/dom.ts.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'viewdesc.dart';

typedef DOMNode = web.Node;
typedef DOMElement = web.Element;
typedef DOMHTMLElement = web.HTMLElement;
typedef DOMSelection = web.Selection;

class DOMSelectionRange {
  final web.Node? focusNode;
  final int focusOffset;
  final web.Node? anchorNode;
  final int anchorOffset;

  const DOMSelectionRange({
    required this.focusNode,
    required this.focusOffset,
    required this.anchorNode,
    required this.anchorOffset,
  });
}

/// ProseMirror stores the ViewDesc that manages a DOM node as an expando
/// property (`pmViewDesc`) on the node itself. With `package:web` (extension
/// types over JSObject, JS and Wasm) that requires `js_interop_unsafe` and
/// boxing the Dart object.
extension PmViewDescProp on web.Node {
  ViewDesc? get pmViewDesc {
    final JSAny? boxed = (this as JSObject).getProperty('pmViewDesc'.toJS);
    if (boxed == null || boxed.isUndefinedOrNull) return null;
    return (boxed as JSBoxedDartObject).toDart as ViewDesc;
  }

  set pmViewDesc(ViewDesc? desc) {
    if (desc == null) {
      (this as JSObject).setProperty('pmViewDesc'.toJS, null);
    } else {
      (this as JSObject).setProperty('pmViewDesc'.toJS, (desc as Object).toJSBox);
    }
  }
}

int domIndex(web.Node node) {
  web.Node? cur = node;
  for (int index = 0;; index++) {
    cur = cur!.previousSibling;
    if (cur == null) return index;
  }
}

web.Node? parentNode(web.Node node) {
  web.Node? parent;
  if (node.isA<web.Element>()) {
    parent = (node as web.Element).assignedSlot;
  }
  parent ??= node.parentNode;
  if (parent != null && parent.nodeType == 11) {
    return (parent as web.ShadowRoot).host;
  }
  return parent;
}

web.Range? _reusedRange;

/// Note that this will always return the same range, because DOM range
/// objects are expensive, and keep slowing down subsequent DOM updates.
web.Range textRange(web.Text node, [int? from, int? to]) {
  final range = _reusedRange ??= web.document.createRange();
  range.setEnd(node, to ?? node.nodeValue!.length);
  range.setStart(node, from ?? 0);
  return range;
}

void clearReusedRange() {
  _reusedRange = null;
}

/// Scans forward and backward through DOM positions equivalent to the given
/// one to see if the two are in the same place (i.e. after a text node vs at
/// the end of that text node).
bool isEquivalentPosition(web.Node node, int off, web.Node? targetNode, int targetOff) {
  return targetNode != null &&
      (_scanFor(node, off, targetNode, targetOff, -1) ||
          _scanFor(node, off, targetNode, targetOff, 1));
}

final RegExp _atomElements = RegExp(r'^(img|br|input|textarea|hr)$', caseSensitive: false);

bool _scanFor(web.Node node, int off, web.Node targetNode, int targetOff, int dir) {
  web.Node cur = node;
  int curOff = off;
  for (;;) {
    if (cur == targetNode && curOff == targetOff) return true;
    if (curOff == (dir < 0 ? 0 : nodeSize(cur))) {
      final parent = cur.parentNode;
      if (parent == null ||
          parent.nodeType != 1 ||
          hasBlockDesc(cur) ||
          _atomElements.hasMatch(cur.nodeName) ||
          (cur.isA<web.HTMLElement>() && (cur as web.HTMLElement).contentEditable == 'false')) {
        return false;
      }
      curOff = domIndex(cur) + (dir < 0 ? 0 : 1);
      cur = parent;
    } else if (cur.nodeType == 1) {
      final child = cur.childNodes.item(curOff + (dir < 0 ? -1 : 0));
      if (child == null) return false;
      if (child.nodeType == 1 &&
          (child as web.HTMLElement).contentEditable == 'false') {
        if (child.pmViewDesc?.ignoreForSelection == true) {
          curOff += dir;
        } else {
          return false;
        }
      } else {
        cur = child;
        curOff = dir < 0 ? nodeSize(cur) : 0;
      }
    } else {
      return false;
    }
  }
}

int nodeSize(web.Node node) {
  return node.nodeType == 3 ? node.nodeValue!.length : node.childNodes.length;
}

web.Text? textNodeBefore(web.Node node, int offset) {
  web.Node cur = node;
  int off = offset;
  for (;;) {
    if (cur.nodeType == 3 && off != 0) return cur as web.Text;
    if (cur.nodeType == 1 && off > 0) {
      if ((cur as web.HTMLElement).contentEditable == 'false') return null;
      cur = cur.childNodes.item(off - 1)!;
      off = nodeSize(cur);
    } else if (cur.parentNode != null && !hasBlockDesc(cur)) {
      off = domIndex(cur);
      cur = cur.parentNode!;
    } else {
      return null;
    }
  }
}

web.Text? textNodeAfter(web.Node node, int offset) {
  web.Node cur = node;
  int off = offset;
  for (;;) {
    if (cur.nodeType == 3 && off < cur.nodeValue!.length) return cur as web.Text;
    if (cur.nodeType == 1 && off < cur.childNodes.length) {
      if ((cur as web.HTMLElement).contentEditable == 'false') return null;
      cur = cur.childNodes.item(off)!;
      off = 0;
    } else if (cur.parentNode != null && !hasBlockDesc(cur)) {
      off = domIndex(cur) + 1;
      cur = cur.parentNode!;
    } else {
      return null;
    }
  }
}

bool isOnEdge(web.Node node, int offset, web.Node parent) {
  web.Node cur = node;
  bool atStart = offset == 0;
  bool atEnd = offset == nodeSize(cur);
  while (atStart || atEnd) {
    if (cur == parent) return true;
    final index = domIndex(cur);
    final next = cur.parentNode;
    if (next == null) return false;
    cur = next;
    atStart = atStart && index == 0;
    atEnd = atEnd && index == nodeSize(cur);
  }
  return false;
}

bool hasBlockDesc(web.Node dom) {
  ViewDesc? desc;
  for (web.Node? cur = dom; cur != null; cur = cur.parentNode) {
    desc = cur.pmViewDesc;
    if (desc != null) break;
  }
  return desc != null &&
      desc.node != null &&
      desc.node!.isBlock &&
      (desc.dom == dom || desc.contentDOM == dom);
}

/// Work around Chrome issue #447523 (isCollapsed inappropriately returns
/// true in shadow dom).
bool selectionCollapsed(DOMSelectionRange domSel) {
  return domSel.focusNode != null &&
      isEquivalentPosition(
          domSel.focusNode!, domSel.focusOffset, domSel.anchorNode, domSel.anchorOffset);
}

web.KeyboardEvent keyEvent(int keyCode, String key) {
  final event = web.KeyboardEvent(
      'keydown', web.KeyboardEventInit(bubbles: true, cancelable: true, key: key));
  (event as JSObject).setProperty('keyCode'.toJS, keyCode.toJS);
  return event;
}

web.Element? deepActiveElement(web.Document doc) {
  var elt = doc.activeElement;
  while (elt != null && elt.shadowRoot != null) {
    elt = elt.shadowRoot!.activeElement;
  }
  return elt;
}

class CaretPosition {
  final web.Node node;
  final int offset;
  CaretPosition(this.node, this.offset);
}

CaretPosition? caretFromPoint(web.Document doc, num x, num y) {
  final docObj = doc as JSObject;
  if (docObj.has('caretPositionFromPoint')) {
    try {
      final pos = docObj.callMethod('caretPositionFromPoint'.toJS, x.toJS, y.toJS) as JSObject?;
      if (pos != null && !pos.isUndefinedOrNull) {
        final node = pos.getProperty('offsetNode'.toJS) as web.Node?;
        final offset = (pos.getProperty('offset'.toJS) as JSNumber?)?.toDartInt ?? 0;
        if (node != null) {
          // Clip the offset, because Chrome will return a text offset into
          // <input> nodes, which can't be treated as a regular DOM offset.
          return CaretPosition(node, offset < nodeSize(node) ? offset : nodeSize(node));
        }
      }
    } catch (_) {
      // Firefox throws for this call in hard-to-predict circumstances (#994).
    }
  }
  if (docObj.has('caretRangeFromPoint')) {
    final range =
        docObj.callMethod('caretRangeFromPoint'.toJS, x.toJS, y.toJS) as web.Range?;
    if (range != null) {
      final node = range.startContainer;
      final offset = range.startOffset;
      return CaretPosition(node, offset < nodeSize(node) ? offset : nodeSize(node));
    }
  }
  return null;
}
