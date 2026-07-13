import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class HighlightExtension extends MarkExtension {
  const HighlightExtension() : super('highlight');

  @override
  MarkSpec config() => MarkSpec(
        attrs: {
          'color': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'mark',
            getAttrs: (web.HTMLElement dom) => {
              'color': dom.style.backgroundColor.isEmpty
                  ? null
                  : dom.style.backgroundColor,
            },
          ),
        ],
        toDOM: (mark, inline) {
          final color = mark.attrs['color'];
          return [
            'mark',
            {'style': color != null ? 'background-color: $color' : null},
            0
          ];
        },
      );
}
