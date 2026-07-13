import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class ImageExtension extends NodeExtension {
  final bool inline;

  const ImageExtension({this.inline = false}) : super('image');

  @override
  NodeSpec config() => NodeSpec(
        inline: inline,
        group: inline ? 'inline' : 'block',
        draggable: true,
        attrs: {
          'src': AttributeSpec(defaultValue: null, hasDefault: true),
          'alt': AttributeSpec(defaultValue: null, hasDefault: true),
          'title': AttributeSpec(defaultValue: null, hasDefault: true),
          'width': AttributeSpec(defaultValue: null, hasDefault: true),
          'height': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'img[src]',
            getAttrs: (web.HTMLElement dom) => {
              'src': dom.getAttribute('src'),
              'alt': dom.getAttribute('alt'),
              'title': dom.getAttribute('title'),
              'width': dom.getAttribute('width'),
              'height': dom.getAttribute('height'),
            },
          ),
        ],
        toDOM: (node) => [
          'img',
          {
            'src': node.attrs['src'],
            'alt': node.attrs['alt'],
            'title': node.attrs['title'],
            'width': node.attrs['width'],
            'height': node.attrs['height'],
          }
        ],
      );
}
