import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../state/index.dart';
import '../transform/index.dart';
import '../view/domcoords.dart';
import '../view/index.dart';

class DropCursorOptions {
  /// Use `null` for the default black cursor, or an empty string to rely only
  /// on CSS classes.
  final String? color;
  final int width;
  final String? className;

  const DropCursorOptions({
    this.color,
    this.width = 1,
    this.className,
  });
}

Plugin dropCursor([DropCursorOptions options = const DropCursorOptions()]) {
  return Plugin(PluginSpec(
    view: (view) => DropCursorView(view as EditorView, options).asPluginView(),
  ));
}

class DropCursorView {
  final EditorView editorView;
  final int width;
  final String? color;
  final String? className;
  int? cursorPos;
  web.HTMLElement? element;
  Timer? timeout;
  web.DragEvent? lastDragEvent;
  final List<({String name, web.EventListener handler})> handlers = [];

  DropCursorView(this.editorView, DropCursorOptions options)
      : width = options.width,
        color = options.color ?? 'black',
        className = options.className {
    for (final name in const ['dragover', 'dragend', 'drop', 'dragleave']) {
      final handler = ((web.Event event) => _handle(name, event)).toJS;
      editorView.dom.addEventListener(name, handler);
      handlers.add((name: name, handler: handler));
    }
  }

  PluginView asPluginView() => PluginView(
        update: (view, prevState) => update(view as EditorView, prevState),
        destroy: destroy,
      );

  void destroy() {
    for (final entry in handlers) {
      editorView.dom.removeEventListener(entry.name, entry.handler);
    }
    handlers.clear();
    timeout?.cancel();
    removeElement();
  }

  void update(EditorView view, EditorState prevState) {
    if (cursorPos == null || identical(prevState.doc, view.state.doc)) return;
    final event = lastDragEvent;
    if (event != null) {
      final target = computeTarget(event);
      if (target == cursorPos) {
        updateOverlay();
      } else {
        setCursor(target);
      }
    } else {
      updateOverlay();
    }
  }

  void _handle(String name, web.Event event) {
    switch (name) {
      case 'dragover':
        if (event is web.DragEvent) dragover(event);
        break;
      case 'dragend':
        dragend();
        break;
      case 'drop':
        drop();
        break;
      case 'dragleave':
        if (event is web.DragEvent) dragleave(event);
        break;
    }
  }

  void setCursor(int? pos) {
    if (pos == cursorPos) return;
    cursorPos = pos;
    if (pos == null) {
      removeElement();
    } else {
      updateOverlay();
    }
  }

  void removeElement() {
    final dom = element;
    if (dom != null && dom.parentNode != null) {
      dom.parentNode!.removeChild(dom);
    }
    element = null;
  }

  void updateOverlay() {
    final pos = cursorPos;
    if (pos == null) return;
    final resolved = editorView.state.doc.resolve(pos);
    final isBlock = !resolved.parent.inlineContent;
    final coords = editorView.coordsAtPos(pos);
    final halfWidth = width / 2;
    final rect = isBlock
        ? Rect(
            left: coords.left,
            right: coords.right,
            top: coords.top - halfWidth,
            bottom: coords.top + halfWidth,
          )
        : Rect(
            left: coords.left - halfWidth,
            right: coords.left + halfWidth,
            top: coords.top,
            bottom: coords.bottom,
          );

    final doc = editorView.dom.ownerDocument ?? web.document;
    final parent = doc.body!;
    final cursor = element ??=
        parent.appendChild(doc.createElement('div')) as web.HTMLElement;
    if (className != null) cursor.className = className!;
    cursor.style.cssText = 'position:absolute;z-index:50;pointer-events:none;';
    if (color != null && color!.isNotEmpty) {
      cursor.style.backgroundColor = color!;
    }
    cursor.classList.toggle('prosemirror-dropcursor-block', isBlock);
    cursor.classList.toggle('prosemirror-dropcursor-inline', !isBlock);
    final scrollX = doc.defaultView?.scrollX ?? 0;
    final scrollY = doc.defaultView?.scrollY ?? 0;
    cursor.style.left = '${rect.left + scrollX}px';
    cursor.style.top = '${rect.top + scrollY}px';
    cursor.style.width = '${rect.right - rect.left}px';
    cursor.style.height = '${rect.bottom - rect.top}px';
  }

  void scheduleRemoval(int milliseconds) {
    timeout?.cancel();
    timeout = Timer(Duration(milliseconds: milliseconds), () {
      setCursor(null);
    });
  }

  int? computeTarget(web.DragEvent event) {
    final pos = editorView.posAtCoords(ViewCoords(
        left: event.clientX.toDouble(), top: event.clientY.toDouble()));
    if (pos == null) return null;

    final node =
        pos.inside >= 0 ? editorView.state.doc.nodeAt(pos.inside) : null;
    final disableDropCursor = node?.type.spec.disableDropCursor;
    final disabled = disableDropCursor is Function
        ? disableDropCursor(editorView, pos, event) == true
        : disableDropCursor == true;
    if (disabled) return null;

    var target = pos.pos;
    final dragging = editorView.dragging;
    if (dragging != null) {
      final point = dropPoint(editorView.state.doc, target, dragging.slice);
      if (point != null) target = point;
    }
    return target;
  }

  void dragover(web.DragEvent event) {
    if (!editorView.editable) return;
    lastDragEvent = event;
    final target = computeTarget(event);
    if (target != null) {
      setCursor(target);
      scheduleRemoval(5000);
    }
  }

  void dragend() {
    scheduleRemoval(20);
  }

  void drop() {
    scheduleRemoval(20);
  }

  void dragleave(web.DragEvent event) {
    final related = event.relatedTarget;
    if (related is! web.Node || !editorView.dom.contains(related)) {
      setCursor(null);
    }
  }
}
