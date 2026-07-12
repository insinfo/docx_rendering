import 'dart:async';

import 'package:web/web.dart' as web;

import '../model/index.dart';
import '../model/from_dom.dart';
import '../state/index.dart';

import 'browser.dart' as browser;
import 'dom.dart';
import 'index.dart';
import 'selection.dart';

class ParseBetweenResult {
  final PMNode doc;
  final ParseSel? sel;
  final int from;
  final int to;

  ParseBetweenResult(this.doc, this.sel, this.from, this.to);
}

class ParseSel {
  int anchor;
  int head;
  ParseSel(this.anchor, this.head);
}

ParseBetweenResult parseBetween(EditorView view, int from_, int to_) {
  final range = view.docView.parseRange(from_, to_);
  final parent = range.node;
  final fromOffset = range.fromOffset;
  int toOffset = range.toOffset;
  final from = range.from;
  final to = range.to;

  final domSel = view.domSelectionRange();
  List<Map<String, dynamic>>? find;
  final anchor = domSel.anchorNode;
  
  if (anchor != null && view.dom.contains(anchor.nodeType == 1 ? anchor : anchor.parentNode)) {
    find = [{'node': anchor, 'offset': domSel.anchorOffset}];
    if (!selectionCollapsed(domSel)) {
      find.add({'node': domSel.focusNode!, 'offset': domSel.focusOffset});
    }
  }

  // Work around issue in Chrome where backspacing sometimes replaces
  // the deleted content with a random BR node (issues #799, #831)
  if (browser.chrome && view.input.lastKeyCode == 8) {
    for (int off = toOffset; off > fromOffset; off--) {
      final node = parent.childNodes.item(off - 1);
      final desc = node?.pmViewDesc;
      if (node?.nodeName == 'BR' && desc == null) {
        toOffset = off;
        break;
      }
      if (desc == null || desc.size > 0) break;
    }
  }

  final startDoc = view.state.doc;
  final parser = view.someProp('domParser') as DOMParser? ?? DOMParser.fromSchema(view.state.schema);
  final $from = startDoc.resolve(from);

  ParseSel? sel;
  final doc = parser.parse(
    parent,
    ParseOptions(
      topNode: $from.parent,
      topMatch: $from.parent.contentMatchAt($from.index()),
      topOpen: true,
      from: fromOffset,
      to: toOffset,
      preserveWhitespace: $from.parent.type.whitespace == 'pre' ? true : true,
      findPositions: find,
      ruleFromNode: ruleFromNode,
      context: $from,
    ),
  );

  if (find != null && find.isNotEmpty && find[0]['pos'] != null) {
    final anchorPos = find[0]['pos'] as int;
    int headPos = (find.length > 1 && find[1]['pos'] != null) ? find[1]['pos'] as int : anchorPos;
    sel = ParseSel(anchorPos + from, headPos + from);
  }

  return ParseBetweenResult(doc, sel, from, to);
}

TagParseRule? ruleFromNode(web.Node dom) {
  final desc = dom.pmViewDesc;
  if (desc != null) {
    return desc.parseRule() as TagParseRule?;
  } else if (dom.nodeName == 'BR' && dom.parentNode != null) {
    // Safari replaces the list item or table cell with a BR
    // directly in the list node (?!) if you delete the last
    // character in a list item or table cell (#708, #862)
    if (browser.safari && RegExp(r'^(ul|ol)$', caseSensitive: false).hasMatch(dom.parentNode!.nodeName)) {
      return TagParseRule(tag: '', ignore: true); // fallback for safari bug
    } else if (dom.parentNode!.lastChild == dom || (browser.safari && RegExp(r'^(tr|table)$', caseSensitive: false).hasMatch(dom.parentNode!.nodeName))) {
      return TagParseRule(tag: '', ignore: true);
    }
  } else if (dom.nodeName == 'IMG' && (dom as web.HTMLElement).getAttribute('mark-placeholder') != null) {
    return TagParseRule(tag: '', ignore: true);
  }
  return null;
}

final RegExp _isInline = RegExp(
    r'^(a|abbr|acronym|b|bd[io]|big|br|button|cite|code|data(list)?|del|dfn|em|i|img|ins|kbd|label|map|mark|meter|output|q|ruby|s|samp|small|span|strong|su[bp]|time|u|tt|var)$',
    caseSensitive: false);

