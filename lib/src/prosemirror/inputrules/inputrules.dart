import 'dart:math';
import '../state/index.dart';

typedef InputRuleHandler = Transaction? Function(EditorState state, RegExpMatch match, int start, int end);

Transaction? Function(EditorState state, RegExpMatch match, int start, int end) stringHandler(String string) {
  return (state, match, start, end) {
    String insert = string;
    final match0 = match.group(0) ?? "";
    final match1 = match.groupCount >= 1 ? match.group(1) : null;
    if (match1 != null) {
      int offset = match0.lastIndexOf(match1);
      insert += match0.substring(offset + match1.length);
      start += offset;
      int cutOff = start - end;
      if (cutOff > 0) {
        insert = match0.substring(offset - cutOff, offset) + insert;
        start = end;
      }
    }
    return state.tr.insertText(insert, start, end);
  };
}

class InputRule {
  final RegExp match;
  final InputRuleHandler handler;
  final bool undoable;
  final dynamic inCode; // bool or String ("only")
  final bool inCodeMark;

  InputRule(
    this.match,
    dynamic handlerVal, {
    this.undoable = true,
    this.inCode = false,
    this.inCodeMark = true,
  }) : handler = handlerVal is String ? stringHandler(handlerVal) : handlerVal as InputRuleHandler;
}

const int MAX_MATCH = 500;

class InputRuleState {
  final Transaction transform;
  final int from;
  final int to;
  final String text;

  InputRuleState({
    required this.transform,
    required this.from,
    required this.to,
    required this.text,
  });
}

final PluginKey inputRulesKey = PluginKey("inputRules");

Plugin inputRules({required List<InputRule> rules}) {
  late final Plugin plugin;
  plugin = Plugin(PluginSpec(
    key: inputRulesKey,
    state: StateField(
      init: (config, instance) => null,
      apply: (tr, prev, oldState, newState) {
        final stored = tr.getMeta(inputRulesKey);
        if (stored != null) return stored;
        return (tr.selectionSet || tr.docChanged) ? null : prev;
      },
    ),
    extraProps: {
      "isInputRules": true,
    },
    props: {
      "handleTextInput": (dynamic view, dynamic from, dynamic to, dynamic text) {
        return run(view, from as int, to as int, text as String, rules, plugin);
      },
      "handleDOMEvents": {
        "compositionend": (dynamic view, dynamic e) {
          // Trigger after composition ends
          // Web only, wrap in try-catch to be VM-safe
          try {
            final sel = view.state.selection;
            final cursor = sel.$cursor;
            if (cursor != null) {
              run(view, cursor.pos as int, cursor.pos as int, "", rules, plugin);
            }
          } catch (_) {}
          return false;
        }
      }
    },
  ));
  return plugin;
}

bool run(dynamic view, int from, int to, String text, List<InputRule> rules, Plugin plugin) {
  // view is EditorView
  if (view.composing == true) return false;
  final state = view.state as EditorState;
  final $from = state.doc.resolve(from);
  final textBefore = $from.parent.textBetween(
    max(0, $from.parentOffset - MAX_MATCH),
    $from.parentOffset,
    blockSeparator: null,
    leafText: (node) => "\uFFFC",
  ) + text;

  for (int i = 0; i < rules.length; i++) {
    final rule = rules[i];
    if (!rule.inCodeMark && $from.marks().any((m) => m.type.spec.code == true)) continue;
    if ($from.parent.type.spec.code == true) {
      if (rule.inCode == false) continue;
    } else if (rule.inCode == "only") {
      continue;
    }

    final matches = rule.match.allMatches(textBefore);
    if (matches.isEmpty) continue;
    final match = matches.last;
    final match0 = match.group(0) ?? "";
    if (match0.length < text.length) continue;
    if (match.end != textBefore.length) continue;

    final startPos = from - (match0.length - text.length);
    if (!rule.inCodeMark) {
      bool hasMark = false;
      state.doc.nodesBetween(startPos, $from.pos, (node, pos, parent, index) {
        if (node.isInline && node.marks.any((m) => m.type.spec.code == true)) {
          hasMark = true;
        }
        return true;
      });
      if (hasMark) continue;
    }

    final tr = rule.handler(state, match, startPos, to);
    if (tr == null) continue;
    if (rule.undoable) {
      tr.setMeta(inputRulesKey, InputRuleState(transform: tr, from: from, to: to, text: text));
    }
    view.dispatch(tr);
    return true;
  }
  return false;
}

bool undoInputRule(EditorState state, [void Function(Transaction tr)? dispatch, dynamic view]) {
  final plugins = state.plugins;
  for (int i = 0; i < plugins.length; i++) {
    final plugin = plugins[i];
    if (plugin.spec.extraProps["isInputRules"] == true) {
      final undoable = plugin.getState(state) as InputRuleState?;
      if (undoable != null) {
        if (dispatch != null) {
          final tr = state.tr;
          final toUndo = undoable.transform;
          for (int j = toUndo.steps.length - 1; j >= 0; j--) {
            tr.step(toUndo.steps[j].invert(toUndo.docs[j]));
          }
          if (undoable.text.isNotEmpty) {
            final marks = tr.doc.resolve(undoable.from).marks();
            tr.replaceWith(undoable.from, undoable.to, state.schema.text(undoable.text, marks));
          } else {
            tr.delete(undoable.from, undoable.to);
          }
          dispatch(tr);
        }
        return true;
      }
    }
  }
  return false;
}
