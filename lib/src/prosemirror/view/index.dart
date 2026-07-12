import 'package:web/web.dart' as web;

import '../state/index.dart';
import 'decoration.dart';
import 'dom.dart';
import 'domcoords.dart' as domcoords;
import 'domchange.dart';
import 'domobserver.dart';
import 'input.dart';
import 'selection.dart';
import 'viewdesc.dart';

typedef HandleDOMEvents
    = Map<String, dynamic Function(EditorView view, dynamic event)>;
typedef NodeViews = Map<String, dynamic>;
typedef MarkViews = Map<String, dynamic>;
typedef Attributes = Map<String, String>;

class EditorProps {
  final bool Function(EditorState state)? editable;
  final dynamic Function(EditorView view, dynamic event)? handleKeyDown;
  final dynamic Function(EditorView view, dynamic event)? handlePaste;
  final dynamic Function(EditorView view, dynamic event)? handleDrop;
  final dynamic Function(EditorView view, dynamic event)?
      handleScrollToSelection;
  final HandleDOMEvents? handleDOMEvents;
  final Attributes Function(EditorState state)? attributes;
  final dynamic Function(EditorState state)? decorations;
  final NodeViews? nodeViews;
  final MarkViews? markViews;
  final dynamic Function(EditorState state)? editableState;

  const EditorProps({
    this.editable,
    this.handleKeyDown,
    this.handlePaste,
    this.handleDrop,
    this.handleScrollToSelection,
    this.handleDOMEvents,
    this.attributes,
    this.decorations,
    this.nodeViews,
    this.markViews,
    this.editableState,
  });
}

class DirectEditorProps extends EditorProps {
  final EditorState state;
  final List<Plugin>? plugins;
  final void Function(Transaction tr)? dispatchTransaction;

  const DirectEditorProps({
    required this.state,
    this.plugins,
    this.dispatchTransaction,
    super.editable,
    super.handleKeyDown,
    super.handlePaste,
    super.handleDrop,
    super.handleScrollToSelection,
    super.handleDOMEvents,
    super.attributes,
    super.decorations,
    super.nodeViews,
    super.markViews,
    super.editableState,
  });
}

class EditorView {
  late final web.HTMLElement dom;
  EditorState state;
  DirectEditorProps _props;
  final List<Plugin> directPlugins;
  late NodeViewDesc docView;
  late final DOMObserver domObserver;
  late InputState input;
  bool mounted = false;
  bool focused = false;
  web.Node? trackWrites;
  List<dynamic>? markCursor;
  CursorWrapper? cursorWrapper;
  Map<String, dynamic> nodeViews = {};
  ViewDesc? lastSelectedViewDesc;
  Dragging? dragging;
  bool requiresGeckoHackNode = false;
  List<PluginView> pluginViews = [];

  EditorView(web.HTMLElement? place, DirectEditorProps props)
      : state = props.state,
        _props = props,
        directPlugins = List<Plugin>.from(props.plugins ?? const []) {
    dom = web.document.createElement('div') as web.HTMLElement;
    dom.classList.add('ProseMirror');
    editable = getEditable(this);
    dom.setAttribute('contenteditable', editable ? 'true' : 'false');

    if (place != null) {
      place.appendChild(dom);
      mounted = true;
    }

    input = InputState();
    nodeViews = buildNodeViews(this);
    docView = docViewDesc(
        state.doc, computeDocDeco(this), viewDecorations(this), dom, this);
    domObserver = DOMObserver(this, (from, to, typeOver, added) {
      readDOMChange(this, from, to, typeOver, added);
    });
    domObserver.start();
    initInput(this);
    updatePluginViews();
  }

  DirectEditorProps get props => _props;

  void update(DirectEditorProps props) {
    final pluginsChanged = props.plugins != _props.plugins;
    _props = props;
    if (props.plugins != null) {
      directPlugins
        ..clear()
        ..addAll(props.plugins!);
    }
    updateState(props.state);
    if (pluginsChanged) updatePluginViews();
  }

  void updateState(EditorState newState) {
    updateStateInner(newState, _props);
  }

  void updateStateInner(EditorState newState, EditorProps prevProps) {
    final prev = state;
    var updateSel = !newState.selection.eq(prev.selection);
    if (newState.storedMarks != null && composing) {
      clearComposition(this);
      updateSel = true;
    }
    state = newState;
    editable = getEditable(this);
    dom.setAttribute('contenteditable', editable ? 'true' : 'false');
    final innerDeco = viewDecorations(this);
    final outerDeco = computeDocDeco(this);
    final updateDoc = !docView.matchesNode(state.doc, outerDeco, innerDeco);
    if (updateDoc || updateSel) {
      domObserver.stop();
      if (updateDoc && !docView.update(state.doc, outerDeco, innerDeco, this)) {
        docView.updateOuterDeco(outerDeco);
        docView.destroy();
        docView = docViewDesc(state.doc, outerDeco, innerDeco, dom, this);
      }
      selectionToDOM(this, updateDoc);
      domObserver.start();
    }
    for (final pluginView in pluginViews) {
      pluginView.update?.call(this, prev);
    }
  }

