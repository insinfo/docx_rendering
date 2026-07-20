import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';
import '../../prosemirror/view/decoration.dart';
import '../../prosemirror/view/index.dart';
import '../core/extension.dart';

/// Renders Word paragraph tabs as measured inline gaps while preserving the
/// literal tab character used for editing, clipboard and DOCX round trips.
class TabRenderingExtension extends Extension {
  final double defaultTabStop;

  const TabRenderingExtension({this.defaultTabStop = 47.244})
      : super('tabRendering');

  @override
  List<Plugin> addPlugins() => [_tabRenderingPlugin(defaultTabStop)];
}

Plugin<DecorationSet> _tabRenderingPlugin(double defaultTabStop) {
  final key = PluginKey<DecorationSet>('tabRendering');
  return Plugin<DecorationSet>(PluginSpec<DecorationSet>(
    key: key,
    state: StateField<DecorationSet>(
      init: (config, state) => _tabDecorations(state.doc),
      apply: (tr, previous, oldState, newState) => tr.docChanged
          ? _tabDecorations(newState.doc)
          : (previous as DecorationSet).map(tr.mapping, tr.doc),
    ),
    props: {'decorations': (EditorState state) => key.getState(state)},
    view: (dynamic rawView) {
      final tabView = _TabRenderingView(rawView as EditorView, defaultTabStop);
      return PluginView(
        update: (view, previousState) =>
            tabView.update(view as EditorView, previousState),
        destroy: tabView.destroy,
      );
    },
  ));
}

DecorationSet _tabDecorations(PMNode doc) {
  final decorations = <Decoration>[];
  doc.descendants((node, position, parent, index) {
    if (!node.isText || node.text == null || !node.text!.contains('\t')) {
      return true;
    }
    for (var offset = node.text!.indexOf('\t');
        offset >= 0;
        offset = node.text!.indexOf('\t', offset + 1)) {
      decorations
          .add(Decoration.inline(position + offset, position + offset + 1, {
        'nodeName': 'span',
        'class': 'tiptap-tab-run',
        'data-tiptap-tab': 'true',
        'aria-hidden': 'true',
      }));
    }
    return true;
  });
  return DecorationSet.create(doc, decorations);
}

class _TabRenderingView {
  EditorView view;
  final double defaultTabStop;
  int? _animationFrame;
  bool _destroyed = false;

  _TabRenderingView(this.view, this.defaultTabStop) {
    _schedule();
  }

  void update(EditorView nextView, EditorState previousState) {
    view = nextView;
    _schedule();
  }

  void destroy() {
    _destroyed = true;
    if (_animationFrame != null)
      web.window.cancelAnimationFrame(_animationFrame!);
    _animationFrame = null;
  }

  void _schedule() {
    if (_destroyed || _animationFrame != null) return;
    _animationFrame = web.window.requestAnimationFrame(((double _) {
      _animationFrame = null;
      _layout();
    }).toJS);
  }

