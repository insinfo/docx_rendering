import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/index.dart';
import 'capturekeys.dart';
import 'clipboard.dart';
import 'index.dart';
import 'selection.dart';
import 'viewdesc.dart';

typedef DOMEventHandler = bool Function(EditorView view, web.Event event);

class LastClick {
  int time = 0;
  double x = 0;
  double y = 0;
  String type = '';
  int button = 0;
}

class InputState {
  bool shiftKey = false;
  MouseDown? mouseDown;
  int lastKeyCode = 0;
  int lastKeyCodeTime = 0;
  LastClick lastClick = LastClick();
  String? lastSelectionOrigin;
  int lastSelectionTime = 0;
  int lastIOSEnter = 0;
  Timer? lastIOSEnterFallbackTimeout;
  int lastFocus = 0;
  int lastTouch = 0;
  int lastChromeDelete = 0;
  bool composing = false;
  web.Text? compositionNode;
  Timer? composingTimeout;
  List<ViewDesc> compositionNodes = [];
  int compositionEndedAt = -200000000;
  int compositionID = 1;
  bool compositionPendingChanges = false;
  int domChangeCount = 0;
  final Map<String, web.EventListener> eventHandlers = {};
  web.EventListener? hideSelectionGuard;
}

class MouseDown {
  final EditorView view;
  final web.MouseEvent event;
  bool done = false;

  MouseDown(this.view, this.event);

  bool delaySelUpdate() => !done;

  void destroy() {
    done = true;
  }
}

class Dragging {
  final Slice slice;
  final bool move;

  Dragging(this.slice, this.move);
}

final Map<String, DOMEventHandler> editHandlers = {
  'keydown': (view, event) {
    final key = event as web.KeyboardEvent;
    view.input.shiftKey = key.shiftKey;
    view.input.lastKeyCode = key.keyCode;
    view.input.lastKeyCodeTime = _now();
    return captureKeyDown(view, key);
  },
  'mousedown': (view, event) {
    view.input.mouseDown?.destroy();
    view.input.mouseDown = MouseDown(view, event as web.MouseEvent);
    setSelectionOrigin(view, 'pointer');
    return false;
  },
  'compositionstart': (view, event) {
    view.input.composing = true;
    view.input.compositionID++;
    return false;
  },
  'compositionupdate': (view, event) {
    view.input.composing = true;
    return false;
  },
  'compositionend': (view, event) {
    endComposition(view);
    return false;
  },
  'focus': (view, event) {
    view.focused = true;
    view.input.lastFocus = _now();
    return false;
  },
  'blur': (view, event) {
    view.focused = false;
    clearComposition(view);
    return false;
  },
};

final Map<String, DOMEventHandler> handlers = {
  ...editHandlers,
  'selectionchange': (view, event) {
    if (!view.domObserver.ignoreSelectionChange(null)) {
      view.domObserver.onSelectionChange();
    }
    return false;
  },
  'copy': (view, event) => false,
  'cut': (view, event) => false,
  'paste': (view, event) {
    view.domObserver.forceFlush();
    if (event is web.ClipboardEvent) {
      final data = event.clipboardData;
      if (data != null) {
        return doPaste(
          view,
          data.getData('text/plain'),
          data.getData('text/html'),
          view.input.shiftKey,
          event,
        );
      }
    }
    return capturePaste(view, event);
  },
  'dragstart': (view, event) => false,
  'dragend': (view, event) {
    view.dragging = null;
    return false;
  },
  'dragover': (view, event) => false,
  'drop': (view, event) {
    view.dragging = null;
    return false;
  },
  'touchstart': (view, event) {
    view.input.lastTouch = _now();
    return false;
  },
  'touchmove': (view, event) {
    view.input.lastTouch = _now();
    return false;
  },
  'contextmenu': (view, event) => false,
  'beforeinput': (view, event) => false,
};

void initInput(EditorView view) {
  ensureListeners(view);
}

void destroyInput(EditorView view) {
  for (final entry in view.input.eventHandlers.entries) {
    view.dom.removeEventListener(entry.key, entry.value);
    view.root.removeEventListener(entry.key, entry.value);
  }
  final guard = view.input.hideSelectionGuard;
  if (guard != null)
    view.dom.ownerDocument?.removeEventListener('selectionchange', guard);
  view.input.composingTimeout?.cancel();
  view.input.lastIOSEnterFallbackTimeout?.cancel();
}

