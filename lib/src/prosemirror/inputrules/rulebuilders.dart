import '../transform/index.dart';
import '../state/index.dart';
import '../model/index.dart';
import 'inputrules.dart';

InputRule wrappingInputRule(
  RegExp regexp,
  NodeType nodeType, {
  dynamic attrs, // Map<String, dynamic>? or Map<String, dynamic>? Function(RegExpMatch)
  bool Function(RegExpMatch match, PMNode node)? joinPredicate,
}) {
  return InputRule(regexp, (EditorState state, RegExpMatch match, int start, int end) {
    final Map<String, dynamic>? attrsMap = attrs is Function
        ? attrs(match) as Map<String, dynamic>?
        : attrs as Map<String, dynamic>?;
    final tr = state.tr;
    tr.delete(start, end);
    final $start = tr.doc.resolve(start);
    final range = $start.blockRange();
    if (range == null) return null;
    final wrapping = findWrapping(range, nodeType, attrsMap);
    if (wrapping == null) return null;
    tr.wrap(range, wrapping);
    final before = tr.doc.resolve(start - 1).nodeBefore;
    if (before != null &&
        before.type == nodeType &&
        canJoin(tr.doc, start - 1) &&
        (joinPredicate == null || joinPredicate(match, before))) {
      tr.join(start - 1);
    }
    return tr;
  });
}

InputRule textblockTypeInputRule(
  RegExp regexp,
  NodeType nodeType, {
  dynamic attrs, // Map<String, dynamic>? or Map<String, dynamic>? Function(RegExpMatch)
}) {
  return InputRule(regexp, (EditorState state, RegExpMatch match, int start, int end) {
    final $start = state.doc.resolve(start);
    final Map<String, dynamic>? attrsMap = attrs is Function
        ? attrs(match) as Map<String, dynamic>?
        : attrs as Map<String, dynamic>?;
    if (!$start.node(-1).canReplaceWith($start.index(-1), $start.indexAfter(-1), nodeType)) return null;
    final tr = state.tr;
    tr.delete(start, end);
    tr.setBlockType(start, start, nodeType, attrsMap);
    return tr;
  });
}
