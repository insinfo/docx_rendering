import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';
import '../../prosemirror/transform/index.dart' show insertPoint;

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
    if (!node.isInline) {
      final selection = state.selection;
      final resolved = selection.fromRes;
      var point = insertPoint(state.doc, selection.from, node.type);
      // A cursor in the middle of a textblock is not itself a valid insertion
      // point for a block. Walk outwards and place the block immediately after
      // the nearest ancestor whose parent accepts it.
      if (point == null) {
        for (var depth = resolved.depth; depth > 0; depth--) {
          final parent = resolved.node(depth - 1);
          final index = resolved.indexAfter(depth - 1);
          if (parent.canReplaceWith(index, index, node.type)) {
            point = resolved.after(depth);
            break;
          }
        }
      }
      if (point == null) return false;
      if (dispatch != null) {
        final tr = state.tr..insert(point, node);
        dispatch(tr.scrollIntoView());
      }
      return true;
    }
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

/// Mescla [attrs] à instância atual da marca em vez de apagar seus demais
/// atributos. Em uma seleção, preserva cor/fonte/tamanho de cada run de texto.
Command updateMarkAttrsCommand(String markName, Map<String, dynamic> attrs) {
  return (state, [dispatch, view]) {
    final markType = state.schema.marks[markName];
    if (markType == null) return false;
    final selection = state.selection;
    if (dispatch == null) return true;
    final tr = state.tr;

    if (selection.empty) {
      final cursor = selection is TextSelection ? selection.$cursor : null;
      final marks = state.storedMarks ?? cursor?.marks() ?? const <Mark>[];
      final existing = markType.isInSet(marks);
      tr.addStoredMark(markType.create({
        if (existing != null) ...existing.attrs,
        ...attrs,
      }));
      dispatch(tr);
      return true;
    }

    state.doc.nodesBetween(selection.from, selection.to,
        (node, pos, parent, index) {
      if (!node.isText) return true;
      final from = pos < selection.from ? selection.from : pos;
      final nodeEnd = pos + node.nodeSize;
      final to = nodeEnd > selection.to ? selection.to : nodeEnd;
      if (from >= to) return false;
      final existing = markType.isInSet(node.marks);
      tr.addMark(
          from,
          to,
          markType.create({
            if (existing != null) ...existing.attrs,
            ...attrs,
          }));
      return false;
    });
    dispatch(tr);
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
