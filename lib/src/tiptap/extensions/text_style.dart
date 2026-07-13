import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';
import '../../prosemirror/model/from_dom.dart';

import '../core/extension.dart';

/// Span-level styling mark: color, background, font family, size and tracking.
/// Equivalent to Tiptap's `TextStyle` + `Color` extensions combined.
class TextStyleExtension extends MarkExtension {
  const TextStyleExtension() : super('textStyle');

  @override
  MarkSpec config() => MarkSpec(
        attrs: {
          'color': AttributeSpec(defaultValue: null, hasDefault: true),
          'backgroundColor':
              AttributeSpec(defaultValue: null, hasDefault: true),
          'fontFamily': AttributeSpec(defaultValue: null, hasDefault: true),
          'fontSize': AttributeSpec(defaultValue: null, hasDefault: true),
          'letterSpacing': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'span',
            getAttrs: (web.HTMLElement dom) {
              final style = dom.style;
              final attrs = <String, dynamic>{
                if (style.color.isNotEmpty) 'color': style.color,
                if (style.backgroundColor.isNotEmpty)
                  'backgroundColor': style.backgroundColor,
                if (style.fontFamily.isNotEmpty) 'fontFamily': style.fontFamily,
                if (style.fontSize.isNotEmpty) 'fontSize': style.fontSize,
                if (style.letterSpacing.isNotEmpty)
                  'letterSpacing': style.letterSpacing,
              };
              if (attrs.isEmpty) return false;
              return attrs;
            },
          ),
        ],
        toDOM: (mark, inline) {
          final style = StringBuffer();
          final color = mark.attrs['color'];
          final background = mark.attrs['backgroundColor'];
          final fontFamily = mark.attrs['fontFamily'];
          final fontSize = mark.attrs['fontSize'];
          final letterSpacing = mark.attrs['letterSpacing'];
          if (color != null) style.write('color: $color;');
          if (background != null) style.write('background-color: $background;');
          if (fontFamily != null) style.write('font-family: $fontFamily;');
          if (fontSize != null) style.write('font-size: $fontSize;');
          if (letterSpacing != null) {
            style.write('letter-spacing: $letterSpacing;');
          }
          return [
            'span',
            {'style': style.isEmpty ? null : style.toString()},
            0
          ];
        },
      );
}
