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
          'position': AttributeSpec(defaultValue: null, hasDefault: true),
          'left': AttributeSpec(defaultValue: null, hasDefault: true),
          'right': AttributeSpec(defaultValue: null, hasDefault: true),
          'top': AttributeSpec(defaultValue: null, hasDefault: true),
          'bottom': AttributeSpec(defaultValue: null, hasDefault: true),
          'alignment': AttributeSpec(defaultValue: null, hasDefault: true),
          'marginTop': AttributeSpec(defaultValue: null, hasDefault: true),
          'marginRight': AttributeSpec(defaultValue: null, hasDefault: true),
          'marginBottom': AttributeSpec(defaultValue: null, hasDefault: true),
          'marginLeft': AttributeSpec(defaultValue: null, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'img[src]',
            getAttrs: (web.HTMLElement dom) => {
              'src': dom.getAttribute('src'),
              'alt': dom.getAttribute('alt'),
              'title': dom.getAttribute('title'),
              'width': _imageDimension(dom, 'width'),
              'height': _imageDimension(dom, 'height'),
              'position': _imageStyle(dom, 'position'),
              'left': _imageStyle(dom, 'left'),
              'right': _imageStyle(dom, 'right'),
              'top': _imageStyle(dom, 'top'),
              'bottom': _imageStyle(dom, 'bottom'),
              'alignment': dom.getAttribute('data-object-align'),
              'marginTop': _imageStyle(dom, 'margin-top'),
              'marginRight': _imageStyle(dom, 'margin-right'),
              'marginBottom': _imageStyle(dom, 'margin-bottom'),
              'marginLeft': _imageStyle(dom, 'margin-left'),
            },
          ),
        ],
        toDOM: (node) {
          final width = node.attrs['width'];
          final height = node.attrs['height'];
          final style = StringBuffer();
          if (width != null && '$width'.isNotEmpty) {
            style.write('width:${_cssImageDimension(width)};');
          }
          if (height != null && '$height'.isNotEmpty) {
            style.write('height:${_cssImageDimension(height)};');
          }
          for (final entry in const {
            'position': 'position',
            'left': 'left',
            'right': 'right',
            'top': 'top',
            'bottom': 'bottom',
          }.entries) {
            final value = node.attrs[entry.value];
            if (value != null && '$value'.isNotEmpty) {
              style.write('${entry.key}:$value;');
            }
          }
          for (final entry in const {
            'margin-top': 'marginTop',
            'margin-right': 'marginRight',
            'margin-bottom': 'marginBottom',
            'margin-left': 'marginLeft',
          }.entries) {
            final value = node.attrs[entry.value];
            if (value != null && '$value'.isNotEmpty) {
              style.write('${entry.key}:$value;');
            }
          }
          final alignment = node.attrs['alignment'];
          if (alignment == 'left') {
            style.write('margin-left:${node.attrs['marginLeft'] ?? '0'};');
            style.write('margin-right:auto;');
          } else if (alignment == 'center') {
            style.write('margin-left:auto;margin-right:auto;');
          } else if (alignment == 'right') {
            style.write('margin-left:auto;');
            style.write('margin-right:${node.attrs['marginRight'] ?? '0'};');
          }
          return [
            'img',
            {
              'src': node.attrs['src'],
              'alt': node.attrs['alt'],
              'title': node.attrs['title'],
              if (node.attrs['alignment'] != null)
                'data-object-align': node.attrs['alignment'],
              if (style.isNotEmpty) 'style': style.toString(),
            }
          ];
        },
      );
}

String? _imageDimension(web.HTMLElement dom, String property) {
  final style = dom.style.getPropertyValue(property).trim();
  if (style.isNotEmpty) return style;
  return dom.getAttribute(property);
}

String? _imageStyle(web.HTMLElement dom, String property) {
  final value = dom.style.getPropertyValue(property).trim();
  return value.isEmpty ? null : value;
}

String _cssImageDimension(dynamic value) {
  final text = '$value'.trim();
  return RegExp(r'[a-z%]$', caseSensitive: false).hasMatch(text)
      ? text
      : '${text}px';
}
