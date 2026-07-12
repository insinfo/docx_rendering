import '../../prosemirror/commands/index.dart' as commands;
import '../../prosemirror/history/history.dart' as history;
import '../../prosemirror/state/index.dart';
import 'editor.dart';

class CommandManager {
  final TiptapEditor editor;
  final List<Command> _commands = [];

  CommandManager(this.editor);

  CommandManager focus() {
    _commands.add((state, [dispatch, view]) {
      editor.view?.focus();
      return true;
    });
    return this;
  }

  CommandManager toggleBold() {
    final mark = editor.state.schema.marks['bold'];
    if (mark != null) _commands.add(commands.toggleMark(mark));
    return this;
  }

  CommandManager toggleItalic() {
    final mark = editor.state.schema.marks['italic'];
    if (mark != null) _commands.add(commands.toggleMark(mark));
    return this;
  }

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
          command(editor.state, editor.view?.dispatch, editor.view) || handled;
    }
    _commands.clear();
    return handled;
  }
}
