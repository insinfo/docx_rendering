import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

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
          'level': AttributeSpec(defaultValue: 1, hasDefault: true),
          'textAlign': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          for (final level in levels)
            TagParseRule(
              tag: 'h$level',
              getAttrs: (web.HTMLElement dom) => {
                'level': level,
                'textAlign':
                    dom.style.textAlign.isEmpty ? null : dom.style.textAlign,
              },
            ),
        ],
        toDOM: (node) {
          final tag = 'h${node.attrs['level']}';
          final align = node.attrs['textAlign'];
          if (align != null) {
            return [tag, {'style': 'text-align: $align'}, 0];
          }
          return [tag, 0];
        },
      );
}
