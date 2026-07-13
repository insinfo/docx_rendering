@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:docx_rendering/tiptap.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('pagina texto longo por linha e cresce/reduz sem alterar o documento',
      () async {
    web.document.body!.innerHTML = '''
      <style>
        body { margin: 0; }
        .ProseMirror { font: 16px/24px Arial; }
        .ProseMirror p { margin: 0; }
        .tiptap-pagination, .tiptap-page-break { height: 0; margin: 0; }
        .tiptap-page-header, .tiptap-page-footer,
        .tiptap-pagination-gap { box-sizing: border-box; width: 100%; }
      </style>
      <div id="mount"></div>
    '''
        .toJS;

    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        PaginationExtension(
          options: PaginationOptions(
            pageWidth: 500,
            pageHeight: 300,
            marginTop: 20,
            marginRight: 20,
            marginBottom: 20,
            marginLeft: 20,
            pageGap: 16,
            debounce: Duration(milliseconds: 5),
          ),
        ),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    final schema = editor.state.schema;
    final longText = List.filled(
      180,
      'Texto comprido que deve continuar automaticamente na página seguinte.',
    ).join(' ');
    final longDoc = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text(longText)]),
    ]);
    final expand = editor.state.tr;
    expand.replaceWith(
      0,
      editor.state.doc.content.size,
      longDoc.content,
    );
    editor.dispatchTransaction(expand);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    final dom = editor.view!.dom;
    final pageCount = int.parse(dom.getAttribute('data-page-count')!);
    final pagination =
        dom.querySelector('[data-tiptap-pagination]') as web.HTMLElement;
    expect(pageCount, greaterThan(2));
    expect(
      pagination.querySelectorAll('.tiptap-page-break').length,
      pageCount + 1,
      reason: 'a cadeia inclui uma sentinela depois da última página',
    );
    expect(
      pagination.querySelectorAll('.tiptap-page-header').length,
      pageCount,
    );
    expect(
      pagination.querySelectorAll('.tiptap-page-footer').length,
      pageCount,
    );

    // A única ocorrência de paragraph atravessa páginas. Range#getClientRects
    // expõe os line boxes e deve conter um salto maior que uma linha normal no
    // ponto em que footer, gap e próximo header bloqueiam o fluxo.
    final paragraph = dom.querySelector('p')!;
    final range = web.document.createRange()..selectNodeContents(paragraph);
    final rects = range.getClientRects();
    var largestLineJump = 0.0;
    double? previousTop;
    for (var index = 0; index < rects.length; index++) {
      final rect = rects.item(index);
      if (rect == null) continue;
      if (previousTop != null) {
        final jump = rect.top - previousTop;
        if (jump > largestLineJump) largestLineJump = jump;
      }
      previousTop = rect.top;
    }
    expect(largestLineJump, greaterThan(40));
    expect(editor.state.doc.childCount, 1);
    expect(editor.state.doc.textContent, longText);
    expect(editor.getHTML(), isNot(contains('tiptap-page-break')));
    expect(editor.getHTML(), isNot(contains('data-tiptap-pagination')));

    final shortDoc = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('Documento curto.')]),
    ]);
    final shrink = editor.state.tr;
    shrink.replaceWith(
      0,
      editor.state.doc.content.size,
      shortDoc.content,
    );
    editor.dispatchTransaction(shrink);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(dom.getAttribute('data-page-count'), '1');
    expect(
      dom.querySelectorAll('.tiptap-page-break').length,
      2,
      reason: 'uma página visível mais a sentinela final',
    );
    expect(double.parse(dom.style.minHeight.replaceAll('px', '')),
        closeTo(300, 1));
  });

  test('usa A4 a 96 dpi e área útil de aproximadamente 642 px', () async {
    web.document.body!.innerHTML = '<div id="a4-mount"></div>'.toJS;
    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('a4-mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        PaginationExtension(),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    await Future<void>.delayed(const Duration(milliseconds: 80));
    final dom = editor.view!.dom;
    final style = web.window.getComputedStyle(dom);
    final contentWidth = dom.getBoundingClientRect().width -
        double.parse(style.paddingLeft.replaceAll('px', '')) -
        double.parse(style.paddingRight.replaceAll('px', ''));

    expect(dom.getBoundingClientRect().width, closeTo(793.7, .2));
    expect(contentWidth, closeTo(642.5, .3));
    expect(dom.getBoundingClientRect().height, closeTo(1122.5, 1));
  });

  test('aplica geometria e repete headers e footers importados do DOCX',
      () async {
    web.document.body!.innerHTML = '''
      <style>
        body { margin: 0; }
        .ProseMirror { font: 16px/24px Arial; }
        .ProseMirror p { margin: 0; }
      </style>
      <div id="docx-mount"></div>
    '''
        .toJS;
    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('docx-mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        PaginationExtension(
          options: PaginationOptions(
            pageGap: 20,
            debounce: Duration(milliseconds: 5),
          ),
        ),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    final schema = editor.state.schema;
    Map<String, dynamic> paragraphJson(String text) => {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': text},
          ],
        };
    final attrs = <String, dynamic>{
      'pageWidth': '450pt', // 600 CSS px
      'pageHeight': '300pt', // 400 CSS px
      'pageMarginTop': '30pt',
      'pageMarginRight': '30pt',
      'pageMarginBottom': '30pt',
      'pageMarginLeft': '30pt',
      'pageMarginHeader': '7.5pt',
      'pageMarginFooter': '7.5pt',
      'titlePage': true,
      'evenAndOddHeaders': true,
      'headers': {
        'first': [paragraphJson('CABEÇALHO DA PRIMEIRA')],
        'default': [paragraphJson('CABEÇALHO PADRÃO')],
        'even': [paragraphJson('CABEÇALHO PAR')],
      },
      'footers': {
        'default': [
          paragraphJson(
              'RODAPÉ REPETIDO Página {{DOCX_PAGE}} | {{DOCX_NUMPAGES}}')
        ],
      },
    };
    final body = List.filled(
      150,
      'Conteúdo do documento que continua nas páginas seguintes.',
    ).join(' ');
    final importedDoc = schema.node('doc', attrs, [
      schema.node('paragraph', null, [schema.text(body)]),
    ]);
    final importedState = EditorState.create(EditorStateConfig(
      schema: schema,
      doc: importedDoc,
      plugins: editor.state.plugins,
    ));
    editor.state = importedState;
    editor.view!.updateState(importedState);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    final dom = editor.view!.dom;
    final pageCount = int.parse(dom.getAttribute('data-page-count')!);
    expect(pageCount, greaterThan(2));
    expect(dom.getBoundingClientRect().width, closeTo(600, .2));
    expect(dom.style.paddingLeft, '40px');
    expect(dom.style.paddingRight, '40px');
    expect(
      dom
          .querySelector('.tiptap-page-header[data-page-number="1"]')
          ?.textContent,
      contains('CABEÇALHO DA PRIMEIRA'),
    );
    expect(
      dom
          .querySelector('.tiptap-page-header[data-page-number="2"]')
          ?.textContent,
      contains('CABEÇALHO PAR'),
    );
    expect(
      dom
          .querySelector('.tiptap-page-header[data-page-number="3"]')
          ?.textContent,
      contains('CABEÇALHO PADRÃO'),
    );
    expect(
      dom.querySelectorAll('.tiptap-page-footer').length,
      pageCount,
    );
    final footers = dom.querySelectorAll('.tiptap-page-footer');
    for (var index = 0; index < footers.length; index++) {
      final footer = footers.item(index);
      if (footer == null) continue;
      expect(footer.textContent, contains('RODAPÉ REPETIDO'));
    }
    expect(
      dom
          .querySelector('.tiptap-page-footer[data-page-number="1"]')
          ?.textContent,
      contains('Página 1 | $pageCount'),
    );
    expect(
      dom
          .querySelector('.tiptap-page-footer[data-page-number="$pageCount"]')
          ?.textContent,
      contains('Página $pageCount | $pageCount'),
    );
    expect(editor.state.doc.attrs['headers'], same(attrs['headers']));
    expect(editor.getHTML(), isNot(contains('CABEÇALHO DA PRIMEIRA')));
    expect(editor.getHTML(), isNot(contains('RODAPÉ REPETIDO')));
  });

  test('usa contagem Word apenas para linha de tabela maior que a página',
      () async {
    web.document.body!.innerHTML = '''
      <style>
        body { margin: 0; }
        .ProseMirror { font: 16px/24px Arial; }
        .ProseMirror table, .ProseMirror tbody { display: contents; }
        .ProseMirror tr { display: grid; grid-template-columns: 1fr; }
      </style>
      <div id="source-count-mount"></div>
    '''
        .toJS;
    final editor = TiptapEditor(EditorOptions(
      element:
          web.document.getElementById('source-count-mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        TableExtension(),
        TableRowExtension(),
        TableCellExtension(),
        TableHeaderExtension(),
        PaginationExtension(
          options: PaginationOptions(
            pageWidth: 500,
            pageHeight: 300,
            marginTop: 20,
            marginRight: 20,
            marginBottom: 20,
            marginLeft: 20,
            pageGap: 16,
            debounce: Duration(milliseconds: 5),
          ),
        ),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });

    final schema = editor.state.schema;
    final shortWithStaleMetadata = schema.node('doc', {
      'sourcePageCount': 5,
    }, [
      schema.node('paragraph', null, [schema.text('Curto.')]),
    ]);
    editor.setDocument(shortWithStaleMetadata);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(
      editor.view!.dom.getAttribute('data-page-count'),
      '1',
      reason: 'metadata stale não deve limitar documento que flui normalmente',
    );

    final oversizedTable = schema.node('table', null, [
      schema.node('tableRow', null, [
        schema.node('tableCell', null, [
          schema.node('paragraph', null, [schema.text('Linha muito alta')]),
        ]),
      ]),
    ]);
    final imported = schema.node('doc', {
      'sourcePageCount': 6,
    }, [
      oversizedTable
    ]);
    editor.setDocument(imported);
    final row = editor.view!.dom.querySelector('tr') as web.HTMLElement;
    row.style.height = '420px';
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(editor.view!.dom.getAttribute('data-page-count'), '6');
    expect(
      editor.view!.dom.querySelectorAll('.tiptap-page-break').length,
      7,
    );

    final replaceBody = editor.state.tr;
    replaceBody.replaceWith(0, editor.state.doc.content.size,
        schema.node('paragraph', null, [schema.text('Editado.')]));
    editor.dispatchTransaction(replaceBody);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      editor.view!.dom.getAttribute('data-page-count'),
      '1',
      reason: 'uma edição de body libera o bootstrap do DOCX',
    );
  });

  test('zoom visual não altera a contagem lógica de páginas', () async {
    web.document.body!.innerHTML = '''
      <style>
        body { margin: 0; }
        .ProseMirror { font: 16px/24px Arial; }
        .ProseMirror p { margin: 0; }
      </style>
      <div id="page-scale" style="zoom:1"><div id="zoom-mount"></div></div>
    '''
        .toJS;
    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('zoom-mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        PaginationExtension(
          options: PaginationOptions(
            pageWidth: 500,
            pageHeight: 300,
            marginTop: 20,
            marginRight: 20,
            marginBottom: 20,
            marginLeft: 20,
            pageGap: 16,
            debounce: Duration(milliseconds: 5),
          ),
        ),
      ],
    ));
    addTearDown(() {
      editor.destroy();
      web.document.body!.innerHTML = ''.toJS;
    });
    final schema = editor.state.schema;
    editor.setDocument(schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema
            .text(List.filled(120, 'Conteúdo paginado invariável.').join(' ')),
      ]),
    ]));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final dom = editor.view!.dom;
    final before = dom.getAttribute('data-page-count');
    expect(int.parse(before!), greaterThan(2));

    (web.document.getElementById('page-scale') as web.HTMLElement).style.zoom =
        '.6';
    dom.setAttribute('data-test-zoom', '60');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(dom.getAttribute('data-page-count'), before);

    // Reproduce the shell race: restore the zoom and import a document before
    // the paginator's debounced measurement observes the zoom transition.
    (web.document.getElementById('page-scale') as web.HTMLElement).style.zoom =
        '.6';
    dom.setAttribute('data-test-zoom', '60-again');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(dom.getAttribute('data-page-count'), before);

    (web.document.getElementById('page-scale') as web.HTMLElement).style.zoom =
        '1';
    dom.setAttribute('data-test-zoom', '100-before-import');
    editor.setDocument(schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('Novo documento curto.')]),
    ]));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      dom.getAttribute('data-page-count'),
      '1',
      reason: 'mudança de body deve liberar o lock puramente visual',
    );
  });
}
