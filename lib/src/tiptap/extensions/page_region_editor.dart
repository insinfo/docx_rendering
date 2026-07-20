import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../prosemirror/model/from_dom.dart';
import '../../prosemirror/view/index.dart';
import '../ui/word_rulers.dart';

/// Interactive editor for the materialized header/footer copies created by
/// the pagination extension.
///
/// Header/footer content is kept outside the main ProseMirror document body,
/// in the top node's `headers`/`footers` JSON attributes. This controller
/// deliberately commits only when editing finishes (or an object transform
/// ends), so typing isn't interrupted by rebuilding all repeated page copies.
class PageRegionEditor {
  EditorView view;

  web.HTMLElement? _region;
  web.HTMLElement? _selectedObject;
  web.HTMLElement? _objectSelection;
  late final WordRulers _rulers;
  bool _dirty = false;
  bool _committing = false;

  JSFunction? _doubleClickListener;
  JSFunction? _clickListener;
  JSFunction? _inputListener;
  JSFunction? _focusOutListener;
  JSFunction? _keyDownListener;
  JSFunction? _pointerDownListener;
  JSFunction? _transformMoveListener;
  JSFunction? _transformEndListener;

  PageRegionEditor(this.view) {
    _installListeners();
    _rulers = WordRulers(view);
  }

  void update(EditorView nextView) {
    view = nextView;
    _rulers.update(nextView);
  }

  void paginationRebuilt() {
    // A payload transaction replaces all materialized copies. Never retain a
    // detached object/region reference after that replacement.
    if (_region != null && !_region!.isConnected) {
      _region = null;
      _selectedObject = null;
      _objectSelection = null;
      view.dom.classList.remove('tiptap-page-region-editing');
      _notifyContextChanged();
    }
    _rulers.refresh();
  }

  void _installListeners() {
    _doubleClickListener = ((web.Event rawEvent) {
      if (rawEvent is! web.MouseEvent) return;
      final target = rawEvent.target;
      if (target is! web.Element) return;
      final region = target.closest(
        '.tiptap-page-header, .tiptap-page-footer',
      );
      if (region is! web.HTMLElement) return;
      rawEvent.stopPropagation();
      _activate(region);
      final object = _editableObjectFor(target, region);
      if (object != null) {
        // Images are atomic objects. Preventing the native double-click only
        // for them avoids the browser's image drag/select behaviour. Textbox
        // descendants must keep the native text-selection default so a user
        // can type immediately after entering header/footer edit mode.
        if (object.tagName == 'IMG') rawEvent.preventDefault();
        _selectObject(object);
        _focusObjectText(object, target);
      } else {
        region.focus();
      }
    }).toJS;

    _clickListener = ((web.Event rawEvent) {
      if (rawEvent is! web.MouseEvent) return;
      final target = rawEvent.target;
      if (target is! web.Element) return;
      final region = _region;
      if (region == null) return;

      final action = target.closest('[data-page-object-action]');
      if (action is web.HTMLElement) {
        rawEvent.preventDefault();
        rawEvent.stopPropagation();
        _handleAction(action.getAttribute('data-page-object-action'));
        return;
      }

      if (!region.contains(target)) {
        _finishEditing(commit: true);
        return;
      }
      final object = _editableObjectFor(target, region);
      if (object != null) _selectObject(object);
    }).toJS;

    _inputListener = ((web.Event rawEvent) {
      final target = rawEvent.target;
      final region = _region;
      if (region != null && target is web.Node && region.contains(target)) {
        _dirty = true;
        _refreshObjectSelection();
      }
    }).toJS;

    _focusOutListener = ((web.Event rawEvent) {
      final region = _region;
      if (region == null) return;
      // focusout fires before document.activeElement is updated.
      web.window.setTimeout(
          (() {
            final active = web.document.activeElement;
            if (_region == region &&
                (active == null || !region.contains(active))) {
              _finishEditing(commit: true);
            }
          }).toJS,
          0.toJS);
    }).toJS;

    _keyDownListener = ((web.Event rawEvent) {
      if (rawEvent is web.KeyboardEvent &&
          rawEvent.key == 'Escape' &&
          _region != null) {
        rawEvent.preventDefault();
        _finishEditing(commit: true);
      }
    }).toJS;

    _pointerDownListener = ((web.Event rawEvent) {
      if (rawEvent is! web.PointerEvent) return;
      if (rawEvent.button != 0) return;
      final target = rawEvent.target;
      if (target is! web.Element) return;
      final handle = target.closest('[data-page-object-handle]');
      if (handle is! web.HTMLElement || _selectedObject == null) return;
      rawEvent.preventDefault();
      rawEvent.stopPropagation();
      _beginTransform(
        rawEvent,
        handle.getAttribute('data-page-object-handle') ?? 'move',
      );
    }).toJS;

    final dom = view.dom as web.EventTarget;
    dom
      ..addEventListener('dblclick', _doubleClickListener)
      ..addEventListener('click', _clickListener)
      ..addEventListener('input', _inputListener)
      ..addEventListener('focusout', _focusOutListener)
      ..addEventListener('keydown', _keyDownListener)
      ..addEventListener('pointerdown', _pointerDownListener);
  }

