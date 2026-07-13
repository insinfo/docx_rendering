import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Visual and functional smoke harness for `web/tiptap_demo.html`.
///
/// By default it compiles the Dart entrypoint, serves `web/` on an ephemeral
/// loopback port, exercises the real browser UI, and writes these artifacts:
///
/// - `test/output/tiptap_demo.png`
/// - `test/output/tiptap_demo_harness.json`
/// - `test/output/tiptap_demo_console.log`
///
/// Usage:
///
/// ```text
/// dart run test/tiptap/render_demo_harness.dart
/// dart run test/tiptap/render_demo_harness.dart --no-compile
/// dart run test/tiptap/render_demo_harness.dart --headed
/// ```
///
/// `--no-compile` requires an existing `web/tiptap_demo.dart.js`.
Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } catch (error, stackTrace) {
    stderr.writeln('Tiptap demo harness failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

Future<void> _run(List<String> args) async {
  final root = Directory.current.absolute;
  final skipCompile = args.contains('--no-compile');
  final headless = !args.contains('--headed');
  final output = Directory('${root.path}/test/output')
    ..createSync(recursive: true);

  final entrypoint = File('${root.path}/web/tiptap_demo.dart');
  final javascript = File('${root.path}/web/tiptap_demo.dart.js');
  final html = File('${root.path}/web/tiptap_demo.html');
  _check(entrypoint.existsSync(), 'Missing ${entrypoint.path}');
  _check(html.existsSync(), 'Missing ${html.path}');

  if (!skipCompile) {
    stdout.writeln('Compiling web/tiptap_demo.dart ...');
    final compile = await Process.run(
      'dart',
      [
        'compile',
        'js',
        'web/tiptap_demo.dart',
        '-o',
        'web/tiptap_demo.dart.js',
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    stdout.write(compile.stdout);
    if (compile.exitCode != 0) {
      stderr.write(compile.stderr);
      throw StateError('Dart-to-JavaScript compilation failed.');
    }
  }
  _check(
    javascript.existsSync(),
    'Missing ${javascript.path}; rerun without --no-compile.',
  );

  final handler = createStaticHandler(
    '${root.path}/web',
    defaultDocument: 'tiptap_demo.html',
  );
  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    0,
  );
  final trace = args.contains('--pagination-trace') ? '?paginationTrace=1' : '';
  final url = 'http://127.0.0.1:${server.port}/tiptap_demo.html$trace';
  stdout.writeln('Serving $url');

  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: _browserExecutable(),
      headless: headless,
      args: const [
        '--force-device-scale-factor=1',
        '--disable-gpu',
        '--hide-scrollbars',
      ],
    );
    await _exercise(browser, url, output);
  } finally {
    await browser?.close();
    await server.close(force: true);
  }
}

Future<void> _exercise(
  Browser browser,
  String url,
  Directory output,
) async {
  final page = await browser.newPage();
  final console = <String>[];
  final pageErrors = <String>[];

  page.onConsole.listen((message) {
    final text = '[${message.type}] ${message.text ?? ''}';
    console.add(text);
    if (text.contains('TR_PAGINATION_MEASURE')) stdout.writeln(text);
  });
  page.onError.listen((error) {
    final text = '$error';
    pageErrors.add(text);
    console.add('PAGE ERROR: $text');
  });

  try {
    await page.setViewport(DeviceViewport(width: 1440, height: 1000));
    await page.goto(url, wait: Until.networkIdle);
    await page.waitForSelector(
      '.ProseMirror',
      visible: true,
      timeout: const Duration(seconds: 20),
    );
    await _waitUntil(
      page,
      '() => typeof window.getTiptapHTML === "function"',
      'debug bridge initialization',
    );

    final rawMetrics = await page.evaluate('''() => {
      const toolbar = document.getElementById('toolbar');
      const sheet = document.getElementById('page-sheet');
      const editor = document.querySelector('.ProseMirror');
      const html = window.getTiptapHTML();
      return {
        title: document.title,
        toolbarButtons: toolbar.querySelectorAll('button').length,
        toolbarHeight: Math.round(toolbar.getBoundingClientRect().height),
        pageWidth: Math.round(sheet.getBoundingClientRect().width),
        pageHeight: Math.round(sheet.getBoundingClientRect().height),
        editorTextLength: editor.textContent.trim().length,
        headings: editor.querySelectorAll('h1, h2, h3').length,
        htmlLength: html.length,
      };
    }''');
    final metrics = Map<String, dynamic>.from(rawMetrics as Map);
    _check(metrics['toolbarButtons'] as int >= 16, 'Toolbar is incomplete.');
    _check(metrics['toolbarHeight'] as int >= 40, 'Toolbar is too short.');
    _check(
        metrics['pageWidth'] as int >= 790, 'A4 sheet width was not applied.');
    _check(metrics['pageHeight'] as int >= 1120,
        'A4 sheet height was not applied.');
    _check(
        metrics['editorTextLength'] as int > 250, 'Welcome document is empty.');
    _check(metrics['headings'] as int >= 2, 'Welcome headings are missing.');
    _check(metrics['htmlLength'] as int > 300,
        'HTML bridge returned no document.');

    // The export menu must be painted over the editor frame, not trapped in a
    // lower stacking context behind the sticky toolbar/canvas.
    await page.click('#export-menu-button');
    await _waitUntil(
      page,
      '() => document.getElementById("export-menu").classList.contains("open")',
      'export menu opening',
    );
    final menuIsTopmost = await page.evaluate('''() => {
      const menu = document.getElementById('export-menu');
      const rect = menu.getBoundingClientRect();
      const top = document.elementFromPoint(rect.left + 20, rect.top + 20);
      return top === menu || menu.contains(top);
    }''');
    _check(menuIsTopmost == true, 'Export menu is rendered behind the editor.');
    await page.click('#export-menu-button');

    // Exercise the visible theme control, then restore light mode so the
    // screenshot remains the canonical visual-fidelity reference.
    await page.click('#theme-toggle');
    await _waitUntil(
      page,
      '() => document.body.classList.contains("dark")',
      'dark theme activation',
    );
    await page.click('#theme-toggle');
    await _waitUntil(
      page,
      '() => !document.body.classList.contains("dark")',
      'light theme restoration',
    );

    // Focus the real contenteditable, then exercise an actual toolbar action.
    // A horizontal rule gives us an unambiguous DOM result even at a collapsed
    // selection; undo restores the canonical document before the screenshot.
    await page.click('.ProseMirror p');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    // Exercise a mark with an actual browser DOM selection. This catches a
    // selectionchange bridge regression that state-only tests cannot see.
    await page.evaluate('''() => {
      const heading = document.querySelector('.ProseMirror h1');
      const range = document.createRange();
      range.selectNodeContents(heading);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.dispatchEvent(new Event('selectionchange'));
    }''');
    await page.click('[data-tiptap-command="bold"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror h1 strong") !== null',
      'bold toolbar command on native selection',
    );
    await page.click('[data-tiptap-action="undo"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror h1 strong") === null',
      'undo bold command',
    );

    await page.click('[data-tiptap-action="horizontal-rule"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror hr") !== null',
      'horizontal-rule toolbar command',
    );
    await page.click('[data-tiptap-action="undo"]');
    await _waitUntil(
      page,
      '() => document.querySelector(".ProseMirror hr") === null',
      'toolbar undo command',
    );

    // Reproduce the zoom level from the reported PDF corruption. The debug
    // bridge returns the exact bytes generated by the browser, avoiding
    // headless Chrome's platform-dependent download handling.
    for (var index = 0; index < 4; index++) {
      await page.click('[data-tiptap-action="zoom-out"]');
    }
    await _waitUntil(
      page,
      '() => document.getElementById("zoom-value").textContent === "60%"',
      '60 percent zoom',
    );
    final encodedPdf = await page.evaluate(
      'async () => await window.getTiptapPdfBase64()',
    );
    _check(encodedPdf is String && encodedPdf.isNotEmpty,
        'Browser PDF bridge returned no bytes.');
    final pdfBytes = base64.decode(encodedPdf as String);
    final browserPdf = File('${output.path}/tiptap_demo_60_percent.pdf');
    await browserPdf.writeAsBytes(pdfBytes, flush: true);
    final pdfSource = latin1.decode(pdfBytes);
    final fontSizes = RegExp(r'/F\d+\s+([0-9.]+)\s+Tf')
        .allMatches(pdfSource)
        .map((match) => double.parse(match.group(1)!))
        .toList();
    _check(fontSizes.isNotEmpty, 'Exported PDF contains no vector text.');
    _check(fontSizes.reduce(math.max) < 25,
        'PDF font sizes were inflated by the 60% editor zoom.');
    for (var index = 0; index < 4; index++) {
      await page.click('[data-tiptap-action="zoom-in"]');
    }
    await _waitUntil(
      page,
      '() => document.getElementById("zoom-value").textContent === "100%"',
      'zoom restoration',
    );

    final png = await page.screenshot(
      format: ScreenshotFormat.png,
      fullPage: false,
    );
    final screenshot = File('${output.path}/tiptap_demo.png');
    await screenshot.writeAsBytes(png, flush: true);

    // Exercise the exact DOCX reported by the user. Besides proving that the
    // file picker path works, these checks ensure imported paragraph/run
    // formatting reaches the editable DOM instead of being flattened.
    final sourceDocx = File(
      '${Directory.current.path}/resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx',
    );
    _check(sourceDocx.existsSync(), 'Reference DOCX is missing.');
    final docxInput = await page.$('#open-docx-input');
    await docxInput.uploadFile([sourceDocx]);
    await _waitUntil(
      page,
      '''() => document.querySelector('.ProseMirror').textContent.includes('ESTUDO TÉCNICO PRELIMINAR')''',
      'reference DOCX import',
    );
    await _waitUntil(
      page,
      '''() => Number(document.querySelector('.ProseMirror').dataset.pageCount || 0) >= 5''',
      'reference DOCX pagination',
    );
    await _waitUntil(
      page,
      '''() => [...document.querySelectorAll('.tiptap-page-header img, .tiptap-page-footer img')]
        .every(image => image.complete && image.naturalWidth > 0)''',
      'reference DOCX header/footer images',
    );
    // Image decoding can change the measured header/footer heights and cause
    // a final page-count adjustment. Record metrics only after that pass.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final docxMetrics = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const editor = document.querySelector('.ProseMirror');
        const state = JSON.parse(window.getTiptapJSON());
        const rootRect = editor.getBoundingClientRect();
        const firstHeader = editor.querySelector('.tiptap-page-header');
        const firstFooter = editor.querySelector('.tiptap-page-footer');
        const headerRect = firstHeader?.getBoundingClientRect();
        const footerRect = firstFooter?.getBoundingClientRect();
        return {
          pageCount: Number(editor.dataset.pageCount || 0),
          paragraphs: editor.querySelectorAll('p').length,
          styledBlocks: editor.querySelectorAll(
            'p[style*="text-align"], p[style*="margin"], p[style*="padding"], p[style*="line-height"]'
          ).length,
          styledRuns: editor.querySelectorAll('span[style]').length,
          tables: editor.querySelectorAll('table').length,
          listItems: editor.querySelectorAll('li').length,
          headerPayloads: Object.keys(state.attrs?.headers || {}).length,
          footerPayloads: Object.keys(state.attrs?.footers || {}).length,
          headerImages: editor.querySelectorAll('.tiptap-page-header img').length,
          footerImages: editor.querySelectorAll('.tiptap-page-footer img').length,
          firstHeaderText: editor.querySelector('.tiptap-page-header')?.textContent || '',
          firstFooterText: editor.querySelector('.tiptap-page-footer')?.textContent || '',
          firstHeaderRect: headerRect ? {
            top: headerRect.top - rootRect.top,
            height: headerRect.height,
            bottom: headerRect.bottom - rootRect.top,
          } : null,
          firstFooterRect: footerRect ? {
            top: footerRect.top - rootRect.top,
            height: footerRect.height,
            bottom: footerRect.bottom - rootRect.top,
          } : null,
        };
      }''') as Map,
    );
    stdout.writeln('DOCX editor metrics: $docxMetrics');
    _check(docxMetrics['paragraphs'] as int > 400,
        'Reference DOCX body was truncated.');
    _check(docxMetrics['styledBlocks'] as int > 10,
        'DOCX paragraph layout was flattened.');
    _check(docxMetrics['styledRuns'] as int > 10,
        'DOCX run formatting was flattened.');
    _check(docxMetrics['tables'] as int >= 3,
        'Reference DOCX tables were not imported.');
    _check(docxMetrics['headerPayloads'] as int > 0,
        'Reference DOCX headers were not preserved.');
    _check(docxMetrics['footerPayloads'] as int > 0,
        'Reference DOCX footers were not preserved.');
    _check(docxMetrics['headerImages'] as int > 0,
        'Reference DOCX header images were not materialized.');
    _check(docxMetrics['footerImages'] as int > 0,
        'Reference DOCX footer images were not materialized.');
    _check((docxMetrics['firstHeaderText'] as String).contains('44505/2025'),
        'Reference DOCX VML process box was not materialized.');
    final docxScreenshot = File('${output.path}/tiptap_demo_docx.png');
    await docxScreenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png, fullPage: false),
      flush: true,
    );
    for (var index = 0; index < 4; index++) {
      await page.click('[data-tiptap-action="zoom-out"]');
    }
    await _waitUntil(
      page,
      '() => document.getElementById("zoom-value").textContent === "60%"',
      'DOCX full-page zoom',
    );
    final stableDocxPageCount = docxMetrics['pageCount'] as int;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final paginationAfterZoom = await page.evaluate('''() => {
      const editor = document.querySelector('.ProseMirror');
      const rect = editor.getBoundingClientRect();
      return {
        pageCount: Number(editor.dataset.pageCount || 0),
        rectWidth: rect.width,
        offsetWidth: editor.offsetWidth,
        rectHeight: rect.height,
        offsetHeight: editor.offsetHeight,
      };
    }''');
    stdout.writeln('DOCX pagination after 60% zoom: $paginationAfterZoom');
    await _waitUntil(
      page,
      '''() => Number(document.querySelector('.ProseMirror').dataset.pageCount) === $stableDocxPageCount''',
      'DOCX pagination after zoom',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final zoomedPageCount = await page.evaluate(
      '''() => Number(document.querySelector('.ProseMirror').dataset.pageCount)''',
    );
    _check(zoomedPageCount == stableDocxPageCount,
        'Display zoom changed the DOCX page count.');
    await page.evaluate(
      '() => document.getElementById("document-viewport").scrollTop = 0',
    );
    final docxFullPageScreenshot =
        File('${output.path}/tiptap_demo_docx_full_page.png');
    await docxFullPageScreenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png, fullPage: false),
      flush: true,
    );
    for (var index = 0; index < 4; index++) {
      await page.click('[data-tiptap-action="zoom-in"]');
    }
    await _waitUntil(
      page,
      '() => document.getElementById("zoom-value").textContent === "100%"',
      'DOCX zoom restoration',
    );

    // Import a real Quill Delta file through the hidden browser input. The
    // fixture is deliberately long: besides validating the UI import path it
    // forces the pagination extension to create several physical pages.
    final deltaFixture = File('${output.path}/tiptap_delta_fixture.json');
    final deltaOps = <Map<String, dynamic>>[
      {'insert': 'Documento importado do Quill'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      for (var index = 0; index < 120; index++)
        {
          'insert':
              'Linha Delta $index — conteúdo suficiente para ocupar várias linhas e validar a quebra automática dentro do editor.\n',
        },
    ];
    await deltaFixture.writeAsString(jsonEncode({'ops': deltaOps}));
    final deltaInput = await page.$('#open-delta-input');
    await deltaInput.uploadFile([deltaFixture]);
    await _waitUntil(
      page,
      '''() => document.querySelector('.ProseMirror').textContent.includes('Linha Delta 119')''',
      'Quill Delta import',
    );
    await _waitUntil(
      page,
      '''() => {
        const pages = Number(document.querySelector('.ProseMirror').dataset.pageCount || 0);
        return pages >= 3 && pages <= 15;
      }''',
      'multi-page layout after Delta import',
    );
    final paginationMetrics = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const editor = document.querySelector('.ProseMirror');
        const sheet = document.getElementById('page-sheet');
        return {
          pageCount: Number(editor.dataset.pageCount || 0),
          pageBreaks: editor.querySelectorAll('.tiptap-page-break').length,
          sheetHeight: Math.round(sheet.getBoundingClientRect().height),
          title: document.getElementById('document-title').value,
        };
      }''') as Map,
    );
    _check(paginationMetrics['pageCount'] as int >= 3,
        'Pagination did not create multiple pages.');
    _check(paginationMetrics['pageBreaks'] as int >= 4,
        'Pagination sentinels are incomplete.');
    _check(
        (paginationMetrics['title'] as String).contains('tiptap_delta_fixture'),
        'Delta import did not update the document title.');

    final paginatedScreenshot = File(
      '${output.path}/tiptap_demo_paginated.png',
    );
    await paginatedScreenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png, fullPage: false),
      flush: true,
    );

    final report = <String, dynamic>{
      'url': url,
      'viewport': {'width': 1440, 'height': 1000},
      'checks': {
        'editor_initialized': true,
        'export_menu_topmost': true,
        'theme_toggle': true,
        'native_selection_bold': true,
        'horizontal_rule_and_undo': true,
        'pdf_at_60_percent_zoom': true,
        'reference_docx_import': true,
        'quill_delta_import': true,
        'multi_page_layout': true,
      },
      'metrics': metrics,
      'docxMetrics': docxMetrics,
      'paginationMetrics': paginationMetrics,
      'pageErrors': pageErrors,
      'screenshot': screenshot.path,
      'docxScreenshot': docxScreenshot.path,
      'docxFullPageScreenshot': docxFullPageScreenshot.path,
      'paginatedScreenshot': paginatedScreenshot.path,
    };
    await File('${output.path}/tiptap_demo_harness.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    await File('${output.path}/tiptap_demo_console.log').writeAsString(
      console.join('\n'),
      flush: true,
    );

    _check(pageErrors.isEmpty, 'Browser emitted page errors: $pageErrors');
    stdout.writeln('Validated theme toggle, horizontal rule, and undo.');
    stdout.writeln('Saved ${screenshot.path}');
  } finally {
    await page.close();
  }
}

Future<void> _waitUntil(
  Page page,
  String predicate,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    if (await page.evaluate(predicate) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Timed out waiting for $description.');
}

String? _browserExecutable() {
  final configured = Platform.environment['CHROME_EXECUTABLE'];
  if (configured != null && File(configured).existsSync()) return configured;

  final candidates = <String>[
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
