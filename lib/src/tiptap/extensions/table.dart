import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class TableExtension extends NodeExtension {
  const TableExtension() : super('table');

  @override
  NodeSpec config() => NodeSpec(
        content: 'tableRow+',
        group: 'block',
        isolating: true,
        attrs: {
          'styleName': AttributeSpec(defaultValue: null, hasDefault: true),
          'width': AttributeSpec(defaultValue: null, hasDefault: true),
          'height': AttributeSpec(defaultValue: null, hasDefault: true),
          'fontFamily': AttributeSpec(defaultValue: null, hasDefault: true),
          'fontSize': AttributeSpec(defaultValue: null, hasDefault: true),
          'lineHeight': AttributeSpec(defaultValue: null, hasDefault: true),
          'textBox': AttributeSpec(defaultValue: false, hasDefault: true),
          'columnWidths': AttributeSpec(defaultValue: null, hasDefault: true),
          'marginLeft': AttributeSpec(defaultValue: null, hasDefault: true),
          'alignment': AttributeSpec(defaultValue: null, hasDefault: true),
          'borderCollapse': AttributeSpec(defaultValue: null, hasDefault: true),
          'borderSpacing': AttributeSpec(defaultValue: null, hasDefault: true),
          'position': AttributeSpec(defaultValue: null, hasDefault: true),
          'right': AttributeSpec(defaultValue: null, hasDefault: true),
          'left': AttributeSpec(defaultValue: null, hasDefault: true),
          'top': AttributeSpec(defaultValue: null, hasDefault: true),
          'bottom': AttributeSpec(defaultValue: null, hasDefault: true),
          'zIndex': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'table',
            getAttrs: (web.HTMLElement dom) => {
              'styleName': dom.getAttribute('data-docx-style'),
              'width': _styleValue(dom, 'width'),
              'height': _styleValue(dom, 'height'),
              'fontFamily': _styleValue(dom, 'font-family'),
              'fontSize': _styleValue(dom, 'font-size'),
              'lineHeight': _styleValue(dom, 'line-height'),
              'textBox': dom.hasAttribute('data-docx-textbox'),
              'columnWidths': _parseWidths(
                dom.getAttribute('data-column-widths'),
              ),
              'marginLeft': _styleValue(dom, 'margin-left'),
              'alignment': _styleValue(dom, 'text-align'),
              'borderCollapse': _styleValue(dom, 'border-collapse'),
              'borderSpacing': _styleValue(dom, 'border-spacing'),
              'position': _styleValue(dom, 'position'),
              'right': _styleValue(dom, 'right'),
              'left': _styleValue(dom, 'left'),
              'top': _styleValue(dom, 'top'),
              'bottom': _styleValue(dom, 'bottom'),
              'zIndex': _styleValue(dom, 'z-index'),
            },
          ),
        ],
        toDOM: (node) {
          final attrs = _styledAttrs(node, {
            'width': 'width',
            'height': 'height',
            'font-family': 'fontFamily',
            'font-size': 'fontSize',
            'line-height': 'lineHeight',
            'margin-left': 'marginLeft',
            'text-align': 'alignment',
            'border-collapse': 'borderCollapse',
            'border-spacing': 'borderSpacing',
            'position': 'position',
            'right': 'right',
            'left': 'left',
            'top': 'top',
            'bottom': 'bottom',
            'z-index': 'zIndex',
          });
          if (node.attrs['styleName'] != null) {
            attrs['data-docx-style'] = node.attrs['styleName'];
          }
          if (node.attrs['textBox'] == true) {
            attrs['data-docx-textbox'] = '';
          }
          final widths = _widths(node.attrs['columnWidths']);
          if (widths != null) {
            attrs['data-column-widths'] = widths.join(',');
          }
          return [
            'table',
            attrs,
            ['tbody', 0]
          ];
        },
      );
}

class TableRowExtension extends NodeExtension {
  const TableRowExtension() : super('tableRow');

