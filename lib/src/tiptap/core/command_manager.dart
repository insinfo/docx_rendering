import '../../prosemirror/commands/index.dart' as commands;
import '../../prosemirror/history/history.dart' as history;
import '../../prosemirror/model/index.dart';
import '../../prosemirror/schema_list/index.dart' as schema_list;
import '../../prosemirror/state/index.dart';
import 'commands.dart';
import 'editor.dart';

class CommandManager {
  final TiptapEditor editor;
  final List<Command> _commands = [];

  CommandManager(this.editor);

  /// Appends an arbitrary ProseMirror command to the chain.
  CommandManager command(Command cmd) {
    _commands.add(cmd);
    return this;
  }

  CommandManager focus() {
    _commands.add((state, [dispatch, view]) {
      editor.view?.focus();
      return true;
    });
    return this;
  }

  // ---------------------------------------------------------------- marks

  CommandManager _toggleMark(String name, [Map<String, dynamic>? attrs]) {
    _commands.add((state, [dispatch, view]) {
      final mark = state.schema.marks[name];
      if (mark == null) return false;
      return commands.toggleMark(mark, attrs)(state, dispatch, view);
    });
    return this;
  }

  CommandManager toggleBold() => _toggleMark('bold');

  CommandManager toggleItalic() => _toggleMark('italic');

  CommandManager toggleUnderline() => _toggleMark('underline');

  CommandManager toggleStrike() => _toggleMark('strike');

  CommandManager toggleCode() => _toggleMark('code');

  CommandManager toggleHighlight([String? color]) =>
      _toggleMark('highlight', color != null ? {'color': color} : null);

  CommandManager setLink(String href, {String? title, String? target}) {
    _commands.add(setMarkCommand(
        'link', {'href': href, 'title': title, 'target': target}));
    return this;
  }

  CommandManager unsetLink() {
    _commands.add(unsetMarkCommand('link'));
    return this;
  }

  CommandManager setColor(String color) {
    _commands.add(updateMarkAttrsCommand('textStyle', {'color': color}));
    return this;
  }

  CommandManager setFontFamily(String fontFamily) {
    _commands
        .add(updateMarkAttrsCommand('textStyle', {'fontFamily': fontFamily}));
    return this;
  }

  CommandManager setFontSize(String fontSize) {
    _commands.add(updateMarkAttrsCommand('textStyle', {'fontSize': fontSize}));
    return this;
  }

  CommandManager unsetColor() {
    _commands.add(unsetMarkCommand('textStyle'));
    return this;
  }

  // --------------------------------------------------------------- blocks

  CommandManager setParagraph() {
    _commands.add((state, [dispatch, view]) {
      final paragraph = state.schema.nodes['paragraph'];
      if (paragraph == null) return false;
      return commands.setBlockType(paragraph)(state, dispatch, view);
    });
    return this;
  }

  CommandManager setHeading(int level) {
    _commands.add((state, [dispatch, view]) {
      final heading = state.schema.nodes['heading'];
      if (heading == null) return false;
      return commands.setBlockType(heading, {'level': level})(
          state, dispatch, view);
    });
    return this;
  }

  /// Sets the heading when not active; reverts to paragraph otherwise.
  CommandManager toggleHeading(int level) {
    _commands.add((state, [dispatch, view]) {
      final heading = state.schema.nodes['heading'];
      final paragraph = state.schema.nodes['paragraph'];
      if (heading == null || paragraph == null) return false;
      if (editor.isActive('heading', {'level': level})) {
        return commands.setBlockType(paragraph)(state, dispatch, view);
      }
      return commands.setBlockType(heading, {'level': level})(
          state, dispatch, view);
    });
    return this;
  }

  CommandManager setTextAlign(String alignment) {
    _commands
        .add(setTextAlignCommand(const ['paragraph', 'heading'], alignment));
    return this;
  }

