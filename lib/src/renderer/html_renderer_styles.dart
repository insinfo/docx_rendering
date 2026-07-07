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

  var wrapperStyle = '''
.$c-wrapper { background: gray; padding: 30px; padding-bottom: 0px; display: flex; flex-flow: column; align-items: center; } 
.$c-wrapper>section.$c { background: white; box-shadow: 0 0 10px rgba(0, 0, 0, 0.5); margin-bottom: 30px; }''';

  if (self.options.hideWrapperOnPrint) {
    wrapperStyle = '@media not print { $wrapperStyle }';
  }

  var styleText = '''$wrapperStyle
.$c { color: black; hyphens: auto; text-underline-position: from-font; }
section.$c { box-sizing: border-box; display: flex; flex-flow: column nowrap; position: relative; overflow: hidden; }
section.$c > article { margin-bottom: auto; z-index: 1; }
section.$c > footer { z-index: 1; }
.$c table { border-collapse: collapse; }
.$c table td, .$c table th { vertical-align: top; }
.$c p { margin: 0pt; min-height: 1em; }
.$c span { white-space: pre-wrap; overflow-wrap: break-word; }
.$c a { color: inherit; text-decoration: inherit; }
.$c svg { fill: transparent; }
''';

  if (self.options.renderComments) {
    styleText += '''
.$c-comment-ref { cursor: default; }
.$c-comment-popover { display: none; z-index: 1000; padding: 0.5rem; background: white; position: absolute; box-shadow: 0 0 0.25rem rgba(0, 0, 0, 0.25); width: 30ch; }
.$c-comment-ref:hover~.$c-comment-popover { display: block; }
.$c-comment-author,.$c-comment-date { font-size: 0.875rem; color: #888; }
''';
  }

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

  final defaultStyles = <String, IDomStyle>{};
  for (final s in styles) {
    if (s.isDefault == true && s.target != null) {
      defaultStyles[s.target!] = s;
    }
  }

  for (final style in styles) {
    var subStyles = style.styles;

    if (style.linked != null) {
      var linkedStyle = stylesMap[style.linked!];

      if (linkedStyle != null) {
        subStyles = subStyles.toList()..addAll(linkedStyle.styles);
      } else if (self.options.debug) {
        print("Can't find linked style ${style.linked}");
      }
    }

    for (final subStyle in subStyles) {
      var selector = '${style.target ?? ''}.${style.cssName}';

      if (style.target != subStyle.target && subStyle.target != null) {
        selector += ' ${subStyle.target}';
      }

      if (style.target != null && defaultStyles[style.target!] == style) {
        selector = '.${self.className} ${style.target}, ' + selector;
      }

      styleText += _styleToString(selector, subStyle.values) + '\n';
    }
  }

  return [
    self.hFunc({'tagName': 'style', 'children': [styleText]}) as web.Node
  ];
}

String _styleToString(String selectors, Map<String, String> values, [String? cssText]) {
  var result = '$selectors {\n';
  for (final key in values.keys) {
    if (key.startsWith('\$')) continue;
    result += '  $key: ${values[key]};\n';
  }
  if (cssText != null) result += cssText;
  result += '}\n';
  return result;
}

void _processNumberings(HtmlRenderer self, List<IDomNumbering> numberings) {
  for (final num in numberings.where((n) => n.pStyleName != null)) {
    final style = self.findStyle(num.pStyleName);

    if (style?.paragraphProps?.numbering != null) {
      style!.paragraphProps!.numbering!.level = num.level;
    }
  }
}