  @override
  NodeSpec config() => NodeSpec(
        content: '(tableCell | tableHeader)*',
        attrs: {
          'columnWidths': AttributeSpec(defaultValue: null, hasDefault: true),
          'isHeader': AttributeSpec(defaultValue: false, hasDefault: true),
          'tableWidth': AttributeSpec(defaultValue: null, hasDefault: true),
          'tableAlignment': AttributeSpec(defaultValue: null, hasDefault: true),
          'height': AttributeSpec(defaultValue: null, hasDefault: true),
          'heightRule': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'tr',
            getAttrs: (web.HTMLElement dom) {
              final heightRule = dom.getAttribute('data-height-rule');
              return {
                'columnWidths': _parseWidths(
                  dom.getAttribute('data-column-widths'),
                ),
                'isHeader': dom.hasAttribute('data-docx-header'),
                'tableWidth': dom.getAttribute('data-table-width'),
                'tableAlignment': dom.getAttribute('data-table-alignment'),
                'height': heightRule == 'exact'
                    ? _styleValue(dom, 'height')
                    : _styleValue(dom, 'min-height') ??
                        _styleValue(dom, 'height'),
                'heightRule': heightRule == 'exact' || heightRule == 'atLeast'
                    ? heightRule
                    : null,
              };
            },
          ),
        ],
        toDOM: (node) {
          final attrs = <String, dynamic>{};
          final widths = _widths(node.attrs['columnWidths']);
          if (widths != null) {
            attrs['data-column-widths'] = widths.join(',');
            // Pagination renders top-level rows as CSS grid. Supplying the
            // actual w:tblGrid tracks keeps columns contiguous and prevents
            // the browser from inventing zero-width/auto-fit tracks.
            attrs['style'] =
                'grid-template-columns:${widths.map((w) => '${w}px').join(' ')};';
          }
          if (node.attrs['isHeader'] == true) {
            attrs['data-docx-header'] = '';
          }
          final tableWidth = node.attrs['tableWidth'];
          final tableAlignment = node.attrs['tableAlignment'];
          if (tableWidth != null && '$tableWidth'.isNotEmpty) {
            attrs['data-table-width'] = '$tableWidth';
            final existing = '${attrs['style'] ?? ''}';
            final positioning = StringBuffer('width:$tableWidth;');
            if (tableAlignment == 'center') {
              positioning.write('margin-left:auto;margin-right:auto;');
            } else if (tableAlignment == 'right' || tableAlignment == 'end') {
              positioning.write('margin-left:auto;margin-right:0;');
            }
            attrs['style'] = '$existing$positioning';
          }
          if (tableAlignment != null && '$tableAlignment'.isNotEmpty) {
            attrs['data-table-alignment'] = '$tableAlignment';
          }
          final height = node.attrs['height'];
          final heightRule = node.attrs['heightRule'];
          if (height != null && '$height'.isNotEmpty) {
            final existing = '${attrs['style'] ?? ''}';
            final property = heightRule == 'exact' ? 'height' : 'min-height';
            attrs['style'] = '$existing$property:$height;--tr-height:$height;';
            attrs['data-height-rule'] =
                heightRule == 'exact' ? 'exact' : 'atLeast';
          }
          return ['tr', attrs, 0];
        },
      );
}

List<int>? _parseWidths(String? value) {
  if (value == null || !RegExp(r'^\d+(,\d+)*$').hasMatch(value)) return null;
  return value.split(',').map(int.parse).where((width) => width > 0).toList();
}

List<int>? _widths(dynamic value) {
  if (value is! List) return null;
  final result = value.whereType<num>().map((width) => width.round()).toList();
  return result.isEmpty || result.any((width) => width <= 0) ? null : result;
}

Map<String, AttributeSpec> _cellAttrs() => {
      'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
      'rowspan': AttributeSpec(defaultValue: 1, hasDefault: true),
      'colwidth': AttributeSpec(defaultValue: null, hasDefault: true),
      'columnIndex': AttributeSpec(defaultValue: null, hasDefault: true),
      'width': AttributeSpec(defaultValue: null, hasDefault: true),
      'backgroundColor': AttributeSpec(defaultValue: null, hasDefault: true),
      'borderTop': AttributeSpec(defaultValue: null, hasDefault: true),
      'borderRight': AttributeSpec(defaultValue: null, hasDefault: true),
      'borderBottom': AttributeSpec(defaultValue: null, hasDefault: true),
      'borderLeft': AttributeSpec(defaultValue: null, hasDefault: true),
      'paddingTop': AttributeSpec(defaultValue: null, hasDefault: true),
      'paddingRight': AttributeSpec(defaultValue: null, hasDefault: true),
      'paddingBottom': AttributeSpec(defaultValue: null, hasDefault: true),
      'paddingLeft': AttributeSpec(defaultValue: null, hasDefault: true),
    };

