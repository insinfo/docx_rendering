import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'icons.dart';

/// Small DOM component foundation used by the embeddable editor chrome.
///
/// It deliberately depends only on `package:web`: applications may consume
/// the same components from plain Dart web, AngularDart or any other host.
abstract class TiptapComponent {
  final web.HTMLElement root;
  final List<TiptapComponent> _children = [];
  final List<({web.EventTarget target, String type, JSFunction listener})>
      _listeners = [];
  bool _disposed = false;

  TiptapComponent(this.root);

  bool get disposed => _disposed;

  T own<T extends TiptapComponent>(T component) {
    _children.add(component);
    return component;
  }

  void listen(web.EventTarget target, String type, JSFunction listener) {
    target.addEventListener(type, listener);
    _listeners.add((target: target, type: type, listener: listener));
  }

  void mount(web.Element host) => host.appendChild(root);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final binding in _listeners.reversed) {
      binding.target.removeEventListener(binding.type, binding.listener);
    }
    for (final child in _children.reversed) {
      child.dispose();
    }
    _listeners.clear();
    _children.clear();
    root.remove();
  }
}

abstract final class TiptapDom {
  static web.HTMLElement element(
    String tag, {
    String classes = '',
    String? id,
    String? text,
    Map<String, String> attrs = const {},
  }) {
    final element = web.document.createElement(tag) as web.HTMLElement;
    if (classes.trim().isNotEmpty) element.className = classes.trim();
    if (id != null) element.id = id;
    if (text != null) element.textContent = text;
    for (final entry in attrs.entries) {
      element.setAttribute(entry.key, entry.value);
    }
    return element;
  }

  static web.HTMLElement icon(String name, {String classes = 'button-icon'}) =>
      element('span', classes: classes, attrs: {'data-tiptap-icon': name});
}

class TiptapButton extends TiptapComponent {
  TiptapButton({
    String? id,
    String label = '',
    String? icon,
    String classes = '',
    Map<String, String> attrs = const {},
    void Function()? onPressed,
  }) : super(TiptapDom.element('button',
            id: id, classes: classes, attrs: attrs)) {
    if (icon != null) root.appendChild(TiptapDom.icon(icon));
    if (label.isNotEmpty)
      root.appendChild(TiptapDom.element('span', text: label));
    if (onPressed != null) {
      listen(root, 'click', ((web.Event _) => onPressed()).toJS);
    }
    TiptapIcons.hydrate(root);
  }
}

class TiptapSelect extends TiptapComponent {
  final StreamController<String> _changes =
      StreamController<String>.broadcast(sync: true);

  TiptapSelect({
    String? id,
    String classes = '',
    required Map<String, String> items,
    String? value,
    String? ariaLabel,
    Map<String, String> attrs = const {},
  }) : super(TiptapDom.element('select', id: id, classes: classes, attrs: {
          if (ariaLabel != null) 'aria-label': ariaLabel,
          ...attrs,
        })) {
    for (final entry in items.entries) {
      final option = TiptapDom.element('option',
          text: entry.value,
          attrs: {'value': entry.key}) as web.HTMLOptionElement;
      option.selected = entry.key == value;
      root.appendChild(option);
    }
    listen(root, 'change', ((web.Event _) => _changes.add(element.value)).toJS);
  }

  web.HTMLSelectElement get element => root as web.HTMLSelectElement;
  Stream<String> get changes => _changes.stream;
  String get value => element.value;
  set value(String value) => element.value = value;

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }
}

class TiptapDropdown extends TiptapComponent {
  final web.HTMLElement trigger;
  final web.HTMLElement panel;
  final web.HTMLElement? portalHost;
  bool _open = false;

  TiptapDropdown({
    required this.trigger,
    required this.panel,
    this.portalHost,
    String classes = 'tiptap-dropdown',
  }) : super(TiptapDom.element('div', classes: classes)) {
    root.appendChild(trigger);
    if (portalHost == null) {
      root.appendChild(panel);
    } else {
      panel.classList.add('tiptap-dropdown-portaled');
      portalHost!.appendChild(panel);
    }
    trigger.setAttribute('aria-expanded', 'false');
    listen(
      trigger,
      'click',
      ((web.Event event) {
        event.stopPropagation();
        setOpen(!_open);
      }).toJS,
    );
    listen(
      web.document,
      'click',
      ((web.Event _) => setOpen(false)).toJS,
    );
  }

  bool get open => _open;

