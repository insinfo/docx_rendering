import 'package:web/web.dart' as web;

import '../state/index.dart';
import 'domobserver.dart';
import 'input.dart';
import 'viewdesc.dart';

typedef HandleDOMEvents = Map<String, dynamic Function(EditorView view, dynamic event)>;
typedef NodeViews = Map<String, dynamic>;
typedef MarkViews = Map<String, dynamic>;
typedef Attributes = Map<String, String>;

class EditorProps {
  final bool Function(EditorState state)? editable;
  final dynamic Function(EditorView view, dynamic event)? handleKeyDown;
  final dynamic Function(EditorView view, dynamic event)? handlePaste;
  final dynamic Function(EditorView view, dynamic event)? handleDrop;
  final dynamic Function(EditorView view, dynamic event)? handleScrollToSelection;
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
  ViewDesc? docView;
  late final DOMObserver domObserver;
  bool mounted = false;
  bool focused = false;

  EditorView(web.HTMLElement? place, DirectEditorProps props)
      : state = props.state,
        _props = props,
        directPlugins = List<Plugin>.from(props.plugins ?? const []) {
    dom = web.document.createElement('div') as web.HTMLElement;
    dom.classList.add('ProseMirror');
    dom.setAttribute('contenteditable', 'true');

    if (place != null) {
      place.appendChild(dom);
      mounted = true;
    }

    domObserver = DOMObserver(this);
    initInput(this);
  }

  DirectEditorProps get props => _props;

  void update(DirectEditorProps props) {
    _props = props;
    if (props.plugins != null) {
      directPlugins
        ..clear()
        ..addAll(props.plugins!);
    }
    updateState(props.state);
  }

  void updateState(EditorState newState) {
    state = newState;
    if (docView != null) {
      docView!.update(state.doc, null, null, this);
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
    if (value != null && (f == null || f(value) != null)) return f == null ? value : f(value);

    for (final plugin in directPlugins) {
      value = plugin.props[propName];
      if (value != null && (f == null || f(value) != null)) return f == null ? value : f(value);
    }
    for (final plugin in state.plugins) {
      value = plugin.props[propName];
      if (value != null && (f == null || f(value) != null)) return f == null ? value : f(value);
    }
    return null;
  }

  void destroy() {
    destroyInput(this);
    domObserver.stop();
    docView?.destroy();
    if (dom.parentNode != null) {
      dom.parentNode!.removeChild(dom);
    }
  }

  bool get editable {
    final value = _props.editable;
    return value == null ? true : value(state);
  }

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
      default:
        return null;
    }
  }
}
