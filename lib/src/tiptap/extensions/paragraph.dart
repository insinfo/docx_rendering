import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class ParagraphExtension extends NodeExtension {
  const ParagraphExtension() : super('paragraph');

  @override
  NodeSpec config() => NodeSpec(
        content: 'inline*',
        group: 'block',
        parseDOM: [TagParseRule(tag: 'p')],
        toDOM: (node) => ['p', 0],
      );
}
