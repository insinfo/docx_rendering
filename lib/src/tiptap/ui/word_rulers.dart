import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../prosemirror/view/index.dart';
import '../extensions/table_commands.dart' show applyColumnWidths;

/// Pointer coordinates can be fractional (zoom, high-DPI); package:web types
/// them as `int`, which throws on non-integral JS numbers. Read them as raw
/// JS numbers instead.
double _clientX(web.PointerEvent event) =>
    ((event as JSObject).getProperty('clientX'.toJS) as JSNumber).toDartDouble;

double _clientY(web.PointerEvent event) =>
    ((event as JSObject).getProperty('clientY'.toJS) as JSNumber).toDartDouble;

/// Word-style rulers for the paginated editor.
///
/// Mirrors the behaviour of Microsoft Word:
/// - The horizontal ruler is pinned to the top of the document viewport,
///   horizontally aligned with the page, and shows the margin zones plus the
///   indent markers of the paragraph that owns the caret.
/// - The vertical ruler stays at the left edge of the document workspace,
///   far from a centred page like Word's ruler. Its scale is vertically
///   aligned with the *active* page (the page that contains the caret), is
///   exactly one page tall and disappears when that page leaves the viewport.
///
/// Both rulers live inside the zoomed subtree (or mirror its `zoom`), so all
/// graduations scale with the page like Word's do. Everything is drawn with
/// DOM elements and gradients — resolution independent at any zoom.
class WordRulers {
  EditorView view;

  web.HTMLElement? _pageScale;
  web.HTMLElement? _viewport;
  web.HTMLElement? _vTrack;
  web.HTMLElement? _vRuler;
  web.HTMLElement? _hTrack;
  web.HTMLElement? _hCenter;
  web.HTMLElement? _hRuler;
  web.HTMLElement? _hScale;
  web.HTMLElement? _hMargins;
  web.HTMLElement? _hIndents;
  web.HTMLElement? _hTabs;
  web.HTMLElement? _tabSelector;
  web.HTMLElement? _tabGuide;
  web.HTMLElement? _tabTooltip;
  web.MutationObserver? _zoomObserver;
  JSFunction? _indentPointerDownListener;
  JSFunction? _indentPointerMoveListener;
  JSFunction? _indentPointerEndListener;
  _IndentDrag? _indentDrag;
  JSFunction? _tabPointerMoveListener;
  JSFunction? _tabPointerEndListener;
  JSFunction? _tabDoubleClickListener;
  JSFunction? _tabContextMenuListener;
  _TabDrag? _tabDrag;
  String _newTabType = 'left';
  JSFunction? _marginPointerMoveListener;
  JSFunction? _marginPointerEndListener;
  _MarginDrag? _marginDrag;
  web.HTMLElement? _hTableCols;
  _TableColDrag? _tableColDrag;
  JSFunction? _tableColMoveListener;
  JSFunction? _tableColEndListener;
  JSFunction? _viewportScrollListener;
  JSFunction? _windowResizeListener;
  String _geometryKey = '';

  static const double _pxPerCm = 96 / 2.54;
  static const double _rulerThickness = 22;

  WordRulers(this.view) {
    refresh();
  }

  void update(EditorView nextView) {
    view = nextView;
    refresh();
  }

  /// Recomputes visibility, graduations, the active page anchor of the
  /// vertical ruler and the indent markers of the horizontal ruler.
  void refresh() {
    if (!_ensureInstalled()) return;
    final geometry = _readGeometry();
    if (geometry == null) {
      _setVisible(false);
      return;
    }
    final visible = view.editable;
    _setVisible(visible);
    if (!visible) return;
    if (geometry.key != _geometryKey) {
      _geometryKey = geometry.key;
      _rebuildHorizontal(geometry);
      _rebuildVertical(geometry);
    }
    _syncZoom();
    _positionHorizontal();
    _positionVertical(geometry);
    _updateVerticalVisibility();
    _positionIndentMarkers(geometry);
    _positionTabMarkers(geometry);
    _positionTableColumns(geometry);
  }

  void destroy() {
    _finishIndentDrag(commit: false);
    _finishTabDrag(commit: false);
    _finishMarginDrag(commit: false);
    _finishTableColDrag(commit: false);
    if (_viewport != null && _viewportScrollListener != null) {
      _viewport!.removeEventListener('scroll', _viewportScrollListener);
    }
    if (_windowResizeListener != null) {
      (web.window as web.EventTarget)
          .removeEventListener('resize', _windowResizeListener);
    }
    _viewportScrollListener = null;
    _windowResizeListener = null;
    _zoomObserver?.disconnect();
    _zoomObserver = null;
    _vTrack?.remove();
    _vTrack = null;
    _hTrack?.remove();
    _tabGuide?.remove();
    _tabTooltip?.remove();
    _vRuler = null;
    _hTrack = null;
    _hCenter = null;
    _hRuler = null;
    _hScale = null;
    _hMargins = null;
    _hIndents = null;
    _hTabs = null;
    _tabSelector = null;
    _tabGuide = null;
    _tabTooltip = null;
    _pageScale = null;
    _viewport = null;
    _geometryKey = '';
  }

  bool _ensureInstalled() {
    final viewport = view.dom.closest('.document-viewport');
    final pageScale = view.dom.closest('.page-scale');
    if (viewport is! web.HTMLElement || pageScale is! web.HTMLElement) {
      return false;
    }
    final chrome = viewport.parentElement;
    if (chrome is! web.HTMLElement) return false;
    // A view replacement (e.g. opening another document) can recreate the
    // shell around us; re-attach to the current ancestors when they change.
    if (!identical(viewport, _viewport) || !identical(pageScale, _pageScale)) {
      destroy();
      _viewport = viewport;
      _pageScale = pageScale;
      if (pageScale.style.position.isEmpty) {
        pageScale.style.position = 'relative';
      }
      _installVertical(chrome);
      _installHorizontal(viewport);
      _observeZoom(pageScale);
      _geometryKey = '';
    }
    return _vRuler != null && _hRuler != null;
  }

  void _installVertical(web.HTMLElement chrome) {
    final track = web.document.createElement('div') as web.HTMLElement;
    track
      ..className = 'tiptap-vertical-ruler-track'
      ..setAttribute('data-tiptap-vertical-ruler-track', 'true')
      ..setAttribute('aria-hidden', 'true')
      ..setAttribute('contenteditable', 'false');
    final ruler = web.document.createElement('div') as web.HTMLElement;
    ruler
      ..className = 'tiptap-vertical-ruler'
      ..setAttribute('data-tiptap-vertical-ruler', 'true')
      ..setAttribute('aria-hidden', 'true')
      ..setAttribute('contenteditable', 'false');
    track.appendChild(ruler);
    chrome.appendChild(track);
    _vTrack = track;
    _vRuler = ruler;
    ruler.addEventListener(
      'pointerdown',
      ((web.Event rawEvent) {
        if (rawEvent is web.PointerEvent) _beginMarginDrag(rawEvent);
      }).toJS,
    );
  }

