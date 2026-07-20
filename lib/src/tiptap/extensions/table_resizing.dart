import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../prosemirror/state/index.dart';
import '../../prosemirror/view/index.dart';
import '../core/extension.dart';
import 'table_commands.dart';

/// Interactive column/row resizing for tables, in the spirit of
/// prosemirror-tables' columnResizing plugin adapted to this package's
/// rendering (paginated rows are CSS grids; nested tables use fixed table
/// layout).
///
/// Hovering within [handleWidth] px of a cell's right edge shows a
/// col-resize cursor; dragging previews the new track list with inline
/// styles only and commits a single transaction on pointerup that writes
/// `columnWidths` to the table and every row. The bottom edge resizes the
/// row's minimum height (`heightRule: atLeast`), matching Word.
class TableResizingExtension extends Extension {
  final double handleWidth;
  final double minColumnWidth;
  final double minRowHeight;

  const TableResizingExtension({
    this.handleWidth = 5,
    this.minColumnWidth = 24,
    this.minRowHeight = 16,
  }) : super('tableResizing');

  @override
  List<Plugin> addPlugins() => [
        Plugin(PluginSpec(
          key: PluginKey('tableResizing'),
          view: (dynamic rawView) {
            final resizer = _TableResizer(
              rawView as EditorView,
              handleWidth: handleWidth,
              minColumnWidth: minColumnWidth,
              minRowHeight: minRowHeight,
            );
            return PluginView(
              update: (view, previousState) {
                resizer.view = view as EditorView;
                resizer.syncOverlay();
              },
              destroy: resizer.destroy,
            );
          },
        )),
      ];
}

class _CornerDrag {
  final int tablePosition;
  final web.HTMLElement tableEl;
  final double startX;
  final double startWidth;
  final double zoom;
  final List<double> tracks;
  final List<(web.HTMLElement, String?)> previewedRows = [];
  double? lastClientX;

  _CornerDrag({
    required this.tablePosition,
    required this.tableEl,
    required this.startX,
    required this.startWidth,
    required this.zoom,
    required this.tracks,
  });

  void rememberRow(web.HTMLElement row) {
    for (final entry in previewedRows) {
      if (entry.$1 == row) return;
    }
    previewedRows.add((row, row.getAttribute('style')));
  }
}

/// Pointer coordinates can be fractional (zoom, high-DPI); package:web types
/// them as `int`, which throws on non-integral JS numbers. Read them as raw
/// JS numbers instead.
double _pointerX(web.PointerEvent event) =>
    ((event as JSObject).getProperty('clientX'.toJS) as JSNumber).toDartDouble;

double _pointerY(web.PointerEvent event) =>
    ((event as JSObject).getProperty('clientY'.toJS) as JSNumber).toDartDouble;

class _TableResizer {
  EditorView view;
  final double handleWidth;
  final double minColumnWidth;
  final double minRowHeight;

  final List<({web.EventTarget target, String type, JSFunction listener})>
      _listeners = [];

  // Hover target (armed, waiting for pointerdown).
  web.HTMLElement? _hoverTable;
  web.HTMLElement? _hoverRow;
  int _hoverBoundary = -1;
  bool _hoverIsColumn = false;

  // Active drag.
  bool _dragging = false;
  bool _dragIsColumn = false;
  web.HTMLElement? _dragTable;
  web.HTMLElement? _dragRow;
  int _dragBoundary = -1;
  double _dragStart = 0;
  double _dragScale = 1;
  List<double> _dragTracks = const [];
  double _dragRowStartHeight = 0;
  final List<(web.HTMLElement, String?)> _previewedRows = [];

  _TableResizer(
    this.view, {
    required this.handleWidth,
    required this.minColumnWidth,
    required this.minRowHeight,
  }) {
    _listen(view.dom, 'pointermove', _onHoverMove);
    _listen(view.dom, 'pointerdown', _onPointerDown, capture: true);
    _listen(view.dom, 'pointerleave', (_) => _clearHover());
  }

