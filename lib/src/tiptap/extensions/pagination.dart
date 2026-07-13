import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/to_dom.dart';
import '../../prosemirror/state/index.dart';
import '../../prosemirror/view/decoration.dart';
import '../../prosemirror/view/index.dart';
import '../core/extension.dart';
import 'page_region_editor.dart';

/// Physical page geometry used by [PaginationExtension].
///
/// The defaults are an A4 sheet at the browser reference density of 96 dpi.
/// Margins match the Tiptap Pages defaults: 2.5 cm vertically and 2 cm
/// horizontally.
class PaginationOptions {
  static const double _pixelsPerCentimetre = 96 / 2.54;

  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;
  final double pageGap;
  final String pageBackground;
  final String pageGapBackground;
  final Duration debounce;

  const PaginationOptions({
    this.pageWidth = 21 * _pixelsPerCentimetre,
    this.pageHeight = 29.7 * _pixelsPerCentimetre,
    this.marginTop = 2.5 * _pixelsPerCentimetre,
    this.marginRight = 2 * _pixelsPerCentimetre,
    this.marginBottom = 2.5 * _pixelsPerCentimetre,
    this.marginLeft = 2 * _pixelsPerCentimetre,
    this.pageGap = 50,
    this.pageBackground = 'var(--tiptap-surface, var(--page, #fff))',
    this.pageGapBackground = 'var(--tiptap-canvas, var(--canvas, #f3f3f2))',
    this.debounce = const Duration(milliseconds: 16),
  });

  double get contentHeight =>
      math.max(1, pageHeight - marginTop - marginBottom);
}

/// Kept for source compatibility with the earlier block-measured paginator.
///
/// Automatic pagination no longer creates position-bound breaks. Pages are
/// produced by a single float-chain decoration, which lets the browser split
/// long paragraphs and lists at line boundaries.
@Deprecated('Automatic pagination now uses a float-chain decoration.')
class PageBreakLayout {
  final int position;
  final double fillHeight;
  final double height;
  final int pageBefore;

  const PageBreakLayout({
    required this.position,
    required this.fillHeight,
    required this.height,
    required this.pageBefore,
  });
}

class PaginationState {
  /// Number of visible physical pages. The DOM contains one extra sentinel.
  final int pageCount;
  final DecorationSet decorations;

  const PaginationState(this.pageCount, this.decorations);
}

/// Adds physical pages without changing the ProseMirror document.
///
/// A single widget at document position zero contains a chain of zero-width
/// floats. Each float leaves exactly one page's writable height in normal
/// flow, followed by a full-width footer/gap/header breaker. The document's
/// real DOM remains after that widget and flows around the floats, so the
/// browser can split text inside a paragraph instead of only between blocks.
class PaginationExtension extends Extension {
  final PaginationOptions options;

  const PaginationExtension({
    this.options = const PaginationOptions(),
  }) : super('pagination');

  @override
  List<Plugin> addPlugins() => [_paginationPlugin(options)];
}

class _PageCountLayout {
  final int pageCount;

  const _PageCountLayout(this.pageCount);
}

class _PageLayoutConfig {
  final PaginationOptions geometry;
  final double headerOffset;
  final double footerOffset;
  final bool titlePage;
  final bool evenAndOddHeaders;
  final Map<String, dynamic>? headers;
  final Map<String, dynamic>? footers;

  const _PageLayoutConfig({
    required this.geometry,
    required this.headerOffset,
    required this.footerOffset,
    required this.titlePage,
    required this.evenAndOddHeaders,
    required this.headers,
    required this.footers,
  });

  bool sameAs(_PageLayoutConfig other) =>
      geometry.pageWidth == other.geometry.pageWidth &&
      geometry.pageHeight == other.geometry.pageHeight &&
      geometry.marginTop == other.geometry.marginTop &&
      geometry.marginRight == other.geometry.marginRight &&
      geometry.marginBottom == other.geometry.marginBottom &&
      geometry.marginLeft == other.geometry.marginLeft &&
      headerOffset == other.headerOffset &&
      footerOffset == other.footerOffset &&
      titlePage == other.titlePage &&
      evenAndOddHeaders == other.evenAndOddHeaders &&
      identical(headers, other.headers) &&
      identical(footers, other.footers);
}