  void _installHorizontal(web.HTMLElement viewport) {
    final track = web.document.createElement('div') as web.HTMLElement;
    track
      ..className = 'tiptap-horizontal-ruler-track'
      ..setAttribute('data-tiptap-horizontal-ruler', 'true')
      ..setAttribute('aria-hidden', 'true')
      ..setAttribute('contenteditable', 'false');
    final center = web.document.createElement('div') as web.HTMLElement;
    center.className = 'tiptap-horizontal-ruler-center';
    final ruler = web.document.createElement('div') as web.HTMLElement;
    ruler.className = 'tiptap-horizontal-ruler';
    final scale = web.document.createElement('div') as web.HTMLElement;
    scale.className = 'tiptap-ruler-scale';
    final margins = web.document.createElement('div') as web.HTMLElement;
    margins.className = 'tiptap-ruler-margins';
    final indents = web.document.createElement('div') as web.HTMLElement;
    indents.className = 'tiptap-ruler-indents';
    final tabs = web.document.createElement('div') as web.HTMLElement;
    tabs.className = 'tiptap-ruler-tabs';
    final tableCols = web.document.createElement('div') as web.HTMLElement;
    tableCols.className = 'tiptap-ruler-table-cols';
    ruler
      ..appendChild(scale)
      ..appendChild(margins)
      ..appendChild(indents)
      ..appendChild(tabs)
      ..appendChild(tableCols);
    _hTableCols = tableCols;
    center.appendChild(ruler);
    track.appendChild(center);
    final chrome = viewport.parentElement;
    if (chrome is! web.HTMLElement) return;
    chrome.insertBefore(track, viewport);
    final selector = web.document.createElement('button') as web.HTMLElement;
    selector
      ..className = 'tiptap-ruler-tab-selector is-left'
      ..setAttribute('type', 'button')
      ..setAttribute('aria-label', 'Tipo de tabulação: Esquerdo')
      ..setAttribute('title', 'Tabulação: Esquerdo');
    track.appendChild(selector);
    selector.addEventListener(
      'click',
      ((web.Event event) {
        event
          ..preventDefault()
          ..stopPropagation();
        _cycleNewTabType();
      }).toJS,
    );
    final guide = web.document.createElement('div') as web.HTMLElement;
    guide.className = 'tiptap-ruler-tab-guide';
    final tooltip = web.document.createElement('div') as web.HTMLElement;
    tooltip.className = 'tiptap-ruler-tab-tooltip';
    chrome
      ..appendChild(guide)
      ..appendChild(tooltip);
    _hTrack = track;
    _hCenter = center;
    _hRuler = ruler;
    _hScale = scale;
    _hMargins = margins;
    _hIndents = indents;
    _hTabs = tabs;
    _tabSelector = selector;
    _tabGuide = guide;
    _tabTooltip = tooltip;
    _indentPointerDownListener = ((web.Event rawEvent) {
      if (rawEvent is! web.PointerEvent) return;
      final target = rawEvent.target;
      if (target is! web.Element) return;
      // A fresh text selection may still be sitting in the DOM observer's
      // queue (selectionchange is async). Flush it so ruler gestures see the
      // real selection — the toolbar does the same on pointerdown.
      view.domObserver.forceFlush();
      // Word's priority when controls overlap: table column markers and tab
      // stops win, then indent markers; the margin boundary only reacts
      // where no marker sits under the pointer, and a bare click on the
      // scale creates a tab stop.
      if (target.closest('[data-ruler-table-col]') != null) {
        _beginTableColDrag(rawEvent);
      } else if (target.closest('[data-ruler-tab]') != null) {
        _beginTabDrag(rawEvent);
      } else if (target.closest('[data-ruler-indent]') != null) {
        _beginIndentDrag(rawEvent);
      } else if (target.closest('[data-ruler-margin]') != null) {
        _beginMarginDrag(rawEvent);
      } else if (target.closest('.tiptap-horizontal-ruler') != null) {
        _addTabAtPointer(rawEvent);
      }
    }).toJS;
    track.addEventListener('pointerdown', _indentPointerDownListener);
    _tabDoubleClickListener = ((web.Event rawEvent) {
      final target = rawEvent.target;
      if (target is web.Element) _cycleTabLeader(target);
    }).toJS;
    _tabContextMenuListener = ((web.Event rawEvent) {
      final target = rawEvent.target;
      if (target is web.Element && _removeTab(target)) {
        rawEvent.preventDefault();
      }
    }).toJS;
    track
      ..addEventListener('dblclick', _tabDoubleClickListener)
      ..addEventListener('contextmenu', _tabContextMenuListener);
    _viewportScrollListener = ((web.Event _) {
      final geometry = _readGeometry();
      if (geometry != null) _positionVertical(geometry);
      _positionHorizontal();
      _updateVerticalVisibility();
    }).toJS;
    _windowResizeListener = ((web.Event _) {
      final geometry = _readGeometry();
      if (geometry != null) _positionVertical(geometry);
      _positionHorizontal();
      _updateVerticalVisibility();
    }).toJS;
    viewport.addEventListener('scroll', _viewportScrollListener);
    (web.window as web.EventTarget)
        .addEventListener('resize', _windowResizeListener);
  }

