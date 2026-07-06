part of '../html_renderer.dart';

Map<String, IDomStyle> _processStyles(HtmlRenderer self, List<IDomStyle> styles) {
  final stylesMap = <String, IDomStyle>{};
  for (final style in styles) {
    if (style.id != null) {
      stylesMap[style.id!] = style;
    }
  }

  for (final style in styles.where((x) => x.basedOn != null)) {
    final baseStyle = stylesMap[style.basedOn!];

    if (baseStyle != null) {
      style.paragraphProps = _mergeParagraphProperties(style.paragraphProps, baseStyle.paragraphProps);
      style.runProps = _mergeRunProperties(style.runProps, baseStyle.runProps);

      for (final baseValues in baseStyle.styles) {
        final styleValues = style.styles.cast<IDomSubStyle?>().firstWhere(
            (x) => x?.target == baseValues.target,
            orElse: () => null);

        if (styleValues != null) {
          _copyStyleProperties(self, baseValues.values, styleValues.values);
        } else {
          style.styles.add(IDomSubStyle()
            ..target = baseValues.target
            ..mod = baseValues.mod
            ..values = Map.from(baseValues.values));
        }
      }
    } else if (self.options.debug) {
      print("Can't find base style ${style.basedOn}");
    }
  }

  for (final style in styles) {
    style.cssName = _processStyleName(self, style.id);
  }

  return stylesMap;
}

String _processStyleName(HtmlRenderer self, String? className) {
  return className != null && className.isNotEmpty
      ? '${self.className}_${escapeClassName(className)}'
      : self.className;
}

Map<String, String> _copyStyleProperties(
    HtmlRenderer self, Map<String, String> input, Map<String, String> output,
    [List<String>? attrs]) {
  attrs ??= input.keys.toList();

  for (final key in attrs) {
    if (input.containsKey(key) && !output.containsKey(key)) {
      output[key] = input[key]!;
    }
  }

  return output;
}

List<web.Node> _renderDefaultStyle(HtmlRenderer self) {
  final c = self.className;
  final styleText = '''
.$c-wrapper { background: gray; padding: 30px; padding-bottom: 0px; display: flex; flex-flow: column; align-items: center; } 
.$c-wrapper > section.docx { background: white; box-shadow: 0 0 10px rgba(0, 0, 0, 0.5); margin-bottom: 30px; }
.$c { color: black; font-family: sans-serif; }
section.$c { box-sizing: border-box; display: flex; flex-flow: column nowrap; position: relative; overflow: hidden; }
section.$c > article { margin-bottom: auto; z-index: 1; }
.$c table { border-collapse: collapse; box-sizing: border-box; }
.$c td, .$c th { box-sizing: border-box; }
.$c p { margin: 0; padding: 0; }
.$c span { white-space: pre-wrap; word-wrap: break-word; }
.$c a { color: inherit; text-decoration: inherit; }
''';

  return [
    self.hFunc({'tagName': 'style', 'children': [styleText]}) as web.Node
  ];
}

List<web.Node> _renderTheme(HtmlRenderer self, ThemePart themePart) {
  final variables = <String, String>{};
  final fontScheme = themePart.theme?.fontScheme;

  if (fontScheme != null) {
    if (fontScheme.majorFont != null) {
      variables['--docx-majorHAnsi-font'] = fontScheme.majorFont!.latinTypeface ?? '';
    }
    if (fontScheme.minorFont != null) {
      variables['--docx-minorHAnsi-font'] = fontScheme.minorFont!.latinTypeface ?? '';
    }
  }

  final colorScheme = themePart.theme?.colorScheme;
  if (colorScheme != null) {
    for (final entry in colorScheme.colors.entries) {
      variables['--docx-${entry.key}-color'] = '#${entry.value}';
    }
  }

  final cssText = _styleToString('.${self.className}', variables);
  return [
    self.hFunc({'tagName': 'style', 'children': [cssText]}) as web.Node
  ];
}

