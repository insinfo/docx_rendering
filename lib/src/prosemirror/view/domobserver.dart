import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dom.dart';
import 'index.dart';
import 'viewdesc.dart';

typedef DOMChangeHandler = void Function(
    int from, int to, bool typeOver, List<web.Node> added);

class SelectionState {
  final web.Node? anchorNode;
  final int anchorOffset;
  final web.Node? focusNode;
  final int focusOffset;

  const SelectionState(
      this.anchorNode, this.anchorOffset, this.focusNode, this.focusOffset);

  factory SelectionState.fromRange(DOMSelectionRange range) => SelectionState(
      range.anchorNode, range.anchorOffset, range.focusNode, range.focusOffset);

  bool eq(DOMSelectionRange range) {
    return anchorNode == range.anchorNode &&
        anchorOffset == range.anchorOffset &&
        focusNode == range.focusNode &&
        focusOffset == range.focusOffset;
  }
}

final observeOptions = web.MutationObserverInit(
    childList: true,
    characterData: true,
    characterDataOldValue: true,
    attributes: true,
    attributeOldValue: true,
    subtree: true);

bool get useCharData => true;

class DOMObserver {
  final EditorView view;
  final DOMChangeHandler? handleDOMChange;
  final List<ViewMutationRecord> queue = [];
  late final web.MutationObserver observer;
  SelectionState currentSelection = const SelectionState(null, 0, null, 0);
  bool flushingSoon = false;
  bool selectionUpdatesSuppressed = false;
  bool active = false;

  DOMObserver(this.view, [this.handleDOMChange]) {
    observer = web.MutationObserver(
        ((JSArray<web.MutationRecord> records, web.MutationObserver observer) {
      final dartRecords = records.toDart;
      for (final record in dartRecords) {
        queue.add(ViewMutationRecord.fromMutation(record));
      }
      flushSoon();
    }).toJS);
  }

  void start() {
    if (active) return;
    active = true;
    observer.observe(view.dom, observeOptions);
    setCurSelection();
  }

  void stop() {
    if (!active) return;
    active = false;
    observer.disconnect();
  }

  void flush() {
    flushingSoon = false;
    final records = pendingRecords();
    if (records.isEmpty) return;
    int from = view.state.doc.content.size;
    int to = 0;
    final added = <web.Node>[];
    for (final record in records) {
      final range = registerMutation(record, added);
      if (range != null) {
        if (range.from < from) from = range.from;
        if (range.to > to) to = range.to;
      }
    }
    if (from <= to) {
      try {
        handleDOMChange?.call(from, to, false, added);
      } catch (_) {
        // Native editing can briefly produce DOM ranges that the still-partial
        // DOM change reader cannot reconcile. Keep the editor alive and let the
        // next observer flush resynchronize.
      }
    }
    setCurSelection();
  }

  void suppressSelectionUpdates() {
    selectionUpdatesSuppressed = true;
    Timer.run(() => selectionUpdatesSuppressed = false);
  }

  void onSelectionChange() {
    if (selectionUpdatesSuppressed) return;
    queue.add(ViewMutationRecord.selection(view.dom));
    flushSoon();
  }

  void setCurSelection() {
    currentSelection = SelectionState.fromRange(view.domSelectionRange());
  }

  bool ignoreSelectionChange(dynamic sel) => selectionUpdatesSuppressed;

  List<ViewMutationRecord> pendingRecords() {
    final native = observer.takeRecords();
    for (int i = 0; i < native.length; i++) {
      queue.add(ViewMutationRecord.fromMutation(native[i]));
    }
    final result = List<ViewMutationRecord>.from(queue);
    queue.clear();
    return result;
  }

  void flushSoon() {
    if (flushingSoon) return;
    flushingSoon = true;
    scheduleMicrotask(flush);
  }

  void forceFlush() {
    flush();
  }

  void disconnectSelection() {
    suppressSelectionUpdates();
  }

  void connectSelection() {
    setCurSelection();
  }

  MutationRange? registerMutation(
      ViewMutationRecord record, List<web.Node> added) {
    if (record.type == 'selection') return null;
    final desc = view.docView.nearestDesc(record.target);
    if (desc == null || desc.ignoreMutation(record)) return null;
    added.addAll(record.addedNodes);
    if (desc.parent == null) {
      return MutationRange(0, view.state.doc.content.size);
    }
    final from = desc.posBefore;
    return MutationRange(from, from + desc.size);
  }
}

class MutationRange {
  final int from;
  final int to;

  MutationRange(this.from, this.to);
}

DOMSelectionRange? safariShadowSelectionRange(EditorView view) => null;
