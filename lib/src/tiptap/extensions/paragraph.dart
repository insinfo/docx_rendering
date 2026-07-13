import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';
import 'block_style.dart';

class ParagraphExtension extends NodeExtension {
  const ParagraphExtension() : super('paragraph');

  @override
  NodeSpec config() => NodeSpec(
        content: 'inline*',
        group: 'block',
        attrs: blockStyleAttributeSpecs(),
        parseDOM: [
          TagParseRule(
            tag: 'p',
            getAttrs: blockStyleAttrsFromDom,
          ),
        ],
        toDOM: (node) {
          final attrs = blockStyleDomAttrs(node);
          return attrs.isEmpty ? ['p', 0] : ['p', attrs, 0];
        },
      );
}