_PageLayoutConfig _layoutConfig(
  PaginationOptions defaults,
  PMNode doc,
) {
  final attrs = doc.attrs;
  final top = _cssPixels(attrs['pageMarginTop'], defaults.marginTop);
  final bottom = _cssPixels(attrs['pageMarginBottom'], defaults.marginBottom);
  final geometry = PaginationOptions(
    pageWidth: _cssPixels(attrs['pageWidth'], defaults.pageWidth),
    pageHeight: _cssPixels(attrs['pageHeight'], defaults.pageHeight),
    marginTop: top,
    marginRight: _cssPixels(attrs['pageMarginRight'], defaults.marginRight),
    marginBottom: bottom,
    marginLeft: _cssPixels(attrs['pageMarginLeft'], defaults.marginLeft),
    pageGap: defaults.pageGap,
    pageBackground: defaults.pageBackground,
    pageGapBackground: defaults.pageGapBackground,
    debounce: defaults.debounce,
  );
  return _PageLayoutConfig(
    geometry: geometry,
    headerOffset: _cssPixels(attrs['pageMarginHeader'], top / 2),
    footerOffset: _cssPixels(attrs['pageMarginFooter'], bottom / 2),
    titlePage: attrs['titlePage'] == true,
    evenAndOddHeaders: attrs['evenAndOddHeaders'] == true,
    headers: _payloadMap(attrs['headers']),
    footers: _payloadMap(attrs['footers']),
  );
}

Map<String, dynamic>? _payloadMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}

double _cssPixels(dynamic value, double fallback) {
  if (value is num && value.isFinite) return value.toDouble();
  if (value is! String) return fallback;
  final match = RegExp(
    r'^\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*(px|pt|pc|in|cm|mm)?\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return fallback;
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || !amount.isFinite) return fallback;
  switch ((match.group(2) ?? 'px').toLowerCase()) {
    case 'pt':
      return amount * 96 / 72;
    case 'pc':
      return amount * 16;
    case 'in':
      return amount * 96;
    case 'cm':
      return amount * 96 / 2.54;
    case 'mm':
      return amount * 96 / 25.4;
    default:
      return amount;
  }
}

Plugin<PaginationState> _paginationPlugin(PaginationOptions options) {
  final key = PluginKey<PaginationState>('pagination');
  return Plugin<PaginationState>(PluginSpec<PaginationState>(
    key: key,
    state: StateField<PaginationState>(
      init: (config, state) => _stateForPageCount(state.doc, options, 1),
      apply: (tr, previous, oldState, newState) {
        final measured = tr.getMeta(key);
        if (measured is _PageCountLayout) {
          return PaginationState(
            measured.pageCount,
            (previous as PaginationState).decorations,
          );
        }

        // The widget is rooted at position zero and stays valid for every
        // document edit. Keeping the same DecorationSet avoids rebuilding the
        // float chain on each keystroke.
        return previous as PaginationState;
      },
    ),
    props: {
      'decorations': (EditorState state) => key.getState(state)?.decorations,
    },
    view: (dynamic rawView) {
      final paginationView = _PaginationView(
        rawView as EditorView,
        key,
        options,
      );
      return PluginView(
        update: (view, previousState) =>
            paginationView.update(view as EditorView, previousState),
        destroy: paginationView.destroy,
      );
    },
  ));
}

int? _sourcePageCount(PMNode doc) {
  final value = doc.attrs['sourcePageCount'];
  final parsed = value is num
      ? value.toInt()
      : value is String
          ? int.tryParse(value)
          : null;
  return parsed != null && parsed > 0 && parsed <= 10000 ? parsed : null;
}

PaginationState _stateForPageCount(
  PMNode doc,
  PaginationOptions options,
  int requestedPageCount,
) {
  final pageCount = math.max(1, requestedPageCount);
  final decoration = Decoration.widget(
    0,
    (EditorView view, int? Function() getPos) => _buildPaginationWidget(
      _layoutConfig(options, view.state.doc),
      view.state.schema,
      pageCount,
    ),
    {
      'side': -1,
      // Keep the widget identity stable. The plugin view updates its float
      // children in place when the count changes, which avoids selection loss
      // and also works with lightweight ProseMirror view implementations that
      // do not replace equal-position widgets eagerly.
      'key': 'tiptap-pagination-${_geometryKey(options)}',
      'ignoreSelection': true,
    },
  );
  return PaginationState(
    pageCount,
    DecorationSet.create(doc, [decoration]),
  );
}

