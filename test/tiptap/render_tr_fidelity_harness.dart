import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Real-document regression for the 140-page Termo de Referência fixture.
///
/// It validates the exact failure modes reported against the browser DOM and
/// against the generated vector PDF: stable page count near the 140-page Word
/// reference, repeated media,
/// editable VML box text, and contiguous Word table-grid columns.
Future<void> main(List<String> args) async {
  final root = Directory.current.absolute;
  final output = Directory('${root.path}/test/output')
    ..createSync(recursive: true);
  if (!args.contains('--no-compile')) {
    final result = await Process.run(
      'dart',
      [
        'compile',
        'js',
        'web/tiptap_demo.dart',
        '-o',
        'web/tiptap_demo.dart.js'
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) throw StateError('dart2js failed');
  }

  final server = await shelf_io.serve(
    createStaticHandler('${root.path}/web',
        defaultDocument: 'tiptap_demo.html'),
    InternetAddress.loopbackIPv4,
    0,
  );
  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: _browserExecutable(),
      headless: !args.contains('--headed'),
      args: const ['--force-device-scale-factor=1', '--disable-gpu'],
    );
    final page = await browser.newPage();
    final errors = <String>[];
    final pageCountTrace = <String>[];
    final paginationMeasureTrace = <String>[];
    page.onError.listen((error) => errors.add('$error'));
    page.onConsole.listen((message) {
      final text = message.text ?? '';
      if (text.startsWith('TR_PAGE_COUNT ')) {
        pageCountTrace.add(text.substring('TR_PAGE_COUNT '.length));
      }
      if (text.startsWith('TR_PAGINATION_MEASURE ')) {
        paginationMeasureTrace
            .add(text.substring('TR_PAGINATION_MEASURE '.length));
      }
    });
    await page.setViewport(DeviceViewport(width: 1440, height: 1000));
    await page.goto(
      'http://127.0.0.1:${server.port}/tiptap_demo.html?paginationTrace=1',
      wait: Until.networkIdle,
    );
    await page.waitForSelector('.ProseMirror', visible: true);
    await page.evaluate(r'''() => {
      const editor = document.querySelector('.ProseMirror');
      let previous = editor?.dataset.pageCount || '0';
      const started = performance.now();
      console.log(`TR_PAGE_COUNT 0:${previous}`);
      new MutationObserver(() => {
        const current = editor?.dataset.pageCount || '0';
        if (current === previous) return;
        previous = current;
        console.log(`TR_PAGE_COUNT ${Math.round(performance.now() - started)}:${current}`);
      }).observe(editor, {attributes:true, attributeFilter:['data-page-count']});
    }''');
    final source = File(
      '${root.path}/resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx',
    );
    final input = await page.$('#open-docx-input');
    await input.uploadFile([source]);
    if (args.contains('--experiment-word-table-spacing')) {
      await page.evaluate(r'''() => {
        const style = document.createElement('style');
        style.id = 'tr-word-table-spacing-experiment';
        style.textContent = `
          .ProseMirror[data-tiptap-pages="true"] > table { margin: 0 !important; }
          .ProseMirror[data-tiptap-pages="true"] > table > tbody > tr > th,
          .ProseMirror[data-tiptap-pages="true"] > table > tbody > tr > td {
            padding-top: 0 !important;
            padding-bottom: 0 !important;
          }
        `;
        document.head.appendChild(style);
        document.querySelector('.ProseMirror')
          ?.setAttribute('data-tr-spacing-experiment', 'true');
      }''');
    }
    if (args.contains('--experiment-disable-letter-spacing')) {
      await page.evaluate(r'''() => {
        const style = document.createElement('style');
        style.id = 'tr-letter-spacing-experiment';
        style.textContent = `
          .ProseMirror span { letter-spacing: normal !important; }
        `;
        document.head.appendChild(style);
        document.querySelector('.ProseMirror')
          ?.setAttribute('data-tr-letter-spacing-experiment', 'true');
      }''');
    }
    if (args.contains('--pagination-trace')) {
      final traceSeconds = args
          .where((arg) => arg.startsWith('--trace-seconds='))
          .map((arg) => int.tryParse(arg.substring('--trace-seconds='.length)))
          .whereType<int>()
          .firstOrNull;
      await Future<void>.delayed(Duration(seconds: traceSeconds ?? 20));
      final layoutDiagnostics = Map<String, dynamic>.from(
        await page.evaluate(r'''() => {
          const editor = document.querySelector('.ProseMirror');
          const pagination = editor?.querySelector('[data-tiptap-pagination]');
          const scale = editor && editor.offsetWidth
            ? editor.getBoundingClientRect().width / editor.offsetWidth : 1;
          const px = name => parseFloat(getComputedStyle(editor)
            .getPropertyValue(name)) || 0;
          const spacer = pagination?.querySelector(
            '.tiptap-page-break[data-page-index="1"] .tiptap-page-spacer');
          const capacity = parseFloat(spacer?.style.marginTop || '') ||
            (px('--tiptap-page-height') - px('--tiptap-page-margin-top') -
              px('--tiptap-page-margin-bottom'));
          const inBody = element =>
            !element.closest('[data-tiptap-pagination]');
          const paragraphs = [...editor.querySelectorAll('p,h1,h2,h3,h4,h5,h6')]
            .filter(inBody);
          const rows = [...editor.querySelectorAll('tr')].filter(inBody);
          const tables = [...editor.querySelectorAll(':scope > table')];
          const rowHeights = rows.map(row =>
            row.getBoundingClientRect().height / scale);
          let atomicRowPages = 1;
          let atomicRowUsed = 0;
          let atomicRowWaste = 0;
          for (const height of rowHeights) {
            if (atomicRowUsed > 0 && atomicRowUsed + height > capacity) {
              atomicRowWaste += capacity - atomicRowUsed;
              atomicRowPages++;
              atomicRowUsed = 0;
            }
            atomicRowUsed += height;
          }
          atomicRowWaste += Math.max(0, capacity - atomicRowUsed);
          const distribution = new Map();
          for (const paragraph of paragraphs) {
            const s = getComputedStyle(paragraph);
            const key = [s.fontFamily, s.fontSize, s.lineHeight,
              s.marginTop, s.marginBottom].join('|');
            distribution.set(key, (distribution.get(key) || 0) + 1);
          }
          const topRows = rows.map(row => ({
            height: row.getBoundingClientRect().height / scale,
            cells: row.children.length,
            text: row.textContent.trim().replace(/\s+/g, ' ').slice(0, 100),
            breakInside: getComputedStyle(row).breakInside,
          })).sort((a,b) => b.height - a.height).slice(0, 15);
          const lastContent = editor.lastElementChild;
          const breaker = pagination?.lastElementChild?.querySelector('.breaker');
          const doc = JSON.parse(window.getTiptapJSON?.() || '{}');
          return {
            pageCount: Number(editor?.dataset.pageCount || 0),
            sourcePageCount: doc?.attrs?.sourcePageCount || null,
            scale, capacity,
            pageHeight: px('--tiptap-page-height'),
            pageGap: px('--tiptap-page-gap'),
            paragraphs: paragraphs.length,
            tables: tables.length,
            rows: rows.length,
            oversizedRows: rows.filter(row =>
              row.getBoundingClientRect().height / scale > capacity + 1).length,
            totalRowHeight: rows.reduce((sum,row) =>
              sum + row.getBoundingClientRect().height / scale, 0),
            continuousRowPages: Math.ceil(
              rowHeights.reduce((sum,height) => sum + height, 0) / capacity),
            atomicRowPages,
            atomicRowWaste,
            firstCellPadding: rows[0]?.firstElementChild ? {
              top:getComputedStyle(rows[0].firstElementChild).paddingTop,
              bottom:getComputedStyle(rows[0].firstElementChild).paddingBottom,
            } : null,
            totalParagraphHeight: paragraphs.reduce((sum,p) =>
              sum + p.getBoundingClientRect().height / scale, 0),
            lastGap: lastContent && breaker
              ? (lastContent.getBoundingClientRect().bottom -
                  breaker.getBoundingClientRect().bottom) / scale : null,
            paragraphStyles: [...distribution.entries()]
              .map(([style,count]) => ({style,count}))
              .sort((a,b) => b.count - a.count).slice(0, 20),
            topRows,
          };
        }''') as Map,
      );
      stdout.writeln('TR page-count trace: ${pageCountTrace.join(', ')}');
      stdout.writeln(
        'TR pagination measures: ${paginationMeasureTrace.join(', ')}',
      );
      stdout.writeln(
        'TR layout diagnostics: '
        '${const JsonEncoder.withIndent('  ').convert(layoutDiagnostics)}',
      );
      await File('${output.path}/tiptap_tr_pagination_trace.json')
          .writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'samples': pageCountTrace,
          'measures': paginationMeasureTrace,
          'layout': layoutDiagnostics,
          'browserErrors': errors,
        }),
        flush: true,
      );
      return;
    }
    await _waitUntil(
      page,
      '''() => document.querySelector('.ProseMirror')?.textContent.includes('TERMO DE REFERÊNCIA')''',
      'TR body import',
      const Duration(seconds: 40),
    );
    await _waitUntil(
      page,
      '''() => Number(document.querySelector('.ProseMirror')?.dataset.pageCount || 0) > 50''',
      'TR pagination',
      const Duration(seconds: 40),
    );
    await _waitUntil(
      page,
      '''() => [...document.querySelectorAll('.tiptap-page-header img,.tiptap-page-footer img')].every(img => img.complete && img.naturalWidth > 0)''',
      'TR repeated media decoding',
      const Duration(seconds: 40),
    );
    final stablePages = await _stablePageCount(page);

    final metrics = Map<String, dynamic>.from(await page.evaluate('''() => {
      const editor = document.querySelector('.ProseMirror');
      const bodyRows = [...editor.children]
        .filter(node => node.tagName === 'TABLE')
        .flatMap(table => [...table.querySelectorAll(':scope > tbody > tr')]);
      const widest = bodyRows
        .filter(row => row.children.length >= 3)
        .sort((a, b) => b.children.length - a.children.length)[0];
      const cells = widest ? [...widest.children].map(cell => {
        const r = cell.getBoundingClientRect();
        const style = getComputedStyle(cell);
        const paragraph = cell.querySelector('p');
        const text = paragraph?.querySelector('span') || paragraph;
        const paragraphStyle = paragraph ? getComputedStyle(paragraph) : null;
        const textStyle = text ? getComputedStyle(text) : null;
        return {
          left:r.left, right:r.right, width:r.width,
          text:cell.textContent.trim().slice(0,30),
          columnIndex:cell.dataset.columnIndex || '',
          colSpan:cell.colSpan,
          inlineStyle:cell.getAttribute('style') || '',
          minWidth:style.minWidth,
          cssWidth:style.width,
          gridColumn:style.gridColumn,
          padding:[style.paddingTop, style.paddingRight,
            style.paddingBottom, style.paddingLeft].join(' '),
          paragraphs:cell.querySelectorAll(':scope > p').length,
          paragraphFont:paragraphStyle ? {
            family:paragraphStyle.fontFamily,
            size:paragraphStyle.fontSize,
            lineHeight:paragraphStyle.lineHeight,
            letterSpacing:paragraphStyle.letterSpacing,
            textAlign:paragraphStyle.textAlign,
          } : null,
          textFont:textStyle ? {
            family:textStyle.fontFamily,
            size:textStyle.fontSize,
            lineHeight:textStyle.lineHeight,
            letterSpacing:textStyle.letterSpacing,
          } : null,
        };
      }) : [];
      const headerImage = editor.querySelector('.tiptap-page-header img');
      const footerImage = editor.querySelector('.tiptap-page-footer img');
      const processBox = [...editor.querySelectorAll('.tiptap-page-header table')]
        .find(table => table.textContent.includes('Continuação de Processo'));
      const contractTable = [...editor.querySelectorAll(':scope > table')]
        .find(table => table.textContent.includes('GRUPO 1'));
      const contractRows = contractTable
        ? [...contractTable.querySelectorAll(':scope > tbody > tr')]
            .slice(0, 10).map((row, rowIndex) => ({
              rowIndex,
              height:row.getBoundingClientRect().height,
              cells:[...row.children].map((cell, cellIndex) => {
                const paragraph = cell.querySelector('p');
                const text = paragraph?.querySelector('span') || paragraph;
                const paragraphStyle = paragraph ? getComputedStyle(paragraph) : null;
                const textStyle = text ? getComputedStyle(text) : null;
                return {
                  cellIndex,
                  width:cell.getBoundingClientRect().width,
                  height:cell.getBoundingClientRect().height,
                  text:cell.textContent.trim(),
                  paragraphs:cell.querySelectorAll(':scope > p').length,
                  paragraphFont:paragraphStyle ? {
                    family:paragraphStyle.fontFamily,
                    size:paragraphStyle.fontSize,
                    lineHeight:paragraphStyle.lineHeight,
                    letterSpacing:paragraphStyle.letterSpacing,
                    textAlign:paragraphStyle.textAlign,
                  } : null,
                  textFont:textStyle ? {
                    family:textStyle.fontFamily,
                    size:textStyle.fontSize,
                    lineHeight:textStyle.lineHeight,
                    letterSpacing:textStyle.letterSpacing,
                  } : null,
                };
              }),
            }))
        : [];
      const inventoryTable = [...editor.querySelectorAll(':scope > table')]
        .find(table => table.querySelectorAll(':scope > tbody > tr').length > 1000);
      const inventoryRows = inventoryTable
        ? [...inventoryTable.querySelectorAll(':scope > tbody > tr')]
        : [];
      const inventoryFirstRow = inventoryRows.find(row => row.children.length === 2)
        || inventoryRows[0];
      const inventoryCells = inventoryFirstRow
        ? [...inventoryFirstRow.children].map(cell => {
            const style = getComputedStyle(cell);
            return {
              width:cell.getBoundingClientRect().width,
              padding:[style.paddingTop, style.paddingRight,
                style.paddingBottom, style.paddingLeft].join(' '),
              colspan:cell.colSpan,
            };
          })
        : [];
      const bounds = editor.getBoundingClientRect();
      const relative = element => element ? {
        top:element.getBoundingClientRect().top - bounds.top,
        bottom:element.getBoundingClientRect().bottom - bounds.top,
        height:element.getBoundingClientRect().height,
      } : null;
      return {
        pageCount:Number(editor.dataset.pageCount || 0),
        tables:editor.querySelectorAll(':scope > table').length,
        columnTrack:widest?.style.gridTemplateColumns || '',
        widestRowWidth:widest?.getBoundingClientRect().width || 0,
        widestTableStyle:widest?.closest('table')?.getAttribute('style') || '',
        cells,
        headerImageWidth:headerImage?.getBoundingClientRect().width || 0,
        footerImageWidth:footerImage?.getBoundingClientRect().width || 0,
        headerImages:editor.querySelectorAll('.tiptap-page-header img').length,
        footerImages:editor.querySelectorAll('.tiptap-page-footer img').length,
        processBoxWidth:processBox?.getBoundingClientRect().width || 0,
        contractRows,
        inventoryTable:{
          rows:inventoryRows.length,
          width:inventoryTable?.getBoundingClientRect().width || 0,
          rowWidth:inventoryFirstRow?.getBoundingClientRect().width || 0,
          grid:inventoryFirstRow?.style.gridTemplateColumns || '',
          cells:inventoryCells,
          totalRowHeight:inventoryRows.reduce(
            (sum, row) => sum + row.getBoundingClientRect().height, 0),
          maxRowHeight:inventoryRows.reduce(
            (height, row) => Math.max(height, row.getBoundingClientRect().height), 0),
        },
        headerText:editor.querySelector('.tiptap-page-header')?.textContent || '',
        footerText:editor.querySelector('.tiptap-page-footer')?.textContent || '',
        pageHeight:getComputedStyle(editor).getPropertyValue('--tiptap-page-height'),
        pageGap:getComputedStyle(editor).getPropertyValue('--tiptap-page-gap'),
        anchors:[1,2,3,4,12,140].map(page => ({
          page,
          header:(() => {
            const region=editor.querySelector('.tiptap-page-header[data-page-number="' + page + '"]');
            return {
              ...relative(region),
              image:relative(region?.querySelector('img')),
              box:relative(region?.querySelector('table')),
            };
          })(),
          footer:(() => {
            const region=editor.querySelector('.tiptap-page-footer[data-page-number="' + page + '"]');
            return {
              ...relative(region),
              image:relative(region?.querySelector('img')),
            };
          })(),
        })),
      };
    }''') as Map);
    _check(metrics['pageCount'] == stablePages, 'page count did not settle');
    // Word can split a table row across pages when w:cantSplit is absent. The
    // current CSS-grid rows are atomic, so the faithful w:trHeight values leave
    // a measured two-page overhead until synchronized cell fragmentation is
    // implemented. Keep that known delta bounded instead of hiding it by
    // shrinking the imported rows below their OOXML height.
    const referencePages = 140;
    _check(
        (stablePages - referencePages).abs() <= 2,
        'TR drifted too far from the $referencePages-page Word reference: '
        '$stablePages pages');
    _check((metrics['tables'] as int) > 10, 'TR tables were not imported');
    _check((metrics['columnTrack'] as String).contains('px'),
        'tblGrid did not reach CSS grid tracks');
    final cells = (metrics['cells'] as List).cast<Map>();
    stdout.writeln('TR widest table: ${jsonEncode({
          'columnTrack': metrics['columnTrack'],
          'rowWidth': metrics['widestRowWidth'],
          'tableStyle': metrics['widestTableStyle'],
          'cells': cells,
        })}');
    for (var index = 1; index < cells.length; index++) {
      final gap = (cells[index]['left'] as num).toDouble() -
          (cells[index - 1]['right'] as num).toDouble();
      _check(gap.abs() < 1.5, 'table columns have a ${gap}px gap');
      _check((cells[index]['width'] as num) > 1, 'table column collapsed');
    }
    final inventory =
        (metrics['inventoryTable'] as Map).cast<String, dynamic>();
    _check(inventory['rows'] == 1367,
        'inventory table row count changed: ${inventory['rows']}');
    _check((inventory['grid'] as String).contains('1px'),
        'sub-pixel OOXML compatibility track was discarded');
    final inventoryCells = (inventory['cells'] as List).cast<Map>();
    _check(inventoryCells.length == 2,
        'inventory table did not preserve its two logical cells');
    final firstShare = (inventoryCells.first['width'] as num).toDouble() /
        (inventory['rowWidth'] as num).toDouble();
    _check(firstShare > .07 && firstShare < .09,
        'inventory first column is ${(firstShare * 100).toStringAsFixed(2)}%');
    _check((metrics['headerImageWidth'] as num) > 400,
        'header artwork is still undersized');
    _check((metrics['footerImageWidth'] as num) > 500,
        'footer artwork is still undersized');
    _check(metrics['headerImages'] == stablePages,
        'not every TR page received the default header artwork');
    _check(metrics['footerImages'] == stablePages,
        'not every TR page received the default footer artwork');
    _check((metrics['processBoxWidth'] as num) > 170,
        'VML process box is still undersized');
    _check((metrics['headerText'] as String).contains('44505/2025'),
        'process box content is missing');

    await page.evaluate(
      '() => document.getElementById("document-viewport").scrollTop = 0',
    );
    await File('${output.path}/tiptap_tr_editor.png').writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png),
      flush: true,
    );

    final encoded = await page.evaluate(
      'async () => await window.getTiptapPdfBase64()',
    );
    final pdfBytes = base64.decode(encoded as String);
    final pdf = File('${output.path}/tiptap_tr_export.pdf');
    await pdf.writeAsBytes(pdfBytes, flush: true);
    final sourceText = latin1.decode(pdfBytes);
    final pdfPages = RegExp(r'/Type /Page\b').allMatches(sourceText).length;
    final imageObjects =
        RegExp(r'/Subtype /Image\b').allMatches(sourceText).length;
    final imageDraws = RegExp(r'/I\d+ Do').allMatches(sourceText).length;
    _check(pdfPages == stablePages,
        'PDF has $pdfPages pages, editor has $stablePages');
    _check(sourceText.contains('(Continuação de Processo) Tj'),
        'PDF omitted header text box');
    // The PAGE field is a separate run. Depending on whether the source run
    // owns the separator, the literal is emitted with or without a trailing
    // space before its own Tj operator.
    _check(
        sourceText.contains('(Página ) Tj') ||
            sourceText.contains('(Página) Tj'),
        'PDF omitted footer text');
    _check(sourceText.contains('(1.1.) Tj'),
        'PDF omitted hierarchical Word numbering labels');
    _check(imageObjects > 0, 'PDF omitted header/footer media');
    _check(imageObjects < 20,
        'Repeated header/footer images were embedded $imageObjects times');
    _check(imageDraws >= stablePages * 2,
        'PDF drew only $imageDraws header/footer images for $stablePages pages');
    _check(errors.isEmpty, 'Browser errors: $errors');

    final report = {
      'metrics': metrics,
      'referencePages': referencePages,
      'pageDelta': stablePages - referencePages,
      'stablePages': stablePages,
      'pdfPages': pdfPages,
      'pdfBytes': pdfBytes.length,
      'pdfImageObjects': imageObjects,
      'pdfImageDraws': imageDraws,
      'browserErrors': errors,
      'pdf': pdf.path,
    };
    await File('${output.path}/tiptap_tr_fidelity.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    await page.close();
  } finally {
    await browser?.close();
    await server.close(force: true);
  }
}

Future<int> _stablePageCount(Page page) async {
  var previous = -1;
  var stable = 0;
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    final current = await page.evaluate(
      '() => Number(document.querySelector(".ProseMirror").dataset.pageCount || 0)',
    ) as int;
    if (current == previous) {
      stable++;
      if (stable >= 8) return current;
    } else {
      previous = current;
      stable = 0;
      stdout.writeln('TR pagination pass: $current pages');
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  throw TimeoutException('TR page count did not stabilize');
}

Future<void> _waitUntil(
    Page page, String predicate, String description, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await page.evaluate(predicate) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException('Timed out waiting for $description');
}

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

String? _browserExecutable() {
  for (final path in [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
  ]) {
    if (File(path).existsSync()) return path;
  }
  return null;
}