  void _observeZoom(web.HTMLElement pageScale) {
    _zoomObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver observer) {
        if (records.length > 0) refresh();
      }).toJS,
    )..observe(
        pageScale,
        web.MutationObserverInit(attributes: true),
      );
  }

  void _setVisible(bool visible) {
    final display = visible ? '' : 'none';
    _hTrack?.style.display = display;
    if (!visible) _vRuler?.style.display = 'none';
  }

  _RulerGeometry? _readGeometry() {
    final style = view.dom.style;
    double? readVar(String name) {
      final raw = style.getPropertyValue(name).trim();
      if (raw.isEmpty) return null;
      return double.tryParse(raw.replaceAll('px', ''));
    }

    final pageWidth = readVar('--tiptap-page-width');
    final pageHeight = readVar('--tiptap-page-height');
    if (pageWidth == null || pageHeight == null) return null;
    return _RulerGeometry(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      marginTop: readVar('--tiptap-page-margin-top') ?? 0,
      marginRight: readVar('--tiptap-page-margin-right') ?? 0,
      marginBottom: readVar('--tiptap-page-margin-bottom') ?? 0,
      marginLeft: readVar('--tiptap-page-margin-left') ?? 0,
    );
  }

  void _rebuildHorizontal(_RulerGeometry geometry) {
    final ruler = _hRuler;
    final scale = _hScale;
    if (ruler == null || scale == null) return;
    ruler.style
      ..width = '${geometry.pageWidth}px'
      ..background = _zoneGradient(
        'to right',
        geometry.pageWidth,
        geometry.marginLeft,
        geometry.marginRight,
      );
    _buildMarks(
      scale,
      vertical: false,
      length: geometry.pageWidth,
      marginStart: geometry.marginLeft,
      marginEnd: geometry.marginRight,
    );
    _buildMarginHandles(
      ruler: ruler,
      host: _hMargins,
      vertical: false,
      length: geometry.pageWidth,
      start: geometry.marginLeft,
      end: geometry.marginRight,
    );
  }

  void _rebuildVertical(_RulerGeometry geometry) {
    final ruler = _vRuler;
    if (ruler == null) return;
    ruler.style
      ..width = '${_rulerThickness}px'
      ..height = '${geometry.pageHeight}px'
      ..background = _zoneGradient(
        'to bottom',
        geometry.pageHeight,
        geometry.marginTop,
        geometry.marginBottom,
      );
    _buildMarks(
      ruler,
      vertical: true,
      length: geometry.pageHeight,
      marginStart: geometry.marginTop,
      marginEnd: geometry.marginBottom,
    );
    _buildMarginHandles(
      ruler: ruler,
      host: ruler,
      vertical: true,
      length: geometry.pageHeight,
      start: geometry.marginTop,
      end: geometry.marginBottom,
    );
  }

  void _buildMarginHandles({
    required web.HTMLElement ruler,
    required web.HTMLElement? host,
    required bool vertical,
    required double length,
    required double start,
    required double end,
  }) {
    if (host == null) return;
    if (!vertical) host.textContent = '';
    void add(String side, double position) {
      final marker = web.document.createElement('span') as web.HTMLElement;
      marker
        ..className = 'tiptap-ruler-margin tiptap-ruler-margin-$side'
        ..setAttribute('data-ruler-margin', side)
        ..setAttribute('title', 'Margem ${_marginLabel(side)}');
      if (vertical) {
        marker.style.top = '${position.toStringAsFixed(2)}px';
      } else {
        marker.style.left = '${position.toStringAsFixed(2)}px';
      }
      host.appendChild(marker);
    }

    add(vertical ? 'top' : 'left', start);
    add(vertical ? 'bottom' : 'right', length - end);
  }

  String _marginLabel(String side) => switch (side) {
        'left' => 'esquerda',
        'right' => 'direita',
        'top' => 'superior',
        _ => 'inferior',
      };

  void _beginMarginDrag(web.PointerEvent event) {
    if (!view.editable || event.button != 0 || _marginDrag != null) return;
    final target = event.target;
    if (target is! web.Element) return;
    final marker = target.closest('[data-ruler-margin]');
    final geometry = _readGeometry();
    if (marker is! web.HTMLElement || geometry == null) return;
    final side = marker.getAttribute('data-ruler-margin');
    if (side == null) return;
    final vertical = side == 'top' || side == 'bottom';
    final ruler = vertical ? _vRuler : _hRuler;
    if (ruler == null) return;

    event
      ..preventDefault()
      ..stopPropagation();
    _marginDrag = _MarginDrag(
      side: side,
      geometry: geometry,
      ruler: ruler,
      start: vertical ? geometry.marginTop : geometry.marginLeft,
      end: vertical ? geometry.marginBottom : geometry.marginRight,
    );
    marker.classList.add('is-dragging');
    _hTrack?.classList.add('tiptap-ruler-dragging');

    _marginPointerMoveListener = ((web.Event rawEvent) {
      if (rawEvent is web.PointerEvent) _updateMarginDrag(rawEvent);
    }).toJS;
    _marginPointerEndListener = ((web.Event rawEvent) {
      _finishMarginDrag(commit: rawEvent.type == 'pointerup');
    }).toJS;
    final windowTarget = web.window as web.EventTarget;
    windowTarget
      ..addEventListener('pointermove', _marginPointerMoveListener)
      ..addEventListener('pointerup', _marginPointerEndListener)
      ..addEventListener('pointercancel', _marginPointerEndListener);
  }

  void _updateMarginDrag(web.PointerEvent event) {
    final drag = _marginDrag;
    if (drag == null) return;
    event.preventDefault();
    final vertical = drag.side == 'top' || drag.side == 'bottom';
    final rect = drag.ruler.getBoundingClientRect();
    final renderedLength = vertical ? rect.height : rect.width;
    if (renderedLength <= 0) return;
    final length =
        vertical ? drag.geometry.pageHeight : drag.geometry.pageWidth;
    final pointer =
        vertical ? _clientY(event) - rect.top : _clientX(event) - rect.left;
    final logical =
        (pointer * length / renderedLength).clamp(0.0, length).toDouble();
    const minimumContent = 48.0;
    if (drag.side == 'left' || drag.side == 'top') {
      drag.start = logical.clamp(0.0, length - drag.end - minimumContent);
    } else {
      drag.end =
          (length - logical).clamp(0.0, length - drag.start - minimumContent);
    }

    drag.ruler.style.background = _zoneGradient(
      vertical ? 'to bottom' : 'to right',
      length,
      drag.start,
      drag.end,
    );
    _placeMarginMarker(
      drag.side,
      drag.side == 'left' || drag.side == 'top'
          ? drag.start
          : length - drag.end,
    );
    if (!vertical) {
      _showTabFeedback(
        drag.side == 'left' ? drag.start : length - drag.end,
        null,
      );
    }
  }

  void _finishMarginDrag({required bool commit}) {
    _hideTabFeedback();
    final drag = _marginDrag;
    if (drag == null) return;
    final windowTarget = web.window as web.EventTarget;
    if (_marginPointerMoveListener != null) {
      windowTarget.removeEventListener(
        'pointermove',
        _marginPointerMoveListener,
      );
    }
    if (_marginPointerEndListener != null) {
      windowTarget
        ..removeEventListener('pointerup', _marginPointerEndListener)
        ..removeEventListener('pointercancel', _marginPointerEndListener);
    }
    _marginPointerMoveListener = null;
    _marginPointerEndListener = null;
    _hTrack?.classList.remove('tiptap-ruler-dragging');
    final selector = '[data-ruler-margin="${drag.side}"]';
    drag.ruler.querySelector(selector)?.classList.remove('is-dragging');
    _marginDrag = null;

    if (!commit) {
      if (drag.side == 'left' || drag.side == 'right') {
        _rebuildHorizontal(drag.geometry);
      } else {
        _rebuildVertical(drag.geometry);
      }
      return;
    }
    final attribute = switch (drag.side) {
      'left' => 'pageMarginLeft',
      'right' => 'pageMarginRight',
      'top' => 'pageMarginTop',
      _ => 'pageMarginBottom',
    };
    final value =
        drag.side == 'left' || drag.side == 'top' ? drag.start : drag.end;
    final transaction = view.state.tr;
    transaction.setDocAttribute(attribute, _px(value));
    view.dispatch(transaction);
  }

  void _placeMarginMarker(String side, double position) {
    final marker = (side == 'top' || side == 'bottom' ? _vRuler : _hMargins)
        ?.querySelector('[data-ruler-margin="$side"]');
    if (marker is! web.HTMLElement) return;
    if (side == 'top' || side == 'bottom') {
      marker.style.top = '${position.toStringAsFixed(2)}px';
    } else {
      marker.style.left = '${position.toStringAsFixed(2)}px';
    }
  }

  /// OnlyOffice draws the scale as a 13px band inside the ruler strip
  /// (`m_nTop=6..m_nBottom=19` at dPR 1, compressed here to 4..17 of our 22px
  /// strip): white writable zone, #D9D9D9 margins, #CBCBCB hairlines above
  /// and below, and the surrounding chrome background elsewhere
  /// (`CreateBackground`, sdkjs/word/Drawing/Rulers.js:335).
  String _zoneGradient(
    String direction,
    double length,
    double marginStart,
    double marginEnd,
  ) {
    final contentEnd = length - marginEnd;
    final zones = 'linear-gradient($direction, '
        'var(--tiptap-ruler-margin-bg, #d9d9d9) 0 ${marginStart}px, '
        'var(--tiptap-ruler-content-bg, #ffffff) ${marginStart}px '
        '${contentEnd}px, '
        'var(--tiptap-ruler-margin-bg, #d9d9d9) ${contentEnd}px 100%)';
    const line =
        'linear-gradient(var(--tiptap-ruler-outline, #cbcbcb), '
        'var(--tiptap-ruler-outline, #cbcbcb))';
    if (direction == 'to bottom') {
      // Vertical ruler: the band spans x 4..17.
      return '$line 4px 0 / 1px 100% no-repeat, '
          '$line 16px 0 / 1px 100% no-repeat, '
          '$zones 5px 0 / 11px 100% no-repeat';
    }
    return '$line 0 4px / 100% 1px no-repeat, '
        '$line 0 16px / 100% 1px no-repeat, '
        '$zones 0 5px / 100% 11px no-repeat';
  }

  /// OnlyOffice's `drawLayoutMM` (Rulers.js:557): the scale walks away from
  /// the margin boundary in quarter-centimetre steps, in both directions —
  /// also into the margins. Every 4th step is a number (7pt Arial anchored
  /// near the band bottom), every 2nd a 5px tick and the remaining quarters a
  /// 3px tick, both centred in the band.
  void _buildMarks(
    web.HTMLElement host, {
    required bool vertical,
    required double length,
    required double marginStart,
    required double marginEnd,
  }) {
    host.textContent = '';
    const quarter = _pxPerCm / 4;

    void mark(double position, int quarterSteps) {
      if (position < 0 || position > length) return;
      final wholeCentimetre = quarterSteps % 4 == 0;
      final halfCentimetre = quarterSteps % 2 == 0;
      final label = quarterSteps ~/ 4;
      final element = web.document.createElement('span') as web.HTMLElement;
      if (wholeCentimetre && label > 0) {
        element
          ..className = 'tiptap-ruler-num'
          ..textContent = '$label';
      } else if (!wholeCentimetre) {
        element.className =
            'tiptap-ruler-tick${halfCentimetre ? ' is-half' : ' is-quarter'}';
      } else {
        return;
      }
      if (vertical) {
        element.style.top = '${position.toStringAsFixed(2)}px';
      } else {
        element.style.left = '${position.toStringAsFixed(2)}px';
      }
      host.appendChild(element);
    }

    // Start margin: anchored at the boundary, counting outward (upwards/left).
    for (var step = 1; marginStart - step * quarter >= -0.5; step++) {
      mark(marginStart - step * quarter, step);
    }
    // Writable area: anchored at the start boundary.
    final contentEnd = length - marginEnd;
    for (var step = 1;
        marginStart + step * quarter <= contentEnd + 0.5;
        step++) {
      mark(marginStart + step * quarter, step);
    }
    // End margin: anchored at its own boundary, counting outward.
    for (var step = 1; contentEnd + step * quarter <= length + 0.5; step++) {
      mark(contentEnd + step * quarter, step);
    }
  }

  void _syncZoom() {
    final pageScale = _pageScale;
    final ruler = _hRuler;
    if (pageScale == null || ruler == null) return;
    final zoom = double.tryParse(pageScale.style.zoom) ?? 1;
    final transform = 'scale($zoom)';
    if (ruler.style.transform != transform) ruler.style.transform = transform;
    final vertical = _vRuler;
    if (vertical != null && vertical.style.transform != transform) {
      vertical.style.transform = transform;
    }
  }

  /// Keeps the fixed editor-chrome ruler aligned with the scrolling page.
  void _positionHorizontal() {
    final track = _hTrack;
    final center = _hCenter;
    final pageScale = _pageScale;
    if (track == null || center == null || pageScale == null) return;
    final left = pageScale.getBoundingClientRect().left -
        track.getBoundingClientRect().left;
    final value = '${left.toStringAsFixed(2)}px';
    if (center.style.left != value) center.style.left = value;
  }

  /// Keeps the ruler in the workspace gutter while its scale follows the
  /// vertical position of the page that owns the caret.
  void _positionVertical(_RulerGeometry geometry) {
    final ruler = _vRuler;
    final track = _vTrack;
    final viewport = _viewport;
    final chrome = viewport?.parentElement;
    if (ruler == null ||
        track == null ||
        viewport == null ||
        chrome is! web.HTMLElement) {
      return;
    }
    final header = _activePageHeader();
    final activeRect = (header ?? view.dom).getBoundingClientRect();
    final chromeRect = chrome.getBoundingClientRect();
    final viewportRect = viewport.getBoundingClientRect();
    final trackTop = viewportRect.top - chromeRect.top;
    final left = viewportRect.left - chromeRect.left;
    final rulerTop = activeRect.top - viewportRect.top;
    final trackTopValue = '${trackTop.toStringAsFixed(2)}px';
    final leftValue = '${left.toStringAsFixed(2)}px';
    final heightValue = '${viewportRect.height.toStringAsFixed(2)}px';
    if (track.style.top != trackTopValue) track.style.top = trackTopValue;
    if (track.style.left != leftValue) track.style.left = leftValue;
    if (track.style.height != heightValue) track.style.height = heightValue;
    final rulerTopValue = '${rulerTop.toStringAsFixed(2)}px';
    if (ruler.style.top != rulerTopValue) ruler.style.top = rulerTopValue;
    ruler.style.left = '0px';
    ruler.style.display = '';
  }

  void _updateVerticalVisibility() {
    final ruler = _vRuler;
    final viewport = _viewport;
    if (ruler == null || viewport == null || !view.editable) return;
    ruler.style.display = '';
    final rulerRect = ruler.getBoundingClientRect();
    final viewportRect = viewport.getBoundingClientRect();
    final intersects = rulerRect.bottom > viewportRect.top + 1 &&
        rulerRect.top < viewportRect.bottom - 1;
    ruler.style.display = intersects ? '' : 'none';
  }

  web.HTMLElement? _activePageHeader() {
    final headers = view.dom.querySelectorAll('.tiptap-page-header');
    if (headers.length == 0) return null;
    double? caretTop;
    try {
      caretTop = view.coordsAtPos(view.state.selection.head).top;
    } catch (_) {
      caretTop = null;
    }
    web.HTMLElement? active;
    for (var index = 0; index < headers.length; index++) {
      final header = headers.item(index);
      if (header is! web.HTMLElement) continue;
      active ??= header;
      if (caretTop == null) break;
      if (header.getBoundingClientRect().top <= caretTop + 1) {
        active = header;
      } else {
        break;
      }
    }
    return active;
  }

  /// Moves the first-line/hanging/right indent markers to reflect the
  /// paragraph that owns the caret, exactly like Word's horizontal ruler.
  void _positionIndentMarkers(_RulerGeometry geometry) {
    final indents = _hIndents;
    if (indents == null) return;
    final current = _currentIndents(geometry);
    final leftIndent = current.left;
    final rightIndent = current.right;
    final firstLine = current.first;
    if (indents.firstChild == null) {
      for (final kind in const ['first', 'hanging', 'left', 'right']) {
        final marker = web.document.createElement('span') as web.HTMLElement;
        marker
          ..className = 'tiptap-ruler-indent tiptap-ruler-indent-$kind'
          ..setAttribute('data-ruler-indent', kind);
        indents.appendChild(marker);
      }
    }
    void place(String kind, double position) {
      final marker = indents.querySelector('[data-ruler-indent="$kind"]');
      if (marker is! web.HTMLElement) return;
      final value = '${position.toStringAsFixed(2)}px';
      if (marker.style.left != value) marker.style.left = value;
    }

    place('first', firstLine);
    place('hanging', leftIndent);
    place('left', leftIndent);
    place('right', rightIndent);
  }

  _IndentGeometry _currentIndents(_RulerGeometry geometry) {
    var left = geometry.marginLeft;
    var right = geometry.pageWidth - geometry.marginRight;
    var first = left;
    var paddingLeft = 0.0;
    var paddingRight = 0.0;
    final block = _caretBlock();
    if (block != null) {
      final style = web.window.getComputedStyle(block);
      double parse(String value) =>
          double.tryParse(value.replaceAll('px', '')) ?? 0;
      paddingLeft = parse(style.paddingLeft);
      paddingRight = parse(style.paddingRight);
      left += parse(style.marginLeft) + paddingLeft;
      right -= parse(style.marginRight) + paddingRight;
      first = left + parse(style.textIndent);
    }
    return _IndentGeometry(
      block: block,
      left: left,
      right: right,
      first: first,
      paddingLeft: paddingLeft,
      paddingRight: paddingRight,
    );
  }

  void _beginIndentDrag(web.PointerEvent event) {
    if (!view.editable || event.button != 0 || _indentDrag != null) return;
    final target = event.target;
    if (target is! web.Element) return;
    final marker = target.closest('[data-ruler-indent]');
    final geometry = _readGeometry();
    final ruler = _hRuler;
    if (marker is! web.HTMLElement || geometry == null || ruler == null) {
      return;
    }
    final kind = marker.getAttribute('data-ruler-indent');
    if (kind == null) return;
    final current = _currentIndents(geometry);
    final block = current.block;
    final targetNode = _caretTextblock();
    if (block == null || targetNode == null) return;

    event
      ..preventDefault()
      ..stopPropagation();
    final inlineStyle = block.getAttribute('style');
    final targets = <_IndentDragTarget>[
      for (final selected in _selectionTextblocks())
        _IndentDragTarget(
          position: selected.position,
          attrs: Map<String, dynamic>.from(selected.node.attrs),
          dom: switch (view.nodeDOM(selected.position)) {
            final web.HTMLElement element => element,
            _ => null,
          },
          inlineStyle: switch (view.nodeDOM(selected.position)) {
            final web.HTMLElement element => element.getAttribute('style'),
            _ => null,
          },
        ),
    ];
    _indentDrag = _IndentDrag(
      kind: kind,
      geometry: geometry,
      block: block,
      nodePosition: targetNode.position,
      originalAttrs: Map<String, dynamic>.from(targetNode.node.attrs),
      originalInlineStyle: inlineStyle,
      paddingLeft: current.paddingLeft,
      paddingRight: current.paddingRight,
      targets: targets,
      left: current.left,
      right: current.right,
      first: current.first,
    );
    _hTrack?.classList.add('tiptap-ruler-dragging');
    marker.classList.add('is-dragging');

    _indentPointerMoveListener = ((web.Event rawEvent) {
      if (rawEvent is web.PointerEvent) _updateIndentDrag(rawEvent);
    }).toJS;
    _indentPointerEndListener = ((web.Event rawEvent) {
      _finishIndentDrag(commit: rawEvent.type == 'pointerup');
    }).toJS;
    final windowTarget = web.window as web.EventTarget;
    windowTarget
      ..addEventListener('pointermove', _indentPointerMoveListener)
      ..addEventListener('pointerup', _indentPointerEndListener)
      ..addEventListener('pointercancel', _indentPointerEndListener);
  }

  void _updateIndentDrag(web.PointerEvent event) {
    final drag = _indentDrag;
    final ruler = _hRuler;
    if (drag == null || ruler == null) return;
    event.preventDefault();
    final rect = ruler.getBoundingClientRect();
    if (rect.width <= 0) return;
    final logical =
        ((_clientX(event) - rect.left) * drag.geometry.pageWidth / rect.width)
            .clamp(0.0, drag.geometry.pageWidth)
            .toDouble();
    final contentStart = drag.geometry.marginLeft;
    final contentEnd = drag.geometry.pageWidth - drag.geometry.marginRight;
    const minimumTextWidth = 12.0;

    switch (drag.kind) {
      case 'first':
        drag.first = logical.clamp(0.0, drag.right - minimumTextWidth);
      case 'hanging':
        final oldFirst = drag.first;
        drag.left = logical.clamp(0.0, drag.right - minimumTextWidth);
        drag.first = oldFirst;
      case 'left':
        final delta =
            logical.clamp(0.0, drag.right - minimumTextWidth) - drag.left;
        drag.left += delta;
        drag.first += delta;
      case 'right':
        drag.right = logical.clamp(
          math.max(drag.left, drag.first) + minimumTextWidth,
          drag.geometry.pageWidth,
        );
    }

    final marginLeft = drag.left - contentStart - drag.paddingLeft;
    final marginRight = contentEnd - drag.right - drag.paddingRight;
    final textIndent = drag.first - drag.left;
    // Live preview on every selected paragraph, like Word.
    for (final target in drag.targets) {
      final dom = target.dom;
      if (dom == null) continue;
      dom.style
        ..marginLeft = _px(marginLeft)
        ..marginRight = _px(marginRight)
        ..textIndent = _px(textIndent);
    }
    _placeIndentMarker('first', drag.first);
    _placeIndentMarker('hanging', drag.left);
    _placeIndentMarker('left', drag.left);
    _placeIndentMarker('right', drag.right);
    _showTabFeedback(
      switch (drag.kind) {
        'first' => drag.first,
        'right' => drag.right,
        _ => drag.left,
      },
      null,
    );
  }

  void _finishIndentDrag({required bool commit}) {
    final drag = _indentDrag;
    if (drag == null) return;
    final windowTarget = web.window as web.EventTarget;
    if (_indentPointerMoveListener != null) {
      windowTarget.removeEventListener(
        'pointermove',
        _indentPointerMoveListener,
      );
    }
    if (_indentPointerEndListener != null) {
      windowTarget
        ..removeEventListener('pointerup', _indentPointerEndListener)
        ..removeEventListener('pointercancel', _indentPointerEndListener);
    }
    _indentPointerMoveListener = null;
    _indentPointerEndListener = null;
    _hideTabFeedback();
    _hTrack?.classList.remove('tiptap-ruler-dragging');
    _hIndents?.querySelector('.is-dragging')?.classList.remove('is-dragging');

    // Drop the live preview styles from every selected paragraph.
    for (final target in drag.targets) {
      final dom = target.dom;
      if (dom == null || !dom.isConnected) continue;
      if (target.inlineStyle == null) {
        dom.removeAttribute('style');
      } else {
        dom.setAttribute('style', target.inlineStyle!);
      }
    }
    if (drag.originalInlineStyle == null) {
      drag.block.removeAttribute('style');
    } else {
      drag.block.setAttribute('style', drag.originalInlineStyle!);
    }
    _indentDrag = null;
    if (!commit) {
      final geometry = _readGeometry();
      if (geometry != null) _positionIndentMarkers(geometry);
      return;
    }

    final contentStart = drag.geometry.marginLeft;
    final contentEnd = drag.geometry.pageWidth - drag.geometry.marginRight;
    final marginLeft = _px(drag.left - contentStart - drag.paddingLeft);
    final marginRight = _px(contentEnd - drag.right - drag.paddingRight);
    final textIndent = _px(drag.first - drag.left);
    // One transaction covering every selected paragraph; setNodeMarkup keeps
    // node sizes stable, so the captured positions remain valid.
    final transaction = view.state.tr;
    var changed = false;
    for (final target in drag.targets) {
      final node = view.state.doc.nodeAt(target.position);
      if (node == null || !node.isTextblock) continue;
      transaction.setNodeMarkup(
        target.position,
        null,
        Map<String, dynamic>.from(target.attrs)
          ..['marginLeft'] = marginLeft
          ..['marginRight'] = marginRight
          ..['textIndent'] = textIndent,
        node.marks,
      );
      changed = true;
    }
    if (changed) view.dispatch(transaction);
  }

  void _placeIndentMarker(String kind, double position) {
    final marker = _hIndents?.querySelector('[data-ruler-indent="$kind"]');
    if (marker is web.HTMLElement) {
      marker.style.left = '${position.toStringAsFixed(2)}px';
    }
  }

  void _cycleNewTabType() {
    const types = ['left', 'center', 'right', 'decimal'];
    _newTabType = types[(types.indexOf(_newTabType) + 1) % types.length];
    final selector = _tabSelector;
    if (selector == null) return;
    selector.className = 'tiptap-ruler-tab-selector is-$_newTabType';
    final label = _tabTypeLabel(_newTabType);
    selector
      ..setAttribute('aria-label', 'Tipo de tabulação: $label')
      ..setAttribute('title', 'Tabulação: $label');
  }

  void _positionTabMarkers(_RulerGeometry geometry) {
    final host = _hTabs;
    if (host == null || _tabDrag != null) return;
    host.textContent = '';
    final target = _caretTextblock();
    if (target == null) return;
    final stops = _tabStops(target.node.attrs['tabStops']);
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      final position = _lengthPx(stop['position']);
      if (position == null) continue;
      final type = _tabType(stop['type']);
      final leader = _tabLeader(stop['leader']);
      final marker = web.document.createElement('span') as web.HTMLElement;
      marker
        ..className = 'tiptap-ruler-tab is-$type'
        ..setAttribute('data-ruler-tab', '$index')
        ..setAttribute('data-tab-type', type)
        ..setAttribute('data-tab-leader', leader)
        ..setAttribute(
          'title',
          '${_tabTypeLabel(type)} ${_centimetres(position)}'
              '${leader == 'none' ? '' : ' · ${_leaderLabel(leader)}'}\n'
              'Arraste para mover; duplo clique muda o preenchimento; botão direito remove.',
        );
      marker.style.left =
          '${(geometry.marginLeft + position).toStringAsFixed(2)}px';
      host.appendChild(marker);
    }
  }

  void _addTabAtPointer(web.PointerEvent event) {
    if (!view.editable || event.button != 0) return;
    final ruler = _hRuler;
    final geometry = _readGeometry();
    final target = _caretTextblock();
    if (ruler == null || geometry == null || target == null) return;
    final rect = ruler.getBoundingClientRect();
    if (rect.width <= 0) return;
    // A click that narrowly misses an indent/margin control is a failed drag,
    // not a request for a new tab stop — Word ignores it too.
    final controls =
        ruler.querySelectorAll('[data-ruler-indent], [data-ruler-margin]');
    for (var i = 0; i < controls.length; i++) {
      final control = controls.item(i);
      if (control is! web.Element) continue;
      final controlRect = control.getBoundingClientRect();
      if (_clientX(event) >= controlRect.left - 6 &&
          _clientX(event) <= controlRect.right + 6) {
        return;
      }
    }
    final logical =
        (_clientX(event) - rect.left) * geometry.pageWidth / rect.width;
    final contentWidth =
        geometry.pageWidth - geometry.marginLeft - geometry.marginRight;
    var position = logical - geometry.marginLeft;
    if (position < 0 || position > contentWidth) return;
    event
      ..preventDefault()
      ..stopPropagation();
    position = _snapTab(position).clamp(0.0, contentWidth).toDouble();
    final stops = _tabStops(target.node.attrs['tabStops']);
    final existing = stops.indexWhere((stop) {
      final value = _lengthPx(stop['position']);
      return value != null && (value - position).abs() <= 3;
    });
    final next = <String, dynamic>{
      'position': _px(position),
      'type': _newTabType,
      'leader': 'none',
    };
    if (existing < 0) {
      stops.add(next);
    } else {
      stops[existing] = next;
    }
    _sortTabStops(stops);
    _setTabStops(target.position, target.node, stops);
  }

  void _beginTabDrag(web.PointerEvent event) {
    if (!view.editable || event.button != 0 || _tabDrag != null) return;
    final rawTarget = event.target;
    final geometry = _readGeometry();
    final ruler = _hRuler;
    final target = _caretTextblock();
    if (rawTarget is! web.Element ||
        geometry == null ||
        ruler == null ||
        target == null) {
      return;
    }
    final marker = rawTarget.closest('[data-ruler-tab]');
    if (marker is! web.HTMLElement) return;
    final index = int.tryParse(marker.getAttribute('data-ruler-tab') ?? '');
    final stops = _tabStops(target.node.attrs['tabStops']);
    if (index == null || index < 0 || index >= stops.length) return;
    final position = _lengthPx(stops[index]['position']);
    if (position == null) return;
    event
      ..preventDefault()
      ..stopPropagation();
    marker.classList.add('is-dragging');
    _tabDrag = _TabDrag(
      index: index,
      geometry: geometry,
      nodePosition: target.position,
      originalNode: target.node,
      stops: stops,
      position: position,
    );
    _showTabFeedback(
      geometry.marginLeft + position,
      '${_tabTypeLabel(_tabType(stops[index]['type']))} ${_centimetres(position)}',
    );
    _tabPointerMoveListener = ((web.Event rawEvent) {
      if (rawEvent is web.PointerEvent) _updateTabDrag(rawEvent);
    }).toJS;
    _tabPointerEndListener = ((web.Event rawEvent) {
      _finishTabDrag(commit: rawEvent.type == 'pointerup');
    }).toJS;
    final windowTarget = web.window as web.EventTarget;
    windowTarget
      ..addEventListener('pointermove', _tabPointerMoveListener)
      ..addEventListener('pointerup', _tabPointerEndListener)
      ..addEventListener('pointercancel', _tabPointerEndListener);
  }

  void _updateTabDrag(web.PointerEvent event) {
    final drag = _tabDrag;
    final ruler = _hRuler;
    if (drag == null || ruler == null) return;
    event.preventDefault();
    final rect = ruler.getBoundingClientRect();
    if (rect.width <= 0) return;
    final contentWidth = drag.geometry.pageWidth -
        drag.geometry.marginLeft -
        drag.geometry.marginRight;
    final logical =
        (_clientX(event) - rect.left) * drag.geometry.pageWidth / rect.width;
    drag.position = _snapTab(logical - drag.geometry.marginLeft)
        .clamp(0.0, contentWidth)
        .toDouble();
    drag.removed =
        _clientY(event) < rect.top - 28 || _clientY(event) > rect.bottom + 28;
    final marker = _hTabs?.querySelector('[data-ruler-tab="${drag.index}"]');
    if (marker is web.HTMLElement) {
      marker
        ..classList.toggle('is-removing', drag.removed)
        ..style.left =
            '${(drag.geometry.marginLeft + drag.position).toStringAsFixed(2)}px';
    }
    final stop = drag.stops[drag.index];
    _showTabFeedback(
      drag.geometry.marginLeft + drag.position,
      drag.removed
          ? 'Remover tabulação'
          : '${_tabTypeLabel(_tabType(stop['type']))} ${_centimetres(drag.position)}',
    );
  }

  void _finishTabDrag({required bool commit}) {
    final drag = _tabDrag;
    if (drag == null) return;
    final windowTarget = web.window as web.EventTarget;
    if (_tabPointerMoveListener != null) {
      windowTarget.removeEventListener('pointermove', _tabPointerMoveListener);
    }
    if (_tabPointerEndListener != null) {
      windowTarget
        ..removeEventListener('pointerup', _tabPointerEndListener)
        ..removeEventListener('pointercancel', _tabPointerEndListener);
    }
    _tabPointerMoveListener = null;
    _tabPointerEndListener = null;
    _hideTabFeedback();
    _tabDrag = null;
    if (!commit) {
      final geometry = _readGeometry();
      if (geometry != null) _positionTabMarkers(geometry);
      return;
    }
    final stops = drag.stops;
    if (drag.removed) {
      stops.removeAt(drag.index);
    } else {
      stops[drag.index] = {
        ...stops[drag.index],
        'position': _px(drag.position),
      };
      _sortTabStops(stops);
    }
    _setTabStops(drag.nodePosition, drag.originalNode, stops);
  }

  void _cycleTabLeader(web.Element eventTarget) {
    final marker = eventTarget.closest('[data-ruler-tab]');
    final target = _caretTextblock();
    if (marker is! web.HTMLElement || target == null) return;
    final index = int.tryParse(marker.getAttribute('data-ruler-tab') ?? '');
    final stops = _tabStops(target.node.attrs['tabStops']);
    if (index == null || index < 0 || index >= stops.length) return;
    const leaders = ['none', 'dot', 'hyphen', 'underscore', 'middleDot'];
    final current = _tabLeader(stops[index]['leader']);
    stops[index] = {
      ...stops[index],
      'leader': leaders[(leaders.indexOf(current) + 1) % leaders.length],
    };
    _setTabStops(target.position, target.node, stops);
  }

  bool _removeTab(web.Element eventTarget) {
    final marker = eventTarget.closest('[data-ruler-tab]');
    final target = _caretTextblock();
    if (marker is! web.HTMLElement || target == null) return false;
    final index = int.tryParse(marker.getAttribute('data-ruler-tab') ?? '');
    final stops = _tabStops(target.node.attrs['tabStops']);
    if (index == null || index < 0 || index >= stops.length) return false;
    stops.removeAt(index);
    _setTabStops(target.position, target.node, stops);
    return true;
  }

  void _setTabStops(
      int position, dynamic node, List<Map<String, dynamic>> stops) {
    // Word applies tab-stop edits to every paragraph in the selection (the
    // dialog and the ruler behave the same way); the anchor paragraph is
    // included even when the selection resolver misses it.
    final targets = _selectionTextblocks();
    if (!targets.any((target) => target.position == position)) {
      targets.add((position: position, node: node));
    }
    final transaction = view.state.tr;
    var changed = false;
    for (final target in targets) {
      final current = view.state.doc.nodeAt(target.position);
      if (current == null || !current.isTextblock) continue;
      final attrs = Map<String, dynamic>.from(current.attrs)
        ..['tabStops'] = stops.isEmpty ? null : stops;
      transaction.setNodeMarkup(target.position, null, attrs, current.marks);
      changed = true;
    }
    if (changed) view.dispatch(transaction);
  }

  /// Shows Word's dotted vertical drag guide at [pagePosition]; with a
  /// non-null [text] the tooltip follows it (tab drags), otherwise only the
  /// guide is shown (indent/margin drags, like Word).
  void _showTabFeedback(double pagePosition, String? text) {
    final guide = _tabGuide;
    final tooltip = _tabTooltip;
    final ruler = _hRuler;
    final chrome = _viewport?.parentElement;
    final geometry = _readGeometry();
    if (guide == null ||
        tooltip == null ||
        ruler == null ||
        chrome is! web.HTMLElement ||
        geometry == null) {
      return;
    }
    final chromeRect = chrome.getBoundingClientRect();
    final rulerRect = ruler.getBoundingClientRect();
    final viewportRect = _viewport!.getBoundingClientRect();
    final x = rulerRect.left -
        chromeRect.left +
        pagePosition * rulerRect.width / geometry.pageWidth;
    final top = rulerRect.bottom - chromeRect.top;
    guide.style
      ..left = '${x.toStringAsFixed(2)}px'
      ..top = '${top.toStringAsFixed(2)}px'
      ..height = '${math.max(0, viewportRect.bottom - rulerRect.bottom)}px';
    guide.classList.add('show');
    if (text == null) {
      tooltip.classList.remove('show');
      return;
    }
    tooltip
      ..textContent = text
      ..style.left = '${(x + 6).toStringAsFixed(2)}px'
      ..style.top = '${math.max(2, rulerRect.top - chromeRect.top - 27)}px';
    tooltip.classList.add('show');
  }

  void _hideTabFeedback() {
    _tabGuide?.classList.remove('show');
    _tabTooltip?.classList.remove('show');
  }

  List<Map<String, dynamic>> _tabStops(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((stop) => Map<String, dynamic>.from(stop))
        .where((stop) => _lengthPx(stop['position']) != null)
        .toList(growable: true);
  }

  void _sortTabStops(List<Map<String, dynamic>> stops) => stops.sort((a, b) =>
      (_lengthPx(a['position']) ?? 0).compareTo(_lengthPx(b['position']) ?? 0));

  double _snapTab(double value) =>
      (value / (_pxPerCm / 4)).round() * (_pxPerCm / 4);

  String _tabType(dynamic value) {
    final type = '$value';
    return const ['left', 'center', 'right', 'decimal'].contains(type)
        ? type
        : 'left';
  }

  String _tabLeader(dynamic value) {
    final leader = '$value';
    return const ['none', 'dot', 'hyphen', 'underscore', 'middleDot']
            .contains(leader)
        ? leader
        : 'none';
  }

  String _tabTypeLabel(String type) => switch (type) {
        'center' => 'Centralizado',
        'right' => 'Direito',
        'decimal' => 'Decimal',
        _ => 'Esquerdo',
      };

  String _leaderLabel(String leader) => switch (leader) {
        'dot' => 'pontos',
        'hyphen' => 'hífens',
        'underscore' => 'sublinhado',
        'middleDot' => 'pontos médios',
        _ => 'sem preenchimento',
      };

  String _centimetres(double pixels) =>
      '${(pixels / _pxPerCm).toStringAsFixed(2).replaceAll('.', ',')} cm';

  double? _lengthPx(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    final match = RegExp(
      r'^\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*(px|pt|pc|in|cm|mm)?\s*$',
      caseSensitive: false,
    ).firstMatch('$value');
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite) return null;
    return switch ((match.group(2) ?? 'px').toLowerCase()) {
      'pt' => amount * 96 / 72,
      'pc' => amount * 16,
      'in' => amount * 96,
      'cm' => amount * _pxPerCm,
      'mm' => amount * _pxPerCm / 10,
      _ => amount,
    };
  }

  // ------------------------------------------------ modo tabela da régua

  double get _pageZoom {
    final value = double.tryParse(_pageScale?.style.zoom ?? '');
    return value != null && value > 0 ? value : 1;
  }

  ({int position, dynamic node})? _caretTable() {
    final resolved = view.state.selection.fromRes;
    for (var depth = resolved.depth; depth > 0; depth--) {
      final node = resolved.node(depth);
      if (node.type.name == 'table') {
        return (position: resolved.before(depth), node: node);
      }
    }
    return null;
  }

  /// Column boundaries of [tableEl] in page-logical px (the ruler's
  /// coordinate space), derived from the rendered cell rectangles so
  /// colspans and both grid/table layouts are handled — the same approach as
  /// the in-document resizer.
  List<double>? _tableBoundariesLogical(web.HTMLElement tableEl) {
    final pageScale = _pageScale;
    if (pageScale == null) return null;
    final zoom = _pageZoom;
    final pageLeft = pageScale.getBoundingClientRect().left;
    final xs = <double>[];
    void push(double value) {
      for (final existing in xs) {
        if ((existing - value).abs() <= 1.5) return;
      }
      xs.add(value);
    }

    final cells = tableEl.querySelectorAll('tr > td, tr > th');
    for (var i = 0; i < cells.length; i++) {
      final cell = cells.item(i);
      if (cell is! web.HTMLElement) continue;
      if (cell.closest('table') != tableEl) continue;
      final rect = cell.getBoundingClientRect();
      push((rect.left - pageLeft) / zoom);
      push((rect.right - pageLeft) / zoom);
    }
    xs.sort();
    return xs.length >= 2 ? xs : null;
  }

  /// Word's `RULER_OBJECT_TYPE_TABLE`: when the caret sits in a table the
  /// ruler shows a draggable marker on every column boundary.
  void _positionTableColumns(_RulerGeometry geometry) {
    final host = _hTableCols;
    if (host == null || _tableColDrag != null) return;
    host.textContent = '';
    final table = _caretTable();
    _hRuler?.classList.toggle('is-table-mode', table != null);
    if (table == null || !view.editable) return;
    final dom = view.nodeDOM(table.position);
    if (dom is! web.HTMLElement) return;
    final xs = _tableBoundariesLogical(dom);
    if (xs == null) return;
    // Skip the left edge: moving it is table indentation, not column width.
    for (var index = 1; index < xs.length; index++) {
      final marker = web.document.createElement('span') as web.HTMLElement;
      marker
        ..className = 'tiptap-ruler-table-col'
        ..setAttribute('data-ruler-table-col', '$index')
        ..setAttribute('title', 'Mover Coluna da Tabela')
        ..style.left = '${xs[index].toStringAsFixed(2)}px';
      host.appendChild(marker);
    }
  }

  void _beginTableColDrag(web.PointerEvent event) {
    if (!view.editable || event.button != 0 || _tableColDrag != null) return;
    final target = event.target;
    if (target is! web.Element) return;
    final marker = target.closest('[data-ruler-table-col]');
    final table = _caretTable();
    if (marker is! web.HTMLElement || table == null) return;
    final boundary =
        int.tryParse(marker.getAttribute('data-ruler-table-col') ?? '');
    final dom = view.nodeDOM(table.position);
    if (boundary == null || boundary < 1 || dom is! web.HTMLElement) return;
    final xs = _tableBoundariesLogical(dom);
    if (xs == null || boundary >= xs.length) return;
    event
      ..preventDefault()
      ..stopPropagation();
    _tableColDrag = _TableColDrag(
      boundary: boundary,
      tablePosition: table.position,
      tableEl: dom,
      tableLeft: xs.first,
      tracks: [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]],
      startX: _clientX(event),
    );
    marker.classList.add('is-dragging');
    _hTrack?.classList.add('tiptap-ruler-dragging');
    _tableColMoveListener = ((web.Event rawEvent) {
      if (rawEvent is web.PointerEvent) _updateTableColDrag(rawEvent);
    }).toJS;
    _tableColEndListener = ((web.Event rawEvent) {
      _finishTableColDrag(commit: rawEvent.type == 'pointerup');
    }).toJS;
    final windowTarget = web.window as web.EventTarget;
    windowTarget
      ..addEventListener('pointermove', _tableColMoveListener)
      ..addEventListener('pointerup', _tableColEndListener)
      ..addEventListener('pointercancel', _tableColEndListener);
  }

  List<double> _tableColTracksFor(_TableColDrag drag, double clientX) {
    const minimumTrack = 24.0;
    final delta = (clientX - drag.startX) / _pageZoom;
    final tracks = List<double>.from(drag.tracks);
    final index = drag.boundary - 1;
    if (index >= 0 && index < tracks.length) {
      tracks[index] = math.max(minimumTrack, tracks[index] + delta);
    }
    return tracks;
  }

  void _updateTableColDrag(web.PointerEvent event) {
    final drag = _tableColDrag;
    if (drag == null) return;
    event.preventDefault();
    drag.lastClientX = _clientX(event);
    final tracks = _tableColTracksFor(drag, drag.lastClientX!);
    final template =
        tracks.map((w) => '${w.toStringAsFixed(1)}px').join(' ');
    final rows = drag.tableEl.querySelectorAll('tr');
    for (var i = 0; i < rows.length; i++) {
      final row = rows.item(i);
      if (row is! web.HTMLElement) continue;
      drag.rememberRow(row);
      row.style.gridTemplateColumns = template;
    }
    var markerX = drag.tableLeft;
    for (var i = 0; i < drag.boundary && i < tracks.length; i++) {
      markerX += tracks[i];
    }
    final marker = _hTableCols
        ?.querySelector('[data-ruler-table-col="${drag.boundary}"]');
    if (marker is web.HTMLElement) {
      marker.style.left = '${markerX.toStringAsFixed(2)}px';
    }
    _showTabFeedback(markerX, null);
  }

  void _finishTableColDrag({required bool commit}) {
    final drag = _tableColDrag;
    if (drag == null) return;
    final windowTarget = web.window as web.EventTarget;
    if (_tableColMoveListener != null) {
      windowTarget.removeEventListener('pointermove', _tableColMoveListener);
    }
    if (_tableColEndListener != null) {
      windowTarget
        ..removeEventListener('pointerup', _tableColEndListener)
        ..removeEventListener('pointercancel', _tableColEndListener);
    }
    _tableColMoveListener = null;
    _tableColEndListener = null;
    _hideTabFeedback();
    _hTrack?.classList.remove('tiptap-ruler-dragging');
    _hTableCols
        ?.querySelector('.is-dragging')
        ?.classList
        .remove('is-dragging');
    for (final (row, style) in drag.previewedRows) {
      if (style == null) {
        row.removeAttribute('style');
      } else {
        row.setAttribute('style', style);
      }
    }
    final lastPointerX = drag.lastClientX;
    _tableColDrag = null;
    if (!commit) {
      refresh();
      return;
    }
    final tracks = _tableColTracksFor(drag, lastPointerX ?? drag.startX);
    final node = view.state.doc.nodeAt(drag.tablePosition);
    if (node == null || node.type.name != 'table') return;
    final transaction = view.state.tr;
    applyColumnWidths(
      transaction,
      drag.tablePosition,
      tracks.map((w) => w.round()).toList(),
    );
    view.dispatch(transaction);
  }

  ({int position, dynamic node})? _caretTextblock() {
    // Word anchors the ruler state on the FIRST paragraph of the selection.
    final resolved = view.state.selection.fromRes;
    for (var depth = resolved.depth; depth > 0; depth--) {
      final node = resolved.node(depth);
      if (node.isTextblock) {
        return (position: resolved.before(depth), node: node);
      }
    }
    return null;
  }

  /// Every textblock intersecting the current selection — the set that ruler
  /// gestures apply to. With a caret selection this is just the caret block,
  /// like Word; with a range, dragging an indent marker or a tab stop
  /// repositions all selected paragraphs.
  List<({int position, dynamic node})> _selectionTextblocks() {
    final selection = view.state.selection;
    final result = <({int position, dynamic node})>[];
    view.state.doc.nodesBetween(selection.from, selection.to,
        (node, pos, parent, index) {
      if (node.isTextblock) {
        result.add((position: pos, node: node));
        return false;
      }
      return true;
    });
    if (result.isEmpty) {
      final caret = _caretTextblock();
      if (caret != null) result.add(caret);
    }
    return result;
  }

  String _px(double value) {
    final normalized = value.abs() < 0.005 ? 0.0 : value;
    return '${normalized.toStringAsFixed(2)}px';
  }

  web.HTMLElement? _caretBlock() {
    try {
      final position = view.domAtPos(view.state.selection.head);
      final node = position.node;
      final element = node.nodeType == web.Node.ELEMENT_NODE
          ? node as web.Element
          : node.parentElement;
      final block = element?.closest('p, h1, h2, h3, h4, h5, h6, li, td, th');
      if (block is! web.HTMLElement || !view.dom.contains(block)) return null;
      return block;
    } catch (_) {
      return null;
    }
  }
}

