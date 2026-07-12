import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/index.dart';
import '../state/index.dart';
import 'browser.dart' as browser;
import 'dom.dart';
import 'index.dart';
import 'viewdesc.dart';

Selection? selectionFromDOM(EditorView view, [String? origin]) {
  final domSel = view.domSelectionRange();
  final doc = view.state.doc;
  if (domSel.focusNode == null) return null;
  var nearestDesc = view.docView.nearestDesc(domSel.focusNode!);
  final inWidget = nearestDesc != null && nearestDesc.size == 0;
  var head = view.docView.posFromDOM(domSel.focusNode!, domSel.focusOffset, 1);
  if (head < 0) return null;
  var headRes = doc.resolve(head);
  int anchor;
  Selection? selection;

  if (selectionCollapsed(domSel)) {
    anchor = head;
    while (nearestDesc != null && nearestDesc.node == null) {
      nearestDesc = nearestDesc.parent;
    }
    final nearestDescNode = nearestDesc?.node;
    if (nearestDesc is NodeViewDesc &&
        nearestDescNode != null &&
        nearestDescNode.isAtom &&
        NodeSelection.isSelectable(nearestDescNode) &&
        nearestDesc.parent != null &&
        !(nearestDescNode.isInline &&
            isOnEdge(domSel.focusNode!, domSel.focusOffset, nearestDesc.dom))) {
      final pos = nearestDesc.posBefore;
      selection = NodeSelection(head == pos ? headRes : doc.resolve(pos));
    }
  } else {
    anchor =
        view.docView.posFromDOM(domSel.anchorNode!, domSel.anchorOffset, 1);
    if (anchor < 0) return null;
  }

  final anchorRes = doc.resolve(anchor);
  if (selection == null) {
    final bias = origin == 'pointer' ||
            (view.state.selection.head < headRes.pos && !inWidget)
        ? 1
        : -1;
    selection = selectionBetween(view, anchorRes, headRes, bias);
  }
  return selection;
}

bool editorOwnsSelection(EditorView view) {
  return view.editable
      ? view.hasFocus()
      : hasSelection(view) &&
          web.document.activeElement != null &&
          web.document.activeElement!.contains(view.dom);
}

void selectionToDOM(EditorView view, [bool force = false]) {
  final sel = view.state.selection;
  syncNodeSelection(view, sel);
  if (!editorOwnsSelection(view)) return;

  final mouseDown = view.input.mouseDown;
  if (!force && browser.chrome && mouseDown != null) {
    final domSel = view.domSelectionRange();
    final curSel = view.domObserver.currentSelection;
    if (domSel.anchorNode != null &&
        curSel.anchorNode != null &&
        isEquivalentPosition(domSel.anchorNode!, domSel.anchorOffset,
            curSel.anchorNode, curSel.anchorOffset) &&
        mouseDown.delaySelUpdate()) {
      view.domObserver.setCurSelection();
      return;
    }
  }

  view.domObserver.disconnectSelection();
  if (view.cursorWrapper != null) {
    selectCursorWrapper(view);
  } else {
    view.docView.setSelection(sel.anchor, sel.head, view, force);
    if (sel.visible) {
      view.dom.classList.remove('ProseMirror-hideselection');
    } else {
      view.dom.classList.add('ProseMirror-hideselection');
      removeClassOnSelectionChange(view);
    }
  }
  view.domObserver.setCurSelection();
  view.domObserver.connectSelection();
}

void removeClassOnSelectionChange(EditorView view) {
  final doc = view.dom.ownerDocument;
  if (doc == null) return;
  final oldGuard = view.input.hideSelectionGuard;
  if (oldGuard != null) {
    doc.removeEventListener('selectionchange', oldGuard);
  }
  final domSel = view.domSelectionRange();
  final node = domSel.anchorNode;
  final offset = domSel.anchorOffset;
  web.EventListener? guard;
  guard = ((web.Event event) {
    final cur = view.domSelectionRange();
    if (cur.anchorNode != node || cur.anchorOffset != offset) {
      doc.removeEventListener('selectionchange', guard);
      Timer(const Duration(milliseconds: 20), () {
        if (!editorOwnsSelection(view) || view.state.selection.visible) {
          view.dom.classList.remove('ProseMirror-hideselection');
        }
      });
    }
  }).toJS;
  view.input.hideSelectionGuard = guard;
  doc.addEventListener('selectionchange', guard);
}

void selectCursorWrapper(EditorView view) {
  final domSel = view.domSelection();
  if (domSel == null || view.cursorWrapper == null) return;
  final node = view.cursorWrapper!.dom;
  if (node.nodeName == 'IMG') {
    domSel.collapse(node.parentNode, domIndex(node) + 1);
  } else {
    domSel.collapse(node, 0);
  }
}

void syncNodeSelection(EditorView view, Selection sel) {
  if (sel is NodeSelection) {
    final desc = view.docView.descAt(sel.from);
    if (desc != view.lastSelectedViewDesc) {
      clearNodeSelection(view);
      if (desc is NodeViewDesc) desc.selectNode();
      view.lastSelectedViewDesc = desc;
    }
  } else {
    clearNodeSelection(view);
  }
}

void clearNodeSelection(EditorView view) {
  final desc = view.lastSelectedViewDesc;
  if (desc != null) {
    if (desc.parent != null && desc is NodeViewDesc) desc.deselectNode();
    view.lastSelectedViewDesc = null;
  }
}

Selection selectionBetween(
    EditorView view, ResolvedPos anchorRes, ResolvedPos headRes,
    [int? bias]) {
  final custom = view.someProp('createSelectionBetween', (dynamic f) {
    return f(view, anchorRes, headRes);
  });
  return custom is Selection
      ? custom
      : TextSelection.between(anchorRes, headRes, bias);
}

bool hasFocusAndSelection(EditorView view) {
  if (view.editable && !view.hasFocus()) return false;
  return hasSelection(view);
}

bool hasSelection(EditorView view) {
  final sel = view.domSelectionRange();
  if (sel.anchorNode == null) return false;
  try {
    final anchor = sel.anchorNode!.nodeType == 3
        ? sel.anchorNode!.parentNode
        : sel.anchorNode;
    final focus = sel.focusNode?.nodeType == 3
        ? sel.focusNode?.parentNode
        : sel.focusNode;
    return anchor != null &&
        view.dom.contains(anchor) &&
        (view.editable || (focus != null && view.dom.contains(focus)));
  } catch (_) {
    return false;
  }
}

bool anchorInRightPlace(EditorView view) {
  final anchorDOM = view.docView.domFromPos(view.state.selection.anchor, 0);
  final domSel = view.domSelectionRange();
  return domSel.anchorNode != null &&
      isEquivalentPosition(anchorDOM.node, anchorDOM.offset, domSel.anchorNode,
          domSel.anchorOffset);
}
