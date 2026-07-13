import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class StrikeExtension extends MarkExtension {
  const StrikeExtension() : super('strike');

  @override
  MarkSpec config() => MarkSpec(
        parseDOM: [
          TagParseRule(tag: 's'),
          TagParseRule(tag: 'del'),
          TagParseRule(tag: 'strike'),
          StyleParseRule(
            style: 'text-decoration',
            getAttrs: (value) =>
                value.contains('line-through') ? const <String, dynamic>{} : false,
          ),
        ],
        toDOM: (mark, inline) => ['s', 0],
      );
}