class _RulerGeometry {
  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;

  _RulerGeometry({
    required this.pageWidth,
    required this.pageHeight,
    required this.marginTop,
    required this.marginRight,
    required this.marginBottom,
    required this.marginLeft,
  });

  String get key => [
        pageWidth,
        pageHeight,
        marginTop,
        marginRight,
        marginBottom,
        marginLeft,
      ].map((value) => value.round()).join('-');
}

class _IndentGeometry {
  final web.HTMLElement? block;
  final double left;
  final double right;
  final double first;
  final double paddingLeft;
  final double paddingRight;

  const _IndentGeometry({
    required this.block,
    required this.left,
    required this.right,
    required this.first,
    required this.paddingLeft,
    required this.paddingRight,
  });
}

class _IndentDrag {
  final String kind;
  final _RulerGeometry geometry;
  final web.HTMLElement block;
  final int nodePosition;
  final Map<String, dynamic> originalAttrs;
  final String? originalInlineStyle;
  final double paddingLeft;
  final double paddingRight;

  /// All paragraphs the gesture applies to (the selection's textblocks).
  /// Word repositions every selected paragraph, not only the caret one.
  final List<_IndentDragTarget> targets;
  double left;
  double right;
  double first;

  _IndentDrag({
    required this.kind,
    required this.geometry,
    required this.block,
    required this.nodePosition,
    required this.originalAttrs,
    required this.originalInlineStyle,
    required this.paddingLeft,
    required this.paddingRight,
    required this.targets,
    required this.left,
    required this.right,
    required this.first,
  });
}