List<web.Node> _renderStyles(HtmlRenderer self, List<IDomStyle> styles) {
  var styleText = '';
  final stylesMap = self.styleMap!;
  final defStyle = stylesMap['default'];

  for (final style in styles) {
    var subStyles = style.styles;

    if (style.linked != null) {
      var linkedStyle = style.linked != null ? stylesMap[style.linked!] : null;

      if (linkedStyle != null) {
        subStyles = subStyles.toList()..addAll(linkedStyle.styles);
      } else if (self.options.debug) {
        print("Can't find linked style ${style.linked}");
      }
    }

    for (final subStyle in subStyles) {
      if (subStyle.target == null || subStyle.target!.isEmpty) continue;
      var selector = '';

      if (style.target == subStyle.target) {
        selector = '${style.cssName}';
      } else if (style.target != null) {
        selector = '${style.cssName} ${subStyle.target}';
      } else {
        selector = '.${self.className} ${subStyle.target}.${style.cssName}';
      }

      if (defStyle != null && style == defStyle) {
        selector = '.${self.className} ${subStyle.target}';
      }

      if (subStyle.mod != null) {
        selector += subStyle.mod!;
      }

      styleText += _styleToString(selector, subStyle.values) + '\n';
    }
  }

  return [
    self.hFunc({'tagName': 'style', 'children': [styleText]}) as web.Node
  ];
}

String _styleToString(String selectors, Map<String, String> values) {
  var result = '$selectors {\n';
  for (final key in values.keys) {
    result += '  $key: ${values[key]};\n';
  }
  result += '}\n';
  return result;
}

void _processNumberings(HtmlRenderer self, List<IDomNumbering> numberings) {
  for (final num in numberings.where((n) => n.pStyleName != null)) {
    final style = self.styleMap != null ? self.styleMap![num.pStyleName!] : null;

    if (style?.paragraphProps?.numbering != null) {
      style!.paragraphProps!.numbering!.level = num.level;
    }
  }
}

Future<List<web.Node>> _renderNumbering(HtmlRenderer self, List<IDomNumbering> numberings) async {
  var styleText = '';
  for (final num in numberings) {
    final selector = '.${self.className}-num-${num.id}-${num.level}';
    final listStyleType = 'none'; // Basic mapping, full mapping could be complex

    styleText += _styleToString(selector, {
      'display': 'list-item',
      'list-style-position': 'inside',
      'list-style-type': listStyleType,
    });
  }

  return [
    self.hFunc({'tagName': 'style', 'children': [styleText]}) as web.Node
  ];
}

Future<List<web.Node>> _renderFontTable(HtmlRenderer self, FontTablePart fontsPart) async {
  final result = <web.Node>[];

  for (final f in fontsPart.fonts) {
    for (final ref in f.embedFontRefs) {
      try {
        final fontData = await self.document.loadFont(ref.id!, ref.key!);
        if (fontData == null) continue;

        final cssValues = {
          'font-family': encloseFontFamily(f.name ?? ''),
          'src': 'url($fontData)'
        };

        if (ref.type == 'bold' || ref.type == 'boldItalic') {
          cssValues['font-weight'] = 'bold';
        }

        if (ref.type == 'italic' || ref.type == 'boldItalic') {
          cssValues['font-style'] = 'italic';
        }

        result.add(self.hFunc({'tagName': 'style', 'children': [_styleToString('@font-face', cssValues)]}) as web.Node);
      } catch (e) {
        if (self.options.debug) print("Can't load font with id ${ref.id} and key ${ref.key}");
      }
    }
  }

  return result;
}

ParagraphProperties? _mergeParagraphProperties(ParagraphProperties? target, ParagraphProperties? source) {
  if (source == null) return target;
  target ??= ParagraphProperties();

  target.sectionProps ??= source.sectionProps;
  target.tabs ??= source.tabs;
  target.numbering ??= source.numbering;
  target.border ??= source.border;
  target.textAlignment ??= source.textAlignment;
  target.lineSpacing ??= source.lineSpacing;
  target.keepLines ??= source.keepLines;
  target.keepNext ??= source.keepNext;
  target.pageBreakBefore ??= source.pageBreakBefore;
  target.outlineLevel ??= source.outlineLevel;
  target.styleName ??= source.styleName;
  target.runProps = _mergeRunProperties(target.runProps, source.runProps);

  target.color ??= source.color;
  target.fontSize ??= source.fontSize;

  return target;
}

RunProperties? _mergeRunProperties(RunProperties? target, RunProperties? source) {
  if (source == null) return target;
  target ??= RunProperties();

  target.color ??= source.color;
  target.fontSize ??= source.fontSize;

  return target;
}