String _geometryKey(PaginationOptions options) => [
      options.pageWidth,
      options.pageHeight,
      options.marginTop,
      options.marginRight,
      options.marginBottom,
      options.marginLeft,
      options.pageGap,
    ].map((value) => value.round()).join('-');

web.HTMLElement _buildPaginationWidget(
  _PageLayoutConfig config,
  Schema schema,
  int pageCount,
) {
  final options = config.geometry;
  final pagination = web.document.createElement('div') as web.HTMLElement;
  pagination
    ..className = 'tiptap-pagination'
    ..setAttribute('data-tiptap-pagination', 'true')
    ..setAttribute('data-page-count', '$pageCount')
    ..setAttribute('contenteditable', 'false')
    ..setAttribute('aria-hidden', 'true');
  pagination.style
    ..height = '0'
    ..pointerEvents = 'none';

  // There is one wrapper for the first header, one per following page, and a
  // final sentinel that contributes only the last page's footer.
  for (var index = 0; index <= pageCount; index++) {
    final wrapper = web.document.createElement('div') as web.HTMLElement;
    wrapper
      ..className = 'tiptap-page-break'
      ..setAttribute('data-page-index', '$index');

    final spacer = web.document.createElement('div') as web.HTMLElement;
    spacer
      ..className = 'tiptap-page-spacer'
      ..setAttribute('data-page-number', '${math.max(1, index)}');
    spacer.style
      ..position = 'relative'
      ..setProperty('float', 'left')
      ..clear = 'both'
      ..width = '0'
      ..height = '0'
      ..marginTop = index == 0 ? '0' : '${options.contentHeight}px';

    final breaker = web.document.createElement('div') as web.HTMLElement;
    breaker
      ..className = 'breaker'
      ..setAttribute('data-page-index', '$index');
    breaker.style
      ..position = 'relative'
      ..setProperty('float', 'left')
      ..clear = 'both'
      ..width = '${options.pageWidth}px'
      ..marginLeft = '-${options.marginLeft}px'
      ..zIndex = '2';

    if (index > 0) {
      breaker.appendChild(_pageFooter(config, schema, index, pageCount));
    }
    if (index < pageCount) {
      if (index > 0) breaker.appendChild(_pageGap(options));
      breaker.appendChild(
        _pageHeader(config, schema, index + 1, pageCount),
      );
    }

    wrapper
      ..appendChild(spacer)
      ..appendChild(breaker);
    pagination.appendChild(wrapper);
  }

  return pagination;
}

web.HTMLElement _pageHeader(
  _PageLayoutConfig config,
  Schema schema,
  int pageNumber,
  int totalPages,
) {
  final options = config.geometry;
  final header = web.document.createElement('div') as web.HTMLElement;
  header
    ..className = 'tiptap-page-header'
    ..setAttribute('data-page-number', '$pageNumber');
  header.style
    ..position = 'relative'
    ..minHeight = '${options.marginTop}px'
    ..paddingTop = '${config.headerOffset}px'
    ..paddingRight = '${options.marginRight}px'
    ..paddingLeft = '${options.marginLeft}px'
    ..boxSizing = 'border-box'
    ..backgroundColor = options.pageBackground;
  _appendPayload(
    header,
    config.headers,
    schema,
    pageNumber,
    totalPages,
    useFirstPagePayload: config.titlePage,
    useEvenPagePayload: config.evenAndOddHeaders,
  );
  return header;
}

