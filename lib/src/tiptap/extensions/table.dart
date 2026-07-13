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
        parseDOM: [TagParseRule(tag: 'table')],
        toDOM: (node) => [
          'table',
          ['tbody', 0]
        ],
      );
}

class TableRowExtension extends NodeExtension {
  const TableRowExtension() : super('tableRow');

  @override
  NodeSpec config() => NodeSpec(
        content: '(tableCell | tableHeader)*',
        parseDOM: [TagParseRule(tag: 'tr')],
        toDOM: (node) => ['tr', 0],
      );
}

Map<String, AttributeSpec> _cellAttrs() => {
      'colspan': AttributeSpec(defaultValue: 1, hasDefault: true),
      'rowspan': AttributeSpec(defaultValue: 1, hasDefault: true),
      'colwidth': AttributeSpec(defaultValue: null, hasDefault: true),
    };

Map<String, dynamic> _cellAttrsFromDom(web.HTMLElement dom) {
  final widthAttr = dom.getAttribute('data-colwidth');
  final widths = widthAttr != null &&
          RegExp(r'^\d+(,\d+)*$').hasMatch(widthAttr)
      ? widthAttr.split(',').map(int.parse).toList()
      : null;
  final colspan = int.tryParse(dom.getAttribute('colspan') ?? '') ?? 1;
  return {
    'colspan': colspan,
    'rowspan': int.tryParse(dom.getAttribute('rowspan') ?? '') ?? 1,
    'colwidth': widths != null && widths.length == colspan ? widths : null,
  };
}

dynamic _cellToDom(PMNode node, String tag) {
  final attrs = <String, dynamic>{};
  if (node.attrs['colspan'] != null && node.attrs['colspan'] != 1) {
    attrs['colspan'] = node.attrs['colspan'];
  }
  if (node.attrs['rowspan'] != null && node.attrs['rowspan'] != 1) {
    attrs['rowspan'] = node.attrs['rowspan'];
  }
  final colwidth = node.attrs['colwidth'];
  if (colwidth is List && colwidth.isNotEmpty) {
    attrs['data-colwidth'] = colwidth.join(',');
  }
  return [tag, attrs, 0];
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
