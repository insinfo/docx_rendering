import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class SubscriptExtension extends MarkExtension {
  const SubscriptExtension() : super('subscript');

  @override
  MarkSpec config() => MarkSpec(
        excludes: 'subscript superscript',
        parseDOM: [
          TagParseRule(tag: 'sub'),
          StyleParseRule(
            style: 'vertical-align',
            getAttrs: (value) =>
                value == 'sub' ? const <String, dynamic>{} : false,
          ),
        ],
        toDOM: (mark, inline) => ['sub', 0],
      );
}

class SuperscriptExtension extends MarkExtension {
  const SuperscriptExtension() : super('superscript');

  @override
  MarkSpec config() => MarkSpec(
        excludes: 'subscript superscript',
        parseDOM: [
          TagParseRule(tag: 'sup'),
          StyleParseRule(
            style: 'vertical-align',
            getAttrs: (value) =>
                value == 'super' ? const <String, dynamic>{} : false,
          ),
        ],
        toDOM: (mark, inline) => ['sup', 0],
      );
}
