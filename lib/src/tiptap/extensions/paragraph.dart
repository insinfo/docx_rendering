import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class ParagraphExtension extends NodeExtension {
  const ParagraphExtension() : super('paragraph');

  @override
  NodeSpec config() => NodeSpec(
        content: 'inline*',
        group: 'block',
        attrs: {
          'textAlign': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'p',
            getAttrs: (web.HTMLElement dom) => {
              'textAlign':
                  dom.style.textAlign.isEmpty ? null : dom.style.textAlign,
            },
          ),
        ],
        toDOM: (node) {
          final align = node.attrs['textAlign'];
          if (align != null) {
            return ['p', {'style': 'text-align: $align'}, 0];
          }
          return ['p', 0];
        },
      );
}
