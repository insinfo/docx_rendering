import 'dart:async';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

/// Automated visual-fidelity render harness.
///
/// Pipeline (fully repeatable, headless):
///   1. Compile `example/web/main.dart` -> `example/web/main.dart.js`.
///   2. Serve `example/web` on 127.0.0.1:<port> via shelf_static.
///   3. For every .docx in `resources/` (or the files passed on argv):
///        - open the page, upload the file, wait for render to complete,
///        - save a full-page PNG + the rendered HTML to `test/output/`.
///
/// Usage:
///   dart run test/render_harness.dart                # render all resources/*.docx
///   dart run test/render_harness.dart resources/x.docx
///   dart run test/render_harness.dart --no-compile   # skip the JS compile step
const _chromePath = r'C:\Program Files\Google\Chrome\Application\chrome.exe';
// 8081 (not 8080) so the harness never collides with a running `webdev serve`.
const _port = 8081;

Future<void> main(List<String> argv) async {
  final projectRoot = Directory.current.path;
  final skipCompile = argv.contains('--no-compile');
  final fileArgs = argv.where((a) => !a.startsWith('--')).toList();

  final outputDir = Directory('$projectRoot/test/output')
    ..createSync(recursive: true);

  // 1. Resolve the list of .docx files to render.
  final docxFiles = <File>[];
  if (fileArgs.isNotEmpty) {
    docxFiles.addAll(fileArgs.map((p) => File(p)));
  } else {
    final resources = Directory('$projectRoot/resources');
    docxFiles.addAll(resources
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.docx'))
        .where((f) => !_baseNameRaw(f.path).startsWith('~\$')));
  }
  if (docxFiles.isEmpty) {
    stderr.writeln('No .docx files found to render.');
    exit(1);
  }

  // 2. Compile the web entrypoint to JS.
  if (!skipCompile) {
    stdout.writeln('==> Compiling example/web/main.dart ...');
    final result = await Process.run(
      'dart',
      ['compile', 'js', 'example/web/main.dart', '-o', 'example/web/main.dart.js'],
      workingDirectory: projectRoot,
    );
    stdout.write(result.stdout);
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr);
      stderr.writeln('Compile failed.');
      exit(result.exitCode);
    }
  }

  // 3. Serve example/web.
  final handler = createStaticHandler('example/web', defaultDocument: 'index.html');
  final server = await io.serve(handler, InternetAddress.loopbackIPv4, _port);
  stdout.writeln('==> Serving http://${server.address.host}:${server.port}');

  // 4. Launch the browser.
  final browser = await puppeteer.launch(
    executablePath: File(_chromePath).existsSync() ? _chromePath : null,
    args: ['--force-device-scale-factor=1'],
  );

  try {
    for (final docx in docxFiles) {
      final name = _baseName(docx.path);
      stdout.writeln('\n==> Rendering $name ...');
      await _renderOne(browser, docx, name, outputDir);
    }
  } finally {
    await browser.close();
    await server.close(force: true);
  }

  stdout.writeln('\n==> Done. Output in ${outputDir.path}');
  exit(0);
}