  void dispatch(Transaction tr) {
    if (_props.dispatchTransaction != null) {
      _props.dispatchTransaction!(tr);
    } else {
      updateState(state.apply(tr));
    }
  }

  dynamic someProp(String propName, [dynamic Function(dynamic value)? f]) {
    dynamic value = _readProp(_props, propName);
    if (value != null) {
      if (f == null) return value;
      final result = f(value);
      if (result != null) return result;
    }

    for (final plugin in directPlugins) {
      value = plugin.props[propName];
      if (value != null) {
        if (f == null) return value;
        final result = f(value);
        if (result != null) return result;
      }
    }
    for (final plugin in state.plugins) {
      value = plugin.props[propName];
      if (value != null) {
        if (f == null) return value;
        final result = f(value);
        if (result != null) return result;
      }
    }
    return null;
  }

  void destroy() {
    for (final pluginView in pluginViews) {
      pluginView.destroy?.call();
    }
    pluginViews = [];
    destroyInput(this);
    domObserver.stop();
    docView.destroy();
    if (dom.parentNode != null) {
      dom.parentNode!.removeChild(dom);
    }
  }

  void updatePluginViews() {
    for (final pluginView in pluginViews) {
      pluginView.destroy?.call();
    }
    pluginViews = [];
    final seen = <Plugin>{};
    for (final plugin in [...directPlugins, ...state.plugins]) {
      if (seen.contains(plugin)) continue;
      seen.add(plugin);
      final createView = plugin.spec.view;
      if (createView != null) pluginViews.add(createView(this));
    }
  }

  late bool editable;

  bool get composing => input.composing;

  web.Node get root => dom.getRootNode();

  web.Selection? domSelection() {
    final currentRoot = root;
    if (currentRoot is web.Document) return currentRoot.getSelection();
    return dom.ownerDocument?.getSelection();
  }

  DOMSelectionRange domSelectionRange() {
    final sel = domSelection();
    return DOMSelectionRange(
      focusNode: sel?.focusNode,
      focusOffset: sel?.focusOffset ?? 0,
      anchorNode: sel?.anchorNode,
      anchorOffset: sel?.anchorOffset ?? 0,
    );
  }

  bool hasFocus() {
    final active = dom.ownerDocument == null
        ? null
        : deepActiveElement(dom.ownerDocument!);
    return focused || active == dom || (active != null && dom.contains(active));
  }

  void focus() {
    dom.focus();
    focused = true;
  }

  DOMPosition domAtPos(int pos, [int side = 0]) =>
      docView.domFromPos(pos, side);

  domcoords.PosAtCoordsResult? posAtCoords(domcoords.ViewCoords coords) =>
      domcoords.posAtCoords(this, coords);

  domcoords.Rect coordsAtPos(int pos, [int side = 1]) =>
      domcoords.coordsAtPos(this, pos, side);

  dynamic _readProp(EditorProps props, String name) {
    switch (name) {
      case 'attributes':
        return props.attributes;
      case 'editable':
        return props.editable;
      case 'handleKeyDown':
        return props.handleKeyDown;
      case 'handlePaste':
        return props.handlePaste;
      case 'handleDrop':
        return props.handleDrop;
      case 'handleScrollToSelection':
        return props.handleScrollToSelection;
      case 'handleDOMEvents':
        return props.handleDOMEvents;
      case 'decorations':
        return props.decorations;
      case 'nodeViews':
        return props.nodeViews;
      case 'markViews':
        return props.markViews;
      case 'createSelectionBetween':
        return null;
      default:
        return null;
    }
  }
}

class CursorWrapper {
  final web.Node dom;
  final Decoration deco;

  CursorWrapper(this.dom, this.deco);
}

bool getEditable(EditorView view) {
  final value = view._props.editable;
  return value == null ? true : value(view.state);
}

Map<String, dynamic> buildNodeViews(EditorView view) {
  final result = <String, dynamic>{};
  final directNodes = view._props.nodeViews;
  final directMarks = view._props.markViews;
  if (directNodes != null) result.addAll(directNodes);
  if (directMarks != null) result.addAll(directMarks);
  view.someProp('nodeViews', (dynamic value) {
    if (value is Map<String, dynamic>) result.addAll(value);
    return null;
  });
  view.someProp('markViews', (dynamic value) {
    if (value is Map<String, dynamic>) result.addAll(value);
    return null;
  });
  return result;
}

List<Decoration> computeDocDeco(EditorView view) {
  final attrs = <String, dynamic>{
    'class': 'ProseMirror',
    'contenteditable': view.editable ? 'true' : 'false',
  };
  final customAttrs = view.someProp('attributes', (dynamic value) {
    return value is Function ? value(view.state) : value;
  });
  if (customAttrs is Map) {
    for (final entry in customAttrs.entries) {
      attrs[entry.key.toString()] = entry.value?.toString();
    }
  }
  return [Decoration.node(0, view.state.doc.content.size, attrs)];
}
