import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';

/// Sets (or clears, when [alignment] is null) the `textAlign` attribute
/// on every selected textblock whose type is one of [typeNames].
Command setTextAlignCommand(List<String> typeNames, String? alignment) {
  return (state, [dispatch, view]) {
    final types = typeNames
        .map((n) => state.schema.nodes[n])
        .whereType<NodeType>()
        .toSet();
    if (types.isEmpty) return false;
    var applicable = false;
    final tr = state.tr;
    for (final range in state.selection.ranges) {
      state.doc.nodesBetween(range.fromRes.pos, range.toRes.pos,
          (node, pos, parent, index) {
        if (types.contains(node.type) && node.attrs.containsKey('textAlign')) {
          applicable = true;
          if (node.attrs['textAlign'] != alignment) {
            tr.setNodeAttribute(pos, 'textAlign', alignment);
          }
        }
        return true;
      });
    }
    if (!applicable) return false;
    if (dispatch != null) {
      tr.scrollIntoView();
      dispatch(tr);
    }
    return true;
  };
}

/// Inserts the given node at the selection, replacing it.
Command insertNodeCommand(PMNode node) {
  return (state, [dispatch, view]) {
    if (dispatch != null) {
      final tr = state.tr;
      tr.replaceSelectionWith(node);
      tr.scrollIntoView();
      dispatch(tr);
    }
    return true;
  };
}

/// Applies a mark with the given attributes to the current selection
/// (does not toggle — replaces any existing instance of the mark).
Command setMarkCommand(String markName, [Map<String, dynamic>? attrs]) {
  return (state, [dispatch, view]) {
    final markType = state.schema.marks[markName];
    if (markType == null) return false;
    final selection = state.selection;
    if (selection.empty) {
      if (dispatch != null) {
        final tr = state.tr;
        tr.addStoredMark(markType.create(attrs));
        dispatch(tr);
      }
      return true;
    }
    if (dispatch != null) {
      final tr = state.tr;
      tr.addMark(selection.from, selection.to, markType.create(attrs));
      dispatch(tr);
    }
    return true;
  };
}

/// Removes the given mark from the current selection.
Command unsetMarkCommand(String markName) {
  return (state, [dispatch, view]) {
    final markType = state.schema.marks[markName];
    if (markType == null) return false;
    final selection = state.selection;
    if (dispatch != null) {
      final tr = state.tr;
      if (selection.empty) {
        tr.removeStoredMark(markType);
      } else {
        tr.removeMark(selection.from, selection.to, markType);
      }
      dispatch(tr);
    }
    return true;
  };
}
