import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class ItalicExtension extends MarkExtension {
  const ItalicExtension() : super('italic');

  @override
  MarkSpec config() => MarkSpec(
        parseDOM: [
          TagParseRule(tag: 'em'),
          TagParseRule(tag: 'i'),
          StyleParseRule(style: 'font-style=italic'),
        ],
        toDOM: (mark, inline) => ['em', 0],
      );
}
