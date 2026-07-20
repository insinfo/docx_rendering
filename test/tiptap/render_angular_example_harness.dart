import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Browser smoke for the prebuilt AngularDart example.
///
/// Build first with:
/// `cd example2 && dart run webdev build --output web:build`
Future<void> main() async {
  final root = Directory.current.absolute;
  final build = Directory('${root.path}/example2/build');
  final output = Directory('${root.path}/test/output')
    ..createSync(recursive: true);
  if (!File('${build.path}/main.dart.js').existsSync()) {
    throw StateError(
      'example2/build is missing; run the webdev build documented above.',
    );
  }

  final handler =
      createStaticHandler(build.path, defaultDocument: 'index.html');
  final server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: _browserExecutable(),
      args: const ['--force-device-scale-factor=1', '--disable-gpu'],
    );
    final page = await browser.newPage();
    final errors = <String>[];
    final console = <String>[];
    page.onConsole.listen((message) {
      console.add('[${message.type}] ${message.text ?? ''}');
    });
    page.onError.listen((error) => errors.add('$error'));
    await page.setViewport(DeviceViewport(width: 1440, height: 1000));
    await page.goto(
      'http://127.0.0.1:${server.port}',
      wait: Until.networkIdle,
    );
    try {
      await _waitUntil(
        page,
        '() => window.__tiptapAngularReady === true',
        'Angular editor initialization',
      );
    } on TimeoutException catch (error) {
      final diagnostic = await page.evaluate('''() => ({
        body: document.body.innerText,
        readyState: document.readyState,
        script: document.querySelector('script[src="main.dart.js"]')?.src,
        stage: window.__tiptapAngularBootstrapStage,
        bootstrapError: window.__tiptapAngularBootstrapError,
        bootstrapStack: window.__tiptapAngularBootstrapStack,
      })''');
      throw StateError(
        '$error\nBrowser errors: $errors\nConsole: $console\nDOM: $diagnostic',
      );
    }

    final initial = Map<String, dynamic>.from(await page.evaluate('''() => ({
      contenteditable: document.querySelector('.ProseMirror').getAttribute('contenteditable'),
      toolbarButtons: document.querySelectorAll('[data-tiptap-command], [data-tiptap-action]').length,
      icons: document.querySelectorAll('.tiptap-icon').length,
      heading: document.querySelector('.ProseMirror h1').textContent,
      pageWidth: Math.round(document.querySelector('.page-sheet').getBoundingClientRect().width),
    })''') as Map);
    stdout.writeln('Angular metrics: $initial');
    _check(initial['contenteditable'] == 'true', 'Editor is not editable.');
    _check(initial['toolbarButtons'] as int >= 17, 'Toolbar is incomplete.');
    _check(initial['icons'] as int >= 18, 'SVG icons were not hydrated.');
    _check(initial['pageWidth'] as int == 794, 'A4 width was not applied.');

    await page.evaluate('''() => {
      const editor = document.querySelector('.ProseMirror');
      const lastParagraph = editor.querySelector(':scope > p:last-of-type');
      const range = document.createRange();
      range.selectNodeContents(lastParagraph);
      range.collapse(false);
      const selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.dispatchEvent(new Event('selectionchange'));

      const clipboard = new DataTransfer();
      clipboard.setData('text/plain', ' ANTES DEPOIS');
      clipboard.setData(
        'text/html',
        '<p>ANTES<!--StartSelection--> DEPOIS</p>',
      );
      editor.dispatchEvent(new ClipboardEvent('paste', {
        bubbles: true,
        cancelable: true,
        composed: true,
        clipboardData: clipboard,
      }));
    }''');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror").textContent.includes("ANTES DEPOIS")',
      'Angular HTML paste with clipboard fragment comments',
    );

    await page.evaluate('''() => {
      const heading = document.querySelector('.ProseMirror h1');
      const range = document.createRange();
      range.selectNodeContents(heading);
      const selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.dispatchEvent(new Event('selectionchange'));
    }''');
    await page.click('[data-tiptap-command="bold"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror h1 strong") !== null',
      'Angular toolbar bold command',
    );
    await page.click('[data-tiptap-action="undo"]');

    await page.click('button[aria-label="Alternar modo de edição"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror").getAttribute("contenteditable") === "false"',
      'read-only mode',
    );
    await _waitUntil(
      page,
      '() => getComputedStyle(document.querySelector(".tiptap-vertical-ruler")).display === "none" && getComputedStyle(document.querySelector(".tiptap-horizontal-ruler-track")).display === "none"',
      'rulers hidden in read-only mode',
    );
    await page.click('button[aria-label="Alternar tema"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".tiptap-ui").classList.contains("tiptap-dark")',
      'component dark theme',
    );
    await page.click('button[aria-label="Alternar tema"]');
    await _waitUntil(
      page,
      '() => !document.querySelector(".tiptap-ui").classList.contains("tiptap-dark")',
      'component light theme restoration',
    );
    await page.click('button[aria-label="Alternar modo de edição"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror").getAttribute("contenteditable") === "true"',
      'editable mode restoration',
    );

    final rulerMetrics = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const viewport = document.querySelector('.document-viewport');
        const pageScale = viewport?.querySelector('.page-scale');
        const ruler = pageScale?.querySelector(':scope > .tiptap-vertical-ruler');
        const horizontal = viewport?.querySelector(':scope > .tiptap-horizontal-ruler-track');
        const pageSheet = viewport?.querySelector('.page-sheet');
        const viewportRect = viewport?.getBoundingClientRect();
        const rulerRect = ruler?.getBoundingClientRect();
        const pageRect = pageSheet?.getBoundingClientRect();
        return {
          exists: !!ruler,
          horizontalExists: !!horizontal,
          marks: ruler?.querySelectorAll('.tiptap-ruler-num, .tiptap-ruler-tick').length || 0,
          indents: horizontal?.querySelectorAll('.tiptap-ruler-indent').length || 0,
          pageHeight: pageRect?.height,
          rulerHeight: rulerRect?.height,
          viewportLeft: viewportRect?.left,
          rulerLeft: rulerRect?.left,
          pageLeft: pageRect?.left,
          pageGap: pageRect && rulerRect ? pageRect.left - rulerRect.right : null,
          alignedToPage: !!rulerRect && !!pageRect &&
            pageRect.left - rulerRect.right >= 5 &&
            pageRect.left - rulerRect.right <= 9 &&
            Math.abs(pageRect.height - rulerRect.height) <= 1,
        };
      }''') as Map,
    );
    _check(rulerMetrics['exists'] == true, 'Vertical ruler is missing.');
    _check(rulerMetrics['horizontalExists'] == true,
        'Horizontal ruler is missing.');
    _check((rulerMetrics['marks'] as num) > 0,
        'Vertical ruler marks are missing.');
    _check(rulerMetrics['indents'] == 4,
        'Horizontal ruler indent markers are incomplete.');
    _check(rulerMetrics['alignedToPage'] == true,
        'Vertical ruler is not attached to the page edge: $rulerMetrics');

    final deltaFixture = File('${output.path}/angular_delta_fixture.json');
    await deltaFixture.writeAsString(jsonEncode(<String, dynamic>{
      'ops': <Map<String, dynamic>>[
        {'insert': 'Delta AngularDart'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        for (var index = 0; index < 90; index++)
          {
            'insert':
                'Linha Angular $index — conteúdo importado de Quill Delta para validar o fluxo real no componente.\n',
          },
      ],
    }));
    final deltaInput = await page.$(
      'input[id^="tiptap-angular-delta-input-"]',
    );
    await deltaInput.uploadFile([deltaFixture]);
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror").textContent.includes("Linha Angular 89")',
      'Angular Quill Delta import',
    );
    await _waitUntil(
      page,
      '() => Number(document.querySelector(".ProseMirror").dataset.pageCount || 0) >= 2',
      'Angular pagination after Delta import',
    );
    final deltaMetrics = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        heading: document.querySelector('.ProseMirror h2')?.textContent,
        pageCount: Number(document.querySelector('.ProseMirror').dataset.pageCount || 0),
        title: document.querySelector('.document-identity strong')?.textContent,
      })''') as Map,
    );
    _check(deltaMetrics['heading'] == 'Delta AngularDart',
        'Delta block attributes were not converted to a heading.');

    final sourceDocx = File(
      '${root.path}/resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx',
    );
    _check(sourceDocx.existsSync(), 'Reference DOCX is missing.');
    final docxInput = await page.$(
      'input[id^="tiptap-angular-docx-input-"]',
    );
    await docxInput.uploadFile([sourceDocx]);
    await _waitUntil(
      page,
      '''() => document.querySelector('.ProseMirror').textContent.includes('ESTUDO TÉCNICO PRELIMINAR')''',
      'Angular reference DOCX import',
    );
    await _waitUntil(
      page,
      '''() => Number(document.querySelector('.ProseMirror').dataset.pageCount || 0) >= 5''',
      'Angular DOCX pagination',
    );
    await _waitUntil(
      page,
      '''() => document.querySelector('.tiptap-page-header') &&
        document.querySelector('.tiptap-page-footer') &&
        [...document.querySelectorAll('.tiptap-page-header img, .tiptap-page-footer img')]
          .every(image => image.complete && image.naturalWidth > 0)''',
      'Angular DOCX header/footer materialization',
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final docxMetrics = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const editor = document.querySelector('.ProseMirror');
        const bounds = editor.getBoundingClientRect();
        const relativeRect = element => element ? {
          left: element.getBoundingClientRect().left - bounds.left,
          right: element.getBoundingClientRect().right - bounds.left,
          top: element.getBoundingClientRect().top - bounds.top,
          width: element.getBoundingClientRect().width,
          height: element.getBoundingClientRect().height,
        } : null;
        const firstHeaderImage = editor.querySelector('.tiptap-page-header img');
        const firstFooterImage = editor.querySelector('.tiptap-page-footer img');
        return {
          pageCount: Number(editor.dataset.pageCount || 0),
          tables: editor.querySelectorAll('table').length,
          headers: editor.querySelectorAll('.tiptap-page-header').length,
          footers: editor.querySelectorAll('.tiptap-page-footer').length,
          headerImages: editor.querySelectorAll('.tiptap-page-header img').length,
          footerImages: editor.querySelectorAll('.tiptap-page-footer img').length,
          firstHeaderImage: relativeRect(firstHeaderImage),
          firstFooterImage: relativeRect(firstFooterImage),
          processBox: [...editor.querySelectorAll('.tiptap-page-header')]
            .some(header => header.textContent.includes('44505/2025')),
        };
      }''') as Map,
    );
    _check(docxMetrics['tables'] as int >= 3,
        'DOCX tables were not imported in AngularDart.');
    _check(docxMetrics['headers'] as int > 0,
        'DOCX headers were not materialized in AngularDart.');
    _check(docxMetrics['footers'] as int > 0,
        'DOCX footers were not materialized in AngularDart.');
    _check(docxMetrics['headerImages'] as int > 0,
        'DOCX header images were not materialized in AngularDart.');
    _check(docxMetrics['footerImages'] as int > 0,
        'DOCX footer images were not materialized in AngularDart.');
    _check(docxMetrics['processBox'] == true,
        'DOCX VML process textbox was not materialized in AngularDart.');
    final firstHeaderImage =
        Map<String, dynamic>.from(docxMetrics['firstHeaderImage'] as Map);
    _check(
      (firstHeaderImage['left'] as num).toDouble() >= 70 &&
          (firstHeaderImage['left'] as num).toDouble() <= 82 &&
          (firstHeaderImage['width'] as num).toDouble() >= 485 &&
          (firstHeaderImage['width'] as num).toDouble() <= 498,
      'Header image does not match the Word margin/extent: $firstHeaderImage',
    );
    final firstFooterImage =
        Map<String, dynamic>.from(docxMetrics['firstFooterImage'] as Map);
    _check(
      (firstFooterImage['right'] as num).toDouble() >= 710 &&
          (firstFooterImage['right'] as num).toDouble() <= 725,
      'Footer image is not right-aligned to the Word margin: '
      '$firstFooterImage',
    );

    final regionGeometry = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const root = document.querySelector('.ProseMirror');
        const bounds = root.getBoundingClientRect();
        const style = getComputedStyle(root);
        const rect = element => element ? {
          left: element.getBoundingClientRect().left - bounds.left,
          right: element.getBoundingClientRect().right - bounds.left,
          top: element.getBoundingClientRect().top - bounds.top,
          bottom: element.getBoundingClientRect().bottom - bounds.top,
          width: element.getBoundingClientRect().width,
          height: element.getBoundingClientRect().height,
          wrapper: element.closest('.tiptap-page-break')?.dataset.pageIndex,
        } : null;
        const bodyLines = [];
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        while (walker.nextNode()) {
          const text = walker.currentNode;
          if (!text.data.trim() || text.parentElement?.closest('[data-tiptap-pagination]')) {
            continue;
          }
          const range = document.createRange();
          range.selectNodeContents(text);
          for (const line of range.getClientRects()) {
            if (line.width > 0 && line.height > 0) {
              bodyLines.push({
                top: line.top - bounds.top,
                bottom: line.bottom - bounds.top,
              });
            }
          }
        }
        return {
          boundsTop: bounds.top,
          boundsHeight: bounds.height,
          offsetHeight: root.offsetHeight,
          pageHeight: style.getPropertyValue('--tiptap-page-height'),
          pageGap: style.getPropertyValue('--tiptap-page-gap'),
          regions: [1, 11, 12, 23, 24].map(page => {
            const headerElement = root.querySelector(
              '.tiptap-page-header[data-page-number="' + page + '"]'
            );
            const footerElement = root.querySelector(
              '.tiptap-page-footer[data-page-number="' + page + '"]'
            );
            const header = rect(headerElement);
            const footer = rect(footerElement);
            const processBox = [...(headerElement?.querySelectorAll(
              'table[data-docx-textbox]'
            ) || [])].find(item => item.textContent.includes('44505/2025'));
            const processBoxGeometry = processBox ? {
              ...rect(processBox),
              authoredHeight: processBox.style.height,
              computedHeight: getComputedStyle(processBox).height,
              cell: (() => {
                const cell = processBox.querySelector('td');
                const cellStyle = getComputedStyle(cell);
                return {
                  height: cell.getBoundingClientRect().height,
                  paddingTop: cellStyle.paddingTop,
                  paddingBottom: cellStyle.paddingBottom,
                  fontSize: cellStyle.fontSize,
                  lineHeight: cellStyle.lineHeight,
                };
              })(),
              paragraphs: [...processBox.querySelectorAll('p')].map(item => {
                const paragraphStyle = getComputedStyle(item);
                return {
                  text: item.textContent,
                  height: item.getBoundingClientRect().height,
                  marginTop: paragraphStyle.marginTop,
                  marginBottom: paragraphStyle.marginBottom,
                  fontSize: paragraphStyle.fontSize,
                  lineHeight: paragraphStyle.lineHeight,
                };
              }),
            } : null;
            const firstBodyLine = bodyLines
              .filter(line => header && footer &&
                line.top >= header.top - 1 && line.bottom <= footer.top + 1)
              .sort((a, b) => a.top - b.top)[0];
            return {
              page,
              header,
              footer,
              processBox: processBoxGeometry,
              firstBodyLineTop: firstBodyLine?.top,
            };
          }),
        };
      }''') as Map,
    );
    var measuredProcessBoxes = 0;
    for (final dynamic rawRegion in regionGeometry['regions'] as List) {
      final region = Map<String, dynamic>.from(rawRegion as Map);
      final rawProcessBox = region['processBox'];
      if (rawProcessBox == null) continue;
      measuredProcessBoxes++;
      final processBox = Map<String, dynamic>.from(rawProcessBox as Map);
      final header = Map<String, dynamic>.from(region['header'] as Map);
      final height = (processBox['height'] as num).toDouble();
      _check(
        height >= 60 && height < 100,
        'Page ${region['page']} process textbox height is $height px; '
        'the authored 59.25pt should render near 79px. Geometry: $processBox',
      );
      final relativeTop = (processBox['top'] as num).toDouble() -
          (header['top'] as num).toDouble();
      final right = (processBox['right'] as num).toDouble();
      _check(
        relativeTop >= 15 && relativeTop <= 21 && right >= 710 && right <= 725,
        'Page ${region['page']} textbox does not honor Word header/right '
        'margins: top=$relativeTop, right=$right, geometry=$processBox',
      );
      final bodyTop = (region['firstBodyLineTop'] as num?)?.toDouble();
      final processBottom = (processBox['bottom'] as num).toDouble();
      _check(
        bodyTop == null || bodyTop >= processBottom - 1,
        'Page ${region['page']} body begins at $bodyTop px before the process '
        'textbox ends at $processBottom px.',
      );
    }
    _check(
      measuredProcessBoxes >= 3,
      'Expected process textbox geometry on at least three sampled pages; '
      'measured $measuredProcessBoxes.',
    );

    await page.evaluate('''() => {
      const header = [...document.querySelectorAll('.tiptap-page-header')]
        .find(item => item.querySelector('img'));
      header.querySelector('img').dispatchEvent(new MouseEvent('dblclick', {
        bubbles: true,
        cancelable: true,
        composed: true,
      }));
    }''');
    await _waitUntil(
      page,
      '''() => document.querySelector('.tiptap-page-region-active .tiptap-page-editor-label')?.textContent === 'Cabeçalho' ''',
      'Angular header edit mode',
    );
    final headerEditorMetrics = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        label: document.querySelector('.tiptap-page-region-active .tiptap-page-editor-label')?.textContent,
        handles: document.querySelectorAll('.tiptap-page-object-selection .tiptap-object-handle').length,
        moveHandles: document.querySelectorAll('.tiptap-page-object-selection .tiptap-object-move-handle').length,
        alignmentActions: document.querySelectorAll(
          '.tiptap-page-region-active [data-page-object-action="left"], ' +
          '.tiptap-page-region-active [data-page-object-action="center"], ' +
          '.tiptap-page-region-active [data-page-object-action="right"]'
        ).length,
      })''') as Map,
    );
    _check(headerEditorMetrics['handles'] == 8,
        'Header image resize handles were not shown.');
    _check(headerEditorMetrics['moveHandles'] == 1,
        'Header image move handle was not shown.');
    _check(headerEditorMetrics['alignmentActions'] == 3,
        'Header object alignment UI is incomplete.');

    await page.evaluate('''() => {
      document.querySelector(
        '.tiptap-page-region-active [data-page-object-action="close"]'
      ).dispatchEvent(new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        composed: true,
      }));
    }''');
    await _waitUntil(
      page,
      "() => !document.querySelector('.tiptap-page-region-active')",
      'Angular header edit mode close',
    );
    await page.evaluate('''() => {
      const header = [...document.querySelectorAll('.tiptap-page-header')]
        .find(item => item.textContent.includes('44505/2025'));
      const textBox = [...header.querySelectorAll('table')]
        .find(item => item.textContent.includes('44505/2025'));
      textBox.dispatchEvent(new MouseEvent('dblclick', {
        bubbles: true,
        cancelable: true,
        composed: true,
      }));
    }''');
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.tiptap-page-region-active .tiptap-object-handle').length === 8''',
      'Angular header textbox selection',
    );
    await page.evaluate('''() => {
      const active = document.querySelector('.tiptap-page-region-active');
      const textBox = [...active.querySelectorAll('table')]
        .find(item => item.textContent.includes('44505/2025'));
      const paragraph = [...textBox.querySelectorAll('p')]
        .find(item => item.textContent.includes('44505/2025'));
      paragraph.textContent = paragraph.textContent.replace(
        '44505/2025',
        '44505/2025A',
      );
      paragraph.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        composed: true,
        inputType: 'insertText',
        data: 'A',
      }));
    }''');
    await page.evaluate('''() => {
      document.querySelector(
        '.tiptap-page-region-active [data-page-object-action="close"]'
      ).dispatchEvent(new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        composed: true,
      }));
    }''');
    await _waitUntil(
      page,
      '''() => window.getAngularTiptapJSON().includes('44505/2025A')''',
      'Angular header textbox persistence',
    );
    await page.evaluate('''() => {
      const footer = document.querySelector('.tiptap-page-footer');
      footer.dispatchEvent(new MouseEvent('dblclick', {
        bubbles: true,
        cancelable: true,
        composed: true,
      }));
    }''');
    await _waitUntil(
      page,
      '''() => document.querySelector('.tiptap-page-region-active .tiptap-page-editor-label')?.textContent === 'Rodapé' ''',
      'Angular footer edit mode',
    );
    await page.evaluate('''() => {
      document.querySelector(
        '.tiptap-page-region-active [data-page-object-action="close"]'
      ).dispatchEvent(new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        composed: true,
      }));
    }''');

    final encodedPdf = await page.evaluate(
      'async () => await window.getAngularTiptapPdfBase64()',
    );
    _check(encodedPdf is String && encodedPdf.isNotEmpty,
        'Angular PDF bridge returned no bytes.');
    final pdfBytes = base64.decode(encodedPdf as String);
    final angularPdf = File('${output.path}/tiptap_angular_docx.pdf');
    await angularPdf.writeAsBytes(pdfBytes, flush: true);
    final pdfSource = latin1.decode(pdfBytes);
    final pdfPages = RegExp(r'/Type\s*/Page\b').allMatches(pdfSource).length;
    _check(
        pdfBytes.length > 10000, 'Angular PDF output is unexpectedly small.');
    _check(pdfPages >= 5, 'Angular PDF did not preserve physical pagination.');
    _check(pdfSource.contains('/Subtype /Image'),
        'Angular PDF contains no header/footer images.');

    _check(errors.isEmpty, 'Browser emitted errors: $errors');
    final screenshot = File('${output.path}/tiptap_angular_example.png');
    await screenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png),
      flush: true,
    );
    await File('${output.path}/tiptap_angular_example.json').writeAsString(
      const JsonEncoder.withIndent(' ').convert(<String, dynamic>{
        'checks': <String, bool>{
          'angular_initialized': true,
          'html_fragment_paste': true,
          'native_selection_bold': true,
          'undo': true,
          'read_only': true,
          'theme': true,
          'vertical_ruler': true,
          'quill_delta_import': true,
          'docx_header_footer': true,
          'header_footer_edit_mode': true,
          'header_textbox_editing': true,
          'object_resize_and_alignment_ui': true,
          'paginated_pdf_dom_capture': true,
        },
        'metrics': <String, dynamic>{
          'initial': initial,
          'ruler': rulerMetrics,
          'delta': deltaMetrics,
          'docx': docxMetrics,
          'headerEditor': headerEditorMetrics,
          'regionGeometry': regionGeometry,
          'pdfBytes': pdfBytes.length,
          'pdfPages': pdfPages,
        },
        'pageErrors': errors,
        'console': console,
      }),
      flush: true,
    );
    stdout.writeln('AngularDart example validated: ${screenshot.path}');
    await page.close();
  } finally {
    await browser?.close();
    await server.close(force: true);
  }
}

Future<void> _waitUntil(Page page, String predicate, String description) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (await page.evaluate(predicate) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Timed out waiting for $description.');
}

String? _browserExecutable() {
  for (final candidate in <String>[
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}