class DiffResult {
  int start;
  int endA;
  int endB;
  DiffResult(this.start, this.endA, this.endB);
}

void readDOMChange(EditorView view, int from_, int to_, bool typeOver, List<web.Node> addedNodes) {
  int compositionID = view.input.compositionPendingChanges
      ? view.input.compositionID
      : (view.composing ? view.input.compositionID : 0);
  view.input.compositionPendingChanges = false;

  if (from_ < 0) {
    final origin = view.input.lastSelectionTime > DateTime.now().millisecondsSinceEpoch - 50
        ? view.input.lastSelectionOrigin
        : null;
    final newSel = selectionFromDOM(view, origin);
    if (newSel != null && !view.state.selection.eq(newSel)) {
      if (browser.chrome &&
          browser.android &&
          view.input.lastKeyCode == 13 &&
          DateTime.now().millisecondsSinceEpoch - 100 < view.input.lastKeyCodeTime &&
          view.someProp('handleKeyDown', (f) => f(view, keyEvent(13, 'Enter')) == true) == true) {
        return;
      }
      var tr = view.state.tr.setSelection(newSel);
      if (origin == 'pointer') {
        tr.setMeta('pointer', true);
      } else if (origin == 'key') {
        tr.scrollIntoView();
      }
      if (compositionID != 0) {
        tr.setMeta('composition', compositionID);
      }
      view.dispatch(tr);
    }
    return;
  }

  final $before = view.state.doc.resolve(from_);
  final shared = $before.sharedDepth(to_);
  int from = $before.before(shared + 1);
  int to = view.state.doc.resolve(to_).after(shared + 1);

  final sel = view.state.selection;
  final parse = parseBetween(view, from, to);

  final doc = view.state.doc;
  final compare = doc.slice(parse.from, parse.to);
  int preferredPos;
  String preferredSide;
  
  if (view.input.lastKeyCode == 8 && DateTime.now().millisecondsSinceEpoch - 100 < view.input.lastKeyCodeTime) {
    preferredPos = view.state.selection.to;
    preferredSide = 'end';
  } else {
    preferredPos = view.state.selection.from;
    preferredSide = 'start';
  }
  view.input.lastKeyCode = 0;

  DiffResult? change = findDiff(compare.content, parse.doc.content, parse.from, preferredPos, preferredSide);
  if (change != null) view.input.domChangeCount++;
  
  if ((browser.ios && view.input.lastIOSEnter > DateTime.now().millisecondsSinceEpoch - 225 || browser.android) &&
      addedNodes.any((n) => n.nodeType == 1 && !_isInline.hasMatch(n.nodeName)) &&
      (change == null || change.endA >= change.endB) &&
      view.someProp('handleKeyDown', (f) => f(view, keyEvent(13, 'Enter')) == true) == true) {
    view.input.lastIOSEnter = 0;
    return;
  }

  if (change == null) {
    if (typeOver &&
        sel is TextSelection &&
        !sel.empty &&
        sel.headRes.sameParent(sel.anchorRes) &&
        !view.composing &&
        !(parse.sel != null && parse.sel!.anchor != parse.sel!.head)) {
      change = DiffResult(sel.from, sel.to, sel.to);
    } else {
      if (parse.sel != null) {
        final newSel = resolveSelection(view, view.state.doc, parse.sel!);
        if (newSel != null && !newSel.eq(view.state.selection)) {
          var tr = view.state.tr.setSelection(newSel);
          if (compositionID != 0) tr.setMeta('composition', compositionID);
          view.dispatch(tr);
        }
      }
      return;
    }
  }

  // Handle overwriting selection
  if (view.state.selection.from < view.state.selection.to &&
      change.start == change.endB &&
      view.state.selection is TextSelection) {
    if (change.start > view.state.selection.from &&
        change.start <= view.state.selection.from + 2 &&
        view.state.selection.from >= parse.from) {
      change.start = view.state.selection.from;
    } else if (change.endA < view.state.selection.to &&
        change.endA >= view.state.selection.to - 2 &&
        view.state.selection.to <= parse.to) {
      change.endB += (view.state.selection.to - change.endA);
      change.endA = view.state.selection.to;
    }
  }

  var $from = parse.doc.resolveNoCache(change.start - parse.from);
  var $to = parse.doc.resolveNoCache(change.endB - parse.from);
  final $fromA = doc.resolve(change.start);
  final inlineChange = $from.sameParent($to) && $from.parent.inlineContent && $fromA.end() >= change.endA;

  if (((browser.ios &&
              view.input.lastIOSEnter > DateTime.now().millisecondsSinceEpoch - 225 &&
              (!inlineChange || addedNodes.any((n) => n.nodeName == 'DIV' || n.nodeName == 'P'))) ||
          (!inlineChange &&
              $from.pos < parse.doc.content.size &&
              (!$from.sameParent($to) || !$from.parent.inlineContent) &&
              $from.pos < $to.pos &&
              !RegExp(r'\S').hasMatch(parse.doc.textBetween($from.pos, $to.pos)))) &&
      view.someProp('handleKeyDown', (f) => f(view, keyEvent(13, 'Enter')) == true) == true) {
    view.input.lastIOSEnter = 0;
    return;
  }

  if (view.state.selection.anchor > change.start &&
      looksLikeBackspace(doc, change.start, change.endA, $from, $to) &&
      view.someProp('handleKeyDown', (f) => f(view, keyEvent(8, 'Backspace')) == true) == true) {
    if (browser.android && browser.chrome) view.domObserver.suppressSelectionUpdates();
    return;
  }

  if (browser.chrome && change.endB == change.start) {
    view.input.lastChromeDelete = DateTime.now().millisecondsSinceEpoch;
  }

  if (browser.android &&
      !inlineChange &&
      $from.start() != $to.start() &&
      $to.parentOffset == 0 &&
      $from.depth == $to.depth &&
      parse.sel != null &&
      parse.sel!.anchor == parse.sel!.head &&
      parse.sel!.head == change.endA) {
    change.endB -= 2;
    $to = parse.doc.resolveNoCache(change.endB - parse.from);
    Timer(const Duration(milliseconds: 20), () {
      view.someProp('handleKeyDown', (f) => f(view, keyEvent(13, 'Enter')));
    });
  }

  final chFrom = change.start;
  final chTo = change.endA;

  Transaction mkTr([Transaction? base]) {
    var tr = base ?? view.state.tr;
    if (base == null) {
      tr.replace(chFrom, chTo, parse.doc.slice(change!.start - parse.from, change.endB - parse.from));
    }
    if (parse.sel != null) {
      final newSel = resolveSelection(view, tr.doc, parse.sel!);
      if (newSel != null &&
          !(browser.chrome &&
              view.composing &&
              newSel.empty &&
              (change!.start != change.endB || view.input.lastChromeDelete < DateTime.now().millisecondsSinceEpoch - 100) &&
              (newSel.head == chFrom || newSel.head == tr.mapping.mapResult(chTo).pos - 1))) {
        tr.setSelection(newSel);
      }
    }
    if (compositionID != 0) tr.setMeta('composition', compositionID);
    tr.scrollIntoView();
    return tr;
  }

  MarkChangeResult? markChange;
  if (inlineChange) {
    if ($from.pos == $to.pos) {
      final tr = mkTr(view.state.tr..delete(chFrom, chTo));
      final marks = doc.resolve(change.start).marksAcross(doc.resolve(change.endA));
      if (marks != null) tr.ensureMarks(marks);
      view.dispatch(tr);
    } else if (change.endA == change.endB &&
        (markChange = isMarkChange($from.parent.content.cut($from.parentOffset, $to.parentOffset),
                $fromA.parent.content.cut($fromA.parentOffset, change.endA - $fromA.start()))) !=
            null) {
      final tr = mkTr(view.state.tr);
      if (markChange!.type == 'add') {
        tr.addMark(chFrom, chTo, markChange.mark!);
      } else {
        tr.removeMark(chFrom, chTo, markChange.mark!);
      }
      view.dispatch(tr);
    } else if ($from.parent.child($from.index()).isText && $from.index() == $to.index() - ($to.textOffset == 0 ? 1 : 0)) {
      final text = $from.parent.textBetween($from.parentOffset, $to.parentOffset);
      Transaction deflt() => mkTr(view.state.tr..insertText(text, chFrom, chTo));
      if (view.someProp('handleTextInput', (f) => f(view, chFrom, chTo, text, deflt)) != true) {
        view.dispatch(deflt());
      }
    } else {
      view.dispatch(mkTr());
    }
  } else {
    view.dispatch(mkTr());
  }
}

