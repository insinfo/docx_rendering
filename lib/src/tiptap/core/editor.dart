import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../prosemirror/commands/index.dart';
import '../../prosemirror/history/history.dart';
import '../../prosemirror/keymap/keymap.dart';
import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/to_dom.dart';
import '../../prosemirror/schema_list/index.dart';
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

  final _updateController = StreamController<Transaction>.broadcast();
  final _selectionUpdateController = StreamController<Transaction>.broadcast();
  final _focusController = StreamController<void>.broadcast();
  final _blurController = StreamController<void>.broadcast();
  JSFunction? _focusListener;
  JSFunction? _blurListener;

  /// Fired after every transaction that changed the document.
  Stream<Transaction> get onUpdate => _updateController.stream;

  /// Fired after every transaction that moved the selection (or changed
  /// the document, which implicitly maps the selection).
  Stream<Transaction> get onSelectionUpdate =>
      _selectionUpdateController.stream;

  /// Fired when the editable DOM receives focus.
  Stream<void> get onFocus => _focusController.stream;

  /// Fired when the editable DOM loses focus.
  Stream<void> get onBlur => _blurController.stream;

  TiptapEditor(EditorOptions options) {
    extensionManager = ExtensionManager(options.extensions);
    final schema = extensionManager.createSchema();
    final hasHistoryExtension =
        options.extensions.any((e) => e is Extension && e.name == 'history');
    _plugins = _defaultPlugins(
        schema, [...extensionManager.createPlugins(), ...options.plugins],
        includeHistory: !hasHistoryExtension);
    state = EditorState.create(EditorStateConfig(
      schema: schema,
      doc: options.content ?? schema.topNodeType.createAndFill(),
      plugins: _plugins,
    ));

    if (options.element != null) {
      view = EditorView(options.element, _viewProps());
      _attachFocusListeners();
    }
  }

  CommandManager get chain => CommandManager(this);

  String getHTML() {
    final wrap = web.document.createElement('div') as web.HTMLElement;
    DOMSerializer.fromSchema(state.schema)
        .serializeFragment(state.doc.content, target: wrap);
    return (wrap as JSObject).getProperty<JSString>('innerHTML'.toJS).toDart;
  }

  dynamic getJSON() => state.doc.toJSON();

  /// Replaces the complete document, including attributes on the top-level
  /// node, in a single transaction.
  ///
  /// Replacing only `doc.content` silently loses section geometry and opaque
  /// DOCX header/footer payloads. This method is the canonical path for whole
  /// document imports such as DOCX and Quill Delta.
  void setDocument(PMNode document) {
    if (document.type != state.doc.type) {
      throw ArgumentError('Document must use the editor top node type.');
    }
    final tr = state.tr;
    for (final name in state.doc.type.attrs.keys) {
      tr.setDocAttribute(name, document.attrs[name]);
    }
    tr.replaceWith(0, state.doc.content.size, document.content);
    dispatchTransaction(tr);
  }

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
      if (state.selection.empty) {
        final $from = state.selection.$from;
        for (var depth = $from.depth; depth >= 0; depth--) {
          final node = $from.node(depth);
          if (node.type == nodeType && _attrsMatch(node.attrs, attrs)) {
            return true;
          }
        }
      }
      var active = false;
      state.doc.nodesBetween(selectionFrom, selectionTo,
          (node, pos, parent, index) {
        if (node.type == nodeType && _attrsMatch(node.attrs, attrs)) {
          active = true;
          return false;
        }
        return true;
      });
      return active;
    }
    return false;
  }

  bool _attrsMatch(
      Map<String, dynamic> nodeAttrs, Map<String, dynamic>? attrs) {
    if (attrs == null) return true;
    for (final entry in attrs.entries) {
      if (nodeAttrs[entry.key] != entry.value) return false;
    }
    return true;
  }

  void destroy() {
    _detachFocusListeners();
    view?.destroy();
    _updateController.close();
    _selectionUpdateController.close();
    _focusController.close();
    _blurController.close();
  }

  /// Applies a transaction to the editor state, updates the view (when
  /// present) and emits the `onUpdate`/`onSelectionUpdate` events.
  void dispatchTransaction(Transaction tr) {
    final selectionBefore = state.selection;
    state = state.apply(tr);
    view?.updateState(state);
    if (tr.docChanged && !_updateController.isClosed) {
      _updateController.add(tr);
    }
    if ((tr.docChanged || !state.selection.eq(selectionBefore)) &&
        !_selectionUpdateController.isClosed) {
      _selectionUpdateController.add(tr);
    }
  }

  DirectEditorProps _viewProps() {
    return DirectEditorProps(
      state: state,
      editable: (_) => _editable,
      dispatchTransaction: dispatchTransaction,
    );
  }

  void _attachFocusListeners() {
    final dom = view?.dom;
    if (dom == null) return;
    _focusListener = (web.Event event) {
      if (!_focusController.isClosed) _focusController.add(null);
    }.toJS;
    _blurListener = (web.Event event) {
      if (!_blurController.isClosed) _blurController.add(null);
    }.toJS;
    (dom as web.EventTarget)
      ..addEventListener('focus', _focusListener)
      ..addEventListener('blur', _blurListener);
  }

  void _detachFocusListeners() {
    final dom = view?.dom;
    if (dom == null) return;
    if (_focusListener != null) {
      (dom as web.EventTarget).removeEventListener('focus', _focusListener);
    }
    if (_blurListener != null) {
      (dom as web.EventTarget).removeEventListener('blur', _blurListener);
    }
  }

  int get selectionFrom => state.selection.from;

  int get selectionTo => state.selection.to;

  List<Plugin> _defaultPlugins(Schema schema, List<Plugin> plugins,
      {bool includeHistory = true}) {
    final bindings = <String, Command>{};
    bindings.addAll(baseKeymap);
    final bold = schema.marks['bold'];
    if (bold != null) bindings['Mod-b'] = toggleMark(bold);
    final italic = schema.marks['italic'];
    if (italic != null) bindings['Mod-i'] = toggleMark(italic);
    final underline = schema.marks['underline'];
    if (underline != null) bindings['Mod-u'] = toggleMark(underline);
    final strike = schema.marks['strike'];
    if (strike != null) bindings['Mod-Shift-x'] = toggleMark(strike);
    final code = schema.marks['code'];
    if (code != null) bindings['Mod-e'] = toggleMark(code);
    final hardBreak = schema.nodes['hardBreak'];
    if (hardBreak != null) {
      Command insertBreak = (state, [dispatch, view]) {
        if (dispatch != null) {
          final tr = state.tr;
          tr.replaceSelectionWith(hardBreak.create());
          tr.scrollIntoView();
          dispatch(tr);
        }
        return true;
      };
      bindings['Shift-Enter'] = insertBreak;
      bindings['Mod-Enter'] = insertBreak;
    }
    final listItem = schema.nodes['listItem'];
    if (listItem != null) {
      final baseEnter = bindings['Enter'];
      bindings['Enter'] = baseEnter != null
          ? chainCommands([splitListItem(listItem), baseEnter])
          : splitListItem(listItem);
      bindings['Tab'] = sinkListItem(listItem);
      bindings['Shift-Tab'] = liftListItem(listItem);
    }
    if (includeHistory) {
      bindings['Mod-z'] = undo;
      bindings['Shift-Mod-z'] = redo;
      bindings['Mod-y'] = redo;
    }
    return [
      if (includeHistory) history(),
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
