import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class OrderedListExtension extends NodeExtension {
  const OrderedListExtension() : super('orderedList');

  @override
  NodeSpec config() => NodeSpec(
        content: 'listItem+',
        group: 'block',
        attrs: {
          'start': AttributeSpec(defaultValue: 1, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'ol',
            getAttrs: (web.HTMLElement dom) => {
              'start': dom.hasAttribute('start')
                  ? int.tryParse(dom.getAttribute('start') ?? '') ?? 1
                  : 1,
            },
          ),
        ],
        toDOM: (node) {
          final start = node.attrs['start'];
          if (start != null && start != 1) {
            return ['ol', {'start': start}, 0];
          }
          return ['ol', 0];
        },
      );
}
