import 'dart:convert';

import 'package:web/web.dart' as web;

import '../../prosemirror/model/index.dart';

/// Block attributes shared by paragraphs and headings.
///
/// The DOCX importer stores Word paragraph geometry here instead of baking it
/// into transient DOM styles. Keeping the values in the ProseMirror document
/// makes native DOM reconciliation, DOCX/PDF export and pagination observe the
/// same layout data.
Map<String, AttributeSpec> blockStyleAttributeSpecs() => {
      'textAlign': nullableBlockAttribute(),
      'styleName': nullableBlockAttribute(),
      'marginTop': nullableBlockAttribute(),
      'marginRight': nullableBlockAttribute(),
      'marginBottom': nullableBlockAttribute(),
      'marginLeft': nullableBlockAttribute(),
      'textIndent': nullableBlockAttribute(),
      'tabStops': nullableBlockAttribute(),
      'lineHeight': nullableBlockAttribute(),
      'fontFamily': nullableBlockAttribute(),
      'fontSize': nullableBlockAttribute(),
      'keepLines': nullableBlockAttribute(),
      'keepNext': nullableBlockAttribute(),
      'pageBreakBefore': nullableBlockAttribute(),
      'numberingId': nullableBlockAttribute(),
      'numberingLevel': nullableBlockAttribute(),
      'numberingFormat': nullableBlockAttribute(),
      'numberingText': nullableBlockAttribute(),
    };

AttributeSpec nullableBlockAttribute() =>
    AttributeSpec(defaultValue: null, hasDefault: true);

Map<String, dynamic> blockStyleAttrsFromDom(web.HTMLElement dom) {
  final style = dom.style;
  String? value(String cssName) {
    final result = style.getPropertyValue(cssName).trim();
    return result.isEmpty ? null : result;
  }

  bool? boolData(String name) {
    final raw = dom.getAttribute(name);
    if (raw == null) return null;
    return raw == 'true';
  }

  int? intData(String name) {
    final raw = dom.getAttribute(name);
    return raw == null ? null : int.tryParse(raw);
  }

  dynamic jsonData(String name) {
    final raw = dom.getAttribute(name);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  return {
    'textAlign': value('text-align'),
    'styleName': dom.getAttribute('data-docx-style'),
    'marginTop': value('margin-top'),
    'marginRight': value('margin-right'),
    'marginBottom': value('margin-bottom'),
    'marginLeft': value('margin-left'),
    'textIndent': value('text-indent'),
    'tabStops': jsonData('data-docx-tabs'),
    'lineHeight': value('line-height'),
    'fontFamily': value('font-family'),
    'fontSize': value('font-size'),
    'keepLines': boolData('data-docx-keep-lines'),
    'keepNext': boolData('data-docx-keep-next'),
    'pageBreakBefore': boolData('data-docx-page-break-before'),
    'numberingId': dom.getAttribute('data-docx-numbering-id'),
    'numberingLevel': intData('data-docx-numbering-level'),
    'numberingFormat': dom.getAttribute('data-docx-numbering-format'),
    'numberingText': dom.getAttribute('data-docx-numbering-text'),
  };
}

Map<String, dynamic> blockStyleDomAttrs(PMNode node) {
  final style = StringBuffer();
  void css(String name, String attr) {
    final value = node.attrs[attr];
    if (value != null && '$value'.isNotEmpty) {
      style.write('$name: $value;');
    }
  }

  css('text-align', 'textAlign');
  css('margin-top', 'marginTop');
  css('margin-right', 'marginRight');
  css('margin-bottom', 'marginBottom');
  css('margin-left', 'marginLeft');
  css('text-indent', 'textIndent');
  css('line-height', 'lineHeight');
  css('font-family', 'fontFamily');
  css('font-size', 'fontSize');
  if (node.attrs['keepLines'] == true) style.write('break-inside: avoid;');
  if (node.attrs['keepNext'] == true) style.write('break-after: avoid;');
  if (node.attrs['pageBreakBefore'] == true) {
    style.write('break-before: page;');
  }

  final attrs = <String, dynamic>{};
  if (style.isNotEmpty) attrs['style'] = style.toString();
  void data(String name, String attr) {
    final value = node.attrs[attr];
    if (value != null) attrs[name] = '$value';
  }

  data('data-docx-style', 'styleName');
  data('data-docx-keep-lines', 'keepLines');
  data('data-docx-keep-next', 'keepNext');
  data('data-docx-page-break-before', 'pageBreakBefore');
  data('data-docx-numbering-id', 'numberingId');
  data('data-docx-numbering-level', 'numberingLevel');
  data('data-docx-numbering-format', 'numberingFormat');
  data('data-docx-numbering-text', 'numberingText');
  final tabStops = node.attrs['tabStops'];
  if (tabStops != null) attrs['data-docx-tabs'] = jsonEncode(tabStops);
  return attrs;
}