class _IndentDragTarget {
  final int position;
  final Map<String, dynamic> attrs;
  final web.HTMLElement? dom;
  final String? inlineStyle;

  const _IndentDragTarget({
    required this.position,
    required this.attrs,
    required this.dom,
    required this.inlineStyle,
  });
}

class _TableColDrag {
  final int boundary;
  final int tablePosition;
  final web.HTMLElement tableEl;
  final double tableLeft;
  final List<double> tracks;
  final double startX;
  final List<(web.HTMLElement, String?)> previewedRows = [];
  double? lastClientX;

  _TableColDrag({
    required this.boundary,
    required this.tablePosition,
    required this.tableEl,
    required this.tableLeft,
    required this.tracks,
    required this.startX,
  });

  void rememberRow(web.HTMLElement row) {
    for (final entry in previewedRows) {
      if (entry.$1 == row) return;
    }
    previewedRows.add((row, row.getAttribute('style')));
  }
}

class _MarginDrag {
  final String side;
  final _RulerGeometry geometry;
  final web.HTMLElement ruler;
  double start;
  double end;

  _MarginDrag({
    required this.side,
    required this.geometry,
    required this.ruler,
    required this.start,
    required this.end,
  });
}

class _TabDrag {
  final int index;
  final _RulerGeometry geometry;
  final int nodePosition;
  final dynamic originalNode;
  final List<Map<String, dynamic>> stops;
  double position;
  bool removed = false;

  _TabDrag({
    required this.index,
    required this.geometry,
    required this.nodePosition,
    required this.originalNode,
    required this.stops,
    required this.position,
  });
}