  void _activate(web.HTMLElement region) {
    if (identical(region, _region)) return;
    if (_region != null) _finishEditing(commit: true);
    _region = region;
    _dirty = false;
    region
      ..classList.add('tiptap-page-region-active')
      ..setAttribute('contenteditable', 'true')
      ..setAttribute('data-editing', 'true');
    view.dom.classList.add('tiptap-page-region-editing');
    final pagination = region.closest('[data-tiptap-pagination]');
    pagination
      ?..setAttribute('aria-hidden', 'false')
      ..setAttribute('data-editing', 'true');
    region.appendChild(_buildRegionOverlay(region));
    _syncObjectToolbar();
    _notifyContextChanged();
  }

  web.HTMLElement _buildRegionOverlay(web.HTMLElement region) {
    final isFooter = region.classList.contains('tiptap-page-footer');
    final overlay = web.document.createElement('div') as web.HTMLElement;
    overlay
      ..className =
          'tiptap-page-editor-overlay ${isFooter ? 'is-footer' : 'is-header'}'
      ..setAttribute('data-page-editor-ui', 'true')
      ..setAttribute('contenteditable', 'false');

    final label = web.document.createElement('span') as web.HTMLElement;
    label
      ..className = 'tiptap-page-editor-label'
      ..textContent = isFooter ? 'Rodapé' : 'Cabeçalho';
    final toolbar = web.document.createElement('div') as web.HTMLElement;
    toolbar.className = 'tiptap-page-object-toolbar';
    toolbar.appendChild(_actionButton('left', 'Alinhar à esquerda', '⇤'));
    toolbar.appendChild(_actionButton('center', 'Centralizar', '↔'));
    toolbar.appendChild(_actionButton('right', 'Alinhar à direita', '⇥'));
    toolbar.appendChild(_actionButton('close', 'Concluir edição', '✓'));
    overlay
      ..appendChild(label)
      ..appendChild(toolbar);
    return overlay;
  }

  web.HTMLElement _actionButton(String action, String title, String text) {
    final button = web.document.createElement('button') as web.HTMLElement;
    button
      ..className = 'tiptap-page-object-action'
      ..setAttribute('type', 'button')
      ..setAttribute('title', title)
      ..setAttribute('aria-label', title)
      ..setAttribute('data-page-object-action', action)
      ..setAttribute('contenteditable', 'false')
      ..textContent = text;
    return button;
  }

  web.HTMLElement? _editableObjectFor(
    web.Element target,
    web.HTMLElement region,
  ) {
    // VML textboxes currently materialize as `table[data-docx-textbox]`, but
    // accepting semantic wrappers keeps the interaction stable if a host or
    // future importer renders them as positioned divs.
    final candidate = target.closest(
            '[data-docx-textbox], [data-tiptap-textbox], .tiptap-textbox') ??
        target.closest('img, table');
    if (candidate is! web.HTMLElement || !region.contains(candidate)) {
      return null;
    }
    return candidate;
  }