  void setOpen(bool value) {
    _open = value;
    if (value && portalHost != null) _positionPortaledPanel();
    panel.classList.toggle('open', value);
    trigger.setAttribute('aria-expanded', '$value');
  }

  void _positionPortaledPanel() {
    final hostBounds = portalHost!.getBoundingClientRect();
    final triggerBounds = trigger.getBoundingClientRect();
    final panelWidth = panel.getBoundingClientRect().width;
    final preferredLeft = triggerBounds.left - hostBounds.left;
    final maximumLeft = hostBounds.width - panelWidth - 6;
    final left = preferredLeft.clamp(6, maximumLeft < 6 ? 6 : maximumLeft);
    panel.style
      ..left = '${left}px'
      ..right = 'auto'
      ..top = '${triggerBounds.bottom - hostBounds.top + 4}px';
  }

  @override
  void dispose() {
    if (portalHost != null) panel.remove();
    super.dispose();
  }
}

class TiptapModal extends TiptapComponent {
  late final web.HTMLElement dialog;
  late final web.HTMLElement body;
  late final web.HTMLElement footer;
  final StreamController<void> _closed = StreamController<void>.broadcast();

  TiptapModal({required String title, String classes = ''})
      : super(TiptapDom.element('div',
            classes: 'tiptap-modal-backdrop $classes',
            attrs: {'aria-hidden': 'true'})) {
    dialog = TiptapDom.element('section', classes: 'tiptap-modal', attrs: {
      'role': 'dialog',
      'aria-modal': 'true',
      'aria-label': title,
    });
    final header = TiptapDom.element('header', classes: 'tiptap-modal-header')
      ..appendChild(TiptapDom.element('strong', text: title));
    final close = TiptapButton(
        label: '×', classes: 'tiptap-modal-close', onPressed: hide);
    own(close);
    header.appendChild(close.root);
    body = TiptapDom.element('div', classes: 'tiptap-modal-body');
    footer = TiptapDom.element('footer', classes: 'tiptap-modal-footer');
    dialog
      ..appendChild(header)
      ..appendChild(body)
      ..appendChild(footer);
    root.appendChild(dialog);
    listen(
      root,
      'pointerdown',
      ((web.Event event) {
        if (identical(event.target, root)) hide();
      }).toJS,
    );
  }

  Stream<void> get closed => _closed.stream;

  void show() {
    root.classList.add('open');
    root.setAttribute('aria-hidden', 'false');
  }

  void hide() {
    root.classList.remove('open');
    root.setAttribute('aria-hidden', 'true');
    _closed.add(null);
  }

  @override
  void dispose() {
    _closed.close();
    super.dispose();
  }
}

class TiptapRibbon extends TiptapComponent {
  final Map<String, web.HTMLElement> _tabs = {};
  final Map<String, web.HTMLElement> _panels = {};
  final StreamController<String> _changes =
      StreamController<String>.broadcast(sync: true);
  String _active;

  TiptapRibbon({
    required Map<String, String> tabs,
    String active = 'home',
    String classes = 'mode-tabs ribbon-tabs',
  })  : _active = active,
        super(TiptapDom.element('nav', classes: classes, attrs: {
          'aria-label': 'Guias da faixa de opções',
        })) {
    for (final entry in tabs.entries) {
      final button = TiptapDom.element('button',
          text: entry.value, attrs: {'data-ribbon-tab': entry.key});
      _tabs[entry.key] = button;
      listen(button, 'click', ((web.Event _) => activate(entry.key)).toJS);
      root.appendChild(button);
    }
    _sync();
  }

  Stream<String> get changes => _changes.stream;
  String get active => _active;

  void registerPanel(String name, web.HTMLElement panel) {
    _panels[name] = panel;
    _sync();
  }

  void activate(String name) {
    if (!_tabs.containsKey(name)) return;
    _active = name;
    _sync();
    _changes.add(name);
  }

  void setContextual(String name, bool visible) {
    _tabs[name]?.classList.toggle('contextual-tab-visible', visible);
  }

  void setTabLabel(String name, String label) {
    final tab = _tabs[name];
    if (tab != null && tab.textContent != label) tab.textContent = label;
  }

  void _sync() {
    for (final entry in _tabs.entries) {
      entry.value.classList.toggle('active', entry.key == _active);
    }
    for (final entry in _panels.entries) {
      entry.value.classList.toggle('active', entry.key == _active);
    }
  }

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }
}