  void destroy() {
    _abortDrag();
    _overlay?.remove();
    _overlay = null;
    _zoomObserver?.disconnect();
    _zoomObserver = null;
    for (final entry in _listeners) {
      entry.target.removeEventListener(entry.type, entry.listener, true.toJS);
      entry.target.removeEventListener(entry.type, entry.listener);
    }
    _listeners.clear();
  }

  // ------------------------------------------- âncoras + mini UI da tabela

  web.HTMLElement? _overlay;
  web.MutationObserver? _zoomObserver;
  int? _overlayTablePos;
  _CornerDrag? _cornerDrag;

  ({int position, dynamic node})? _caretTable() {
    final resolved = view.state.selection.fromRes;
    for (var depth = resolved.depth; depth > 0; depth--) {
      final node = resolved.node(depth);
      if (node.type.name == 'table') {
        return (position: resolved.before(depth), node: node);
      }
    }
    // A NodeSelection on the table itself also counts.
    final selection = view.state.selection;
    final at = view.state.doc.nodeAt(selection.from);
    if (at != null && at.type.name == 'table') {
      return (position: selection.from, node: at);
    }
    return null;
  }

  /// Word's table chrome: the ⊞ move/select anchor at the top-left corner,
  /// the resize square at the bottom-right and a floating quick toolbar with
  /// the common structural actions.
  void syncOverlay() {
    if (_cornerDrag != null) return;
    final host = view.dom.closest('.page-scale');
    final table = view.editable ? _caretTable() : null;
    if (host is! web.HTMLElement || table == null) {
      _overlay?.remove();
      _overlay = null;
      _overlayTablePos = null;
      return;
    }
    final tableDom = view.nodeDOM(table.position);
    if (tableDom is! web.HTMLElement) {
      _overlay?.remove();
      _overlay = null;
      return;
    }
    var overlay = _overlay;
    if (overlay == null || overlay.parentElement != host) {
      overlay?.remove();
      overlay = _buildOverlay();
      host.appendChild(overlay);
      _overlay = overlay;
      _observeZoom(host);
    }
    _overlayTablePos = table.position;
    final hostRect = host.getBoundingClientRect();
    // Paginated top-level tables render with display:contents — the <table>
    // element has no box of its own, so measure the union of its rows.
    final tableRect = _tableBox(tableDom) ?? tableDom.getBoundingClientRect();
    final zoom = _scaleOf(host, hostRect);
    overlay.style
      ..left = '${((tableRect.left - hostRect.left) / zoom).toStringAsFixed(1)}px'
      ..top = '${((tableRect.top - hostRect.top) / zoom).toStringAsFixed(1)}px'
      ..width = '${(tableRect.width / zoom).toStringAsFixed(1)}px'
      ..height = '${(tableRect.height / zoom).toStringAsFixed(1)}px';
  }

  web.DOMRect? _tableBox(web.HTMLElement tableDom) {
    final rows = tableDom.querySelectorAll('tr');
    double? left, top, right, bottom;
    for (var i = 0; i < rows.length; i++) {
      final row = rows.item(i);
      if (row is! web.HTMLElement) continue;
      if (row.closest('table') != tableDom) continue;
      final rect = row.getBoundingClientRect();
      if (rect.width == 0 && rect.height == 0) continue;
      left = left == null ? rect.left : math.min(left, rect.left);
      top = top == null ? rect.top : math.min(top, rect.top);
      right = right == null ? rect.right : math.max(right, rect.right);
      bottom = bottom == null ? rect.bottom : math.max(bottom, rect.bottom);
    }
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return web.DOMRect(left, top, right - left, bottom - top);
  }