  CommandManager unsetTextAlign() {
    _commands.add(setTextAlignCommand(const ['paragraph', 'heading'], null));
    return this;
  }

  // ---------------------------------------------------------------- lists

  Command _toggleList(String listName) {
    return (state, [dispatch, view]) {
      final listType = state.schema.nodes[listName];
      final itemType = state.schema.nodes['listItem'];
      if (listType == null || itemType == null) return false;
      final $from = state.selection.$from;
      for (var depth = $from.depth; depth > 0; depth--) {
        if ($from.node(depth).type == listType) {
          return schema_list.liftListItem(itemType)(state, dispatch, view);
        }
      }
      return schema_list.wrapInList(listType)(state, dispatch, view);
    };
  }

  CommandManager toggleBulletList() {
    _commands.add(_toggleList('bulletList'));
    return this;
  }

  CommandManager toggleOrderedList() {
    _commands.add(_toggleList('orderedList'));
    return this;
  }

  CommandManager liftListItem() {
    _commands.add((state, [dispatch, view]) {
      final itemType = state.schema.nodes['listItem'];
      if (itemType == null) return false;
      return schema_list.liftListItem(itemType)(state, dispatch, view);
    });
    return this;
  }

  CommandManager sinkListItem() {
    _commands.add((state, [dispatch, view]) {
      final itemType = state.schema.nodes['listItem'];
      if (itemType == null) return false;
      return schema_list.sinkListItem(itemType)(state, dispatch, view);
    });
    return this;
  }

  // ------------------------------------------------------------- inserção

  CommandManager setHardBreak() {
    _commands.add((state, [dispatch, view]) {
      final hardBreak = state.schema.nodes['hardBreak'];
      if (hardBreak == null) return false;
      return insertNodeCommand(hardBreak.create())(state, dispatch, view);
    });
    return this;
  }

  CommandManager setHorizontalRule() {
    _commands.add((state, [dispatch, view]) {
      final hr = state.schema.nodes['horizontalRule'];
      if (hr == null) return false;
      return insertNodeCommand(hr.create())(state, dispatch, view);
    });
    return this;
  }

  CommandManager setImage(String src, {String? alt, String? title}) {
    _commands.add((state, [dispatch, view]) {
      final image = state.schema.nodes['image'];
      if (image == null) return false;
      return insertNodeCommand(
              image.create({'src': src, 'alt': alt, 'title': title}))(
          state, dispatch, view);
    });
    return this;
  }

  CommandManager insertTable(
      {int rows = 3, int cols = 3, bool withHeaderRow = true}) {
    _commands.add((state, [dispatch, view]) {
      final table = state.schema.nodes['table'];
      final rowType = state.schema.nodes['tableRow'];
      final cellType = state.schema.nodes['tableCell'];
      final headerType = state.schema.nodes['tableHeader'];
      final paragraph = state.schema.nodes['paragraph'];
      if (table == null ||
          rowType == null ||
          cellType == null ||
          paragraph == null) {
        return false;
      }
      final rowNodes = <PMNode>[];
      for (var r = 0; r < rows; r++) {
        final type = withHeaderRow && r == 0 && headerType != null
            ? headerType
            : cellType;
        final cells = [
          for (var c = 0; c < cols; c++)
            type.create(null, Fragment.from(paragraph.create()))
        ];
        rowNodes.add(rowType.create(null, Fragment.fromArray(cells)));
      }
      final node = table.create(null, Fragment.fromArray(rowNodes));
      return insertNodeCommand(node)(state, dispatch, view);
    });
    return this;
  }

  // -------------------------------------------------------------- history

  CommandManager undo() {
    _commands.add(history.undo);
    return this;
  }

  CommandManager redo() {
    _commands.add(history.redo);
    return this;
  }

  bool run() {
    var handled = false;
    for (final command in _commands) {
      handled =
          command(editor.state, editor.dispatchTransaction, editor.view) ||
              handled;
    }
    _commands.clear();
    return handled;
  }
}
