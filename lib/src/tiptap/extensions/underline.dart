import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class UnderlineExtension extends MarkExtension {
  const UnderlineExtension() : super('underline');

  @override
  MarkSpec config() => MarkSpec(
        parseDOM: [
          TagParseRule(tag: 'u'),
          StyleParseRule(
            style: 'text-decoration',
            getAttrs: (value) =>
                value.contains('underline') ? const <String, dynamic>{} : false,
          ),
        ],
        toDOM: (mark, inline) => ['u', 0],
      );
}