web.HTMLElement _pageFooter(
  _PageLayoutConfig config,
  Schema schema,
  int pageNumber,
  int totalPages,
) {
  final options = config.geometry;
  final footer = web.document.createElement('div') as web.HTMLElement;
  footer
    ..className = 'tiptap-page-footer'
    ..setAttribute('data-page-number', '$pageNumber');
  footer.style
    ..position = 'relative'
    ..minHeight = '${options.marginBottom}px'
    ..paddingRight = '${options.marginRight}px'
    ..paddingBottom = '${config.footerOffset}px'
    ..paddingLeft = '${options.marginLeft}px'
    ..boxSizing = 'border-box'
    ..display = 'flex'
    ..flexDirection = 'column'
    ..justifyContent = 'flex-end'
    ..backgroundColor = options.pageBackground;
  _appendPayload(
    footer,
    config.footers,
    schema,
    pageNumber,
    totalPages,
    useFirstPagePayload: config.titlePage,
    useEvenPagePayload: config.evenAndOddHeaders,
  );
  return footer;
}

void _appendPayload(
  web.HTMLElement target,
  Map<String, dynamic>? payloads,
  Schema schema,
  int pageNumber,
  int totalPages, {
  required bool useFirstPagePayload,
  required bool useEvenPagePayload,
}) {
  if (payloads == null || payloads.isEmpty) return;
  final dynamic payload =
      pageNumber == 1 && useFirstPagePayload && payloads['first'] != null
          ? payloads['first']
          : useEvenPagePayload && pageNumber.isEven && payloads['even'] != null
              ? payloads['even']
              : payloads['default'] ?? payloads['odd'];
  if (payload is! List) return;
  try {
    final nodes = payload.map(schema.nodeFromJSON).toList();
    DOMSerializer.fromSchema(schema).serializeFragment(
      Fragment.fromArray(nodes),
      target: target,
    );
    _replacePageFieldText(target, pageNumber, totalPages);
  } catch (_) {
    // A malformed optional header/footer must not prevent opening the body.
  }
}

void _replacePageFieldText(
  web.Node node,
  int pageNumber,
  int totalPages,
) {
  for (var child = node.firstChild; child != null; child = child.nextSibling) {
    if (child.nodeType == web.Node.TEXT_NODE) {
      final text = child as web.Text;
      final value = text.data;
      final matches =
          RegExp(r'\{\{DOCX_(PAGE|NUMPAGES)\}\}').allMatches(value).toList();
      if (matches.isEmpty) continue;
      final fragment = web.document.createDocumentFragment();
      var offset = 0;
      for (final match in matches) {
        if (match.start > offset) {
          fragment.appendChild(
            web.document.createTextNode(value.substring(offset, match.start)),
          );
        }
        final total = match.group(1) == 'NUMPAGES';
        final field = web.document.createElement('span') as web.HTMLElement;
        field
          ..className = 'tiptap-docx-page-field'
          ..setAttribute('data-docx-page-field', total ? 'total' : 'page')
          ..setAttribute('contenteditable', 'false')
          ..textContent = total ? '$totalPages' : '$pageNumber';
        fragment.appendChild(field);
        offset = match.end;
      }
      if (offset < value.length) {
        fragment
            .appendChild(web.document.createTextNode(value.substring(offset)));
      }
      text.replaceWith(fragment);
    } else {
      _replacePageFieldText(child, pageNumber, totalPages);
    }
  }
}

web.HTMLElement _pageGap(PaginationOptions options) {
  final gap = web.document.createElement('div') as web.HTMLElement;
  gap.className = 'tiptap-pagination-gap';
  gap.style
    ..height = '${options.pageGap}px'
    ..backgroundColor = options.pageGapBackground;
  return gap;
}

class _PaginationView {
  EditorView view;
  final PluginKey<PaginationState> key;
  final PaginationOptions options;
  late _PageLayoutConfig _config;
  Timer? _timer;
  int? _animationFrame;
  web.ResizeObserver? _resizeObserver;
  web.MutationObserver? _mutationObserver;
  bool _destroyed = false;
  bool _measuring = false;
  final List<_LayoutSample> _history = [];
  DateTime? _holdUntil;
  int? _heldPageCount;
  int? _sourcePageHint;
  bool _sourcePageHintLocked = false;
  bool _sourcePageHintEligibilityChecked = false;
  int? _nonFlowingPageCount;
  double? _lastExplicitZoom;
  int? _visualZoomPageCount;
  late final PageRegionEditor _regionEditor;

  _PaginationView(this.view, this.key, this.options) {
    _config = _layoutConfig(options, view.state.doc);
    _sourcePageHint = _sourcePageCount(view.state.doc);
    _lastExplicitZoom = _explicitLayoutZoom(view.dom);
    _configureRoot();
    _installObservers();
    _regionEditor = PageRegionEditor(view);
    _schedule();
  }

