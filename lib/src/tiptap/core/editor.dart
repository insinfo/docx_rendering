import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../prosemirror/commands/index.dart';
import '../../prosemirror/history/history.dart';
import '../../prosemirror/keymap/keymap.dart';
import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/to_dom.dart';
import '../../prosemirror/state/index.dart';
import '../../prosemirror/view/index.dart';
import 'command_manager.dart';
import 'extension.dart';
import 'extension_manager.dart';

class EditorOptions {
  final List<AnyExtension> extensions;
  final PMNode? content;
  final web.HTMLElement? element;
  final List<Plugin> plugins;

  const EditorOptions({
    required this.extensions,
    this.content,
    this.element,
    this.plugins = const [],
  });
}

class TiptapEditor {
  late EditorState state;
  EditorView? view;
  late final ExtensionManager extensionManager;
  bool _editable = true;
  late final List<Plugin> _plugins;

  TiptapEditor(EditorOptions options) {
    extensionManager = ExtensionManager(options.extensions);
    final schema = extensionManager.createSchema();
    _plugins = _defaultPlugins(schema, options.plugins);
    state = EditorState.create(EditorStateConfig(
      schema: schema,
      doc: options.content ?? schema.topNodeType.createAndFill(),
      plugins: _plugins,
    ));

    if (options.element != null) {
      view = EditorView(options.element, _viewProps());
    }
  }

  CommandManager get chain => CommandManager(this);

  String getHTML() {
    final currentView = view;
    if (currentView != null) {
      return (currentView.dom as JSObject)
          .getProperty<JSString>('innerHTML'.toJS)
          .toDart;
    }
    final wrap = web.document.createElement('div') as web.HTMLElement;
    DOMSerializer.fromSchema(state.schema)
        .serializeFragment(state.doc.content, target: wrap);
    return (wrap as JSObject).getProperty<JSString>('innerHTML'.toJS).toDart;
  }

  dynamic getJSON() => state.doc.toJSON();

  void setEditable(bool editable) {
    if (_editable == editable) return;
    _editable = editable;
    view?.update(_viewProps());
  }

  bool isActive(String name, [Map<String, dynamic>? attrs]) {
    final markType = state.schema.marks[name];
    if (markType != null) {
      final selection = state.selection;
      final cursor = selection is TextSelection ? selection.$cursor : null;
      if (cursor != null) {
        return markType.isInSet(state.storedMarks ?? cursor.marks()) != null;
      }
      return state.doc.rangeHasMark(selection.from, selection.to, markType);
    }

    final nodeType = state.schema.nodes[name];
    if (nodeType != null) {
      var active = false;
      state.doc.nodesBetween(selectionFrom, selectionTo,
          (node, pos, parent, index) {
        if (node.type == nodeType) {
          active = true;
          return false;
        }
        return true;
      });
      return active;
    }
    return false;
  }

  void destroy() {
    view?.destroy();
  }

  DirectEditorProps _viewProps() {
    return DirectEditorProps(
      state: state,
      plugins: _plugins,
      editable: (_) => _editable,
      dispatchTransaction: (tr) {
        state = state.apply(tr);
        view?.updateState(state);
      },
    );
  }

  int get selectionFrom => state.selection.from;

  int get selectionTo => state.selection.to;

  List<Plugin> _defaultPlugins(Schema schema, List<Plugin> plugins) {
    final bindings = <String, Command>{};
    bindings.addAll(baseKeymap);
    final bold = schema.marks['bold'];
    if (bold != null) bindings['Mod-b'] = toggleMark(bold);
    final italic = schema.marks['italic'];
    if (italic != null) bindings['Mod-i'] = toggleMark(italic);
    bindings['Mod-z'] = undo;
    bindings['Shift-Mod-z'] = redo;
    bindings['Mod-y'] = redo;
    return [
      history(),
      _nativeInlineShortcutPlugin(),
      keymap(bindings),
      ...plugins,
    ];
  }

  Plugin _nativeInlineShortcutPlugin() {
    return Plugin(PluginSpec(
      props: {
        'handleKeyDown': (EditorView view, dynamic event) {
          if (event is! web.KeyboardEvent) return false;
          final key = event.key.toLowerCase();
          final mod = event.ctrlKey || event.metaKey;
          if (!mod || event.altKey || event.shiftKey) return false;
          if (key == 'b' || key == 'i') {
            event.preventDefault();
            final command = key == 'b' ? 'bold' : 'italic';
            (view.dom.ownerDocument as JSObject)
                .callMethod('execCommand'.toJS, command.toJS, false.toJS);
            return true;
          }
          return false;
        },
      },
    ));
  }
}