Selection? resolveSelection(EditorView view, PMNode doc, ParseSel parsedSel) {
  if (parsedSel.anchor > doc.content.size || parsedSel.head > doc.content.size) return null;
  return selectionBetween(view, doc.resolve(parsedSel.anchor), doc.resolve(parsedSel.head));
}

class MarkChangeResult {
  final Mark? mark;
  final String type;
  MarkChangeResult(this.mark, this.type);
}

MarkChangeResult? isMarkChange(Fragment cur, Fragment prev) {
  final curMarks = cur.firstChild!.marks;
  final prevMarks = prev.firstChild!.marks;
  var added = curMarks;
  var removed = prevMarks;
  String? type;
  Mark? mark;
  PMNode Function(PMNode) update;

  for (int i = 0; i < prevMarks.length; i++) {
    added = prevMarks[i].removeFromSet(added);
  }
  for (int i = 0; i < curMarks.length; i++) {
    removed = curMarks[i].removeFromSet(removed);
  }
  
  if (added.length == 1 && removed.isEmpty) {
    mark = added[0];
    type = 'add';
    update = (PMNode node) => node.mark(mark!.addToSet(node.marks));
  } else if (added.isEmpty && removed.length == 1) {
    mark = removed[0];
    type = 'remove';
    update = (PMNode node) => node.mark(mark!.removeFromSet(node.marks));
  } else {
    return null;
  }

  final updated = <PMNode>[];
  for (int i = 0; i < prev.childCount; i++) {
    updated.add(update(prev.child(i)));
  }
  if (Fragment(updated).eq(cur)) {
    return MarkChangeResult(mark, type);
  }
  return null;
}

