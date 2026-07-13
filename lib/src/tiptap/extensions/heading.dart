import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';
import 'block_style.dart';

class HeadingExtension extends NodeExtension {
  final List<int> levels;

  const HeadingExtension({this.levels = const [1, 2, 3, 4, 5, 6]})
      : super('heading');

  @override
  NodeSpec config() => NodeSpec(
        content: 'inline*',
        group: 'block',
        defining: true,
        attrs: {
          ...blockStyleAttributeSpecs(),
          'level': AttributeSpec(defaultValue: 1, hasDefault: true),
        },
        parseDOM: [
          for (final level in levels)
            TagParseRule(
              tag: 'h$level',
              getAttrs: (web.HTMLElement dom) => {
                ...blockStyleAttrsFromDom(dom),
                'level': level,
              },
            ),
        ],
        toDOM: (node) {
          final tag = 'h${node.attrs['level']}';
          final attrs = blockStyleDomAttrs(node);
          return attrs.isEmpty ? [tag, 0] : [tag, attrs, 0];
        },
      );
}