Future<List<web.Node>> _renderNumbering(HtmlRenderer self, List<IDomNumbering> numberings) async {
  var styleText = '';
  final resetCounters = <String>[];

  for (final num in numberings) {
    final selector = 'p.${self.className}-num-${num.id}-${num.level}';
    var listStyleType = 'none';

    if (num.bullet != null) {
      final variable = '--${self.className}-${num.bullet!.src}'.toLowerCase();

      styleText += _styleToString('$selector:before', {
        'content': "' '",
        'display': 'inline-block',
        'background': 'var($variable)',
      }, num.bullet!.style);

      try {
        final imgData = await self.document.loadNumberingImage(num.bullet!.src);
        if (imgData != null) {
          styleText += '${self.rootSelector} { $variable: url($imgData) }\n';
        }
      } catch (e) {
        if (self.options.debug) print("Can't load numbering image with src ${num.bullet!.src}");
      }
    } else if (num.levelText != null) {
      final counter = '${self.className}-num-${num.id}-${num.level}';
      final counterReset = '$counter ${num.start - 1}';

      if (num.level > 0) {
        styleText += _styleToString('p.${self.className}-num-${num.id}-${num.level - 1}', {
          'counter-set': counterReset,
        });
      }
      resetCounters.add(counterReset);

      final rStyleWithContent = Map<String, String>.from(num.rStyle);
      rStyleWithContent['content'] = _levelTextToContent(self, num.levelText!, num.suff, num.id, _numFormatToCssValue(num.format));
      rStyleWithContent['counter-increment'] = counter;

      styleText += _styleToString('$selector:before', rStyleWithContent);
    } else {
      listStyleType = _numFormatToCssValue(num.format);
    }

    final pStyleWithList = Map<String, String>.from(num.pStyle);
    pStyleWithList['display'] = 'list-item';
    pStyleWithList['list-style-position'] = 'inside';
    pStyleWithList['list-style-type'] = listStyleType;

    styleText += _styleToString(selector, pStyleWithList);
  }

  if (resetCounters.isNotEmpty) {
    styleText += _styleToString(self.rootSelector, {
      'counter-reset': resetCounters.join(' '),
    });
  }

  return [
    self.hFunc({'tagName': 'style', 'children': [styleText]}) as web.Node
  ];
}

String _levelTextToContent(HtmlRenderer self, String text, String suff, String id, String numformat) {
  final suffMap = {
    'tab': '\\9',
    'space': '\\a0',
  };

  final result = text.replaceAllMapped(RegExp(r'%\d*'), (s) {
    final lvl = int.parse(s.group(0)!.substring(1)) - 1;
    return '" counter(${self.className}-num-$id-$lvl, $numformat) "';
  });

  return '"$result${suffMap[suff] ?? ''}"';
}

String _numFormatToCssValue(String? format) {
  const mapping = {
    'none': 'none',
    'bullet': 'disc',
    'decimal': 'decimal',
    'lowerLetter': 'lower-alpha',
    'upperLetter': 'upper-alpha',
    'lowerRoman': 'lower-roman',
    'upperRoman': 'upper-roman',
    'decimalZero': 'decimal-leading-zero',
    'aiueo': 'katakana',
    'aiueoFullWidth': 'katakana',
    'chineseCounting': 'simp-chinese-informal',
    'chineseCountingThousand': 'simp-chinese-informal',
    'chineseLegalSimplified': 'simp-chinese-formal',
    'chosung': 'hangul-consonant',
    'ideographDigital': 'cjk-ideographic',
    'ideographTraditional': 'cjk-heavenly-stem',
    'ideographLegalTraditional': 'trad-chinese-formal',
    'ideographZodiac': 'cjk-earthly-branch',
    'iroha': 'katakana-iroha',
    'irohaFullWidth': 'katakana-iroha',
    'japaneseCounting': 'japanese-informal',
    'japaneseDigitalTenThousand': 'cjk-decimal',
    'japaneseLegal': 'japanese-formal',
    'thaiNumbers': 'thai',
    'koreanCounting': 'korean-hangul-formal',
    'koreanDigital': 'korean-hangul-formal',
    'koreanDigital2': 'korean-hanja-informal',
    'hebrew1': 'hebrew',
    'hebrew2': 'hebrew',
    'hindiNumbers': 'devanagari',
    'ganada': 'hangul',
    'taiwaneseCounting': 'cjk-ideographic',
    'taiwaneseCountingThousand': 'cjk-ideographic',
    'taiwaneseDigital': 'cjk-decimal',
  };

  return mapping[format] ?? format ?? 'decimal';
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