Map<String, dynamic> _cellAttrsFromDom(web.HTMLElement dom) {
  final widthAttr = dom.getAttribute('data-colwidth');
  final widths =
      widthAttr != null && RegExp(r'^\d+(,\d+)*$').hasMatch(widthAttr)
          ? widthAttr.split(',').map(int.parse).toList()
          : null;
  final colspan = int.tryParse(dom.getAttribute('colspan') ?? '') ?? 1;
  return {
    'colspan': colspan,
    'rowspan': int.tryParse(dom.getAttribute('rowspan') ?? '') ?? 1,
    'colwidth': widths != null && widths.length == colspan ? widths : null,
    'columnIndex': int.tryParse(dom.getAttribute('data-column-index') ?? ''),
    'width': _styleValue(dom, 'width'),
    'backgroundColor': _styleValue(dom, 'background-color'),
    'borderTop': _styleValue(dom, 'border-top'),
    'borderRight': _styleValue(dom, 'border-right'),
    'borderBottom': _styleValue(dom, 'border-bottom'),
    'borderLeft': _styleValue(dom, 'border-left'),
    'paddingTop': _styleValue(dom, 'padding-top'),
    'paddingRight': _styleValue(dom, 'padding-right'),
    'paddingBottom': _styleValue(dom, 'padding-bottom'),
    'paddingLeft': _styleValue(dom, 'padding-left'),
  };
}

dynamic _cellToDom(PMNode node, String tag) {
  final attrs = <String, dynamic>{};
  final gridStyle = StringBuffer();
  final columnIndex = node.attrs['columnIndex'];
  final colspan =
      node.attrs['colspan'] is int ? node.attrs['colspan'] as int : 1;
  if (columnIndex is int && columnIndex >= 0) {
    attrs['data-column-index'] = columnIndex;
    gridStyle.write(colspan > 1
        ? 'grid-column:${columnIndex + 1} / span $colspan;'
        : 'grid-column-start:${columnIndex + 1};');
  }
  if (colspan != 1) {
    attrs['colspan'] = colspan;
    if (columnIndex is! int || columnIndex < 0) {
      gridStyle.write('grid-column:span $colspan;');
    }
  }
  if (node.attrs['rowspan'] != null && node.attrs['rowspan'] != 1) {
    attrs['rowspan'] = node.attrs['rowspan'];
  }
  final colwidth = node.attrs['colwidth'];
  if (colwidth is List && colwidth.isNotEmpty) {
    attrs['data-colwidth'] = colwidth.join(',');
  }
  attrs.addAll(_styledAttrs(node, {
    'width': 'width',
    'background-color': 'backgroundColor',
    'border-top': 'borderTop',
    'border-right': 'borderRight',
    'border-bottom': 'borderBottom',
    'border-left': 'borderLeft',
    'padding-top': 'paddingTop',
    'padding-right': 'paddingRight',
    'padding-bottom': 'paddingBottom',
    'padding-left': 'paddingLeft',
  }));
  if (gridStyle.isNotEmpty) {
    attrs['style'] = '${attrs['style'] ?? ''}${gridStyle.toString()}';
  }
  return [tag, attrs, 0];
}

String? _styleValue(web.HTMLElement dom, String name) {
  final value = dom.style.getPropertyValue(name).trim();
  return value.isEmpty ? null : value;
}

Map<String, dynamic> _styledAttrs(PMNode node, Map<String, String> properties) {
  final style = StringBuffer();
  for (final entry in properties.entries) {
    final value = node.attrs[entry.value];
    if (value != null && '$value'.isNotEmpty) {
      style.write('${entry.key}: $value;');
    }
  }
  return style.isEmpty ? <String, dynamic>{} : {'style': style.toString()};
}

class TableCellExtension extends NodeExtension {
  const TableCellExtension() : super('tableCell');

  @override
  NodeSpec config() => NodeSpec(
        content: 'block+',
        isolating: true,
        attrs: _cellAttrs(),
        parseDOM: [
          TagParseRule(tag: 'td', getAttrs: _cellAttrsFromDom),
        ],
        toDOM: (node) => _cellToDom(node, 'td'),
      );
}

class TableHeaderExtension extends NodeExtension {
  const TableHeaderExtension() : super('tableHeader');

  @override
  NodeSpec config() => NodeSpec(
        content: 'block+',
        isolating: true,
        attrs: _cellAttrs(),
        parseDOM: [
          TagParseRule(tag: 'th', getAttrs: _cellAttrsFromDom),
        ],
        toDOM: (node) => _cellToDom(node, 'th'),
      );
}
