@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:docx_rendering/tiptap.dart';
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
        .tiptap-ui .tiptap-page-editor-overlay { position:absolute;left:0;right:0;bottom:0;border-top:2px dashed #6d5dfc;z-index:40; }
        .tiptap-ui .tiptap-page-object-selection { position:absolute;border:2px solid #6d5dfc;z-index:50;pointer-events:none; }
        .tiptap-ui .tiptap-object-handle { position:absolute;width:8px;height:8px;pointer-events:auto; }
        .tiptap-ui .tiptap-vertical-ruler { position:absolute;left:8px;top:8px;width:22px;height:0;overflow:visible; }
        .tiptap-ui .tiptap-vertical-ruler::before { content:'';position:absolute;width:22px;height:540px; }
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
      editor.state.schema.node('paragraph', null, [
        editor.state.schema.text('Corpo do documento.'),
      ]),
    ]);
    editor.setDocument(doc);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final root = editor.view!.dom;
    final ruler = web.document.querySelector('[data-tiptap-vertical-ruler]');
    final viewport = web.document.getElementById('viewport')!;
    expect(ruler, isNotNull);
    expect(ruler!.parentElement, same(viewport));
    expect(
      web.window.getComputedStyle(ruler).getPropertyValue('float'),
      isNot('left'),
      reason: 'a régua não pode participar dos floats usados pela paginação',
    );
    expect(ruler.getBoundingClientRect().height, 0);
    final pageRect = root.getBoundingClientRect();
    final rulerRect = ruler.getBoundingClientRect();
    final rulerGap = pageRect.left - rulerRect.right;
    expect(
      rulerGap,
      inInclusiveRange(4, 9),
      reason: 'a régua fica encostada à borda esquerda da folha',
    );
    final pageScale =
        web.document.querySelector('.page-scale') as web.HTMLElement;
    pageScale.style.setProperty('zoom', '.75');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final zoomedGap =
        root.getBoundingClientRect().left - ruler.getBoundingClientRect().right;
    expect(
      zoomedGap,
      inInclusiveRange(4, 9),
      reason: 'a régua acompanha a folha após mudar o zoom',
    );
    pageScale.style.removeProperty('zoom');
    await Future<void>.delayed(const Duration(milliseconds: 50));

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