  void update(EditorView nextView, EditorState previousState) {
    view = nextView;
    _regionEditor.update(nextView);
    final previousSourcePageCount = _sourcePageCount(previousState.doc);
    final nextSourcePageCount = _sourcePageCount(nextView.state.doc);
    final bodyChanged =
        !identical(previousState.doc.content, nextView.state.doc.content);
    if (previousSourcePageCount != nextSourcePageCount) {
      _sourcePageHint = nextSourcePageCount;
      _sourcePageHintLocked = false;
      _sourcePageHintEligibilityChecked = false;
    } else if (bodyChanged) {
      // Word's cached page count is an import-time bootstrap, not a cap. Once
      // the user changes body content, return to live measurement.
      _sourcePageHintLocked = false;
      // Do not immediately reapply stale Word metadata after a user edit.
      // The monotonic-growth guard may still choose it if the live layout
      // proves non-flowing again.
      _sourcePageHintEligibilityChecked = true;
    }
    if (bodyChanged || previousSourcePageCount != nextSourcePageCount) {
      _history.clear();
      _holdUntil = null;
      _heldPageCount = null;
      _nonFlowingPageCount = null;
      _visualZoomPageCount = null;
      // A document replacement must win over a zoom transition that has not
      // reached the debounced measurement yet. Otherwise the next _measure
      // observes the pending zoom and immediately locks the old document's
      // page count around the newly imported content.
      _lastExplicitZoom = _explicitLayoutZoom(nextView.dom);
    }
    final nextConfig = _layoutConfig(options, nextView.state.doc);
    final geometryChanged = !_config.sameAs(nextConfig);
    if (geometryChanged) {
      _visualZoomPageCount = null;
      _lastExplicitZoom = _explicitLayoutZoom(nextView.dom);
    }
    _config = nextConfig;
    _configureRoot();
    final previousPages = key.getState(previousState)?.pageCount;
    final currentPages = key.getState(nextView.state)?.pageCount;
    if (geometryChanged) {
      final pagination = nextView.dom.querySelector(
        '[data-tiptap-pagination]',
      );
      if (pagination is web.HTMLElement) {
        _syncPaginationWidget(
          pagination,
          currentPages ?? 1,
        );
      }
    }
    if (geometryChanged ||
        !identical(previousState.doc, nextView.state.doc) ||
        previousPages != currentPages) {
      _schedule();
    }
  }

  void _configureRoot() {
    final dom = view.dom;
    final geometry = _config.geometry;
    _setAttributeIfChanged(dom, 'data-tiptap-pages', 'true');
    _setAttributeIfChanged(
      dom,
      'data-page-count',
      '${key.getState(view.state)?.pageCount ?? 1}',
    );
    dom.style
      ..width = '${geometry.pageWidth}px'
      ..paddingTop = '0'
      ..paddingRight = '${geometry.marginRight}px'
      ..paddingBottom = '0'
      ..paddingLeft = '${geometry.marginLeft}px'
      ..boxSizing = 'border-box'
      ..setProperty('--tiptap-page-width', '${geometry.pageWidth}px')
      ..setProperty('--tiptap-page-height', '${geometry.pageHeight}px')
      ..setProperty('--tiptap-page-gap', '${geometry.pageGap}px')
      ..setProperty('--tiptap-page-margin-top', '${geometry.marginTop}px')
      ..setProperty('--tiptap-page-margin-right', '${geometry.marginRight}px')
      ..setProperty('--tiptap-page-margin-bottom', '${geometry.marginBottom}px')
      ..setProperty('--tiptap-page-margin-left', '${geometry.marginLeft}px');
  }

