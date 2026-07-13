import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

class ListItemExtension extends NodeExtension {
  const ListItemExtension() : super('listItem');

  @override
  NodeSpec config() => NodeSpec(
        content: 'paragraph block*',
        defining: true,
        attrs: {
          'numberingLabel': AttributeSpec(defaultValue: null, hasDefault: true),
          'numberingLevel': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'li',
            getAttrs: (dom) => {
              'numberingLabel': dom.getAttribute('data-docx-numbering-label'),
              'numberingLevel': int.tryParse(
                dom.getAttribute('data-docx-numbering-level') ?? '',
              ),
            },
          ),
        ],
        toDOM: (node) {
          final label = node.attrs['numberingLabel'];
          if (label == null) return ['li', 0];
          final attrs = <String, dynamic>{
            'data-docx-numbering-label': label,
          };
          final level = node.attrs['numberingLevel'];
          if (level != null) attrs['data-docx-numbering-level'] = level;
          return ['li', attrs, 0];
        },
      );
}