  void _observeZoom(web.HTMLElement host) {
    _zoomObserver?.disconnect();
    _zoomObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver observer) {
        syncOverlay();
      }).toJS,
    )..observe(
        host,
        web.MutationObserverInit(attributes: true),
      );
  }

  web.HTMLElement _buildOverlay() {
    final overlay = web.document.createElement('div') as web.HTMLElement;
    overlay
      ..className = 'tiptap-table-overlay'
      ..setAttribute('contenteditable', 'false')
      ..setAttribute('aria-hidden', 'true');

    final move = web.document.createElement('button') as web.HTMLElement;
    move
      ..className = 'tiptap-table-move'
      ..setAttribute('type', 'button')
      ..setAttribute('title', 'Selecionar Tabela')
      ..setAttribute('data-table-anchor', 'move')
      ..textContent = '⠿';
    move.addEventListener(
        'mousedown', ((web.Event event) => event.preventDefault()).toJS);
    move.addEventListener(
        'click',
        (web.Event event) {
          event.preventDefault();
          final position = _overlayTablePos;
          if (position == null) return;
          final node = view.state.doc.nodeAt(position);
          if (node == null || node.type.name != 'table') return;
          final tr = view.state.tr;
          tr.setSelection(NodeSelection.create(view.state.doc, position));
          view.dispatch(tr);
          view.focus();
        }.toJS);

    final resize = web.document.createElement('span') as web.HTMLElement;
    resize
      ..className = 'tiptap-table-corner'
      ..setAttribute('title', 'Redimensionar Tabela')
      ..setAttribute('data-table-anchor', 'resize');
    resize.addEventListener(
        'pointerdown',
        ((web.Event event) {
          if (event is web.PointerEvent) _beginCornerDrag(event);
        }).toJS);

    final bar = web.document.createElement('div') as web.HTMLElement;
    bar.className = 'tiptap-table-quickbar';
    for (final item in const [
      ('row-below', 'Linha+', 'Inserir Linha Abaixo'),
      ('col-right', 'Col+', 'Inserir Coluna à Direita'),
      ('del-row', 'Linha−', 'Excluir Linha'),
      ('del-col', 'Col−', 'Excluir Coluna'),
      ('merge', 'Mesclar', 'Mesclar Células'),
      ('split', 'Dividir', 'Dividir Célula'),
      ('del-table', '✕', 'Excluir Tabela'),
    ]) {
      final button = web.document.createElement('button') as web.HTMLElement;
      button
        ..className = 'tiptap-table-quick'
        ..setAttribute('type', 'button')
        ..setAttribute('title', item.$3)
        ..setAttribute('data-table-quick', item.$1)
        ..textContent = item.$2;
      button.addEventListener(
          'mousedown', ((web.Event event) => event.preventDefault()).toJS);
      button.addEventListener(
          'click',
          (web.Event event) {
            event.preventDefault();
            _runQuickAction(item.$1);
          }.toJS);
      bar.appendChild(button);
    }

    overlay
      ..appendChild(move)
      ..appendChild(resize)
      ..appendChild(bar);
    return overlay;
  }

  void _runQuickAction(String action) {
    void dispatchTr(Transaction tr) => view.dispatch(tr);
    final command = switch (action) {
      'row-below' => addRowCommand(before: false),
      'col-right' => addColumnCommand(before: false),
      'del-row' => deleteRowCommand(),
      'del-col' => deleteColumnCommand(),
      'merge' => mergeCellsCommand(),
      'split' => splitCellCommand(),
      'del-table' => deleteTableCommand(),
      _ => null,
    };
    if (command == null) return;
    command(view.state, dispatchTr, view);
    view.focus();
  }

  void _beginCornerDrag(web.PointerEvent event) {
    if (!view.editable || _cornerDrag != null) return;
    final position = _overlayTablePos;
    if (position == null) return;
    final tableDom = view.nodeDOM(position);
    final host = view.dom.closest('.page-scale');
    if (tableDom is! web.HTMLElement || host is! web.HTMLElement) return;
    event
      ..preventDefault()
      ..stopPropagation();
    final tableRect = _tableBox(tableDom) ?? tableDom.getBoundingClientRect();
    final zoom = _scaleOf(host, host.getBoundingClientRect());
    final boundaries = _columnBoundaries(tableDom);
    if (boundaries.length < 2) return;
    _cornerDrag = _CornerDrag(
      tablePosition: position,
      tableEl: tableDom,
      startX: _pointerX(event),
      startWidth: tableRect.width / zoom,
      zoom: zoom,
      tracks: [
        for (var i = 1; i < boundaries.length; i++)
          boundaries[i] - boundaries[i - 1]
      ],
    );
    _listen(web.document, 'pointermove', _onCornerMove);
    _listen(web.document, 'pointerup', _onCornerEnd);
    _listen(web.document, 'pointercancel', _onCornerEnd);
  }

  List<double> _cornerTracksFor(_CornerDrag drag, double clientX) {
    final delta = (clientX - drag.startX) / drag.zoom;
    final factor =
        ((drag.startWidth + delta) / drag.startWidth).clamp(0.2, 5.0);
    return [
      for (final track in drag.tracks) math.max(24.0, track * factor)
    ];
  }

  void _onCornerMove(web.Event event) {
    final drag = _cornerDrag;
    if (drag == null || event is! web.PointerEvent) return;
    event.preventDefault();
    drag.lastClientX = _pointerX(event);
    final tracks = _cornerTracksFor(drag, drag.lastClientX!);
    final template =
        tracks.map((w) => '${w.toStringAsFixed(1)}px').join(' ');
    final rows = drag.tableEl.querySelectorAll('tr');
    for (var i = 0; i < rows.length; i++) {
      final row = rows.item(i);
      if (row is! web.HTMLElement) continue;
      drag.rememberRow(row);
      row.style.gridTemplateColumns = template;
    }
  }

  void _onCornerEnd(web.Event event) {
    final drag = _cornerDrag;
    if (drag == null) return;
    for (final (row, style) in drag.previewedRows) {
      if (style == null) {
        row.removeAttribute('style');
      } else {
        row.setAttribute('style', style);
      }
    }
    _listeners.removeWhere((entry) {
      if (entry.target == web.document) {
        entry.target.removeEventListener(entry.type, entry.listener);
        return true;
      }
      return false;
    });
    _cornerDrag = null;
    if (event.type != 'pointerup') {
      syncOverlay();
      return;
    }
    final tracks =
        _cornerTracksFor(drag, drag.lastClientX ?? drag.startX);
    final node = view.state.doc.nodeAt(drag.tablePosition);
    if (node == null || node.type.name != 'table') return;
    final tr = view.state.tr;
    applyColumnWidths(
        tr, drag.tablePosition, tracks.map((w) => w.round()).toList());
    view.dispatch(tr);
  }

  void _listen(web.EventTarget target, String type,
      void Function(web.Event event) handler,
      {bool capture = false}) {
    final listener = handler.toJS;
    if (capture) {
      target.addEventListener(type, listener, true.toJS);
    } else {
      target.addEventListener(type, listener);
    }
    _listeners.add((target: target, type: type, listener: listener));
  }

  // ------------------------------------------------------------- hovering

  void _onHoverMove(web.Event event) {
    if (_dragging || event is! web.PointerEvent || !view.editable) return;
    final target = event.target;
    if (target is! web.Element) {
      _clearHover();
      return;
    }
    final cell = target.closest('td, th');
    if (cell is! web.HTMLElement) {
      _clearHover();
      return;
    }
    final table = cell.closest('table');
    final rowEl = cell.closest('tr');
    if (table is! web.HTMLElement || rowEl is! web.HTMLElement) {
      _clearHover();
      return;
    }
    final rect = cell.getBoundingClientRect();
    final nearRight = (rect.right - _pointerX(event)).abs() <= handleWidth;
    final nearBottom = (rect.bottom - _pointerY(event)).abs() <= handleWidth;
    if (nearRight) {
      final boundaries = _columnBoundaries(table);
      if (boundaries.length < 2) {
        _clearHover();
        return;
      }
      // Which boundary matches the cell's right edge?
      final tableRect = table.getBoundingClientRect();
      final scale = _scaleOf(table, tableRect);
      final localRight = (rect.right - tableRect.left) / scale;
      var boundary = -1;
      for (var i = 1; i < boundaries.length; i++) {
        if ((boundaries[i] - localRight).abs() <= 2.5) {
          boundary = i;
          break;
        }
      }
      if (boundary <= 0) {
        _clearHover();
        return;
      }
      _hoverTable = table;
      _hoverRow = null;
      _hoverBoundary = boundary;
      _hoverIsColumn = true;
      view.dom.classList.add('tiptap-resize-col');
      view.dom.classList.remove('tiptap-resize-row');
      return;
    }
    if (nearBottom) {
      _hoverTable = table;
      _hoverRow = rowEl;
      _hoverBoundary = -1;
      _hoverIsColumn = false;
      view.dom.classList.add('tiptap-resize-row');
      view.dom.classList.remove('tiptap-resize-col');
      return;
    }
    _clearHover();
  }

  void _clearHover() {
    _hoverTable = null;
    _hoverRow = null;
    _hoverBoundary = -1;
    view.dom.classList.remove('tiptap-resize-col');
    view.dom.classList.remove('tiptap-resize-row');
  }

  // ------------------------------------------------------------- dragging

  void _onPointerDown(web.Event event) {
    if (event is! web.PointerEvent || _hoverTable == null || !view.editable) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    final table = _hoverTable!;
    final tableRect = table.getBoundingClientRect();
    _dragging = true;
    _dragIsColumn = _hoverIsColumn;
    _dragTable = table;
    _dragScale = _scaleOf(table, tableRect);
    if (_dragIsColumn) {
      _dragBoundary = _hoverBoundary;
      _dragStart = _pointerX(event);
      final boundaries = _columnBoundaries(table);
      _dragTracks = [
        for (var i = 1; i < boundaries.length; i++)
          boundaries[i] - boundaries[i - 1]
      ];
    } else {
      _dragRow = _hoverRow;
      _dragStart = _pointerY(event);
      _dragRowStartHeight =
          (_hoverRow!.getBoundingClientRect().height / _dragScale);
    }
    _listen(web.document, 'pointermove', _onDragMove);
    _listen(web.document, 'pointerup', _onDragEnd);
    _listen(web.document, 'pointercancel', (_) => _abortDrag());
  }

  void _onDragMove(web.Event event) {
    if (!_dragging || event is! web.PointerEvent) return;
    event.preventDefault();
    if (_dragIsColumn) {
      _previewColumns(_tracksForPointer(_pointerX(event)));
    } else {
      final height = _rowHeightForPointer(_pointerY(event));
      final row = _dragRow;
      if (row != null) {
        _rememberRowStyle(row);
        row.style.minHeight = '${height.toStringAsFixed(1)}px';
        row.style.setProperty('--tr-height', '${height.toStringAsFixed(1)}px');
      }
    }
  }

  void _onDragEnd(web.Event event) {
    if (!_dragging) return;
    final isColumn = _dragIsColumn;
    final table = _dragTable;
    final row = _dragRow;
    List<int>? widths;
    double? height;
    if (isColumn && event is web.PointerEvent) {
      widths =
          _tracksForPointer(_pointerX(event)).map((w) => w.round()).toList();
    } else if (!isColumn && event is web.PointerEvent) {
      height = _rowHeightForPointer(_pointerY(event));
    }
    _abortDrag();
    if (table == null || !view.dom.contains(table)) return;
    if (isColumn && widths != null) {
      final tablePos = _posBefore(table);
      if (tablePos == null) return;
      final tr = view.state.tr;
      applyColumnWidths(tr, tablePos, widths);
      view.dispatch(tr);
    } else if (!isColumn && row != null && height != null) {
      final rowPos = _posBefore(row);
      if (rowPos == null) return;
      final node = view.state.doc.nodeAt(rowPos);
      if (node == null || node.type.name != 'tableRow') return;
      final tr = view.state.tr;
      tr.setNodeMarkup(
        rowPos,
        null,
        Map<String, dynamic>.from(node.attrs)
          ..['height'] = '${height.toStringAsFixed(1)}px'
          ..['heightRule'] = 'atLeast',
      );
      view.dispatch(tr);
    }
  }

  List<double> _tracksForPointer(double clientX) {
    final tracks = List<double>.from(_dragTracks);
    final delta = (clientX - _dragStart) / _dragScale;
    final index = _dragBoundary - 1;
    if (index >= 0 && index < tracks.length) {
      tracks[index] = math.max(minColumnWidth, tracks[index] + delta);
    }
    return tracks;
  }

  double _rowHeightForPointer(double clientY) {
    final delta = (clientY - _dragStart) / _dragScale;
    return math.max(minRowHeight, _dragRowStartHeight + delta);
  }

  void _previewColumns(List<double> tracks) {
    final table = _dragTable;
    if (table == null) return;
    final template =
        tracks.map((w) => '${w.toStringAsFixed(1)}px').join(' ');
    final rows = table.querySelectorAll('tr');
    for (var i = 0; i < rows.length; i++) {
      final row = rows.item(i);
      if (row is! web.HTMLElement) continue;
      _rememberRowStyle(row);
      row.style.gridTemplateColumns = template;
    }
    // Non-paginated tables use fixed table layout: preview widths on the
    // first row's cells so the browser distributes the remaining columns.
    final firstRow = rows.item(0);
    if (firstRow is web.HTMLElement &&
        web.window.getComputedStyle(firstRow).display != 'grid') {
      var track = 0;
      for (var c = 0; c < firstRow.children.length; c++) {
        final cell = firstRow.children.item(c);
        if (cell is! web.HTMLElement) continue;
        final span = int.tryParse(cell.getAttribute('colspan') ?? '1') ?? 1;
        var width = 0.0;
        for (var s = 0; s < span && track + s < tracks.length; s++) {
          width += tracks[track + s];
        }
        track += span;
        if (width > 0) cell.style.width = '${width.toStringAsFixed(1)}px';
      }
    }
  }

  void _rememberRowStyle(web.HTMLElement row) {
    for (final entry in _previewedRows) {
      if (entry.$1 == row) return;
    }
    _previewedRows.add((row, row.getAttribute('style')));
  }

  void _abortDrag() {
    if (!_dragging &&
        _previewedRows.isEmpty &&
        _dragTable == null &&
        _dragRow == null) {
      return;
    }
    _dragging = false;
    // Restore preview styles; the committed transaction re-renders rows with
    // the persisted attributes.
    for (final (row, style) in _previewedRows) {
      if (style == null) {
        row.removeAttribute('style');
      } else {
        row.setAttribute('style', style);
      }
      // Cell width previews (non-grid path) live on cells, not rows.
      for (var c = 0; c < row.children.length; c++) {
        final cell = row.children.item(c);
        if (cell is web.HTMLElement) cell.style.removeProperty('width');
      }
    }
    _previewedRows.clear();
    _dragTable = null;
    _dragRow = null;
    _dragBoundary = -1;
    // Drop the document-level listeners added for the drag.
    _listeners.removeWhere((entry) {
      if (entry.target == web.document) {
        entry.target.removeEventListener(entry.type, entry.listener);
        return true;
      }
      return false;
    });
    _clearHover();
  }

  // ------------------------------------------------------------- geometry

  /// Sorted x-offsets (unscaled CSS px, relative to the table) of every
  /// column boundary, derived from rendered cell rectangles so colspans and
  /// grid/table layouts are both handled.
  List<double> _columnBoundaries(web.HTMLElement table) {
    final tableRect = table.getBoundingClientRect();
    final scale = _scaleOf(table, tableRect);
    final xs = <double>[];
    void push(double value) {
      for (final existing in xs) {
        if ((existing - value).abs() <= 1.5) return;
      }
      xs.add(value);
    }

    final cells = table.querySelectorAll('tr > td, tr > th');
    for (var i = 0; i < cells.length; i++) {
      final cell = cells.item(i);
      if (cell is! web.HTMLElement) continue;
      // Nested tables' cells belong to another <table>.
      if (cell.closest('table') != table) continue;
      final rect = cell.getBoundingClientRect();
      push((rect.left - tableRect.left) / scale);
      push((rect.right - tableRect.left) / scale);
    }
    xs.sort();
    return xs;
  }

  double _scaleOf(web.HTMLElement table, web.DOMRect rect) {
    final offsetWidth = table.offsetWidth;
    if (offsetWidth == 0) return 1;
    final scale = rect.width / offsetWidth;
    return scale.isFinite && scale > 0 ? scale : 1;
  }

  int? _posBefore(web.HTMLElement element) {
    try {
      final desc = view.docView.nearestDesc(element, true);
      if (desc == null || desc.parent == null) return null;
      return desc.posBefore;
    } catch (_) {
      return null;
    }
  }
}