  void _focusObjectText(web.HTMLElement object, web.Element eventTarget) {
    if (object.tagName == 'IMG') return;
    final region = _region;
    if (region == null) return;
    final targetContainer = eventTarget.closest('p, td, th');
    final container =
        targetContainer != null && object.contains(targetContainer)
            ? targetContainer
            : object.querySelector('p, td, th');
    if (container == null) return;
    region.focus();
    final range = web.document.createRange()
      ..selectNodeContents(container)
      ..collapse(false);
    web.document.getSelection()
      ?..removeAllRanges()
      ..addRange(range);
  }

  void _selectObject(web.HTMLElement object) {
    if (identical(object, _selectedObject)) {
      _refreshObjectSelection();
      return;
    }
    _clearObjectSelection();
    _selectedObject = object;
    object.classList.add('tiptap-page-object-selected');
    final selection = web.document.createElement('div') as web.HTMLElement;
    selection
      ..className = 'tiptap-page-object-selection'
      ..setAttribute('data-page-editor-ui', 'true')
      ..setAttribute('contenteditable', 'false');
    for (final direction in const [
      'nw',
      'n',
      'ne',
      'e',
      'se',
      's',
      'sw',
      'w',
    ]) {
      final handle = web.document.createElement('span') as web.HTMLElement;
      handle
        ..className = 'tiptap-object-handle handle-$direction'
        ..setAttribute('data-page-object-handle', direction)
        ..setAttribute('contenteditable', 'false');
      selection.appendChild(handle);
    }
    final move = web.document.createElement('span') as web.HTMLElement;
    move
      ..className = 'tiptap-object-move-handle'
      ..setAttribute('data-page-object-handle', 'move')
      ..setAttribute('title', 'Arrastar objeto')
      ..setAttribute('contenteditable', 'false')
      ..textContent = '✥';
    selection.appendChild(move);
    _region!.appendChild(selection);
    _objectSelection = selection;
    _refreshObjectSelection();
    _syncObjectToolbar();
  }

  void _refreshObjectSelection() {
    final object = _selectedObject;
    final selection = _objectSelection;
    final region = _region;
    if (object == null || selection == null || region == null) return;
    final objectRect = object.getBoundingClientRect();
    final regionRect = region.getBoundingClientRect();
    final scale = _scaleFor(region);
    selection.style
      ..left = '${(objectRect.left - regionRect.left) / scale}px'
      ..top = '${(objectRect.top - regionRect.top) / scale}px'
      ..width = '${objectRect.width / scale}px'
      ..height = '${objectRect.height / scale}px';
  }

  void _handleAction(String? action) {
    if (action == 'close') {
      _finishEditing(commit: true);
      return;
    }
    final object = _selectedObject;
    final region = _region;
    if (object == null || region == null || action == null) return;
    _makeAbsolute(object, region);
    final width = object.getBoundingClientRect().width / _scaleFor(region);
    if (action == 'left') {
      object.style
        ..left = '0px'
        ..right = 'auto';
    } else if (action == 'center') {
      object.style
        ..left = '${math.max(0, (region.clientWidth - width) / 2)}px'
        ..right = 'auto';
    } else if (action == 'right') {
      object.style
        ..left = 'auto'
        ..right = '0px';
    }
    object.setAttribute('data-object-align', action);
    _dirty = true;
    _refreshObjectSelection();
    _syncObjectToolbar();
    _commitRegion();
  }

  void _syncObjectToolbar() {
    final region = _region;
    if (region == null) return;
    final object = _selectedObject;
    final alignment = object?.getAttribute('data-object-align') ??
        (object?.style.right == '0px'
            ? 'right'
            : object?.style.left == '0px'
                ? 'left'
                : null);
    for (final action in const ['left', 'center', 'right']) {
      final button = region.querySelector(
        '[data-page-object-action="$action"]',
      );
      if (button is! web.HTMLElement) continue;
      button
        ..setAttribute('aria-disabled', object == null ? 'true' : 'false')
        ..setAttribute('aria-pressed', alignment == action ? 'true' : 'false');
    }
  }