  void _installObservers() {
    _resizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> entries,
              web.ResizeObserver observer) =>
          _schedule()).toJS,
    )..observe(view.dom);

    _mutationObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver observer) {
        if (records.length > 0) _schedule();
      }).toJS,
    )..observe(
        view.dom,
        web.MutationObserverInit(attributes: true),
      );
  }

  void _schedule() {
    if (_destroyed) return;
    _timer?.cancel();
    _timer = Timer(options.debounce, () {
      if (_destroyed) return;
      if (_animationFrame != null) {
        web.window.cancelAnimationFrame(_animationFrame!);
      }
      _animationFrame = web.window.requestAnimationFrame(((double time) {
        _animationFrame = null;
        _measure();
      }).toJS);
    });
  }

  void _measure() {
    if (_destroyed || _measuring || !view.dom.isConnected) return;
    _measuring = true;
    try {
      final current = key.getState(view.state);
      if (current == null) return;
      final explicitZoom = _explicitLayoutZoom(view.dom);
      if (explicitZoom != _lastExplicitZoom) {
        _lastExplicitZoom = explicitZoom;
        // The current shells use CSS `zoom` as a visual control. Chromium may
        // round line boxes differently at 60%, but zooming must never add or
        // remove logical document pages. Keep the count until content or page
        // geometry changes; those changes clear this visual-only lock.
        _visualZoomPageCount = current.pageCount;
      }
      final pagination = view.dom.querySelector('[data-tiptap-pagination]');
      if (pagination == null || pagination is! web.HTMLElement) return;

      _adjustPageSpacers(pagination);
      final nextPageCount = _calculatePageCount(
        pagination,
        current.pageCount,
      );
      if (nextPageCount != current.pageCount ||
          pagination.children.length != nextPageCount + 1) {
        _syncPaginationWidget(pagination, nextPageCount);
        // The replacement starts with nominal spacers. Correct them in the
        // same frame so the next measurement never observes a transient
        // header/footer geometry.
        _adjustPageSpacers(pagination);
      }
      _setRootHeight(pagination);
      _setAttributeIfChanged(
        view.dom,
        'data-page-count',
        '$nextPageCount',
      );

      if (nextPageCount != current.pageCount) {
        view.dispatch(
          view.state.tr.setMeta(key, _PageCountLayout(nextPageCount)),
        );
      }
    } finally {
      _measuring = false;
    }
  }

  void _adjustPageSpacers(web.HTMLElement pagination) {
    final geometry = _config.geometry;
    final scale = _layoutScale(view.dom);
    final wrappers = pagination.querySelectorAll('.tiptap-page-break');
    for (var index = 1; index < wrappers.length; index++) {
      final wrapper = wrappers.item(index);
      if (wrapper is! web.Element) continue;
      final spacer = wrapper.querySelector('.tiptap-page-spacer');
      final header = pagination.querySelector(
        '.tiptap-page-header[data-page-number="$index"]',
      );
      final footer = pagination.querySelector(
        '.tiptap-page-footer[data-page-number="$index"]',
      );
      if (spacer is! web.HTMLElement || header == null || footer == null) {
        continue;
      }
      final headerHeight = _reserveVisualRegionHeight(
        header,
        scale,
        growDownward: true,
      );
      final footerHeight = _reserveVisualRegionHeight(
        footer,
        scale,
        growDownward: false,
      );
      final available = math.max(
        1,
        geometry.pageHeight - headerHeight - footerHeight,
      );
      final value = '${available.toDouble()}px';
      if (spacer.style.marginTop != value) spacer.style.marginTop = value;
    }
  }

  double _reserveVisualRegionHeight(
    web.Element region,
    double scale, {
    required bool growDownward,
  }) {
    final regionRect = region.getBoundingClientRect();
    var top = regionRect.top;
    var bottom = regionRect.bottom;
    final descendants = region.querySelectorAll('*');
    for (var index = 0; index < descendants.length; index++) {
      final descendant = descendants.item(index);
      if (descendant == null || descendant.nodeType != 1) {
        continue;
      }
      final element = descendant as web.Element;
      if (element.closest('[data-page-editor-ui]') != null) {
        continue;
      }
      final rect = element.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) continue;
      if (!growDownward) top = math.min(top, rect.top);
      bottom = math.max(bottom, rect.bottom);
    }
    final visualHeight = math.max(1, (bottom - top) / scale);
    if (region is web.HTMLElement) {
      final currentHeight = regionRect.height / scale;
      if (visualHeight > currentHeight + .5) {
        region.style.minHeight = '${visualHeight.toDouble()}px';
      }
      return math
          .max(
            visualHeight,
            region.getBoundingClientRect().height / scale,
          )
          .toDouble();
    }
    return visualHeight.toDouble();
  }

  void _syncPaginationWidget(
    web.HTMLElement pagination,
    int pageCount,
  ) {
    final replacement = _buildPaginationWidget(
      _config,
      view.state.schema,
      pageCount,
    );
    while (pagination.firstChild != null) {
      pagination.removeChild(pagination.firstChild!);
    }
    while (replacement.firstChild != null) {
      pagination.appendChild(replacement.firstChild!);
    }
    pagination.setAttribute('data-page-count', '$pageCount');
    _regionEditor.paginationRebuilt();
  }

  int _calculatePageCount(
    web.HTMLElement pagination,
    int currentPageCount,
  ) {
    final lastContent = view.dom.lastElementChild;
    final lastWrapper = pagination.lastElementChild;
    final lastBreaker = lastWrapper?.querySelector('.breaker');
    if (lastContent == null ||
        identical(lastContent, pagination) ||
        lastBreaker == null) {
      return 1;
    }

    final scale = _layoutScale(view.dom);
    final contentRect = lastContent.getBoundingClientRect();
    final breakerRect = lastBreaker.getBoundingClientRect();
    final gap = (contentRect.bottom - breakerRect.bottom) / scale;

    if (!_sourcePageHintEligibilityChecked && _sourcePageHint != null) {
      _sourcePageHintEligibilityChecked = true;
      if (_containsOversizedTableRow(pagination, scale)) {
        _sourcePageHintLocked = true;
      }
    }

    if (_sourcePageHintLocked && _sourcePageHint != null) {
      return _sourcePageHint!;
    }
    if (_visualZoomPageCount != null) return _visualZoomPageCount!;
    if (_nonFlowingPageCount != null) return _nonFlowingPageCount!;

    final now = DateTime.now();
    if (_holdUntil != null &&
        now.isBefore(_holdUntil!) &&
        _heldPageCount != null) {
      return _heldPageCount!;
    }
    if (_history.isNotEmpty &&
        now.difference(_history.last.at) > const Duration(seconds: 2)) {
      _history.clear();
    }
    final sample = _LayoutSample(currentPageCount, gap, now);
    if (_history.isNotEmpty && _history.last.pageCount == currentPageCount) {
      _history[_history.length - 1] = sample;
    } else {
      _history.add(sample);
    }
    if (_history.length > 6) _history.removeAt(0);

    final stabilized = _stabilizedPageCount(now);
    if (stabilized != null) return stabilized;

    if (gap > .5) {
      return currentPageCount + (gap / _config.geometry.contentHeight).ceil();
    }

    final geometry = _config.geometry;
    final removeThreshold = -(geometry.pageHeight - 10);
    if (gap < removeThreshold) {
      // floor() rounds a negative ratio away from zero (-1.25 -> -2), which
      // removes two pages and creates an avoidable bounce. Only remove fully
      // unused page strides (-1.25 -> -1).
      final delta = (gap / (geometry.pageHeight + geometry.pageGap)).truncate();
      return math.max(1, currentPageCount + delta);
    }
    return currentPageCount;
  }

  bool _containsOversizedTableRow(
    web.HTMLElement pagination,
    double scale,
  ) {
    var bodyCapacity = _config.geometry.contentHeight;
    final spacer = pagination.querySelector(
      '.tiptap-page-break[data-page-index="1"] .tiptap-page-spacer',
    );
    if (spacer is web.HTMLElement) {
      final measured = double.tryParse(
        spacer.style.marginTop.replaceAll('px', ''),
      );
      if (measured != null && measured.isFinite && measured > 0) {
        bodyCapacity = measured;
      }
    }
    final rows = view.dom.querySelectorAll('tr');
    for (var index = 0; index < rows.length; index++) {
      final row = rows.item(index);
      if (row is! web.Element || pagination.contains(row)) continue;
      if (row.getBoundingClientRect().height / scale > bodyCapacity + 1) {
        return true;
      }
    }
    return false;
  }

  int? _stabilizedPageCount(DateTime now) {
    if (_history.length >= 2) {
      final previous = _history[_history.length - 2];
      final current = _history.last;
      final added = current.pageCount - previous.pageCount;
      if (added > 0 && previous.gap > .5 && current.gap > .5) {
        final reduction = previous.gap - current.gap;
        final progressPerPage = reduction / added;
        // A grid row/BFC taller than a page can be displaced by every float
        // in the chain. In that case adding pages barely consumes overflow
        // and page counts grow without bound. Stop after the first measured
        // low-progress transition instead of materialising thousands of
        // duplicate headers and footers.
        if (reduction.abs() < 50 ||
            progressPerPage < _config.geometry.contentHeight * .4) {
          _nonFlowingPageCount =
              _sourcePageHint ?? math.max(1, previous.pageCount);
          _history.clear();
          return _nonFlowingPageCount;
        }
      }
    }

    if (_history.length < 4) return null;
    final samples = _history.sublist(_history.length - 4);
    final alternating = samples[0].pageCount == samples[2].pageCount &&
        samples[1].pageCount == samples[3].pageCount &&
        samples[0].pageCount != samples[1].pageCount;
    final quick = samples.last.at.difference(samples.first.at) <
        const Duration(seconds: 1);
    if (!alternating || !quick) return null;

    final stable = math.min(samples[0].pageCount, samples[1].pageCount);
    _history.clear();
    _heldPageCount = stable;
    _holdUntil = now.add(const Duration(seconds: 2));
    return stable;
  }

  void _setRootHeight(web.HTMLElement pagination) {
    final lastFooter = pagination.querySelectorAll('.tiptap-page-footer');
    if (lastFooter.length == 0) return;
    final footer = lastFooter.item(lastFooter.length - 1);
    if (footer == null || footer is! web.Element) return;
    final scale = _layoutScale(view.dom);
    final rootRect = view.dom.getBoundingClientRect();
    final footerRect = footer.getBoundingClientRect();
    final height = math.max(
      _config.geometry.pageHeight,
      (footerRect.bottom - rootRect.top) / scale,
    );
    final value = '${height.round()}px';
    if (view.dom.style.minHeight != value) {
      view.dom.style.minHeight = value;
    }
  }

  void destroy() {
    _destroyed = true;
    _timer?.cancel();
    _timer = null;
    if (_animationFrame != null) {
      web.window.cancelAnimationFrame(_animationFrame!);
      _animationFrame = null;
    }
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    _mutationObserver?.disconnect();
    _mutationObserver = null;
    _regionEditor.destroy();
  }
}

