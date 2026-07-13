import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class CodeExtension extends MarkExtension {
  const CodeExtension() : super('code');

  @override
  MarkSpec config() => MarkSpec(
        code: true,
        excludes: '_',
        parseDOM: [TagParseRule(tag: 'code')],
        toDOM: (mark, inline) => ['code', 0],
      );
}
