@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:docx_rendering/tiptap.dart';
import 'package:docx_rendering/src/prosemirror/state/index.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('edita header, seleciona objetos e persiste JSON do payload', () async {
    web.document.body!.innerHTML = '''
      <style>
        body { margin: 0; }
        .tiptap-ui .document-viewport { position: relative; width: 760px; height: 600px; overflow: auto; padding: 20px; }
        .tiptap-ui .page-scale { width: fit-content; margin: 0 auto; }
        .tiptap-ui .ProseMirror { font: 14px/20px Arial; }
        .tiptap-ui .ProseMirror p { margin: 0; }
        .tiptap-ui .tiptap-pagination, .tiptap-ui .tiptap-page-break { height: 0; margin: 0; pointer-events: none; }
        .tiptap-ui .tiptap-page-header, .tiptap-ui .tiptap-page-footer { pointer-events: auto; }
        .tiptap-ui .tiptap-page-region-active { isolation:isolate; }
        .tiptap-ui .tiptap-page-editor-overlay { position:absolute;left:0;right:0;bottom:0;border-top:2px dashed #6d5dfc;z-index:2147483646; }
        .tiptap-ui .tiptap-page-object-selection { position:absolute;border:2px solid #6d5dfc;z-index:2147483645;pointer-events:none; }
        .tiptap-ui .tiptap-object-handle { position:absolute;width:8px;height:8px;pointer-events:auto; }
        .tiptap-ui .tiptap-vertical-ruler-track { position:absolute;width:22px;overflow:hidden; }
        .tiptap-ui .tiptap-vertical-ruler { position:absolute;box-sizing:border-box;width:22px;overflow:hidden;transform-origin:top left; }
        .tiptap-ui .tiptap-horizontal-ruler-track { position:relative;height:22px;overflow:hidden; }
        .tiptap-ui .tiptap-horizontal-ruler-center { position:absolute;top:0;width:fit-content; }
        .tiptap-ui .tiptap-horizontal-ruler { position:relative;height:22px;transform-origin:top left; }
        .tiptap-ui .tiptap-ruler-scale, .tiptap-ui .tiptap-ruler-margins, .tiptap-ui .tiptap-ruler-indents, .tiptap-ui .tiptap-ruler-tabs { position:absolute;inset:0; }
        .tiptap-ui .tiptap-ruler-num, .tiptap-ui .tiptap-ruler-tick, .tiptap-ui .tiptap-ruler-indent { position:absolute; }
        .tiptap-ui .tiptap-ruler-indent { pointer-events:auto;touch-action:none; }
        .tiptap-ui .tiptap-ruler-tab { position:absolute;width:10px;height:9px;pointer-events:auto; }
        .tiptap-ui .tiptap-tab-run { display:inline-block;min-width:1px; }
        .tiptap-ui .tiptap-ruler-margin { position:absolute;z-index:4;pointer-events:auto;touch-action:none; }
        .tiptap-ui .tiptap-horizontal-ruler .tiptap-ruler-margin { width:4px;height:22px;transform:translateX(-50%); }
        .tiptap-ui .tiptap-vertical-ruler .tiptap-ruler-margin { width:22px;height:4px;transform:translateY(-50%); }
      </style>
      <div class="tiptap-ui">
        <section class="document-viewport" id="viewport">
          <div class="page-scale"><div id="mount"></div></div>
        </section>
      </div>
    '''
        .toJS;

    final editor = TiptapEditor(EditorOptions(
      element: web.document.getElementById('mount') as web.HTMLElement,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        ImageExtension(),
        TableExtension(),
        TableRowExtension(),
        TableCellExtension(),
        TableHeaderExtension(),
        TabRenderingExtension(),
        PaginationExtension(
          options: PaginationOptions(
            pageWidth: 520,
            pageHeight: 500,
            marginTop: 100,
            marginRight: 40,
            marginBottom: 70,
            marginLeft: 40,
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

    final transparentPixel =
        'data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=';
    final headerPayload = [
      {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': 'Cabeçalho original'},
        ],
      },
      {
        'type': 'image',
        'attrs': {
          'src': transparentPixel,
          'width': '40',
          'height': '30',
        },
      },
      {
        'type': 'table',
        'attrs': {
          'position': 'absolute',
          'right': '0px',
          'top': '8px',
          'width': '130px',
          'zIndex': '251659264',
        },
        'content': [
          {
            'type': 'tableRow',
            'content': [
              {
                'type': 'tableCell',
                'content': [
                  {
                    'type': 'paragraph',
                    'content': [
                      {'type': 'text', 'text': 'Caixa editável'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    ];
    final doc = editor.state.schema.node('doc', {
      'headers': {'default': headerPayload},
      'footers': {
        'default': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'Rodapé {{DOCX_PAGE}}'},
            ],
          },
        ],
      },
    }, [
      editor.state.schema.node('paragraph', {
        'tabStops': [
          {'position': '160px', 'type': 'left', 'leader': 'none'},
        ],
      }, [
        editor.state.schema.text('Corpo\tValor do documento.'),
      ]),
      editor.state.schema.node('paragraph', null, [
        editor.state.schema.text('Tab padrão\tsem parada explícita.'),
      ]),
    ]);
    editor.setDocument(doc);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final root = editor.view!.dom;
    final ruler = web.document.querySelector('[data-tiptap-vertical-ruler]')
        as web.HTMLElement;
    final horizontal = web.document
        .querySelector('[data-tiptap-horizontal-ruler]') as web.HTMLElement;
    final viewport = web.document.getElementById('viewport')!;
    final pageScale =
        web.document.querySelector('.page-scale') as web.HTMLElement;
    final verticalTrack = ruler.parentElement as web.HTMLElement;
    expect(verticalTrack.parentElement, same(viewport.parentElement));
    expect(horizontal.parentElement, same(viewport.parentElement));
    expect(
      web.window.getComputedStyle(ruler).getPropertyValue('float'),
      isNot('left'),
      reason: 'a régua não pode participar dos floats usados pela paginação',
    );
    expect(ruler.getBoundingClientRect().height, closeTo(500, 1));
    expect(ruler.querySelectorAll('.tiptap-ruler-num').length, greaterThan(0));
    expect(
      horizontal.querySelectorAll('.tiptap-ruler-indent').length,
      4,
      reason: 'a régua horizontal mostra os quatro marcadores de recuo',
    );
    final renderedTab =
        root.querySelector('.tiptap-tab-run') as web.HTMLElement;
    expect(renderedTab.getBoundingClientRect().width, greaterThan(20));
    expect(root.querySelectorAll('.tiptap-tab-run').length, 2);
    expect(
      (root.querySelectorAll('.tiptap-tab-run').item(1) as web.HTMLElement)
          .getBoundingClientRect()
          .width,
      greaterThan(1),
      reason: 'tabs sem w:tabs usam a parada padrão de 1,25 cm',
    );
    final pageRect = root.getBoundingClientRect();
    final viewportRect = viewport.getBoundingClientRect();
    final rulerRect = ruler.getBoundingClientRect();
    expect(
      rulerRect.left,
      closeTo(viewportRect.left, 1),
      reason: 'a régua fica na borda esquerda da área de trabalho',
    );
    expect(
      rulerRect.top,
      closeTo(pageRect.top, 1),
      reason: 'a escala vertical começa no topo da página ativa',
    );
    pageScale.style.setProperty('zoom', '.75');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      ruler.getBoundingClientRect().height,
      closeTo(375, 1),
      reason: 'a régua acompanha a escala de 75% da folha',
    );
    pageScale.style.removeProperty('zoom');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    editor.setEditable(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(ruler.style.display, 'none');
    expect(horizontal.style.display, 'none');
    editor.setEditable(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(ruler.style.display, isEmpty);
    expect(horizontal.style.display, isEmpty);

    final selectBody = editor.state.tr;
    selectBody.setSelection(TextSelection.create(selectBody.doc, 1));
    editor.view!.dispatch(selectBody);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(horizontal.querySelectorAll('.tiptap-ruler-tab').length, 1);

    _dragTab(horizontal, 220);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    var paragraphAttrs = editor.state.doc.firstChild!.attrs;
    final movedTabs = paragraphAttrs['tabStops'] as List;
    expect(movedTabs.single['position'], isNot('160px'));
    final tabMarker = horizontal.querySelector('.tiptap-ruler-tab')!;
    _doubleClick(tabMarker);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    paragraphAttrs = editor.state.doc.firstChild!.attrs;
    expect((paragraphAttrs['tabStops'] as List).single['leader'], 'dot');
    _addTab(horizontal, 300);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    paragraphAttrs = editor.state.doc.firstChild!.attrs;
    expect((paragraphAttrs['tabStops'] as List).length, 2);

    _dragIndent(horizontal, 'left', 80);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    paragraphAttrs = editor.state.doc.firstChild!.attrs;
    expect(paragraphAttrs['marginLeft'], '40.00px');
    expect(paragraphAttrs['textIndent'], '0.00px');

    _dragIndent(horizontal, 'first', 100);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    paragraphAttrs = editor.state.doc.firstChild!.attrs;
    expect(paragraphAttrs['marginLeft'], '40.00px');
    expect(paragraphAttrs['textIndent'], '20.00px');

    _dragIndent(horizontal, 'hanging', 90);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    paragraphAttrs = editor.state.doc.firstChild!.attrs;
    expect(paragraphAttrs['marginLeft'], '50.00px');
    expect(paragraphAttrs['textIndent'], '10.00px');

    _dragIndent(horizontal, 'right', 450);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    paragraphAttrs = editor.state.doc.firstChild!.attrs;
    expect(paragraphAttrs['marginRight'], '30.00px');

    _dragMargin(horizontal, 'left', 60, vertical: false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(editor.state.doc.attrs['pageMarginLeft'], '60.00px');

    _dragMargin(horizontal, 'right', 440, vertical: false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(editor.state.doc.attrs['pageMarginRight'], '80.00px');

    _dragMargin(ruler, 'top', 70, vertical: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(editor.state.doc.attrs['pageMarginTop'], '70.00px');

    _dragMargin(ruler, 'bottom', 410, vertical: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(editor.state.doc.attrs['pageMarginBottom'], '90.00px');

    var header = root.querySelector(
      '.tiptap-page-header[data-page-number="1"]',
    ) as web.HTMLElement;
    final paragraph = header.querySelector('p')!;
    _doubleClick(paragraph);
    expect(header.getAttribute('data-editing'), 'true');
    expect(header.getAttribute('contenteditable'), 'true');
    expect(
      header.querySelector('.tiptap-page-editor-label')?.textContent,
      'Cabeçalho',
    );
    expect(header.querySelector('.tiptap-page-editor-overlay'), isNotNull);
    expect(
      header
          .querySelector('[data-page-object-action="left"]')
          ?.getAttribute('aria-disabled'),
      'true',
    );

    paragraph.textContent = 'Cabeçalho alterado';
    paragraph.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    final close = header.querySelector(
      '[data-page-object-action="close"]',
    )!;
    _click(close);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      editor.state.doc.attrs['headers'].toString(),
      contains('Cabeçalho alterado'),
    );

    header = root.querySelector(
      '.tiptap-page-header[data-page-number="1"]',
    ) as web.HTMLElement;
    final textBox = header.querySelector('table')!;
    _doubleClick(textBox);
    expect(
      header.querySelectorAll('[data-page-object-handle]').length,
      9,
      reason: 'oito alças de resize e uma alça central para mover',
    );
    expect(header.querySelectorAll('.tiptap-object-handle').length, 8);
    expect(header.querySelector('.tiptap-page-object-toolbar'), isNotNull);
    final overlay = header.querySelector('.tiptap-page-editor-overlay')!;
    expect(
      int.parse(web.window.getComputedStyle(overlay).zIndex),
      greaterThan(int.parse(web.window.getComputedStyle(textBox).zIndex)),
      reason:
          'a toolbar contextual precisa ficar acima do z-index importado da caixa',
    );
    expect(
      header
          .querySelector('[data-page-object-action="left"]')
          ?.getAttribute('aria-disabled'),
      'false',
    );
    final selection = web.document.getSelection();
    expect(selection?.anchorNode, isNotNull);
    expect(
      textBox.contains(selection!.anchorNode),
      isTrue,
      reason: 'duplo clique na caixa deve posicionar o cursor no seu texto',
    );

    final boxParagraph = textBox.querySelector('p')!;
    boxParagraph.textContent = 'Caixa realmente modificada';
    boxParagraph
        .dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    final initialWidth = textBox.getBoundingClientRect().width;
    final southEast = header.querySelector(
      '[data-page-object-handle="se"]',
    )!;
    final handleRect = southEast.getBoundingClientRect();
    southEast.dispatchEvent(web.PointerEvent(
      'pointerdown',
      web.PointerEventInit(
        bubbles: true,
        cancelable: true,
        clientX: handleRect.left.round(),
        clientY: handleRect.top.round(),
      ),
    ));
    web.window.dispatchEvent(web.PointerEvent(
      'pointermove',
      web.PointerEventInit(
        bubbles: true,
        clientX: handleRect.left.round() + 35,
        clientY: handleRect.top.round() + 20,
      ),
    ));
    web.window.dispatchEvent(web.PointerEvent(
      'pointerup',
      web.PointerEventInit(bubbles: true),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      editor.state.doc.attrs['headers'].toString(),
      contains('Caixa realmente modificada'),
    );

    header = root.querySelector(
      '.tiptap-page-header[data-page-number="1"]',
    ) as web.HTMLElement;
    final resizedBox = header.querySelector('table')!;
    expect(resizedBox.getBoundingClientRect().width, greaterThan(initialWidth));
    _doubleClick(resizedBox);

    final beforeMove = resizedBox.getBoundingClientRect();
    final moveHandle = header.querySelector(
      '[data-page-object-handle="move"]',
    )!;
    final moveRect = moveHandle.getBoundingClientRect();
    moveHandle.dispatchEvent(web.PointerEvent(
      'pointerdown',
      web.PointerEventInit(
        bubbles: true,
        cancelable: true,
        clientX: moveRect.left.round(),
        clientY: moveRect.top.round(),
        button: 0,
      ),
    ));
    web.window.dispatchEvent(web.PointerEvent(
      'pointermove',
      web.PointerEventInit(
        bubbles: true,
        clientX: moveRect.left.round() + 24,
        clientY: moveRect.top.round() + 16,
      ),
    ));
    web.window.dispatchEvent(web.PointerEvent(
      'pointerup',
      web.PointerEventInit(bubbles: true),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    header = root.querySelector(
      '.tiptap-page-header[data-page-number="1"]',
    ) as web.HTMLElement;
    final movedBox = header.querySelector('table')!;
    final afterMove = movedBox.getBoundingClientRect();
    expect(afterMove.left, greaterThan(beforeMove.left + 15));
    expect(afterMove.top, greaterThan(beforeMove.top + 8));
    expect(editor.state.doc.attrs['headers'].toString(), contains('top:'));
    _doubleClick(movedBox);

    final left = header.querySelector('[data-page-object-action="left"]')!;
    _click(left);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final payloadText = editor.state.doc.attrs['headers'].toString();
    expect(payloadText, contains('Caixa realmente modificada'));
    expect(payloadText, contains('left: 0px'));

    header = root.querySelector(
      '.tiptap-page-header[data-page-number="1"]',
    ) as web.HTMLElement;
    final image = header.querySelector('img')!;
    _doubleClick(image);
    expect(header.querySelectorAll('.tiptap-object-handle').length, 8);
    _click(header.querySelector('[data-page-object-action="right"]')!);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final imagePayload = editor.state.doc.attrs['headers'].toString();
    expect(imagePayload, contains('alignment: right'));
    expect(imagePayload, contains('position: absolute'));

    final footer = root.querySelector(
      '.tiptap-page-footer[data-page-number="1"]',
    )!;
    expect(footer.querySelector('[data-docx-page-field]')?.textContent, '1');
    _doubleClick(footer);
    expect(
      footer.querySelector('.tiptap-page-editor-label')?.textContent,
      'Rodapé',
    );

    // The real TR fixture contains first/even/default parts even though both
    // titlePg and evenAndOddHeaders are disabled. Word (and PaginationExtension)
    // therefore displays the default part on page 2. Persisting an edit made
    // there must update that displayed payload, not the dormant even part.
    final defaultHeader = [
      {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': 'Cabeçalho padrão ativo'},
        ],
      },
    ];
    final dormantEvenHeader = [
      {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': 'Cabeçalho par inativo'},
        ],
      },
    ];
    final parityDoc = editor.state.schema.node('doc', {
      'titlePage': false,
      'evenAndOddHeaders': false,
      'headers': {
        'default': defaultHeader,
        'even': dormantEvenHeader,
      },
    }, [
      for (var index = 0; index < 50; index++)
        editor.state.schema.node('paragraph', null, [
          editor.state.schema.text(
            'Linha $index para forçar uma segunda página editável.',
          ),
        ]),
    ]);
    editor.setDocument(parityDoc);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final secondHeader = root.querySelector(
      '.tiptap-page-header[data-page-number="2"]',
    ) as web.HTMLElement?;
    expect(secondHeader, isNotNull);
    expect(secondHeader!.textContent, contains('Cabeçalho padrão ativo'));
    final secondParagraph = secondHeader.querySelector('p')!;
    _doubleClick(secondParagraph);
    secondParagraph.textContent = 'Padrão alterado na página par';
    secondParagraph.dispatchEvent(
      web.Event('input', web.EventInit(bubbles: true)),
    );
    _click(secondHeader.querySelector(
      '[data-page-object-action="close"]',
    )!);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final persistedHeaders =
        Map<String, dynamic>.from(editor.state.doc.attrs['headers'] as Map);
    expect(
      persistedHeaders['default'].toString(),
      contains('Padrão alterado na página par'),
    );
    expect(
      persistedHeaders['even'].toString(),
      contains('Cabeçalho par inativo'),
    );
    expect(
      persistedHeaders['even'].toString(),
      isNot(contains('Padrão alterado na página par')),
    );
  });
}

void _doubleClick(web.Element target) {
  target.dispatchEvent(web.MouseEvent(
    'dblclick',
    web.MouseEventInit(bubbles: true, cancelable: true),
  ));
}

void _click(web.Element target) {
  target.dispatchEvent(web.MouseEvent(
    'click',
    web.MouseEventInit(bubbles: true, cancelable: true),
  ));
}

void _dragIndent(web.HTMLElement horizontalTrack, String kind, double x) {
  final ruler = horizontalTrack.querySelector('.tiptap-horizontal-ruler')!;
  final marker = horizontalTrack.querySelector(
    '[data-ruler-indent="$kind"]',
  )!;
  final rulerRect = ruler.getBoundingClientRect();
  final markerRect = marker.getBoundingClientRect();
  marker.dispatchEvent(web.PointerEvent(
    'pointerdown',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: (markerRect.left + markerRect.width / 2).round(),
      clientY: (markerRect.top + markerRect.height / 2).round(),
    ),
  ));
  web.window.dispatchEvent(web.PointerEvent(
    'pointermove',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      buttons: 1,
      clientX: (rulerRect.left + x).round(),
      clientY: (rulerRect.top + rulerRect.height / 2).round(),
    ),
  ));
  web.window.dispatchEvent(web.PointerEvent(
    'pointerup',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: (rulerRect.left + x).round(),
      clientY: (rulerRect.top + rulerRect.height / 2).round(),
    ),
  ));
}

void _dragTab(web.HTMLElement horizontalTrack, double x) {
  final ruler = horizontalTrack.querySelector('.tiptap-horizontal-ruler')!;
  final marker = horizontalTrack.querySelector('.tiptap-ruler-tab')!;
  final rulerRect = ruler.getBoundingClientRect();
  final markerRect = marker.getBoundingClientRect();
  marker.dispatchEvent(web.PointerEvent(
    'pointerdown',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: (markerRect.left + markerRect.width / 2).round(),
      clientY: (markerRect.top + markerRect.height / 2).round(),
    ),
  ));
  web.window.dispatchEvent(web.PointerEvent(
    'pointermove',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      buttons: 1,
      clientX: (rulerRect.left + x).round(),
      clientY: (rulerRect.top + rulerRect.height / 2).round(),
    ),
  ));
  web.window.dispatchEvent(web.PointerEvent(
    'pointerup',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: (rulerRect.left + x).round(),
      clientY: (rulerRect.top + rulerRect.height / 2).round(),
    ),
  ));
}

void _addTab(web.HTMLElement horizontalTrack, double x) {
  final ruler = horizontalTrack.querySelector('.tiptap-horizontal-ruler')!;
  final rect = ruler.getBoundingClientRect();
  ruler.dispatchEvent(web.PointerEvent(
    'pointerdown',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: (rect.left + x).round(),
      clientY: (rect.top + rect.height / 2).round(),
    ),
  ));
}

void _dragMargin(
  web.HTMLElement container,
  String side,
  double position, {
  required bool vertical,
}) {
  final ruler = vertical
      ? container
      : container.querySelector('.tiptap-horizontal-ruler')!;
  final marker = container.querySelector('[data-ruler-margin="$side"]')!;
  final rulerRect = ruler.getBoundingClientRect();
  final markerRect = marker.getBoundingClientRect();
  final targetX = vertical
      ? rulerRect.left + rulerRect.width / 2
      : rulerRect.left + position;
  final targetY = vertical
      ? rulerRect.top + position
      : rulerRect.top + rulerRect.height / 2;
  marker.dispatchEvent(web.PointerEvent(
    'pointerdown',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: (markerRect.left + markerRect.width / 2).round(),
      clientY: (markerRect.top + markerRect.height / 2).round(),
    ),
  ));
  web.window.dispatchEvent(web.PointerEvent(
    'pointermove',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      buttons: 1,
      clientX: targetX.round(),
      clientY: targetY.round(),
    ),
  ));
  web.window.dispatchEvent(web.PointerEvent(
    'pointerup',
    web.PointerEventInit(
      bubbles: true,
      cancelable: true,
      button: 0,
      clientX: targetX.round(),
      clientY: targetY.round(),
    ),
  ));
}