  void _beginTransform(web.PointerEvent start, String direction) {
    final object = _selectedObject!;
    final region = _region!;
    _makeAbsolute(object, region);
    final scale = _scaleFor(region);
    final objectRect = object.getBoundingClientRect();
    final regionRect = region.getBoundingClientRect();
    var left = (objectRect.left - regionRect.left) / scale;
    var top = (objectRect.top - regionRect.top) / scale;
    var width = objectRect.width / scale;
    var height = objectRect.height / scale;
    final initialLeft = left;
    final initialTop = top;
    final initialWidth = width;
    final initialHeight = height;
    final initialX = start.clientX;
    final initialY = start.clientY;

    _transformMoveListener = ((web.Event rawEvent) {
      if (rawEvent is! web.PointerEvent) return;
      rawEvent.preventDefault();
      final dx = (rawEvent.clientX - initialX) / scale;
      final dy = (rawEvent.clientY - initialY) / scale;
      left = initialLeft;
      top = initialTop;
      width = initialWidth;
      height = initialHeight;
      if (direction == 'move') {
        left += dx;
        top += dy;
      } else {
        if (direction.contains('e')) width = math.max(24, initialWidth + dx);
        if (direction.contains('s')) height = math.max(24, initialHeight + dy);
        if (direction.contains('w')) {
          width = math.max(24, initialWidth - dx);
          left = initialLeft + initialWidth - width;
        }
        if (direction.contains('n')) {
          height = math.max(24, initialHeight - dy);
          top = initialTop + initialHeight - height;
        }
      }
      object.style
        ..left = '${left.round()}px'
        ..top = '${top.round()}px'
        ..right = 'auto'
        ..bottom = 'auto'
        ..width = '${width.round()}px'
        ..height = '${height.round()}px';
      if (object.tagName == 'IMG') {
        object
          ..setAttribute('width', '${width.round()}')
          ..setAttribute('height', '${height.round()}');
        object.style.setProperty('object-fit', 'contain');
      }
      _dirty = true;
      _refreshObjectSelection();
    }).toJS;

    _transformEndListener = ((web.Event rawEvent) {
      _removeTransformListeners();
      _dirty = true;
      _commitRegion();
    }).toJS;
    (web.window as web.EventTarget)
      ..addEventListener('pointermove', _transformMoveListener)
      ..addEventListener('pointerup', _transformEndListener)
      ..addEventListener('pointercancel', _transformEndListener);
  }

  void _makeAbsolute(web.HTMLElement object, web.HTMLElement region) {
    if (object.style.position == 'absolute' &&
        object.style.left.isNotEmpty &&
        object.style.left != 'auto') {
      return;
    }
    final scale = _scaleFor(region);
    final objectRect = object.getBoundingClientRect();
    final regionRect = region.getBoundingClientRect();
    object.style
      ..position = 'absolute'
      ..left = '${(objectRect.left - regionRect.left) / scale}px'
      ..top = '${(objectRect.top - regionRect.top) / scale}px'
      ..right = 'auto'
      ..bottom = 'auto'
      ..width = '${objectRect.width / scale}px'
      ..height = '${objectRect.height / scale}px'
      ..margin = '0';
  }

  double _scaleFor(web.HTMLElement element) {
    final rect = element.getBoundingClientRect();
    final scale =
        element.offsetWidth > 0 ? rect.width / element.offsetWidth : 1;
    return (scale.isFinite && scale > 0 ? scale : 1).toDouble();
  }

  void _finishEditing({required bool commit}) {
    if (_region == null || _committing) return;
    if (commit && _dirty) _commitRegion(closeAfterCommit: true);
    final region = _region;
    if (region != null && region.isConnected) {
      region
        ..classList.remove('tiptap-page-region-active')
        ..setAttribute('contenteditable', 'false')
        ..removeAttribute('data-editing');
      region.querySelector('[data-page-editor-ui]')?.remove();
    }
    _clearObjectSelection();
    _region = null;
    _dirty = false;
    view.dom.classList.remove('tiptap-page-region-editing');
    final pagination = view.dom.querySelector('[data-tiptap-pagination]');
    pagination
      ?..removeAttribute('data-editing')
      ..setAttribute('aria-hidden', 'true');
    _notifyContextChanged();
  }

  void _notifyContextChanged() {
    view.dom.dispatchEvent(
      web.Event('tiptap-context-change', web.EventInit(bubbles: true)),
    );
  }

  void _clearObjectSelection() {
    _selectedObject?.classList.remove('tiptap-page-object-selected');
    _objectSelection?.remove();
    _selectedObject = null;
    _objectSelection = null;
    _syncObjectToolbar();
  }

