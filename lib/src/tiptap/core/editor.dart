import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';
import '../../prosemirror/view/index.dart';
import 'command_manager.dart';
import 'extension.dart';
import 'extension_manager.dart';

class EditorOptions {
  final List<AnyExtension> extensions;
  final PMNode? content;
  final web.HTMLElement? element;

  const EditorOptions({
    required this.extensions,
    this.content,
    this.element,
  });
}

class TiptapEditor {
  late EditorState state;
  EditorView? view;
  late final ExtensionManager extensionManager;

  TiptapEditor(EditorOptions options) {
    extensionManager = ExtensionManager(options.extensions);
    final schema = extensionManager.createSchema();
    state = EditorState.create(EditorStateConfig(
      schema: schema,
      doc: options.content ?? schema.topNodeType.createAndFill(),
      plugins: const [],
    ));

    if (options.element != null) {
      view = EditorView(
        options.element,
        DirectEditorProps(
          state: state,
          plugins: const [],
          dispatchTransaction: (tr) {
            state = state.apply(tr);
            view?.updateState(state);
          },
        ),
      );
    }
  }

  CommandManager get chain => CommandManager(this);

  void destroy() {
    view?.destroy();
  }
}
