import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class HorizontalRuleExtension extends NodeExtension {
  const HorizontalRuleExtension() : super('horizontalRule');

  @override
  NodeSpec config() => NodeSpec(
        group: 'block',
        parseDOM: [TagParseRule(tag: 'hr')],
        toDOM: (node) => ['hr'],
      );
}
