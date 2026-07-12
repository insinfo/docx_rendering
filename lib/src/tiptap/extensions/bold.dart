import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class BoldExtension extends MarkExtension {
  const BoldExtension() : super('bold');

  @override
  MarkSpec config() => MarkSpec(
        parseDOM: [
          TagParseRule(tag: 'strong'),
          TagParseRule(tag: 'b'),
          StyleParseRule(
            style: 'font-weight',
            getAttrs: (value) {
              final regExp = RegExp(r'^(bold(er)?|[7-9]00)$');
              if (regExp.hasMatch(value)) {
                return const <String, dynamic>{};
              }
              return false;
            },
          ),
        ],
        toDOM: (mark, inline) => ['strong', 0],
      );
}
