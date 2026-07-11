@TestOn('browser')

import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:test/test.dart';
import 'package:docx_rendering/docx_rendering.dart';

void main() {
  group('extended-props', () {
    test('loads extended props', () async {
      final response = await web.window.fetch('extended-props-test/document.docx'.toJS).toDart;
      if (!response.ok) {
        throw Exception('Fetch failed: ${response.status} ${response.statusText}');
      }
      final arrayBuffer = await response.arrayBuffer().toDart;
      final bytes = arrayBuffer.toDart.asUint8List();

      final div = web.document.createElement('div') as web.HTMLElement;
      web.document.body!.appendChild(div);

      final doc = await renderAsync(bytes, div, null, null);

      expect(doc.extendedPropsPart, isNotNull);
      expect(doc.extendedPropsPart!.props, isNotNull);
      expect(doc.extendedPropsPart!.props!.appVersion, equals('16.0000'));
      expect(doc.extendedPropsPart!.props!.application, equals('Microsoft Office Word'));
      expect(doc.extendedPropsPart!.props!.characters, equals(393));
      expect(doc.extendedPropsPart!.props!.company, equals(''));
      expect(doc.extendedPropsPart!.props!.lines, equals(3));
      expect(doc.extendedPropsPart!.props!.pages, equals(3));
      expect(doc.extendedPropsPart!.props!.paragraphs, equals(1));
      expect(doc.extendedPropsPart!.props!.template, equals('Normal.dotm'));
      expect(doc.extendedPropsPart!.props!.words, equals(68));

      div.remove();
    });
  });

  group('Render document', () {
    final tests = [
      'text',
      'underlines',
      'text-break',
      'table',
      'page-layout',
      'revision',
      'numbering',
      'line-spacing',
      'header-footer',
      'footnote',
      'equation'
    ];

    for (final path in tests) {
      test('from $path should be correct', () async {
        final docResponse = await web.window.fetch('render-test/$path/document.docx'.toJS).toDart;
        if (!docResponse.ok) {
          throw Exception('Doc fetch failed: ${docResponse.status} ${docResponse.statusText}');
        }
        final arrayBuffer = await docResponse.arrayBuffer().toDart;
        final bytes = arrayBuffer.toDart.asUint8List();

        final resultResponse = await web.window.fetch('render-test/$path/result.html'.toJS).toDart;
        if (!resultResponse.ok) {
          throw Exception('Result fetch failed: ${resultResponse.status} ${resultResponse.statusText}');
        }
        final resultTextJS = await resultResponse.text().toDart;
        final resultText = resultTextJS.toDart;

        final div = web.document.createElement('div') as web.HTMLElement;
        web.document.body!.appendChild(div);

        await renderAsync(bytes, div, null, null);

        final actual = formatHTML((div.innerHTML as JSString).toDart);
        final expected = formatHTML(resultText);

        if (actual != expected) {
          print('--- ACTUAL ($path) ---');
          print(actual);
          print('--- EXPECTED ($path) ---');
          print(expected);
        }

        expect(actual, equals(expected));

        div.remove();
      });
    }
  });
}

String formatHTML(String text) {
  return text.replaceAll(RegExp(r'\t+|\s+'), ' ').replaceAll(RegExp(r'><'), '>\n<').trim();
}