  void _layout() {
    if (_destroyed || !view.dom.isConnected) return;
    final effectiveDefaultTabStop =
        _lengthPx(view.state.doc.attrs['defaultTabStop']) ?? defaultTabStop;
    // Paragraphs containing a literal tab still need Word's default 1.25 cm
    // stops even when no explicit w:tabs collection exists.
    final blocks = view.dom.querySelectorAll('p, h1, h2, h3, h4, h5, h6');
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      final rawBlock = blocks.item(blockIndex);
      if (rawBlock is! web.HTMLElement) continue;
      final tabs = rawBlock.querySelectorAll('.tiptap-tab-run');
      if (tabs.length == 0) continue;
      final stops = _readStops(rawBlock.getAttribute('data-docx-tabs'));
      for (var index = 0; index < tabs.length; index++) {
        final rawTab = tabs.item(index);
        if (rawTab is web.HTMLElement) rawTab.style.width = '1px';
      }
      for (var index = 0; index < tabs.length; index++) {
        final rawTab = tabs.item(index);
        if (rawTab is web.HTMLElement) {
          _layoutTab(
            rawBlock,
            rawTab,
            tabs,
            index,
            stops,
            effectiveDefaultTabStop,
          );
        }
      }
    }
  }

  void _layoutTab(
    web.HTMLElement block,
    web.HTMLElement tab,
    web.NodeList tabs,
    int index,
    List<_RenderedTabStop> stops,
    double effectiveDefaultTabStop,
  ) {
    final blockRect = block.getBoundingClientRect();
    final tabRect = tab.getBoundingClientRect();
    final current = math.max(0, tabRect.left - blockRect.left).toDouble();
    final computed = web.window.getComputedStyle(block);
    final paragraphIndent =
        double.tryParse(computed.marginLeft.replaceAll('px', '')) ?? 0;
    final logicalCurrent = current + paragraphIndent;
    final stop = _nextStop(
      stops,
      logicalCurrent,
      blockRect.width + paragraphIndent,
      effectiveDefaultTabStop,
    );
    if (stop == null) return;
    final followingWidth =
        _followingWidth(block, tab, tabs, index, stop.type == 'decimal');
    var width = stop.position - logicalCurrent;
    switch (stop.type) {
      case 'right':
        width -= followingWidth;
      case 'center':
        width -= followingWidth / 2;
      case 'decimal':
        width -= followingWidth;
    }
    width = width.clamp(1.0, math.max(1, blockRect.width - current));
    tab
      ..setAttribute('data-tab-type', stop.type)
      ..setAttribute('data-tab-leader', stop.leader)
      ..style.width = '${width.toStringAsFixed(2)}px';
  }

  double _followingWidth(web.HTMLElement block, web.HTMLElement tab,
      web.NodeList tabs, int index, bool decimalOnly) {
    final range = web.document.createRange()..setStartAfter(tab);
    if (index + 1 < tabs.length) {
      final next = tabs.item(index + 1);
      if (next != null) range.setEndBefore(next);
    } else {
      range.setEnd(block, block.childNodes.length);
    }
    final fullWidth = range.getBoundingClientRect().width;
    if (!decimalOnly) return fullWidth;
    final text = range.toString();
    final decimal = text.indexOf(RegExp(r'[\.,]'));
    if (decimal < 0 || text.isEmpty) return fullWidth;
    return fullWidth * (decimal + .5) / text.length;
  }

  _RenderedTabStop? _nextStop(
    List<_RenderedTabStop> stops,
    double current,
    double blockWidth,
    double effectiveDefaultTabStop,
  ) {
    for (final stop in stops) {
      if (stop.position > current + .5) return stop;
    }
    var position = stops.isEmpty ? 0.0 : stops.last.position;
    position +=
        (math.max(0, current - position) / effectiveDefaultTabStop).floor() *
            effectiveDefaultTabStop;
    while (position <= current + .5) {
      position += effectiveDefaultTabStop;
    }
    return position <= blockWidth
        ? _RenderedTabStop(position, 'left', 'none')
        : null;
  }

  List<_RenderedTabStop> _readStops(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final result = <_RenderedTabStop>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final position = _lengthPx(item['position']);
        if (position == null) continue;
        final type = '${item['type'] ?? 'left'}';
        final leader = '${item['leader'] ?? 'none'}';
        result.add(_RenderedTabStop(
          position,
          const ['left', 'center', 'right', 'decimal'].contains(type)
              ? type
              : 'left',
          const ['none', 'dot', 'hyphen', 'underscore', 'middleDot']
                  .contains(leader)
              ? leader
              : 'none',
        ));
      }
      result.sort((a, b) => a.position.compareTo(b.position));
      return result;
    } catch (_) {
      return [];
    }
  }

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
      'cm' => amount * 96 / 2.54,
      'mm' => amount * 96 / 25.4,
      _ => amount,
    };
  }
}

class _RenderedTabStop {
  final double position;
  final String type;
  final String leader;

  const _RenderedTabStop(this.position, this.type, this.leader);
}
