import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/editor.dart';

/// Requests a URL from the host application when the link action is used.
///
/// Keeping this callback outside the controller lets applications provide a
/// dialog, popover or Angular component instead of relying on `window.prompt`.
typedef TiptapLinkRequest = FutureOr<String?> Function();

/// Handles toolbar actions that are not built into this controller.
typedef TiptapUnhandledAction = bool Function(String action);

/// Connects a declarative toolbar to a [TiptapEditor].
///
/// All DOM lookups are scoped to [root]. This makes the controller safe for
/// multiple editor instances and keeps it usable from plain Dart Web as well
/// as component frameworks such as AngularDart.
///
/// Supported attributes:
///
/// * `data-tiptap-command="bold|italic|underline|strike|code|bulletList|..."`
/// * `data-tiptap-action="zoom-in|zoom-out|link|table|horizontal-rule|undo|redo"`
/// * `data-tiptap-control="block-style|font-family|font-size|text-color|highlight-color"`
/// * `data-tiptap-color-indicator="text-color|highlight-color"`
/// * `data-tiptap-zoom-value`
class TiptapToolbarController {
  final TiptapEditor editor;
  final web.Element root;
  final TiptapLinkRequest? requestLink;
  final void Function(double value)? onZoomChanged;
  final TiptapUnhandledAction? onUnhandledAction;
  final double minZoom;
  final double maxZoom;
  final double zoomStep;

  final List<({String type, web.EventListener listener})> _listeners = [];
  StreamSubscription<dynamic>? _selectionSubscription;
  double _zoom;
  bool _destroyed = false;

  TiptapToolbarController({
    required this.editor,
    required this.root,
    this.requestLink,
    this.onZoomChanged,
    this.onUnhandledAction,
    double initialZoom = 1,
    this.minZoom = .6,
    this.maxZoom = 1.4,
    this.zoomStep = .1,
  }) : _zoom = initialZoom {
    _listen('pointerdown', _handlePointerDown);
    _listen('click', _handleClick);
    _listen('change', _handleChange);
    _listen('input', _handleInput);
    _selectionSubscription = editor.onSelectionUpdate.listen((_) => sync());
    setZoom(initialZoom);
    sync();
  }

  double get zoom => _zoom;

  void _listen(String type, void Function(web.Event event) callback) {
    final listener = callback.toJS;
    root.addEventListener(type, listener);
    _listeners.add((type: type, listener: listener));
  }

  void _handlePointerDown(web.Event event) {
    final interactive = _closest(
      event,
      'button[data-tiptap-command], button[data-tiptap-action], button[data-tiptap-preserve-selection], [data-tiptap-control], .color-button',
    );
    if (interactive == null) return;

    // Capture a selection-only DOM change synchronously, before a select,
    // color input or toolbar button is allowed to move browser focus.
    editor.view?.domObserver.forceFlush();
    if (interactive.matches(
      'button[data-tiptap-command], button[data-tiptap-action], button[data-tiptap-preserve-selection]',
    )) {
      // Toolbar buttons must not steal the native contenteditable selection.
      event.preventDefault();
    }
  }

  void _handleClick(web.Event event) {
    final commandControl = _closest(event, 'button[data-tiptap-command]');
    if (commandControl != null) {
      final command = commandControl.getAttribute('data-tiptap-command');
      if (command != null) runCommand(command);
      return;
    }

    final actionControl = _closest(event, 'button[data-tiptap-action]');
    if (actionControl != null) {
      final action = actionControl.getAttribute('data-tiptap-action');
      if (action != null) unawaited(runAction(action));
    }
  }

  void _handleChange(web.Event event) {
    final control = _closest(event, '[data-tiptap-control]');
    if (control == null) return;
    final name = control.getAttribute('data-tiptap-control');
    if (control is! web.HTMLSelectElement) return;

    switch (name) {
      case 'block-style':
        if (control.value == 'paragraph') {
          editor.chain.focus().setParagraph().run();
        } else if (control.value.startsWith('heading-')) {
          final level = int.tryParse(control.value.substring(8));
          if (level != null) editor.chain.focus().setHeading(level).run();
        }
      case 'font-family':
        editor.chain.focus().setFontFamily(control.value).run();
      case 'font-size':
        editor.chain.focus().setFontSize('${control.value}px').run();
    }
    sync();
  }