class _LayoutSample {
  final int pageCount;
  final double gap;
  final DateTime at;

  const _LayoutSample(this.pageCount, this.gap, this.at);
}

double _layoutScale(web.HTMLElement element) {
  // CSS `zoom` is normally applied by the editor shell (`.page-scale`), not
  // by the ProseMirror root itself. Prefer that exact author value: deriving
  // it from getBoundingClientRect/offsetWidth loses a fraction through device
  // pixel rounding, which accumulates to a whole page in long documents.
  final explicitZoom = _explicitLayoutZoom(element);
  if (explicitZoom != null) return explicitZoom;

  final rect = element.getBoundingClientRect();
  final widthScale =
      element.offsetWidth > 0 ? rect.width / element.offsetWidth : 0;
  final heightScale =
      element.offsetHeight > 0 ? rect.height / element.offsetHeight : 0;
  final scale = widthScale > 0
      ? widthScale
      : heightScale > 0
          ? heightScale
          : 1;
  return (scale.isFinite && scale > 0 ? scale : 1).toDouble();
}

double? _explicitLayoutZoom(web.HTMLElement element) {
  var explicitZoom = 1.0;
  var hasExplicitZoom = false;
  web.Element? ancestor = element;
  while (ancestor is web.HTMLElement) {
    final zoom = double.tryParse(ancestor.style.zoom);
    if (zoom != null && zoom.isFinite && zoom > 0) {
      explicitZoom *= zoom;
      hasExplicitZoom = true;
    }
    ancestor = ancestor.parentElement;
  }
  return hasExplicitZoom ? explicitZoom : null;
}

void _setAttributeIfChanged(
  web.Element element,
  String name,
  String value,
) {
  if (element.getAttribute(name) != value) {
    element.setAttribute(name, value);
  }
}