void ensureListeners(EditorView view) {
  for (final entry in view.input.eventHandlers.entries) {
    view.dom.removeEventListener(entry.key, entry.value);
    view.root.removeEventListener(entry.key, entry.value);
  }
  view.input.eventHandlers.clear();
  for (final type in handlers.keys) {
    final listener = ((web.Event event) {
      dispatchEvent(view, event);
    }).toJS;
    view.input.eventHandlers[type] = listener;
    final web.EventTarget target =
        type == 'selectionchange' ? view.dom.ownerDocument! : view.dom;
    target.addEventListener(type, listener);
  }
}

bool runCustomHandler(EditorView view, String propName, web.Event event) {
  if (propName == 'handleDOMEvents') {
    final result = view.someProp(propName, (dynamic handlers) {
      if (handlers is Map) {
        final handler = handlers[event.type];
        if (handler != null) return handler(view, event);
      }
      return null;
    });
    return result == true;
  }

  final result = view.someProp(propName, (dynamic handler) {
    return handler(view, event);
  });
  return result == true;
}

bool eventBelongsToView(EditorView view, web.Event event) {
  final target = event.target;
  return target is web.Node && view.dom.contains(target);
}

bool dispatchEvent(EditorView view, dynamic event) {
  if (event is! web.Event) return false;
  final type = event.type;
  if (!eventBelongsToView(view, event) && type != 'selectionchange') {
    return false;
  }
  if (runCustomHandler(view, 'handleDOMEvents', event)) return true;
  if (type == 'keydown' && runCustomHandler(view, 'handleKeyDown', event)) {
    event.preventDefault();
    return true;
  }
  final handler = handlers[type];
  final handled = handler != null && handler(view, event);
  if (handled) event.preventDefault();
  return handled;
}

bool doPaste(EditorView view, String text, String? html, bool preferPlain,
    [web.Event? event]) {
  final slice = parseFromClipboard(
      view, text, html, preferPlain, view.state.selection.$from);
  final handled = view.someProp('handlePaste', (dynamic handler) {
    return handler(view, event, slice ?? Slice.empty);
  });
  if (handled == true) return true;
  if (slice == null) return false;

  final singleNode = slice.openStart == 0 &&
          slice.openEnd == 0 &&
          slice.content.childCount == 1
      ? slice.content.firstChild
      : null;
  final tr = singleNode != null
      ? view.state.tr.replaceSelectionWith(singleNode, preferPlain)
      : view.state.tr.replaceSelection(slice);
  view.dispatch(
      tr.scrollIntoView().setMeta('paste', true).setMeta('uiEvent', 'paste'));
  return true;
}

bool capturePaste(EditorView view, web.Event event) => false;

bool get brokenClipboardAPI => false;

void setSelectionOrigin(EditorView view, String origin) {
  view.input.lastSelectionOrigin = origin;
  view.input.lastSelectionTime = _now();
}

void forceDOMFlush(EditorView view) {
  view.domObserver.forceFlush();
}

bool selectClickedLeaf(EditorView view, int inside) => false;

bool selectClickedNode(EditorView view, int inside) => false;

bool handleSingleClick(
        EditorView view, int pos, int inside, web.MouseEvent event,
        [bool selectNode = false]) =>
    false;

bool handleDoubleClick(
        EditorView view, int pos, int inside, web.MouseEvent event) =>
    false;

bool handleTripleClick(
        EditorView view, int pos, int inside, web.MouseEvent event) =>
    defaultTripleClick(view, pos, inside, event);

bool defaultTripleClick(
    EditorView view, int pos, int inside, web.MouseEvent event) {
  view.dispatch(view.state.tr
      .setSelection(selectionBetween(view, view.state.doc.resolve(0),
          view.state.doc.resolve(view.state.doc.content.size)))
      .scrollIntoView());
  return true;
}

bool inOrNearComposition(EditorView view, int pos) => view.composing;

int timestampFromCustomEvent(web.Event event) =>
    event.timeStamp.isFinite ? event.timeStamp.round() : _now();

void endComposition(EditorView view) {
  view.input.composing = false;
  view.input.compositionNode = null;
  view.input.compositionPendingChanges = false;
  view.input.compositionEndedAt = _now();
}

void clearComposition(EditorView view) {
  view.input.composing = false;
  view.input.compositionNode = null;
  view.input.compositionNodes.clear();
}

web.Text? findCompositionNode(EditorView view) => view.input.compositionNode;

int _now() => DateTime.now().millisecondsSinceEpoch;
