import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class ListItemExtension extends NodeExtension {
  const ListItemExtension() : super('listItem');

  @override
  NodeSpec config() => NodeSpec(
        content: 'paragraph block*',
        defining: true,
        parseDOM: [TagParseRule(tag: 'li')],
        toDOM: (node) => ['li', 0],
      );
}
