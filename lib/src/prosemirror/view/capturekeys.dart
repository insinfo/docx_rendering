import 'package:web/web.dart' as web;

import '../state/index.dart';
import 'domcoords.dart';
import 'index.dart';

bool captureKeyDown(EditorView view, web.KeyboardEvent event) {
  final code = event.keyCode;
  if (code == 8 || code == 46)
    return stopNativeHorizontalDelete(view, code == 8 ? -1 : 1);
  if (code == 37 || code == 39)
    return selectHorizontally(view, code == 37 ? -1 : 1, event);
  if (code == 38 || code == 40)
    return selectVertically(view, code == 38 ? -1 : 1, event);
  return false;
}

bool selectHorizontally(EditorView view, int dir, web.KeyboardEvent event) {
  final sel = view.state.selection;
  if (sel is NodeSelection && !event.shiftKey) {
    final $head = dir > 0 ? sel.toRes : sel.fromRes;
    view.dispatch(view.state.tr
        .setSelection(Selection.near($head, dir))
        .scrollIntoView());
    return true;
  }
  return false;
}

bool selectVertically(EditorView view, int dir, web.KeyboardEvent event) {
  if (!view.state.selection.empty || event.shiftKey) return false;
  return endOfTextblock(view, view.state, dir < 0 ? 'up' : 'down');
}

bool stopNativeHorizontalDelete(EditorView view, int dir) {
  final sel = view.state.selection;
  if (!sel.empty) return false;
  final found =
      Selection.findFrom(dir < 0 ? sel.fromRes : sel.toRes, dir, true);
  return found == null;
}

bool switchEditable(EditorView view, web.Node node, String state) {
  if (node is! web.HTMLElement) return false;
  node.contentEditable = state;
  return true;
}

bool safariDownArrowBug(EditorView view) => false;

String getMods(web.KeyboardEvent event) {
  final result = StringBuffer();
  if (event.ctrlKey) result.write('c');
  if (event.metaKey) result.write('m');
  if (event.altKey) result.write('a');
  if (event.shiftKey) result.write('s');
  return result.toString();
}

Selection? moveSelectionBlock(EditorView view, int dir) => Selection.findFrom(
    dir < 0 ? view.state.selection.fromRes : view.state.selection.toRes, dir);

bool apply(EditorView view, Selection? sel) {
  if (sel == null) return false;
  view.dispatch(view.state.tr.setSelection(sel).scrollIntoView());
  return true;
}

void skipIgnoredNodesLeft(EditorView view) {}

void skipIgnoredNodesRight(EditorView view) {}

int? findDirection(EditorView view, web.Node node) => null;