bool looksLikeBackspace(PMNode old, int start, int end, ResolvedPos $newStart, ResolvedPos $newEnd) {
  if (end - start <= $newEnd.pos - $newStart.pos || skipClosingAndOpening($newStart, true, false) < $newEnd.pos) {
    return false;
  }

  final $start = old.resolve(start);

  if (!$newStart.parent.isTextblock) {
    final after = $start.nodeAfter;
    return after != null && end == start + after.nodeSize;
  }

  if ($start.parentOffset < $start.parent.content.size || !$start.parent.isTextblock) {
    return false;
  }
  
  final $next = old.resolve(skipClosingAndOpening($start, true, true));
  if (!$next.parent.isTextblock || $next.pos > end || skipClosingAndOpening($next, true, false) < end) {
    return false;
  }

  return $newStart.parent.content.cut($newStart.parentOffset).eq($next.parent.content);
}

int skipClosingAndOpening(ResolvedPos $pos, bool fromEnd, bool mayOpen) {
  int depth = $pos.depth;
  int end = fromEnd ? $pos.end() : $pos.pos;
  while (depth > 0 && (fromEnd || $pos.indexAfter(depth) == $pos.node(depth).childCount)) {
    depth--;
    end++;
    fromEnd = false;
  }
  if (mayOpen) {
    PMNode? next = $pos.node(depth).maybeChild($pos.indexAfter(depth));
    while (next != null && !next.isLeaf) {
      next = next.firstChild;
      end++;
    }
  }
  return end;
}

DiffResult? findDiff(Fragment a, Fragment b, int pos, int preferredPos, String preferredSide) {
  int? start = a.findDiffStart(b, pos);
  int lenA = pos + a.size;
  int lenB = pos + b.size;
  if (start == null) return null;
  final endDiff = a.findDiffEnd(b, lenA, lenB)!;
  int endA = endDiff.a;
  int endB = endDiff.b;
  
  if (preferredSide == 'end') {
    int adjust = 0;
    final minEnd = endA < endB ? endA : endB;
    if (start - minEnd > 0) adjust = start - minEnd;
    preferredPos -= endA + adjust - start;
  }
  
  if (endA < start && lenA < lenB) {
    int move = preferredPos <= start && preferredPos >= endA ? start - preferredPos : 0;
    start -= move;
    endB = start + (endB - endA);
    endA = start;
  } else if (endB < start) {
    int move = preferredPos <= start && preferredPos >= endB ? start - preferredPos : 0;
    start -= move;
    endA = start + (endA - endB);
    endB = start;
  }
  return DiffResult(start, endA, endB);
}