Future<void> _renderOne(
    Browser browser, File docx, String name, Directory outputDir) async {
  final page = await browser.newPage();
  await page.setViewport(DeviceViewport(width: 1200, height: 1400));

  final rendered = Completer<void>();
  final logs = <String>[];
  page.onConsole.listen((msg) {
    final text = msg.text ?? '';
    logs.add('[${msg.type}] $text');
    if (text.contains('Render complete!') && !rendered.isCompleted) {
      rendered.complete();
    }
    if (text.contains('Render error') && !rendered.isCompleted) {
      rendered.completeError(StateError(text));
    }
  });
  page.onError.listen((err) {
    logs.add('PAGE ERROR: $err');
  });

  await page.goto('http://127.0.0.1:$_port', wait: Until.networkIdle);

  // Neutralize the example page's constraining container styles so the
  // screenshot reflects the library's true page-sized output (docx wrapper).
  await page.evaluate('''() => {
    const s = document.createElement('style');
    s.textContent = `
      body { background: #808080 !important; padding: 0 !important; margin: 0 !important; }
      #container { max-width: none !important; margin: 0 !important; padding: 0 !important;
                   background: transparent !important; box-shadow: none !important; }
    `;
    document.head.appendChild(s);
  }''');

  // Upload the docx into the file input and fire the change event.
  final input = await page.waitForSelector('#fileInput');
  await input!.uploadFile([docx]);
  await page.evaluate('''() => {
    const input = document.getElementById('fileInput');
    input.dispatchEvent(new Event('change'));
  }''');

  // Wait for the render-complete console signal (with a hard timeout fallback).
  try {
    await rendered.future.timeout(const Duration(seconds: 30));
  } on TimeoutException {
    stdout.writeln('   ! render-complete signal not seen in 30s, continuing');
  }
  // Let images decode / async tasks settle.
  await Future.delayed(const Duration(seconds: 2));

  // Capture stats about what was rendered.
  final stats = await page.evaluate('''() => {
    const c = document.getElementById('container');
    const ps = Array.from(c.querySelectorAll('article > p'));
    const lh = {};   // computed line-height -> count
    const ff = {};   // font-family (first) -> count
    let empty = 0, emptyH = 0;
    for (const p of ps) {
      const cs = getComputedStyle(p);
      const k = cs.lineHeight;
      lh[k] = (lh[k] || 0) + 1;
      if (!p.textContent.trim()) { empty++; emptyH += p.getBoundingClientRect().height; }
      const span = p.querySelector('span');
      if (span) { const f = getComputedStyle(span).fontFamily.split(',')[0]; ff[f] = (ff[f]||0)+1; }
    }
    return {
      pages: c.querySelectorAll('section.docx').length,
      paragraphs: c.querySelectorAll('p').length,
      tables: c.querySelectorAll('table').length,
      images: c.querySelectorAll('img').length,
      imagesLoaded: Array.from(c.querySelectorAll('img')).filter(i => i.complete && i.naturalWidth > 0).length,
      pageFields: Array.from(c.querySelectorAll('[data-docx-field="PAGE"]')).slice(0,3).map(e=>e.textContent),
      numFields: Array.from(c.querySelectorAll('[data-docx-field="NUMPAGES"]')).slice(0,2).map(e=>e.textContent),
      lineHeights: lh, fonts: ff, emptyParas: empty, emptyParaTotalH: Math.round(emptyH),
    };
  }''');
  stdout.writeln('   pages=${stats['pages']} paragraphs=${stats['paragraphs']} '
      'tables=${stats['tables']} images=${stats['imagesLoaded']}/${stats['images']} loaded');
  stdout.writeln('   PAGE=${stats['pageFields']} NUMPAGES=${stats['numFields']}');
  stdout.writeln('   lineHeights=${stats['lineHeights']}');
  stdout.writeln('   fonts=${stats['fonts']}  emptyParas=${stats['emptyParas']} (Σh=${stats['emptyParaTotalH']}px)');

  // Full-page screenshot.
  final png = await page.screenshot(fullPage: true, format: ScreenshotFormat.png);
  final pngFile = File('${outputDir.path}/$name.png')..writeAsBytesSync(png);

  // Readable top-of-document crop (first page region) at full resolution.
  final topCrop = await page.screenshot(
    format: ScreenshotFormat.png,
    clip: Rectangle(0, 0, 1200, 1500),
  );
  File('${outputDir.path}/${name}__top.png').writeAsBytesSync(topCrop);

  // Mid-document crop (useful to inspect table splits across page boundaries).
  final midCrop = await page.screenshot(
    format: ScreenshotFormat.png,
    clip: Rectangle(0, 1750, 1200, 1500),
  );
  File('${outputDir.path}/${name}__mid.png').writeAsBytesSync(midCrop);

  // Optional: crop around the first element whose text contains FIND (env var),
  // for comparing a specific region against the reference PDF pages.
  final find = Platform.environment['FIND'];
  if (find != null && find.isNotEmpty) {
    final top = await page.evaluate('''(needle) => {
      const els = Array.from(document.querySelectorAll('#container *'));
      const el = els.find(e => e.children.length === 0 && e.textContent.includes(needle));
      if (!el) return -1;
      const r = el.getBoundingClientRect();
      return Math.max(0, r.top + window.scrollY - 120);
    }''', args: [find]);
    if (top is num && top >= 0) {
      final findCrop = await page.screenshot(
        format: ScreenshotFormat.png,
        clip: Rectangle(0, top.toInt(), 1200, 1500),
      );
      File('${outputDir.path}/${name}__find.png').writeAsBytesSync(findCrop);
      stdout.writeln('   FIND "$find" -> crop at y=${top.toInt()}');
    } else {
      stdout.writeln('   FIND "$find" not found');
    }
  }

  // HTML dump of the rendered container (for structural inspection).
  final html = await page.evaluate('''() => document.getElementById('container').outerHTML''');
  File('${outputDir.path}/$name.html').writeAsStringSync(html as String);

  // Save console logs for debugging.
  File('${outputDir.path}/$name.log').writeAsStringSync(logs.join('\n'));

  stdout.writeln('   saved ${pngFile.path}');
  await page.close();
}

String _baseNameRaw(String path) => path.replaceAll('\\', '/').split('/').last;

String _baseName(String path) {
  var n = path.replaceAll('\\', '/').split('/').last;
  if (n.toLowerCase().endsWith('.docx')) n = n.substring(0, n.length - 5);
  // Sanitize for filesystem.
  return n.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
