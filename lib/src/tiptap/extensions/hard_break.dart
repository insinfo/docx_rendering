import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class HardBreakExtension extends NodeExtension {
  const HardBreakExtension() : super('hardBreak');

  @override
  NodeSpec config() => NodeSpec(
        inline: true,
        group: 'inline',
        selectable: false,
        linebreakReplacement: true,
        parseDOM: [TagParseRule(tag: 'br')],
        toDOM: (node) => ['br'],
      );
}
