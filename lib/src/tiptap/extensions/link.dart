import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class LinkExtension extends MarkExtension {
  const LinkExtension() : super('link');

  @override
  MarkSpec config() => MarkSpec(
        inclusive: false,
        attrs: {
          'href': AttributeSpec(defaultValue: null, hasDefault: true),
          'title': AttributeSpec(defaultValue: null, hasDefault: true),
          'target': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'a[href]',
            getAttrs: (web.HTMLElement dom) => {
              'href': dom.getAttribute('href'),
              'title': dom.getAttribute('title'),
              'target': dom.getAttribute('target'),
            },
          ),
        ],
        toDOM: (mark, inline) => [
          'a',
          {
            'href': mark.attrs['href'],
            'title': mark.attrs['title'],
            'target': mark.attrs['target'],
          },
          0
        ],
      );
}
