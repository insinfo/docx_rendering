import 'package:web/web.dart' as web;

import '../model/index.dart';
import '../model/from_dom.dart';
import '../state/index.dart';
import 'index.dart';
import 'selection.dart';

class ParseBetweenResult {
  final PMNode doc;
  final int sel;
  final int start;
  final int end;

  ParseBetweenResult(this.doc, this.sel, this.start, this.end);
}

ParseBetweenResult parseBetween(EditorView view, int from, int to) {
  final range = view.docView.parseRange(from, to);
  final find = <Map<String, dynamic>>[];
  final sel = view.domSelectionRange();
  if (sel.anchorNode != null) {
    find.add({'node': sel.anchorNode, 'offset': sel.anchorOffset});
  }
  final parser = DOMParser.fromSchema(view.state.schema);
  final doc = parser.parse(
    range.node,
    ParseOptions(
      topNode: view.state.doc,
      from: range.fromOffset,
      to: range.toOffset,
      preserveWhitespace: true,
      findPositions: find,
    ),
  );
  final found = find.isNotEmpty ? find[0]['pos'] : null;
  return ParseBetweenResult(
      doc, found is int ? found : -1, range.from, range.to);
}

ParseRule? ruleFromNode(web.Node dom) => null;

void readDOMChange(EditorView view, int from, int to,
    [bool typeOver = false, List<web.Node>? added]) {
  final state = view.state;
  if (from < 0 || to < from || view.composing) return;
  final parsed = parseBetween(view, from, to);
  if (parsed.doc.eq(state.doc)) {
    final sel = selectionFromDOM(view);
    if (sel != null && !sel.eq(state.selection)) {
      view.dispatch(state.tr.setSelection(sel));
    }
    return;
  }
  final tr = state.tr;
  tr.replace(parsed.start, parsed.end,
      parsed.doc.slice(parsed.start, parsed.end, false));
  final sel = resolveSelection(view, tr.doc, parsed.sel);
  if (sel != null) tr.setSelection(sel);
  view.dispatch(tr);
}

Selection? resolveSelection(EditorView view, PMNode doc, int parsedSel) {
  if (parsedSel > -1 && parsedSel <= doc.content.size) {
    return selectionBetween(
        view, doc.resolve(parsedSel), doc.resolve(parsedSel));
  }
  return null;
}

bool isMarkChange(EditorView view, int from, int to) => false;

bool looksLikeBackspace(Transaction tr) => false;

bool looksLikeJoin(PMNode old, PMNode cur, int from, int to) => false;