  void _commitRegion({bool closeAfterCommit = false}) {
    final region = _region;
    if (region == null || !_dirty || _committing) return;
    _committing = true;
    try {
      final isFooter = region.classList.contains('tiptap-page-footer');
      final attribute = isFooter ? 'footers' : 'headers';
      final current = _asStringMap(view.state.doc.attrs[attribute]);
      final pageNumber =
          int.tryParse(region.getAttribute('data-page-number') ?? '') ?? 1;
      final key = _payloadKey(current, pageNumber);
      final payload = _serializeRegion(region);
      final next = Map<String, dynamic>.from(current)..[key] = payload;
      _dirty = false;
      if (closeAfterCommit) {
        region
          ..classList.remove('tiptap-page-region-active')
          ..setAttribute('contenteditable', 'false')
          ..removeAttribute('data-editing');
      }
      final tr = view.state.tr;
      tr.setDocAttribute(attribute, next);
      view.dispatch(tr);
    } finally {
      _committing = false;
    }
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return <String, dynamic>{};
  }

  String _payloadKey(Map<String, dynamic> payloads, int pageNumber) {
    final titlePage = view.state.doc.attrs['titlePage'] == true;
    final evenAndOddHeaders = view.state.doc.attrs['evenAndOddHeaders'] == true;
    if (pageNumber == 1 && titlePage && payloads.containsKey('first')) {
      return 'first';
    }
    if (evenAndOddHeaders &&
        pageNumber.isEven &&
        payloads.containsKey('even')) {
      return 'even';
    }
    if (payloads.containsKey('default')) return 'default';
    if (payloads.containsKey('odd')) return 'odd';
    return pageNumber == 1 && titlePage ? 'first' : 'default';
  }

  List<dynamic> _serializeRegion(web.HTMLElement region) {
    final clone = region.cloneNode(true) as web.HTMLElement;
    final ui = clone.querySelectorAll('[data-page-editor-ui]');
    for (var index = ui.length - 1; index >= 0; index--) {
      final item = ui.item(index);
      if (item is web.Element) item.remove();
    }
    clone
      ..classList.remove('tiptap-page-region-active')
      ..removeAttribute('contenteditable')
      ..removeAttribute('data-editing');
    final selected = clone.querySelectorAll('.tiptap-page-object-selected');
    for (var index = 0; index < selected.length; index++) {
      final item = selected.item(index);
      if (item is web.Element) {
        item.classList.remove('tiptap-page-object-selected');
      }
    }
    final fields = clone.querySelectorAll('[data-docx-page-field]');
    for (var index = fields.length - 1; index >= 0; index--) {
      final field = fields.item(index);
      if (field is! web.Element) continue;
      final kind = field.getAttribute('data-docx-page-field');
      field.replaceWith(web.document.createTextNode(
        kind == 'total' ? '{{DOCX_NUMPAGES}}' : '{{DOCX_PAGE}}',
      ));
    }
    final parsed = DOMParser.fromSchema(view.state.schema).parse(clone);
    return [
      for (var index = 0; index < parsed.childCount; index++)
        parsed.child(index).toJSON(),
    ];
  }

  void _removeTransformListeners() {
    final target = web.window as web.EventTarget;
    if (_transformMoveListener != null) {
      target.removeEventListener('pointermove', _transformMoveListener);
    }
    if (_transformEndListener != null) {
      target
        ..removeEventListener('pointerup', _transformEndListener)
        ..removeEventListener('pointercancel', _transformEndListener);
    }
    _transformMoveListener = null;
    _transformEndListener = null;
  }

  void destroy() {
    _removeTransformListeners();
    _finishEditing(commit: false);
    _rulers.destroy();
    final dom = view.dom as web.EventTarget;
    dom
      ..removeEventListener('dblclick', _doubleClickListener)
      ..removeEventListener('click', _clickListener)
      ..removeEventListener('input', _inputListener)
      ..removeEventListener('focusout', _focusOutListener)
      ..removeEventListener('keydown', _keyDownListener)
      ..removeEventListener('pointerdown', _pointerDownListener);
  }
}