  void _handleInput(web.Event event) {
    final control = _closest(event, '[data-tiptap-control]');
    if (control is! web.HTMLInputElement) return;
    final name = control.getAttribute('data-tiptap-control');
    if (name != 'text-color' && name != 'highlight-color') return;

    final indicator =
        root.querySelector('[data-tiptap-color-indicator="$name"]');
    if (indicator is web.HTMLElement) {
      indicator.style.backgroundColor = control.value;
    }
    if (name == 'text-color') {
      editor.chain.focus().setColor(control.value).run();
    } else {
      editor.chain.focus().toggleHighlight(control.value).run();
    }
  }

  /// Runs a built-in formatting command and refreshes active button states.
  bool runCommand(String command) {
    final chain = editor.chain.focus();
    switch (command) {
      case 'bold':
        chain.toggleBold();
      case 'italic':
        chain.toggleItalic();
      case 'underline':
        chain.toggleUnderline();
      case 'strike':
        chain.toggleStrike();
      case 'code':
        chain.toggleCode();
      case 'bulletList':
        chain.toggleBulletList();
      case 'orderedList':
        chain.toggleOrderedList();
      case 'align-left':
        chain.setTextAlign('left');
      case 'align-center':
        chain.setTextAlign('center');
      case 'align-right':
        chain.setTextAlign('right');
      default:
        return onUnhandledAction?.call(command) ?? false;
    }
    final handled = chain.run();
    sync();
    return handled;
  }

  /// Runs a built-in toolbar action.
  Future<bool> runAction(String action) async {
    switch (action) {
      case 'zoom-out':
        setZoom(_zoom - zoomStep);
        return true;
      case 'zoom-in':
        setZoom(_zoom + zoomStep);
        return true;
      case 'link':
        final href = await requestLink?.call();
        if (href == null || href.trim().isEmpty) return false;
        return editor.chain
            .focus()
            .setLink(href.trim(), target: '_blank')
            .run();
      case 'table':
        return editor.chain.focus().insertTable().run();
      case 'horizontal-rule':
        return editor.chain.focus().setHorizontalRule().run();
      case 'undo':
        return editor.chain.focus().undo().run();
      case 'redo':
        return editor.chain.focus().redo().run();
      default:
        return onUnhandledAction?.call(action) ?? false;
    }
  }

  void setZoom(double value) {
    _zoom = value.clamp(minZoom, maxZoom).toDouble();
    final label = root.querySelector('[data-tiptap-zoom-value]');
    if (label != null) label.textContent = '${(_zoom * 100).round()}%';
    onZoomChanged?.call(_zoom);
  }

  /// Synchronizes active block/mark state to the controls inside [root].
  void sync() {
    if (_destroyed) return;
    final active = <String, bool>{
      'bold': editor.isActive('bold'),
      'italic': editor.isActive('italic'),
      'underline': editor.isActive('underline'),
      'strike': editor.isActive('strike'),
      'code': editor.isActive('code'),
      'bulletList': editor.isActive('bulletList'),
      'orderedList': editor.isActive('orderedList'),
      'align-left': _alignmentActive('left'),
      'align-center': _alignmentActive('center'),
      'align-right': _alignmentActive('right'),
    };
    for (final entry in active.entries) {
      final button = root.querySelector('[data-tiptap-command="${entry.key}"]');
      if (button is web.HTMLElement) {
        button.classList.toggle('active', entry.value);
        button.setAttribute('aria-pressed', '${entry.value}');
      }
    }

    final blockStyle =
        root.querySelector('[data-tiptap-control="block-style"]');
    if (blockStyle is web.HTMLSelectElement) {
      if (editor.isActive('heading', {'level': 1})) {
        blockStyle.value = 'heading-1';
      } else if (editor.isActive('heading', {'level': 2})) {
        blockStyle.value = 'heading-2';
      } else if (editor.isActive('heading', {'level': 3})) {
        blockStyle.value = 'heading-3';
      } else {
        blockStyle.value = 'paragraph';
      }
    }
  }

  bool _alignmentActive(String value) =>
      editor.isActive('paragraph', {'textAlign': value}) ||
      editor.isActive('heading', {'textAlign': value});

  web.Element? _closest(web.Event event, String selector) {
    final target = event.target;
    if (target is! web.Element) return null;
    final control = target.closest(selector);
    if (control == null || !root.contains(control)) return null;
    return control;
  }

  /// Detaches DOM listeners and editor subscriptions without destroying the
  /// editor itself.
  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    for (final entry in _listeners) {
      root.removeEventListener(entry.type, entry.listener);
    }
    _listeners.clear();
    await _selectionSubscription?.cancel();
    _selectionSubscription = null;
  }
}
