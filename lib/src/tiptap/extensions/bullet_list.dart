import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class BulletListExtension extends NodeExtension {
  const BulletListExtension() : super('bulletList');

  @override
  NodeSpec config() => NodeSpec(
        content: 'listItem+',
        group: 'block',
        parseDOM: [TagParseRule(tag: 'ul')],
        toDOM: (node) => ['ul', 0],
      );
}
