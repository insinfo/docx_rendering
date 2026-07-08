

image.png
1919×1079

image.png
1919×1079

image.png
1919×1079

image.png
1919×1079
c#22-22
crie um plano em C:\MyDartProjects\docx_rendering\doc  com foco em melhorar a fidelidade visual da rendrização de arquivos docx C:\MyDartProjects\docx_rendering\resources e comece aimplementar para testes use o puppeteer: ^3.19.0
I'll start by exploring the project structure to understand the current state of the DOCX rendering code before creating a plan.

Read c:\MyDartProjects\docx_rendering\pubspec.yaml
Globpattern: "**/*.dart"
Found 83 files
Globpattern: "resources/**/*"
Found 2 files
Bash List project root and doc directory
IN
ls -la c:/MyDartProjects/docx_rendering/ && echo "---DOC---" && ls -la c:/MyDartProjects/docx_rendering/doc/ 2>/dev/null || echo "no doc dir"

OUT
total 73
drwxr-xr-x 1 isaque.santana 197121     0 Jul  8 03:09 .
drwxr-xr-x 1 isaque.santana 197121     0 Jul  7 02:58 ..
drwxr-xr-x 1 isaque.santana 197121     0 Jul  6 01:28 .dart_tool
drwxr-xr-x 1 isaque.santana 197121     0 Jul  7 04:54 .git
-rw-r--r-- 1 isaque.santana 197121    39 Jul  6 01:37 .gitignore
-rw-r--r-- 1 isaque.santana 197121 16023 Jul  7 02:18 ROTEIRO.md
drwxr-xr-x 1 isaque.santana 197121     0 Jul  8 03:09 doc
drwxr-xr-x 1 isaque.santana 197121     0 Jul  6 01:26 example
drwxr-xr-x 1 isaque.santana 197121     0 Jul  6 01:37 lib
-rw-r--r-- 1 isaque.santana 197121 17904 Jul  6 00:45 pubspec.lock
-rw-r--r-- 1 isaque.santana 197121   707 Jul  6 00:31 pubspec.yaml
drwxr-xr-x 1 isaque.santana 197121     0 Jul  6 00:28 referencias
drwxr-xr-x 1 isaque.santana 197121     0 Jul  8 03:10 resources
drwxr-xr-x 1 isaque.santana 197121     0 Jul  6 01:41 scripts
drwxr-xr-x 1 isaque.santana 197121     0 Jul  7 04:47 test
drwxr-xr-x 1 isaque.santana 197121     0 Jul  6 01:28 web
---DOC---
total 4
drwxr-xr-x 1 isaque.santana 197121 0 Jul  8 03:09 .
drwxr-xr-x 1 isaque.santana 197121 0 Jul  8 03:09 ..
This is a substantial pure-Dart DOCX-to-HTML rendering library. Let me read the key files to understand the architecture before planning.

Read c:\MyDartProjects\docx_rendering\ROTEIRO.md
Read c:\MyDartProjects\docx_rendering\lib\docx_rendering.dart
Read c:\MyDartProjects\docx_rendering\test\take_screenshot.dart
This is a pure-Dart port of docx-preview (docxjs). There's already puppeteer test infrastructure and a shelf server. Let me examine the rendering pipeline and serving setup in depth.

Read c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_core.dart
Read c:\MyDartProjects\docx_rendering\scripts\server.dart
Read c:\MyDartProjects\docx_rendering\example\web\main.dart
Read c:\MyDartProjects\docx_rendering\web\main.dart
Let me read the main renderer, styles rendering, public API, and the example HTML to complete my understanding of the fidelity pipeline.

Read c:\MyDartProjects\docx_rendering\lib\src\html_renderer.dart
Read c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_styles.dart
Read c:\MyDartProjects\docx_rendering\lib\src\docx_preview.dart
Let me examine the remaining renderer files, the drawings parser, and the example HTML to identify current fidelity gaps.

Read c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_blocks.dart
Read c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_tables.dart
Bash List referencias, example, test dirs and gitignore
IN
echo "=== referencias ===" && ls c:/MyDartProjects/docx_rendering/referencias/ 2>/dev/null && echo "=== example/web ===" && ls -la c:/MyDartProjects/docx_rendering/example/web/ && echo "=== test ===" && ls -la c:/MyDartProjects/docx_rendering/test/ && echo "=== .gitignore ===" && cat c:/MyDartProjects/docx_rendering/.gitignore

OUT
=== referencias ===
FortuneExcel-main
docxjs-master
fortune-sheet-master
=== example/web ===
total 12
drwxr-xr-x 1 isaque.santana 197121    0 Jul  6 01:29 .
drwxr-xr-x 1 isaque.santana 197121    0 Jul  6 01:26 ..
-rw-r--r-- 1 isaque.santana 197121  806 Jul  6 01:26 index.html
-rw-r--r-- 1 isaque.santana 197121 1020 Jul  6 01:29 main.dart
=== test ===
total 216
drwxr-xr-x 1 isaque.santana 197121      0 Jul  7 04:47 .
drwxr-xr-x 1 isaque.santana 197121      0 Jul  8 03:09 ..
-rw-r--r-- 1 isaque.santana 197121   3311 Jul  6 01:47 docx_test.dart
drwxr-xr-x 1 isaque.santana 197121      0 Jul  6 01:44 extended-props-test
-rw-r--r-- 1 isaque.santana 197121    781 Jul  7 04:37 inspect_doc_xml.dart
-rw-r--r-- 1 isaque.santana 197121   1540 Jul  7 04:36 inspect_docx.dart
-rw-r--r-- 1 isaque.santana 197121    887 Jul  7 04:36 inspect_styles.dart
drwxr-xr-x 1 isaque.santana 197121      0 Jul  6 01:44 render-test
-rw-r--r-- 1 isaque.santana 197121   2555 Jul  7 04:32 take_screenshot.dart
-rw-r--r-- 1 isaque.santana 197121 184739 Jul  5 20:25 test.docx
=== .gitignore ===
.dart_tool/
pubspec.lock

errors.txt
Read c:\MyDartProjects\docx_rendering\lib\src\parser\document_parser_drawings.dart
Read c:\MyDartProjects\docx_rendering\example\web\index.html
Bash Check dart, chrome, compiled JS availability
IN
cd c:/MyDartProjects/docx_rendering && echo "=== dart version ===" && dart --version 2>&1 | head -1; echo "=== compiled JS in example? ===" && ls -la example/web/*.js 2>/dev/null || echo "no js"; echo "=== chrome? ===" && ls "C:/Program Files/Google/Chrome/Application/chrome.exe" 2>/dev/null && echo "chrome found" || echo "no chrome at default path"; echo "=== build dir ===" && ls .dart_tool/build/ 2>/dev/null | head

OUT
=== dart version ===
Dart SDK version: 3.6.2 (stable) (Wed Jan 29 01:20:39 2025 -0800) on "windows_x64"
=== compiled JS in example? ===
no js
=== chrome? ===
C:/Program Files/Google/Chrome/Application/chrome.exe
chrome found
=== build dir ===
entrypoint
fcd1995bc647fb959e82ea360c6c2c9a
generated
I now have a thorough understanding. This is a pure-Dart port of docx-preview that renders DOCX → HTML in the browser. The target resource files are complex Brazilian government documents (headers with coat-of-arms, footer logos, justified Arial text, numbered headings, multi-page bordered tables with merged/shaded cells). Let me de-risk the build/render path and set up todo tracking before writing the plan.

Bash Inspect root web and test subdirs
IN
cd c:/MyDartProjects/docx_rendering && echo "=== root web/ ===" && ls -la web/ && echo "=== test/render-test ===" && ls test/render-test/ 2>/dev/null && echo "=== test/extended-props-test ===" && ls test/extended-props-test/ 2>/dev/null

OUT
=== root web/ ===
total 12
drwxr-xr-x 1 isaque.santana 197121    0 Jul  6 01:28 .
drwxr-xr-x 1 isaque.santana 197121    0 Jul  8 03:09 ..
-rw-r--r-- 1 isaque.santana 197121  806 Jul  6 01:26 index.html
-rw-r--r-- 1 isaque.santana 197121 1097 Jul  7 04:46 main.dart
=== test/render-test ===
equation
footnote
header-footer
line-spacing
numbering
page-layout
revision
table
table-spans
test.spec.js
text
text-break
underlines
=== test/extended-props-test ===
document.docx
extended-props.spec.js
Let me de-risk the critical path — compiling the Dart web app to JS. This determines the whole test harness design.

Bash Compile example web entrypoint to JS
IN
cd c:/MyDartProjects/docx_rendering && echo "Compiling example/web/main.dart to JS..." && time dart compile js example/web/main.dart -o example/web/main.dart.js 2>&1 | tail -30

OUT
Compiling example/web/main.dart to JS...
Compiled 13,190,392 input bytes (8,179,184 characters source) to 687,838 characters JavaScript in 5.54 seconds using 0.000 MB of memory

real	0m8.410s
user	0m0.031s
sys	0m0.015s
Compile works cleanly in ~8s via dart compile js. That de-risks the entire harness. Now let me set up tracking and build an automated render/screenshot harness.

Update Todos

Build automated puppeteer render harness (compile → serve → upload docx → screenshot + HTML dump)

Run harness to capture baseline renders of both resource docx files

Compare baseline renders vs Word screenshots to build concrete fidelity gap list

Write the visual-fidelity improvement plan in doc/

Implement first high-impact fidelity fix and verify via harness
Now let me build a robust, repeatable render harness. This is the foundation of all fidelity work — it compiles, serves, drives puppeteer, and captures both a full-page screenshot and the rendered HTML for each resource file.

Write c:\MyDartProjects\docx_rendering\test\render_harness.dart
164 lines
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
const _port = 8080;

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
        .where((f) => f.path.toLowerCase().endsWith('.docx')));
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
    logs.add('[${msg.type}] ${msg.text}');
    if (msg.text.contains('Render complete!') && !rendered.isCompleted) {
      rendered.complete();
    }
    if (msg.text.contains('Render error') && !rendered.isCompleted) {
      rendered.completeError(StateError(msg.text));
    }
  });
  page.onError.listen((err) {
    logs.add('PAGE ERROR: $err');
  });

  await page.goto('http://127.0.0.1:$_port', wait: Until.networkIdle);

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
    return {
      pages: c.querySelectorAll('section.docx').length,
      paragraphs: c.querySelectorAll('p').length,
      tables: c.querySelectorAll('table').length,
      images: c.querySelectorAll('img').length,
      imagesLoaded: Array.from(c.querySelectorAll('img')).filter(i => i.complete && i.naturalWidth > 0).length,
    };
  }''');
  stdout.writeln('   pages=${stats['pages']} paragraphs=${stats['paragraphs']} '
      'tables=${stats['tables']} images=${stats['imagesLoaded']}/${stats['images']} loaded');

  // Full-page screenshot.
  final png = await page.screenshot(fullPage: true, format: ScreenshotFormat.png);
  final pngFile = File('${outputDir.path}/$name.png')..writeAsBytesSync(png);

  // HTML dump of the rendered container (for structural inspection).
  final html = await page.evaluate('''() => document.getElementById('container').outerHTML''');
  File('${outputDir.path}/$name.html').writeAsStringSync(html as String);

  // Save console logs for debugging.
  File('${outputDir.path}/$name.log').writeAsStringSync(logs.join('\n'));

  stdout.writeln('   saved ${pngFile.path}');
  await page.close();
}

String _baseName(String path) {
  var n = path.replaceAll('\\', '/').split('/').last;
  if (n.toLowerCase().endsWith('.docx')) n = n.substring(0, n.length - 5);
  // Sanitize for filesystem.
  return n.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
The puppeteer ConsoleMessage.text is nullable. Let me fix those.

Edit c:\MyDartProjects\docx_rendering\test\render_harness.dart
Added 1 line
Now let me run the harness to capture baseline renders of both documents.

Bash Run render harness on both resource docx files
IN
cd c:/MyDartProjects/docx_rendering && dart run test/render_harness.dart --no-compile 2>&1 | tail -40

OUT
==> Serving http://127.0.0.1:8080

==> Rendering PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica ...
   pages=1 paragraphs=534 tables=3 images=2/2 loaded
   saved C:\MyDartProjects\docx_rendering/test/output/PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.png

==> Rendering PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_ ...
   pages=3 paragraphs=4428 tables=22 images=5/5 loaded
   saved C:\MyDartProjects\docx_rendering/test/output/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_.png

==> Rendering __CTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_ ...
Unhandled exception:
Bad state: Render error: FormatException: Invalid ZIP archive: end of central directory not found.
Both real documents rendered (ETP: 534 paragraphs/3 tables/2 images; TR: 3 pages/22 tables/5 images). It crashed on a Word lock file (~$...). Let me exclude temp files, then view the baseline screenshots.

Edit c:\MyDartProjects\docx_rendering\test\render_harness.dart
Added 1 line
Edit c:\MyDartProjects\docx_rendering\test\render_harness.dart
Added 2 lines
Now let me view the baseline screenshots to assess current fidelity against the Word originals.

Read c:\MyDartProjects\docx_rendering\test\output\PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.png
The full-page image is one giant 17k-px column — the biggest immediate issue is visible: no pagination (everything renders as a single continuous section, not A4 pages). The scaled-down image hides detail, so let me inspect the rendered HTML structure and capture high-resolution crops of the header and first table.

Bash Inspect rendered HTML structure and styles
IN
cd c:/MyDartProjects/docx_rendering/test/output && echo "=== file sizes ===" && ls -la *.png *.html && echo "" && echo "=== ETP html: first 60 lines (structure/styles) ===" && head -c 6000 "PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.html"

OUT
=== file sizes ===
-rw-r--r-- 1 isaque.santana 197121   310789 Jul  8 03:16 PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.html
-rw-r--r-- 1 isaque.santana 197121  1660188 Jul  8 03:16 PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.png
-rw-r--r-- 1 isaque.santana 197121  1985077 Jul  8 03:16 PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_.html
-rw-r--r-- 1 isaque.santana 197121 16492250 Jul  8 03:16 PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_.png

=== ETP html: first 60 lines (structure/styles) ===
<div id="container"><style>.docx-wrapper { background: gray; padding: 30px; padding-bottom: 0px; display: flex; flex-flow: column; align-items: center; } 
.docx-wrapper>section.docx { background: white; box-shadow: 0 0 10px rgba(0, 0, 0, 0.5); margin-bottom: 30px; }
.docx { color: black; hyphens: auto; text-underline-position: from-font; }
section.docx { box-sizing: border-box; display: flex; flex-flow: column nowrap; position: relative; overflow: hidden; }
section.docx > article { margin-bottom: auto; z-index: 1; }
section.docx > footer { z-index: 1; }
.docx table { border-collapse: collapse; }
.docx table td, .docx table th { vertical-align: top; }
.docx p { margin: 0pt; min-height: 1em; }
.docx span { white-space: pre-wrap; overflow-wrap: break-word; }
.docx a { color: inherit; text-decoration: inherit; }
.docx svg { fill: transparent; }
</style><style>.docx {
  --docx-majorHAnsi-font: Calibri Light;
  --docx-minorHAnsi-font: Calibri;
  --docx-dk1-color: #000000;
  --docx-lt1-color: #FFFFFF;
  --docx-dk2-color: #44546A;
  --docx-lt2-color: #E7E6E6;
  --docx-accent1-color: #4472C4;
  --docx-accent2-color: #ED7D31;
  --docx-accent3-color: #A5A5A5;
  --docx-accent4-color: #FFC000;
  --docx-accent5-color: #5B9BD5;
  --docx-accent6-color: #70AD47;
  --docx-hlink-color: #0563C1;
  --docx-folHlink-color: #954F72;
}
</style><style>.docx_default span {
  font-family: 'Times New Roman', 'MS Mincho';
}

.docx_default p {
}

.docx p, p.docx_normal {
}

.docx p, p.docx_normal span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

p.docx_ttulo1 {
  margin-top: 24.00pt;
}

p.docx_ttulo1 span {
  font-family: Calibri, 'MS Gothic', 'Times New Roman';
  font-weight: bold;
  color: #365F91;
  font-size: 14.00pt;
}

p.docx_ttulo2 {
  margin-right: 0.05pt;
  text-align: center;
}

p.docx_ttulo2 span {
  font-family: 'Times New Roman';
  font-weight: bold;
  color: #000000;
  font-size: 12.00pt;
}

p.docx_ttulo3 {
  margin-top: 2.00pt;
  line-height: 1.07;
}

p.docx_ttulo3 span {
  font-family: Calibri, 'MS Gothic', 'Times New Roman';
  color: #243F60;
  font-size: 12.00pt;
}

p.docx_ttulo4 {
  margin-top: 2.00pt;
}

p.docx_ttulo4 span {
  font-family: Calibri, 'MS Gothic', 'Times New Roman';
  font-style: italic;
  color: #365F91;
  font-size: 12.00pt;
}

p.docx_ttulo6 {
  margin-top: 2.00pt;
  line-height: 1.07;
}

p.docx_ttulo6 span {
  font-family: Calibri, 'MS Gothic', 'Times New Roman';
  color: #243F60;
  font-size: 11.00pt;
}

.docx table, table.docx_tabelanormal td {
}

.docx_wwoutlineliststyle p {
}

p.docx_nivel01 {
  margin-top: 12.00pt;
  margin-bottom: 6.00pt;
  line-height: 1.15;
  margin-left: 0.00pt;
  text-indent: 0.00pt;
  text-align: justify;
}

p.docx_nivel01 span {
  font-family: Arial;
  color: black;
  font-size: 10.00pt;
  font-weight: bold;
}

p.docx_nvel1-semnum {
  margin-left: 17.85pt;
  margin-top: 12.00pt;
  margin-bottom: 6.00pt;
  line-height: 1.15;
  text-indent: 0.00pt;
  text-align: justify;
}

p.docx_nvel1-semnum span {
  color: #FF0000;
  font-family: Arial;
  font-size: 10.00pt;
  font-weight: bold;
}

p.docx_pargrafodalista {
  margin-left: 36.00pt;
}

p.docx_pargrafodalista span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

p.docx_pargrafodalista span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

p.docx_normalweb {
  margin-top: 5.00pt;
  margin-bottom: 5.00pt;
}

p.docx_normalweb span {
  font-family: 'Times New Roman';
  font-size: 12.00pt;
}

p.docx_textodebalo span {
  font-family: Tahoma;
  font-size: 8.00pt;
}

p.docx_textodebalo {
}

span.docx_textodebalochar {
  font-family: Tahoma;
  font-size: 8.00pt;
}

span.docx_ttulo2char {
  font-weight: bold;
  color: #000000;
  font-size: 12.00pt;
}

p.docx_nvel2 {
  margin-bottom: 6.00pt;
  text-align: justify;
}

p.docx_nvel2 span {
  font-family: Arial, 'Times New Roman';
  font-weight: bold;
  font-size: 12.00pt;
}

span.docx_normalchar1 {
  font-family: Arial;
  text-decoration: underline;
  font-size: 12.00pt;
}

span.docx_hyperlink {
  color: #000080;
  text-decoration: underline;
}

p.docx_citao {
  border-top: 0.50pt solid #1F497D;
  border-left: 0.50pt solid #1F497D;
  border-bottom: 0.50pt solid #1F497D;
  border-right: 0.50pt solid #1F497D;
  background-color: #FFFFCC;
  margin-top: 6.00pt;
  text-align: justify;
}

p.docx_citao span {
  font-family: Arial, Calibri;
  font-style: italic;
  color: #000000;
  font-size: 10.00pt;
}

span.docx_citaochar {
  font-family: Arial, Calibri, Tahoma;
  font-style: italic;
  color: #000000;
  background-color: #FFFFCC;
}

p.docx_commarcadores5 {
}

p.docx_commarcadores5 span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

p.docx_notaexplicativa span {
  font-family: Arial, Calibri;
  font-style: italic;
  color: #000000;
  font-size: 10.00pt;
}

p.docx_notaexplicativa {
  border-top: 0.50pt solid #1F497D;
  border-left: 0.50pt solid #1F497D;
  border-bottom: 0.50pt solid #1F497D;
  border-right: 0.50pt solid #1F497D;
  background-color: #FFFFCC;
  margin-top: 6.00pt;
  text-align: justify;
}

span.docx_notaexplicativachar {
  font-family: Arial, Calibri, Tahoma;
  font-style: italic;
  color: #000000;
  background-color: #FFFFCC;
}

p.docx_cabealho {
}

p.docx_cabealho span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

span.docx_cabealhochar {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

p.docx_rodap {
}

p.docx_rodap span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

p.docx_rodap span {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

span.docx_rodapchar {
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
  font-size: 12.00pt;
}

span.docx_refdecomentrio {
  font-size: 8.00pt;
}

p.docx_textodecomentrio span {
  font-size: 10.00pt;
  font-family: Ecofont_Spranq_eco_Sans, Tahoma;
}

p.docx_textodecomentrio {
}

p.docx_textodecomentrio span {
  font-fami
Now I can see concrete fidelity issues. Two important ones: (1) no pagination — the whole doc is one giant section; (2) the example page's #container { max-width: 900px; padding: 40px } constrains the page box, so the screenshot doesn't reflect the library's true page-sized output. Let me update the harness to neutralize that container styling and capture a readable top-of-page crop, then re-render.

Edit c:\MyDartProjects\docx_rendering\test\render_harness.dart
Added 12 lines
Edit c:\MyDartProjects\docx_rendering\test\render_harness.dart
Added 7 lines
Bash Re-run harness with clean container and top crop
IN
cd c:/MyDartProjects/docx_rendering && dart run test/render_harness.dart --no-compile 2>&1 | tail -20

OUT
==> Serving http://127.0.0.1:8080

==> Rendering PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica ...
   pages=1 paragraphs=534 tables=3 images=2/2 loaded
   saved C:\MyDartProjects\docx_rendering/test/output/PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.png

==> Rendering PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_ ...
   pages=3 paragraphs=4428 tables=22 images=5/5 loaded
   saved C:\MyDartProjects\docx_rendering/test/output/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_.png

==> Done. Output in C:\MyDartProjects\docx_rendering/test/output
Now let me view the readable top crops of both documents to compare against the Word originals.

Read c:\MyDartProjects\docx_rendering\test\output\PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica__top.png
Excellent — this is very readable and the body rendering is actually quite faithful (justified Arial, numbered headings, bullets, correct text). The dominant defect is the header: the coat-of-arms image, the "ESTADO DO RIO DE JANEIRO…" address block, and the "Continuação de Processo" box are all overlapping/stacked instead of laid out horizontally (arms left, address center, bordered box right). Let me inspect the header's rendered HTML and its source XML to diagnose.

Bash Extract rendered header HTML from ETP output
IN
cd c:/MyDartProjects/docx_rendering/test/output && echo "=== header region in rendered HTML ===" && grep -o '<header[^>]*>.*</header>' "PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.html" | head -c 4000

OUT
=== header region in rendered HTML ===
<header style="margin-top: calc(-66.1333px); min-height: calc(66.1333px);"><p class="docx_cabealho"><span><div><svg style="position:absolute;margin-left:79.3pt;margin-top:-7.8pt;width:130.5pt;height:59.25pt;z-index:251659264;visibility:visible;mso-wrap-style:square;mso-width-percent:0;mso-height-percent:0;mso-wrap-distance-left:9pt;mso-wrap-distance-top:3.6pt;mso-wrap-distance-right:9pt;mso-wrap-distance-bottom:3.6pt;mso-position-horizontal:right;mso-position-horizontal-relative:margin;mso-position-vertical:absolute;mso-position-vertical-relative:text;mso-width-percent:0;mso-height-percent:0;mso-width-relative:margin;mso-height-relative:margin;v-text-anchor:top"><g><foreignObject width="100%" height="100%"><p style="text-align: center"><span style="font-size: 10.00pt;text-decoration: underline">Continuação de Processo</span></p><p><span style="font-size: 10.00pt">Processo nº </span><span style="font-weight: bold;font-size: 10.00pt">44505</span><span style="font-weight: bold;font-size: 10.00pt">/2025</span></p><p><span style="font-size: 10.00pt">Folha: ___</span><span style="font-size: 10.00pt">___</span><span style="font-size: 10.00pt">_ </span></p><p><span style="font-size: 10.00pt">Rubrica: </span><span style="font-size: 10.00pt">MSS </span><span style="font-size: 10.00pt">Mat. </span><span style="font-size: 10.00pt">3888-1</span></p></foreignObject></g></svg></div></span><span><div style="width: 369.13pt; height: 45.8pt; display: inline-block; position: relative; text-indent: 0px;"><img style="position: relative;left: 0.00pt;top: 0.00pt;width: 377.25pt;height: 46.81pt" src="data:image/jpeg;base64,/9j/4QBORXhpZgAATU0AKgAAAAgAAwEaAAUAAAABAAAAMgEbAAUAAAABAAAAOgEoAAMAAAABAAIAAAAAAAAACvyAAAAnEAAK/IAAACcQAAAAAP/tAEBQaG90b3Nob3AgMy4wADhCSU0EBgAAAAAABwAIAQEAAQEAOEJJTQQlAAAAAAAQAAAAAAAAAAAAAAAAAAAAAP/iDFhJQ0NfUFJPRklMRQABAQAADEhMaW5vAhAAAG1udHJSR0IgWFlaIAfOAAIACQAGADEAAGFjc3BNU0ZUAAAAAElFQyBzUkdCAAAAAAAAAAAAAAAAAAD21gABAAAAANMtSFAgIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEWNwcnQAAAFQAAAAM2Rlc2MAAAGEAAAAbHd0cHQAAAHwAAAAFGJrcHQAAAIEAAAAFHJYWVoAAAIYAAAAFGdYWVoAAAIsAAAAFGJYWVoAAAJAAAAAFGRtbmQAAAJUAAAAcGRtZGQAAALEAAAAiHZ1ZWQAAANMAAAAhnZpZXcAAAPUAAAAJGx1bWkAAAP4AAAAFG1lYXMAAAQMAAAAJHRlY2gAAAQwAAAADHJUUkMAAAQ8AAAIDGdUUkMAAAQ8AAAIDGJUUkMAAAQ8AAAIDHRleHQAAAAAQ29weXJpZ2h0IChjKSAxOTk4IEhld2xldHQtUGFja2FyZCBDb21wYW55AABkZXNjAAAAAAAAABJzUkdCIElFQzYxOTY2LTIuMQAAAAAAAAAAAAAAEnNSR0IgSUVDNjE5NjYtMi4xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABYWVogAAAAAAAA81EAAQAAAAEWzFhZWiAAAAAAAAAAAAAAAAAAAAAAWFlaIAAAAAAAAG+iAAA49QAAA5BYWVogAAAAAAAAYpkAALeFAAAY2lhZWiAAAAAAAAAkoAAAD4QAALbPZGVzYwAAAAAAAAAWSUVDIGh0dHA6Ly93d3cuaWVjLmNoAAAAAAAAAAAAAAAWSUVDIGh0dHA6Ly93d3cuaWVjLmNoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGRlc2MAAAAAAAAALklFQyA2MTk2Ni0yLjEgRGVmYXVsdCBSR0IgY29sb3VyIHNwYWNlIC0gc1JHQgAAAAAAAAAAAAAALklFQyA2MTk2Ni0yLjEgRGVmYXVsdCBSR0IgY29sb3VyIHNwYWNlIC0gc1JHQgAAAAAAAAAAAAAAAAAAAAAAAAAAAABkZXNjAAAAAAAAACxSZWZlcmVuY2UgVmlld2luZyBDb25kaXRpb24gaW4gSUVDNjE5NjYtMi4xAAAAAAAAAAAAAAAsUmVmZXJlbmNlIFZpZXdpbmcgQ29uZGl0aW9uIGluIElFQzYxOTY2LTIuMQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdmlldwAAAAAAE6T+ABRfLgAQzxQAA+3MAAQTCwADXJ4AAAABWFlaIAAAAAAATAlWAFAAAABXH+dtZWFzAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAACjwAAAAJzaWcgAAAAAENSVCBjdXJ2AAAAAAAABAAAAAAFAAoADwAUABkAHgAjACgALQAyADcAOwBAAEUASgBPAFQAWQBeAGMAaABtAHIAdwB8AIEAhgCLAJAAlQCaAJ8ApACpAK4AsgC3ALwAwQDGAMsA0ADVANsA4ADlAOsA8AD2APsBAQEHAQ0BEwEZAR8BJQErATIBOAE+AUUBTAFSAVkBYAFnAW4BdQF8AYMBiwGSAZoBoQGpAbEBuQHBAckB0QHZAeEB6QHyAfoCAwIMAhQCHQImAi8COAJBAksCVAJdAmcCcQJ6AoQCjgKYAqICrAK2AsECywLVAuAC6wL1AwADCwMWAyEDLQM4A0MDTwNaA2YDcgN+A4oDlgOiA64DugPHA9MD4APsA/kEBgQTBCAELQQ7BEgEVQRjBHEEfgSMBJoEqAS2BMQE0wThBPAE/gUNBRwFKwU6BUkFWAVnBXcFhgWWBaYFtQXFBdUF5QX2BgYGFgYnBjcGSAZZBmoGewaMBp0GrwbABtEG4wb1BwcHGQcrBz0HTwdhB3QHhgeZB6wHvwfSB+UH+AgLCB8IMghGCFoIbgiCCJYIqgi+CNII5wj7CRAJJQk6CU8JZAl5CY8JpAm6Cc8J5Qn7ChEKJwo9ClQKagqBCpgKrgrFCtwK8wsLCyILOQtRC2kLgAuYC7ALyAvhC/kMEgwqDEMMXAx1DI4MpwzADNkM8w0NDS
Now the header defect is fully diagnosed. The header contains a VML textbox (the "Continuação de Processo" box), rendered as <svg><foreignObject> with the raw VML style copied verbatim — including position:absolute; margin-left:79.3pt; mso-position-horizontal:right. Browsers ignore the mso-position-* hints, so the box lands top-left over the crest/address instead of top-right, and the textbox border is dropped. Let me check the TR document's top crop (the heavy-table doc) before finalizing the gap list.

Read c:\MyDartProjects\docx_rendering\test\output\PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica___top.png
The TR render is genuinely faithful — tables (borders, colspans, wrapping, bold, column widths) match Word closely, and the header lays out horizontally. The one shared defect is the "Continuação de Processo" VML textbox: in TR it's positioned right but clipped off the page edge; in ETP it overlaps the crest/address. Both stem from VML textbox positioning (mso-position-* ignored) and the missing box border. Let me examine the VML renderer/parser to scope the fix.

Read c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_vml.dart
Read c:\MyDartProjects\docx_rendering\lib\src\vml\vml.dart
I now understand the VML pipeline: _renderVmlElement dumps the raw VML style string (with position:absolute; margin-left; mso-position-horizontal:right; …) straight onto the <svg>, and browsers ignore every mso-* hint — so the box mispositions and the stroke never draws. Let me read html.dart (the h() helper) and the parts renderer to see how styles/headers flow, so my fix is correct.

Read c:\MyDartProjects\docx_rendering\lib\src\html.dart
I now have a complete picture. Let me update tracking and write the comprehensive plan, then implement the first fix.

Baseline verdict: Body text, headings, bullets, and especially the complex multi-page tables render with high fidelity. The dominant defect is the VML textbox ("Continuação de Processo" box) mispositioning (raw mso-position-* styles browsers ignore), plus no dynamic pagination. Let me write the plan.

Update Todos

Build automated puppeteer render harness (compile → serve → upload docx → screenshot + HTML dump)

Run harness to capture baseline renders of both resource docx files

Compare baseline renders vs Word screenshots to build concrete fidelity gap list

Write the visual-fidelity improvement plan in doc/

Implement first high-impact fidelity fix (VML textbox positioning) and verify via harness
Write c:\MyDartProjects\docx_rendering\doc\PLANO_FIDELIDADE_VISUAL.md
215 lines
# PLANO — Fidelidade Visual da Renderização DOCX

> **Escopo:** `docx_rendering` (porte Dart puro do docx-preview/docxjs).
> **Meta:** aproximar a renderização HTML do que o Microsoft Word exibe, usando
> como documentos-alvo os arquivos em `resources/` (ETP e TR — modelos de
> governo do Município de Rio das Ostras).
> **Ferramenta de teste:** Puppeteer (`^3.19.0`) dirigindo Chrome headless.
> **Atualizado:** 2026-07-08.

---

## 1. Objetivo

Elevar a **fidelidade visual** (o quão perto o HTML renderizado fica do PDF/Word
original) sem quebrar a arquitetura existente (Dart puro + `package:web`, saída
HTML/CSS no browser). O trabalho é orientado por evidência: cada mudança é
validada com screenshots automatizados antes/depois via o *harness* Puppeteer.

Não-objetivos (por ora): editar/salvar DOCX, paginação dinâmica pixel-perfect
(o docx-preview é estático por design), suporte fora do browser.

---

## 2. Metodologia de teste (harness Puppeteer)

O harness `test/render_harness.dart` é a espinha dorsal do trabalho de fidelidade.
Ele torna a renderização **reproduzível e headless**:

1. Compila `example/web/main.dart` → `example/web/main.dart.js` (`dart compile js`).
2. Sobe um servidor estático (shelf) em `127.0.0.1:8080` servindo `example/web`.
3. Para cada `.docx` em `resources/` (ignora arquivos de lock `~$…`):
   - abre a página, faz upload do arquivo, dispara `change`;
   - espera o sinal de console `Render complete!` (timeout 30 s);
   - neutraliza o CSS do `#container` do exemplo para que o screenshot reflita a
     saída real da lib (o "wrapper" de páginas do docx-preview);
   - salva em `test/output/`:
     - `<nome>.png` — screenshot de página inteira (regressão visual completa);
     - `<nome>__top.png` — recorte legível do topo (1200×1500) para inspeção;
     - `<nome>.html` — HTML renderizado (inspeção estrutural/CSS);
     - `<nome>.log` — logs de console (depuração).

### Como rodar

```bash
# renderiza todos os resources/*.docx (compila antes)
dart run test/render_harness.dart

# pula a compilação (itera rápido em mudanças só de Dart-lib já compiladas)
dart run test/render_harness.dart --no-compile

# um arquivo específico
dart run test/render_harness.dart resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx
```

> **Ciclo de iteração:** editar lib → `dart run test/render_harness.dart`
> (recompila) → abrir `test/output/*__top.png` → comparar com o Word.
> Estatísticas impressas por documento: nº de páginas, parágrafos, tabelas e
> imagens carregadas — servem como *smoke test* numérico.

### Próximos incrementos do harness (ver Fase 4)

- Recortes por região (cabeçalho, rodapé, cada tabela) para diffs focados.
- Diff de imagem pixel-a-pixel contra um baseline aprovado (detectar regressão).
- Baseline "verdade" a partir de PNGs exportados pelo próprio Word.

---

## 3. Diagnóstico da linha de base

Renderização atual dos dois documentos-alvo (baseline capturado em
`test/output/`). **A base já é boa** — corpo de texto, títulos e tabelas saem
com alta fidelidade. Os problemas concentram-se em objetos flutuantes (VML) e
paginação.

| Aspecto | Estado | Evidência / observação |
|---|---|---|
| Texto justificado (Arial) | ✅ Fiel | Alinhamento, quebra e espaçamento batem com o Word |
| Títulos numerados (1., 2., 3., 4.) | ✅ Fiel | Negrito, tamanho e numeração corretos |
| Listas com marcadores | ✅ Fiel | Bullets e recuo próximos do original |
| Tabelas multi-página (TR) | ✅ Fiel | Bordas, `colspan` (SUBTOTAL), merge vertical, larguras de coluna, quebra de célula e negrito corretos |
| Imagens (brasão, logos) | ✅ Carregam | `images loaded = 2/2` (ETP), `5/5` (TR); base64 embutido OK |
| Fontes / cores de tema | ✅ OK | Variáveis `--docx-*-color`, mapeamento de fontes de estilo aplicados |
| **Caixa VML "Continuação de Processo"** | ❌ **Falha** | Posicionada errada — sobrepõe brasão/endereço (ETP) ou é cortada à direita (TR); sem borda |
| **Composição do cabeçalho (objetos flutuantes)** | ⚠️ Parcial | Sobreposição no ETP; no TR o layout horizontal sai bem |
| **Paginação dinâmica** | ⚠️ Limitação | ETP vira 1 "página" gigante (17 000 px); Word tem várias. Cabeçalho/rodapé aparecem 1× em vez de por página |
| Borda de textbox / autoshapes VML | ❌ Falta | `<v:shape>` vira `<g>` sem retângulo de contorno; stroke não desenha |
| Rodapé (logos GOVTIC/DIGITAL) | ⚠️ Verificar | Imagens carregam; conferir alinhamento horizontal dos 3 logos |

### Causa-raiz dos defeitos principais

**(D1) Caixa VML mal posicionada** — `lib/src/renderer/html_renderer_vml.dart:14-16`:
o `cssStyleText` bruto do VML é jogado direto no atributo `style` do `<svg>`.
Esse texto contém `position:absolute; margin-left:79.3pt; …;
mso-position-horizontal:right; mso-position-horizontal-relative:margin; …`.
O browser **ignora todas as propriedades `mso-*`**, então a caixa não vai para a
margem direita — fica no canto superior esquerdo (deslocada por `margin-left`),
sobrepondo o brasão/endereço. Faltam também um bloco-contêiner posicionado
(`position: relative`) para ancorar o `right:0` na área de conteúdo e a borda.

**(D2) Paginação estática** — `_renderSections` em
`html_renderer_core.dart` só quebra página em quebras explícitas
(`w:br type="page"`), seções, ou `lastRenderedPageBreak` — e este último está
desligado por padrão (`ignoreLastRenderedPageBreak = true`,
`html_renderer.dart:97`). O Word pagina dinamicamente por medição de layout, o
que o docx-preview não faz por design. Como cabeçalho/rodapé são renderizados
por página, um documento de 1 página só mostra 1 cabeçalho.

---

## 4. Backlog priorizado

Ordenado por (impacto visual ÷ risco/esforço). Cada item: **problema → causa →
abordagem → risco**.

### TIER 1 — Alto impacto, escopo isolado

**F1. Posicionamento da caixa VML (textbox flutuante)** — *defeito nº 1, aparece
nos dois documentos.*
- **Causa:** D1 acima.
- **Abordagem:**
  1. Adicionar `_translateVmlStyle(String raw)` que faz o *parse* do style VML
     em um `Map<String,String>`, **remove ruído** (`mso-*`, `v-*`,
     `*-percent`) e **traduz** as dicas de posição:
     - `mso-position-horizontal:right` → `right:0` (remove `left`/`margin-left`);
       `left`/`inside` → `left:0`; `center` → `left:0;right:0;margin:auto`.
     - `mso-position-vertical:top` → `top:0`; `bottom` → `bottom:0`;
       `center` → centraliza; caso contrário mantém `margin-top` como offset.
  2. Passar o Map (em vez do string bruto) no `_renderVmlElement`.
  3. Ancoragem: adicionar ao CSS default
     `section.docx header, section.docx footer { position: relative; }` para que
     o `right:0` da `<svg>` absoluta se meça pela **caixa de conteúdo** (entre
     margens) do cabeçalho/rodapé, alinhando à margem direita (como no Word).
- **Risco:** Baixo — afeta só o caminho VML, que hoje já sai errado.
- **Validação:** `__top.png` de ETP e TR — caixa no canto superior direito, sem
  sobrepor brasão/endereço, sem corte.
- **Status:** ✅ **implementado nesta iteração** (ver §7).

**F2. Borda/contorno de autoshapes e textboxes VML.**
- **Causa:** `<v:shape>`/`<v:rect>` viram `<g>`/`<rect>` mas o textbox
  (`foreignObject`) não recebe contorno; stroke em `<g>` não pinta.
- **Abordagem:** quando o shape tiver stroke (ou stroke default do VML, salvo
  `stroked="f"`), aplicar `border` via CSS no conteúdo do `foreignObject`
  (ou inserir `<rect fill="none" stroke=… width="100%" height="100%">` como
  primeiro filho). Ler cor/espessura de `<v:stroke>`/atributos `strokecolor`,
  `strokeweight`.
- **Risco:** Médio — precisa distinguir shapes com/sem borda.

### TIER 2 — Estrutural

**F3. Paginação aproximada via `lastRenderedPageBreak`.**
- **Abordagem:** permitir `ignoreLastRenderedPageBreak = false` (opção já
  existe) e garantir que o parser emita `WmlBreak(breakType:
  'lastRenderedPageBreak')` a partir de `<w:lastRenderedPageBreak>`. Isso
  reproduz *aproximadamente* a paginação que o Word gravou, fazendo
  cabeçalho/rodapé se repetirem por página.
- **Risco:** Médio — muda a contagem de páginas de muitos docs; validar que não
  fragmenta parágrafos incorretamente. Manter como **opção** (default atual
  preservado) para evitar regressão.

**F4. Cabeçalho/rodapé por página (consequência de F3).**
- Após F3, revisar `_renderHeaderFooter` para seleção default/even/first e as
  margens `calc(header - top)` em documentos multi-página reais.

### TIER 3 — Polimento

- **F5.** Rodapé: alinhamento horizontal dos logos (GOVTIC/DIGITAL/Rio das
  Ostras) e do número de página `Página X | Y`.
- **F6.** Precisão de recuo/espaçamento de listas (comparar `margin-left`/
  `text-indent` com o Word).
- **F7.** Tab stops (`w:tabs`) — a feature é `experimental` e hoje não computa
  posições reais (`_refreshTabStops` é no-op). Alinhamentos por tabulação em
  cabeçalhos podem depender disso.
- **F8.** Mapeamento de fontes ausentes (ex.: `Ecofont_Spranq_eco_Sans` →
  fallback). Conferir se o fallback casa com a métrica do Word.
- **F9.** Cores/sombreamento de células (`w:shd`) em cabeçalhos de tabela.

---

## 5. Métricas e critérios de aceite

- **Smoke numérico** (impresso pelo harness): páginas/parágrafos/tabelas/imagens
  não regridem entre execuções; `images loaded == images total`.
- **Inspeção visual:** `__top.png` de cada alvo revisado contra o screenshot do
  Word a cada mudança de Tier 1/2.
- **Sem regressão de análise:** `dart analyze` limpo (0 erros) após cada fix.
- **Meta Tier 1:** caixa "Continuação de Processo" no canto superior direito,
  com borda, sem sobreposição, nos dois documentos.
- **(Fase 4) Diff de pixels:** desvio < limiar acordado contra baseline aprovado.

---

## 6. Cronograma por fases

| Fase | Entrega | Itens |
|---|---|---|
| **0 — Harness** ✅ | Renderização headless reproduzível + baseline capturado | `test/render_harness.dart`, `test/output/*` |
| **1 — VML** | Objetos flutuantes fiéis | F1 ✅, F2 |
| **2 — Paginação** | Paginação aproximada opcional + header/footer por página | F3, F4 |
| **3 — Polimento** | Rodapé, listas, tabs, fontes, sombreamento | F5–F9 |
| **4 — Regressão** | Diff de pixels automatizado + baseline do Word | incrementos do harness |

---

## 7. Estado da implementação (esta iteração)

- ✅ **Harness Puppeteer** (`test/render_harness.dart`) — compila, serve, dirige
  o Chrome, captura PNG de página inteira + recorte de topo + HTML + logs para
  cada `resources/*.docx`. Base de todo o trabalho de fidelidade.
- ✅ **Baseline capturado** para ETP e TR em `test/output/`.
- ✅ **F1 — Posicionamento da caixa VML** implementado (ver detalhes abaixo,
  preenchido após a verificação).

> Referências de código citadas: caminho:linha apontam para o commit atual e
> podem deslocar conforme o código evolui.
Plan written. Now let me implement F1 — VML textbox positioning. Two changes: (1) add _translateVmlStyle that parses the VML style, strips mso-*/v-* noise, and translates positioning keywords into real CSS; (2) make header/footer positioned so the box anchors to the content area.

Edit c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_vml.dart
Added 2 lines
Now let me add the _translateVmlStyle function at the end of the VML renderer file:

Edit c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_vml.dart
Added 78 lines
Now add the anchoring rule to the default stylesheet so absolutely-positioned VML shapes in header/footer anchor to the content area:

Edit c:\MyDartProjects\docx_rendering\lib\src\renderer\html_renderer_styles.dart
Added 1 line
Now let me verify analysis is clean and re-run the harness (which recompiles) to see the effect.

Bash Analyze lib for errors
IN
cd c:/MyDartProjects/docx_rendering && echo "=== dart analyze (lib) ===" && dart analyze lib 2>&1 | tail -15

OUT
=== dart analyze (lib) ===
Analyzing lib...

warning - src\renderer\html_renderer_blocks.dart:45:6 - Unnecessary cast. Try removing the cast. - unnecessary_cast

1 issue found.
Clean (only a pre-existing unrelated warning). Now re-run the harness with recompile to verify the fix on both documents.

Bash Recompile and re-render both docs to verify VML fix
IN
cd c:/MyDartProjects/docx_rendering && dart run test/render_harness.dart 2>&1 | tail -20

OUT
==> Compiling example/web/main.dart ...
Compiled 13,193,059 input bytes (8,181,851 characters source) to 692,110 characters JavaScript in 6.19 seconds using 0.000 MB of memory
==> Serving http://127.0.0.1:8080

==> Rendering PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica ...
   pages=1 paragraphs=534 tables=3 images=2/2 loaded
   saved C:\MyDartProjects\docx_rendering/test/output/PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica.png

==> Rendering PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_ ...
   pages=3 paragraphs=4428 tables=22 images=5/5 loaded
   saved C:\MyDartProjects\docx_rendering/test/output/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica_.png

==> Done. Output in C:\MyDartProjects\docx_rendering/test/output
Let me view the top crops of both documents to verify the VML box now positions correctly.

Read c:\MyDartProjects\docx_rendering\test\output\PGCTIC1_-_ETP_-_Sistema_de_Gest_o_P_blica__top.png
The ETP header is now fixed — brasão left, address center (no overlap), and the "Continuação de Processo" box correctly in the top-right corner aligned to the right margin, matching the Word original. The only remaining detail is the box border (planned as F2). Let me confirm TR is fixed too (it was clipped off-page before).

Read c:\MyDartProjects\docx_rendering\test\output\PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recupera__o_Autom_tica___top.png
Both documents are fixed. TR's box — previously clipped ("Continuação de Pro…", "44505/202…" cut off at the page edge) — now renders fully in the top-right corner, matching Word. Let me finalize the plan doc with the confirmed result and close out the todos.

Edit c:\MyDartProjects\docx_rendering\doc\PLANO_FIDELIDADE_VISUAL.md
Added 22 lines
Update Todos

Build automated puppeteer render harness (compile → serve → upload docx → screenshot + HTML dump)

Run harness to capture baseline renders of both resource docx files

Compare baseline renders vs Word screenshots to build concrete fidelity gap list

Write the visual-fidelity improvement plan in doc/

Implement first high-impact fidelity fix (VML textbox positioning) and verify via harness
Pronto. Criei o plano e já comecei a implementação, com teste via Puppeteer.

O que foi entregue
1. Plano → doc/PLANO_FIDELIDADE_VISUAL.md
Diagnóstico da linha de base, backlog priorizado (F1–F9 em 3 tiers), métricas de aceite e cronograma por fases.

2. Harness Puppeteer → test/render_harness.dart
Pipeline headless e reproduzível: compila (dart compile js) → serve (shelf) → faz upload de cada resources/*.docx no Chrome → salva em test/output/ o PNG de página inteira, um recorte legível do topo, o HTML renderizado e os logs.


dart run test/render_harness.dart              # todos os docs (recompila)
dart run test/render_harness.dart --no-compile # itera rápido
3. Primeiro fix implementado e verificado — F1: posicionamento da caixa VML ("Continuação de Processo")

O defeito nº 1: o style bruto do VML era jogado no <svg> com mso-position-horizontal:right etc., que o browser ignora — a caixa sobrepunha o brasão/endereço (ETP) ou era cortada fora da página (TR).

Alterações:

html_renderer_vml.dart — nova _translateVmlStyle(): faz parse do style, remove ruído mso-*/v-* e traduz as âncoras de posição para CSS real (right/left/top/bottom).
html_renderer_styles.dart — header/footer viram position: relative para o right:0 ancorar na área de conteúdo (entre margens).
Resultado verificado nos dois documentos: a caixa agora fica no canto superior direito alinhada à margem direita, batendo com o Word — sem sobreposição (ETP) e sem corte (TR). dart analyze lib limpo, sem regressão numérica.

Notas importantes
A base já é boa: corpo justificado (Arial), títulos numerados, listas e sobretudo as tabelas multi-página do TR (bordas, colspan de SUBTOTAL, merge vertical, larguras) saem com alta fidelidade.
Próximos itens (no plano): F2 — desenhar a borda do retângulo da caixa (único detalhe que falta na caixa); F3 — paginação aproximada via lastRenderedPageBreak (o ETP hoje vira 1 página gigante, limitação de design do docx-preview).
Quer que eu siga com o F2 (borda da caixa) ou com o F3 (paginação) em seguida?


image.png
1919×1079
c:\MyDartProjects\docx_rendering\doc\PLANO_FIDELIDADE_VISUAL.md
sim continue implementando e acho que isso pode ajudar qualquei coisa clone na pasta referencias https://github.com/hugs7/tiptap-extension-pagination  https://github.com/RomikMakavana/tiptap-pagination/  https://github.com/adityayaduvanshi/tiptap-pagination-breaks  https://github.com/ueberdosis/tiptap/discussions/5719  https://github.com/adalat-ai-tech/tiptap-pages  Skip to content
adalat-ai-tech
tiptap-pages
Repository navigation
Code
Issues
2
 (2)
Pull requests
17
 (17)
Agents
Actions
Projects
Security and quality
Insights
Owner avatar
tiptap-pages
Public
adalat-ai-tech/tiptap-pages
Go to file
t
T
Name		
Prakhargoel8c
Prakhargoel8c
Merge pull request #34 from adalat-ai-tech/fix/dependencies
9414dd1
 · 
10 months ago
.github
fix: respect branch protection rules in deployment workflows
10 months ago
.husky
fix: comment out demo build in pre-push hook
10 months ago
demo
fix: ci/cd for version bumping
10 months ago
src
feat/ added /ci cd pipeline for linting, testing and added husky pre-…
10 months ago
tests
feat/added page extension package and test cases
10 months ago
.gitignore
feat/added page extension package and test cases
10 months ago
.npmignore
feat/added page extension package and test cases
10 months ago
LICENSE
feat/added page extension package and test cases
10 months ago
README.md
docs/updated readme file
10 months ago
eslint.config.js
feat/ added /ci cd pipeline for linting, testing and added husky pre-…
10 months ago
jest.config.cjs
feat/ added /ci cd pipeline for linting, testing and added husky pre-…
10 months ago
package-lock.json
fix: sync package version with NPM registry
10 months ago
package.json
fix: update package dependencies and improve compatibility
10 months ago
pnpm-lock.yaml
fix: update package dependencies and improve compatibility
10 months ago
test-cicd.md
feat/ added /ci cd pipeline for linting, testing and added husky pre-…
10 months ago
test-pr.md
feat/ added /ci cd pipeline for linting, testing and added husky pre-…
10 months ago
tsconfig.json
feat/added play wright tests
10 months ago
Repository files navigation
README
MIT license
📄 PageExtension for Tiptap
A fully isolated Tiptap extension that provides automatic page management, pagination, and professional document styling. This extension automatically wraps your content in pages and handles all the complex pagination logic with advanced features like copy-paste functionality, cross-page operations, and comprehensive error handling.

✨ Features
🔄 Automatic Page Creation: Content is automatically wrapped in <page> nodes
📊 Smart Pagination: Automatically splits content across pages when it overflows
🎨 Professional Styling: A4 dimensions, proper margins, and shadows
🔢 Page Numbering: Configurable page numbers with positioning options
🔒 Fully Isolated: No external dependencies on app-level stores or CSS
📝 TypeScript Support: Full type definitions included
💉 CSS Auto-Injection: Styles are automatically applied when the extension is added
📋 Advanced Copy-Paste: Comprehensive copy-paste functionality across pages
🌍 International Support: Multi-language and Unicode character support
⚡ Performance Optimized: Efficient pagination algorithms and memory management
🚀 Installation
npm install @adalat-ai/page-extension
# or
yarn add @adalat-ai/page-extension
# or
pnpm add @adalat-ai/page-extension
📖 Basic Usage
import { useEditor } from '@tiptap/react';
import { PageExtension, PageDocument } from '@adalat-ai/page-extension';
import { 
  Paragraph, 
  Text, 
  Bold, 
  Italic, 
  Underline,
  Heading, 
  BulletList, 
  OrderedList, 
  ListItem 
} from '@tiptap/starter-kit';

const editor = useEditor({
  extensions: [
    PageDocument, // Required: Enforces PAGE node structure
    PageExtension.configure({
      // Required: Page dimensions
      bodyHeight: 1123, // A4 height at 96 DPI (29.7cm = 11.69in × 96 DPI)
      bodyWidth: 794,   // A4 width at 96 DPI (21.0cm = 8.27in × 96 DPI)
      
      // Optional: Page layout settings
      pageLayout: {
        margins: {
          top: { unit: 'INCHES', value: 0.75 },
          bottom: { unit: 'INCHES', value: 0.75 },
          left: { unit: 'INCHES', value: 0.5 },
          right: { unit: 'INCHES', value: 0.5 }
        },
        paragraphSpacing: {
          before: { unit: 'PTS', value: 6 },
          after: { unit: 'PTS', value: 6 }
        }
      },
      
      // Optional: Page numbering
      pageNumber: {
        show: true,
        showCount: true,
        showOnFirstPage: false,
        position: 'bottom',
        alignment: 'center'
      },
      
      // Optional: Header/Footer heights
      headerHeight: 30,
      footerHeight: 80
    }),
    
    // Your other Tiptap extensions...
    Paragraph, Text, Bold, Italic, Underline,
    Heading, BulletList, OrderedList, ListItem
  ],
  content: `
    <h2>Your content here</h2>
    <p>This will automatically be wrapped in pages...</p>
  `
});
⚙️ API Reference
Core Extensions
PageExtension
The main extension that handles pagination logic, configuration, and lifecycle management.

Configuration Options:

Option	Type	Required	Default	Description
bodyHeight	number	✅	-	Height of each page in pixels
bodyWidth	number	✅	-	Width of each page in pixels
bodyPadding	number	❌	0	Internal padding for page content
headerHeight	number	❌	30	Height of page header area
footerHeight	number	❌	30	Height of page footer area
pageLayout	PageLayoutConfig	❌	See below	Page layout configuration
pageNumber	PageNumberConfig	❌	See below	Page numbering configuration
types	never[]	❌	[]	Additional node types to support
headerData	unknown[]	❌	[]	Custom header data
footerData	unknown[]	❌	[]	Custom footer data
Commands:

// Recompute pagination after configuration changes
editor.commands.recomputeComputedHtml();
PageDocument
Document extension that enforces the PAGE node structure. Must be included in your extensions array.

import { PageDocument } from '@adalat-ai/page-extension';

// Add to your extensions array
extensions: [
  PageDocument, // Required
  PageExtension.configure({...}),
  // ... other extensions
]
Configuration Types
PageLayoutConfig
Controls page margins and paragraph spacing.

interface PageLayoutConfig {
  margins?: PageMargins;
  paragraphSpacing?: ParagraphSpacingConfig;
}
Example:

pageLayout: {
  margins: {
    top: { unit: 'INCHES', value: 1.0 },
    bottom: { unit: 'INCHES', value: 1.0 },
    left: { unit: 'INCHES', value: 0.75 },
    right: { unit: 'INCHES', value: 0.75 }
  },
  paragraphSpacing: {
    before: { unit: 'PTS', value: 12 },
    after: { unit: 'PTS', value: 12 }
  }
}
PageMargins
Defines page margins with unit support.

interface PageMargins {
  top: MarginConfig;
  bottom: MarginConfig;
  left: MarginConfig;
  right: MarginConfig;
}

interface MarginConfig {
  unit: 'CM' | 'INCHES';
  value: number;
}
Supported Units:

'CM': Centimeters
'INCHES': Inches
ParagraphSpacingConfig
Controls spacing between paragraphs.

interface ParagraphSpacingConfig {
  before: {
    unit: 'PTS';
    value: number;
  };
  after: {
    unit: 'PTS';
    value: number;
  };
}
Supported Units:

'PTS': Points (1 point = 1/72 inch)
PageNumberConfig
Configures page numbering display and positioning.

interface PageNumberConfig {
  show: boolean;                    // Enable/disable page numbers
  showCount: boolean;              // Show total page count (e.g., "1 of 5")
  showOnFirstPage: boolean;        // Show page number on first page
  position: 'top' | 'bottom' | null;  // Vertical position
  alignment: 'left' | 'center' | 'right' | null;  // Horizontal alignment
}
Example:

pageNumber: {
  show: true,
  showCount: true,
  showOnFirstPage: false,
  position: 'bottom',
  alignment: 'center'
}
Utility Classes
UnitConversion
Utility class for converting between different measurement units.

import { UnitConversion } from '@adalat-ai/page-extension';

const converter = new UnitConversion();

// Convert pixels to millimeters
const mm = converter.pxConversionMm(96); // 25mm

// Convert millimeters to pixels
const px = converter.mmConversionPx(25); // 96px

// Convert points to pixels
const ptToPx = converter.ptConversionPx(12); // 16px

// Convert pixels to points
const pxToPt = converter.pxConversionPt(16); // 12pt
Methods:

pxConversionMm(value: number): number - Convert pixels to millimeters
mmConversionPx(value: number): number - Convert millimeters to pixels
ptConversionPx(value: number): number - Convert points to pixels
pxConversionPt(value: number): number - Convert pixels to points
🎨 Styling
The extension automatically injects all necessary CSS styles. Your content will automatically have:

📏 A4 page dimensions with proper scaling
🎭 Professional shadows and borders
📐 Proper margins and spacing
📱 Responsive design for different screen sizes
✍️ Typography optimized for documents
Custom Styling
You can override default styles by targeting the generated CSS classes:

/* Custom page styling */
.Page {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid #e0e0e0;
}

/* Custom page content styling */
.PageContent {
  padding: 20px;
  line-height: 1.6;
}

/* Custom page number styling */
.PageNumber {
  font-size: 12px;
  color: #666;
}
🔧 Advanced Usage
Custom Page Layouts
PageExtension.configure({
  bodyHeight: 1123,
  bodyWidth: 794,
  pageLayout: {
    margins: {
      top: { unit: 'INCHES', value: 1.0 },
      bottom: { unit: 'INCHES', value: 1.0 },
      left: { unit: 'INCHES', value: 0.75 },
      right: { unit: 'INCHES', value: 0.75 }
    },
    paragraphSpacing: {
      before: { unit: 'PTS', value: 12 },
      after: { unit: 'PTS', value: 12 }
    }
  }
})
Page Numbering Options
PageExtension.configure({
  bodyHeight: 1123,
  bodyWidth: 794,
  pageNumber: {
    show: true,
    showCount: true,
    showOnFirstPage: false,
    position: 'bottom',
    alignment: 'center'
  }
})
Dynamic Configuration Updates
// Update configuration and recompute pagination
editor.commands.recomputeComputedHtml();

// Or update options directly
editor.extensionManager.extensions.find(ext => ext.name === 'PageExtension')
  ?.options = {
    ...editor.extensionManager.extensions.find(ext => ext.name === 'PageExtension')?.options,
    pageNumber: {
      show: true,
      showCount: true,
      showOnFirstPage: true,
      position: 'top',
      alignment: 'right'
    }
  };

// Recompute after changes
editor.commands.recomputeComputedHtml();
Custom Node Types
PageExtension.configure({
  bodyHeight: 1123,
  bodyWidth: 794,
  types: ['customBlock', 'customNode'] // Add your custom node types
})
🏗️ Architecture
This extension is completely isolated and consists of:

📦 PageExtension: Main extension that handles configuration and lifecycle
📄 PageDocument: Document extension that enforces PAGE node structure
🔧 Page Node: Custom node for rendering individual pages
⚙️ Page Plugin: ProseMirror plugin for pagination logic
💉 CSS Injector: Automatic style injection and cleanup
🧮 Core Utilities: Pagination algorithms and calculations
🔄 Copy-Paste Handler: Advanced clipboard operations
🌍 International Support: Multi-language and Unicode handling
Key Components
Pagination Engine
Smart Content Splitting: Automatically breaks content across pages
Height Calculation: Precise measurement of content dimensions
Overflow Detection: Identifies when content exceeds page boundaries
Binary Search Algorithm: Efficient text breaking for optimal pagination
Copy-Paste System
Cross-Page Operations: Seamless content transfer between pages
Format Preservation: Maintains formatting during copy-paste operations
PageContent Validation: Ensures content is properly placed within page structure
International Support: Handles Unicode, emojis, and multi-language content
Performance Optimizations
Caching System: Reduces redundant calculations
Lazy Loading: Efficient memory management
Debounced Updates: Prevents excessive re-computations
Virtual DOM: Optimized rendering for large documents
📱 Browser Support
Modern browsers with ES2020 support
React 18+
Tiptap 2.x
Chrome 90+
Firefox 88+
Safari 14+
Edge 90+
🧪 Testing
The package includes comprehensive test coverage:

Test Categories
Unit Tests (69 tests)
Integration Tests: CSS injector, document, page component, page extension
Unit Tests: Core utilities, types, unit conversion
Playwright E2E Tests (112 tests)
Basic Pagination Tests: Page structure, multi-page content, formatting, lists, headings
Focused Tests: Specific page creation scenarios
Cross-Browser Tests: Browser compatibility, viewport sizes, input methods
Edge Cases: Empty documents, special characters, rapid operations
Error Handling: Graceful error recovery scenarios
Performance Tests: Large documents, memory management
Copy-Paste Tests: 38 comprehensive copy-paste functionality tests
Running Tests
# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run E2E tests only
npm run test:e2e

# Run specific test file
npm test pagination-copy-paste
🤝 Contributing
Contributions are welcome! Please ensure all functionality remains isolated and doesn't introduce external dependencies.

Development Setup
# Clone the repository
git clone https://github.com/your-username/page-extension.git

# Install dependencies
npm install

# Run tests
npm test

# Build the package
npm run build
Code Style
TypeScript: Full type safety
ESLint: Code quality enforcement
Prettier: Code formatting
Jest: Unit testing
Playwright: E2E testing
📄 License
MIT License - see LICENSE file for details.

🔗 Links
Tiptap Documentation
ProseMirror Documentation
Package Repository
NPM Package
🆘 Troubleshooting
Common Issues
Page dimensions not working
// Ensure you provide valid numeric values
PageExtension.configure({
  bodyHeight: 1123, // Must be a positive number (A4 height at 96 DPI)
  bodyWidth: 794,   // Must be a positive number (A4 width at 96 DPI)
})
Page numbers not showing
// Check your page number configuration
pageNumber: {
  show: true,        // Must be true
  position: 'bottom', // Must be 'top' or 'bottom'
  alignment: 'center' // Must be 'left', 'center', or 'right'
}
Content not paginating
// Ensure PageDocument is included
extensions: [
  PageDocument, // Required
  PageExtension.configure({...}),
  // ... other extensions
]
Styling issues
// The extension auto-injects styles, but you can override them
// Check browser console for any CSS conflicts
Performance Tips
Use appropriate page dimensions for your content
Limit paragraph spacing for better performance
Avoid extremely large documents without pagination
Use the recompute command sparingly
Monitor memory usage with large documents
Getting Help
GitHub Issues: Report bugs and request features
Documentation: Check the API reference above
Examples: See the demo folder for usage examples
Tests: Check test files for implementation examples
About
No description, website, or topics provided.
Resources
 Readme
License
 MIT license
 Activity
 Custom properties
Stars
 22 stars
Watchers
 2 watching
Forks
 6 forks
Report repository
Releases 2
Release v1.0.9
Latest
on Sep 28, 2025
+ 1 release
Packages
No packages published
Contributors
2
@nishant-adalat-ai
nishant-adalat-ai
@Prakhargoel8c
Prakhargoel8c Prakhar Goel
Languages
TypeScript
98.5%
 
JavaScript
1.5%
Footer
© 2026 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Community
Docs
Contact
Manage cookies
Do not share my personal information
  Skip to content
ueberdosis
tiptap
Repository navigation
Code
Issues
797
 (797)
Pull requests
89
 (89)
Agents
Discussions
Actions
Projects
Security and quality
Insights
Feature Request: Pagination extension (A4 format content) #5719
Closed
clemente-xyz started this conversation in Feature Requests

clemente-xyz
on Oct 10, 2024
Comentário original em inglês - 

Description
Extension which purpose is to emulate the content into an A4 page format, and automatically split the content for the user when the max height is exceeded.

Until now, Tiptap has no extensions that allow the editor to enter to this "page" format.

Use Case
Many apps with more conventional users (mainly in industries such as lawyers, legal guardians, any anyone which has to work with lots of paper) still need online editors that emulate the content into an A4 page format. Many need to print it out or export it to PDF to be sent to recipients that need to document in A4 format.

Type
New extension

Replies:14 comments · 57 replies

clemente-xyz
on Oct 10, 2024
Author
Comentário original em inglês - 

I have already done some work for my Nextjs app, but it still a bit buggy:

import { Extension } from '@tiptap/core';
import { Node, mergeAttributes } from '@tiptap/core';
import { Node as PMNode } from '@tiptap/pm/model';
import { Plugin, PluginKey, TextSelection } from '@tiptap/pm/state';

export const PageNode = Node.create({
  name: 'page',
  group: 'block',
  content: 'block+',
  defining: true,
  isolating: true,

  parseHTML() {
    return [
      {
        tag: 'div[data-page]',
      },
    ];
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', mergeAttributes(HTMLAttributes, { 'data-page': true, class: 'page' }), 0];
  },

  addNodeView() {
    return () => {
      const dom = document.createElement('div');
      dom.setAttribute('data-page', 'true');
      dom.classList.add('page');
      dom.style.height = '297mm'; // A4 height in mm
      dom.style.width = '210mm'; // A4 width in mm
      dom.style.padding = '25.4mm';
      dom.style.border = '1px solid #ccc';
      dom.style.background = 'white';
      dom.style.overflow = 'hidden';
      dom.style.position = 'relative';

      const contentDOM = document.createElement('div');
      dom.appendChild(contentDOM);

      return {
        dom,
        contentDOM,
      };
    };
  },
});

export const PaginationExtension = Extension.create({
  name: 'pagination',

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: new PluginKey('pagination'),
        appendTransaction: (transactions, oldState, newState) => {
          const paginationMeta = 'pagination';
          const lastTransaction = transactions[transactions.length - 1];
          const isPaginationTransaction = lastTransaction.getMeta(paginationMeta);

          // Avoid infinite loops and unnecessary processing
          if (isPaginationTransaction || !lastTransaction.docChanged) {
            return null;
          }

          const { schema } = newState;
          const pageType = schema.nodes.page;

          if (!pageType) {
            return null;
          }

          // Collect content nodes, flattening existing pages
          const contentNodes: PMNode[] = [];

          newState.doc.forEach((node) => {
            if (node.type === pageType) {
              node.forEach((child) => contentNodes.push(child));
            } else {
              contentNodes.push(node);
            }
          });

          // Partition content nodes into pages
          const pages = [];
          let currentPageContent: PMNode[] = [];
          let currentHeight = 0;
          const pageHeight = (297 - 25.4 * 2) * 3.77953; // A4 height in mm minus padding, converted to px (1 mm = 3.77953 px)
          const lineHeight = 24; // Line height in px

          for (const node of contentNodes) {
            const nodeHeight = estimateNodeHeight(node, lineHeight);

            if (currentHeight + nodeHeight > pageHeight && currentPageContent.length > 0) {
              // Start a new page
              pages.push(pageType.create({}, currentPageContent));
              currentPageContent = [node];
              currentHeight = nodeHeight;
            } else {
              currentPageContent.push(node);
              currentHeight += nodeHeight;
            }
          }

          if (currentPageContent.length > 0) {
            pages.push(pageType.create({}, currentPageContent));
          }

          const newDoc = schema.topNodeType.create(null, pages);

          // Compare the content of the documents
          if (newDoc.content.eq(newState.doc.content)) {
            return null; // No changes, skip transaction
          }

          const tr = newState.tr.replaceWith(0, newState.doc.content.size, newDoc.content);
          tr.setMeta(paginationMeta, true);

          // Map the selection from oldState to the new document
          const { selection } = oldState;
          const mappedSelection = selection.map(tr.doc, tr.mapping);

          if (mappedSelection) {
            tr.setSelection(mappedSelection);
          } else {
            // Fallback to a safe selection at the end of the document
            tr.setSelection(TextSelection.create(tr.doc, tr.doc.content.size));
          }

          return tr;
        },
      }),
    ];
  },
});

function estimateNodeHeight(node: PMNode, lineHeight: number): number {
  if (node.isTextblock) {
    const lines = node.textContent.split('\n').length || 1;
    return lines * lineHeight;
  } else if (node.type.name === 'image') {
    return 200;
  } else {
    return lineHeight;
  }
}
3 replies
@bdbch
bdbch
on Oct 11, 2024
Maintainer
Nice job. I was working on something similar at some point but didn't find enough time to put into this in general.

The biggest task is actually calculating if content on a page fits the page's boundaries (in size including margin) and if content needs to be moved to a new page or should be merged back into a previous page.

Do you have a few more insights into this?

@Cassielxd
Cassielxd
on Oct 11, 2024
You can refer to this implementation https://github.com/Cassielxd/CassieEditor

@clemente-xyz
clemente-xyz
on Oct 11, 2024
Author
@Cassielxd your implementation looks nice, but the code is super hard to follow and adapt to React. I actually submitted an issue on your repo asking for a React extension/adaptation to it: Cassielxd/CassieEditor#5

I spent a lot of time trying to adapt it, but no case


clemente-xyz
on Oct 11, 2024
Author
@bdbch yes. Right now the content split into nodes is working super good, but only for paragraphs, lists, and other simple nodes. The big issue comes with more complex HTML elements such as tables. It's not an easy job to traverse the table element and make a split. Something similar with images.

There are also some buggy behaviors when deleting content and passing to previous page nodes, which I still cant figure out how to solve

9 replies
@clemente-xyz
clemente-xyz
on Nov 22, 2024
Author
Hey @AntonA-DB thanks for your message!

I was out of time with the project timeline, and had to go with a work around that has no pagination :/

But I would love to continue ue working on it with collaboration

@hugs7
hugs7
on Dec 23, 2024
Hey @clemente-xyz , love your work. @AntonA-DB . I was able to get this working by adding a backspace handler within the Pagination Extension. I also handled the delete key for deleting (forwards) from the end of a page. See my code below. It's still not perfect though - very tricky!

Update: See my next comment with more improvements.

import { Extension } from "@tiptap/core";
import { keymap } from "@tiptap/pm/keymap";
import { Selection } from "@tiptap/pm/state";
import PaginationPlugin from "../Plugins/Pagination";
import { isHighlighting, getResolvedPosition, setSelectionAtPos, setSelection } from "../utils/selection";
import { getPositionNodeType } from "../utils/node";
import {
    getNextParagraph,
    getParagraphNodeAndPosition,
    getPreviousParagraph,
    getThisPageNodePosition,
    isPageNode,
    isPosAtEndOfPage,
    isPosAtLastChildOfPage,
    isPosAtStartOfPage,
    isTextNode,
} from "../utils/pagination";

const PaginationExtension = Extension.create({
    name: "pagination",
    addProseMirrorPlugins() {
        return [
            keymap({
                Enter: (state, dispatch) => {
                    if (!dispatch) {
                        console.warn("No dispatch function provided");
                        return false;
                    }

                    if (isHighlighting(state)) {
                        return false;
                    }

                    const { from } = state.selection;
                    const tr = state.tr;
                    const $pos = getResolvedPosition(state);

                    // Ensure that the position is within a valid block (paragraph)
                    if (getPositionNodeType($pos) !== "paragraph") {
                        console.warn("Not inside a paragraph node");
                        return false;
                    }

                    if (!isPosAtLastChildOfPage(state.doc, $pos)) {
                        return false;
                    }

                    const paragraph = state.schema.nodes.paragraph.create();

                    // Create a new empty paragraph node
                    console.log("Inserting new paragraph at position", from);

                    // if (isPosAtEndOfPage(state.doc, $pos)) {
                    tr.insert(from, paragraph);
                    // } else {
                    // tr.insert(from - 1, paragraph);
                    // }

                    // Find the nearest valid cursor position inside the new paragraph

                    const newPosition = tr.doc.resolve(from + 1);
                    const newSelection = Selection.near(newPosition, 1);

                    // Set the selection to be inside the new paragraph
                    setSelection(tr, newSelection);
                    dispatch(tr);

                    return true;
                },
                Backspace: (state, dispatch) => {
                    if (!dispatch) {
                        console.warn("No dispatch function provided");
                        return false;
                    }

                    if (isHighlighting(state)) {
                        return false;
                    }

                    const { from, to } = state.selection;
                    const tr = state.tr;
                    const $pos = getResolvedPosition(state);

                    // Ensure that the position is within a valid block (paragraph)
                    if (getPositionNodeType($pos) !== "paragraph") {
                        return false;
                    }

                    if (!isPosAtStartOfPage(state.doc, $pos)) {
                        return false;
                    }

                    // Traverse $pos.path to find the nearest page node
                    const thisNodePos = $pos.pos;
                    const thisPageNodePos = getThisPageNodePosition(state.doc, $pos);

                    const thisPageNode = state.doc.nodeAt(thisPageNodePos);
                    const firstChildPos = thisPageNodePos + 1;

                    if (firstChildPos !== thisNodePos - 1) {
                        // Not at the beginning of the page
                        return false;
                    }

                    const prevPageChild = state.doc.childBefore(thisPageNodePos);
                    const prevPageNode = prevPageChild.node;

                    // Confirm that the previous node is a page node
                    if (!prevPageNode) {
                        // Start of document
                        console.log("No previous page node found");
                        return false;
                    }

                    if (prevPageNode.type.name !== "page") {
                        console.warn("Previous node is not a page node");
                        return false;
                    }

                    // Append the content of the current paragraph to the end of the previous paragraph
                    const { paragraphPos, paragraphNode } = getParagraphNodeAndPosition(state.doc, $pos);
                    if (!paragraphNode) {
                        console.warn("No current paragraph node found");
                        return false;
                    }

                    const { prevParagraphPos, prevParagraphNode } = getPreviousParagraph(state.doc, paragraphPos);
                    if (!prevParagraphNode) {
                        console.warn("No previous paragraph node found");
                        return false;
                    }

                    tr.delete(paragraphPos, paragraphPos + paragraphNode.nodeSize);

                    const newContent = prevParagraphNode.content.append(paragraphNode.content);
                    tr.replaceWith(prevParagraphPos, prevParagraphPos + prevParagraphNode.nodeSize, newContent);

                    // Set the selection to the end of the previous paragraph
                    const lastChildPosition = tr.doc.resolve(prevPageNode.content.size);
                    const newSelection = Selection.near(lastChildPosition, 1);
                    console.log("Setting selection to", newSelection);
                    setSelection(tr, newSelection);
                    dispatch(tr);

                    return true;
                },
                Delete: (state, dispatch) => {
                    if (!dispatch) {
                        console.warn("No dispatch function provided");
                        return false;
                    }

                    if (isHighlighting(state)) {
                        return false;
                    }

                    const tr = state.tr;
                    const $pos = getResolvedPosition(state);

                    // Ensure that the position is within a valid block (paragraph)
                    if (getPositionNodeType($pos) !== "paragraph") {
                        console.warn("Not inside a paragraph node");
                        return false;
                    }

                    if (!isPosAtEndOfPage(state.doc, $pos)) {
                        return false;
                    }

                    // We need to remove the current paragraph node and prepend any
                    // content to the next paragraph node (which will now be at the
                    // end of the current page)

                    const thisPos = $pos.pos;
                    const expectedTextNodePos = thisPos - 1;
                    const thisTextNode = state.doc.nodeAt(expectedTextNodePos);
                    if (!thisTextNode) {
                        console.warn("No node found at position", expectedTextNodePos);
                        return false;
                    }

                    if (!isTextNode(thisTextNode)) {
                        const nodeType = thisTextNode.type.name;
                        console.warn("Expected text node before paragraph node. Found", nodeType);
                        return false;
                    }

                    const { paragraphPos, paragraphNode } = getParagraphNodeAndPosition(state.doc, $pos);
                    if (!paragraphNode) {
                        console.warn("No current paragraph node found");
                        return false;
                    }

                    const thisPageChild = state.doc.childAfter(paragraphPos);
                    if (!isPageNode(thisPageChild.node)) {
                        console.warn("No page node found");
                        return false;
                    }

                    const pageNum = thisPageChild.index;
                    const nextPageNode = state.doc.child(pageNum + 1);
                    if (!nextPageNode) {
                        console.log("No next page node found");
                        return false;
                    }

                    const { nextParagraphPos, nextParagraphNode } = getNextParagraph(state.doc, thisPos);
                    if (!nextParagraphNode) {
                        console.log("No first paragraph node found");
                        return false;
                    }

                    tr.delete(nextParagraphPos, nextParagraphPos + nextParagraphNode.nodeSize);

                    const newContent = paragraphNode.content.append(nextParagraphNode.content);
                    tr.replaceWith(paragraphPos, paragraphPos + paragraphNode.nodeSize, newContent);

                    // Set selection
                    setSelectionAtPos(tr, thisPos);

                    dispatch(tr);

                    return true;
                },
            }),
            PaginationPlugin,
        ];
    },
});

export default PaginationExtension;
Some utils referenced above

/**
 * @file /src/components/TipTap/utils/pagination.ts
 * @name Pagination
 * @description Utility functions for paginating the editor content.
 */

import { ResolvedPos } from "@tiptap/pm/model";
import { EditorState, Selection, TextSelection, Transaction } from "@tiptap/pm/state";

/**
 * Check if the editor is currently highlighting text.
 * @param state - The current editor state.
 * @returns True if text is currently highlighted, false otherwise.
 */
export const isHighlighting = (state: EditorState): boolean => {
    const { from, to } = state.selection;
    return from !== to;
};

/**
 * Get the resolved position in the document.
 * @param state - The current editor state.
 * @returns The resolved position in the document.
 */
export const getResolvedPosition = (state: EditorState): ResolvedPos => {
    const { from } = state.selection;
    const $pos = state.doc.resolve(from);
    return $pos;
};

/**
 * Set the selection at the specified anchor and head positions. If head is not provided,
 * it will be set to the anchor position.
 * @param tr - The current transaction.
 * @param anchor - The anchor position.
 * @param head - The head position.
 * @returns The updated transaction.
 */
export const setSelectionAtPos = (tr: Transaction, anchor: number, head?: number): Transaction => {
    const selection = TextSelection.create(tr.doc, anchor, head ?? anchor);
    return setSelection(tr, selection);
};

/**
 * Set the selection to the specified selection object.
 * @param tr - The current transaction.
 * @param selection - The selection object.
 * @returns The updated transaction.
 */
export const setSelection = <S extends Selection>(tr: Transaction, selection: S): Transaction => {
    console.log("Setting selection to", selection.$anchor.pos, "-", selection.$head.pos);
    return tr.setSelection(selection);
};
/**
 * @file /src/components/TipTap/utils/node.ts
 * @name Node
 * @description Utility functions for creating custom nodes in the editor.
 */

import { Node, ResolvedPos } from "@tiptap/pm/model";

/**
 * Get the type of the node at the specified position.
 * @param $pos - The resolved position in the document.
 * @returns The type of the node at the specified position.
 */
export const getPositionNodeType = ($pos: ResolvedPos): string => {
    return $pos.parent.type.name;
};

/**
 * Get the parent node position of the specified type.
 * @param doc - The document node.
 * @param $pos - The resolved position in the document or the absolute position of the node.
 * @param type - The type of the node to search for.
 * @returns The position of the parent node of the specified type.
 */
export const getParentNodePosOfType = (doc: Node, $pos: ResolvedPos | number, type: string): ResolvedPos => {
    // Base case: If the position is a number, resolve it
    if (typeof $pos !== "number") {
        return getParentNodePosOfType(doc, $pos.before(), type);
    }

    const thisPos = doc.resolve($pos);

    // Base case: If the node at the position is of the specified type, return the position
    if (doc.nodeAt($pos)?.type.name === type) {
        return thisPos;
    }

    // Recursive case: Move one level up and check again
    const prevPos = thisPos.before();
    return getParentNodePosOfType(doc, prevPos, type);
};
/**
 * @file /src/components/TipTap/utils/pagination.ts
 * @name Pagination
 * @description Utility functions for paginating the editor content.
 */

import { Node, ResolvedPos } from "@tiptap/pm/model";
import { getParentNodePosOfType, getPositionNodeType } from "./node";
import { Nullable } from "../../../utils/record";

/**
 * Check if the given node is a page node.
 * @param node - The node to check.
 * @returns {boolean} True if the node is a page node, false otherwise.
 */
export const isPageNode = (node: Nullable<Node>): boolean => {
    if (!node) {
        console.warn("No node provided");
        return false;
    }

    return node.type.name === "page";
};

/**
 * Check if the given node is a paragraph node.
 * @param node - The node to check.
 * @returns {boolean} True if the node is a paragraph node, false otherwise.
 */
export const isParagraphNode = (node: Nullable<Node>): boolean => {
    if (!node) {
        console.warn("No node provided");
        return false;
    }

    return node.type.name === "paragraph";
};

/**
 * Check if the given node is a text node.
 * @param node - The node to check.
 * @returns {boolean} True if the node is a text node, false otherwise.
 */
export const isTextNode = (node: Nullable<Node>): boolean => {
    if (!node) {
        console.warn("No node provided");
        return false;
    }

    return node.type.name === "text";
};

/**
 * Get the page node (parent of the current node) position.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {number} The position of the page node.
 */
export const getThisPageNodePosition = (doc: Node, pos: ResolvedPos | number): number => {
    return getParentNodePosOfType(doc, pos, "page").pos;
};

/**
 * Get the paragraph node position.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {number} The position of the paragraph node.
 */
export const getThisParagraphNodePosition = (doc: Node, pos: ResolvedPos | number): number => {
    return getParentNodePosOfType(doc, pos, "paragraph").pos;
};

/**
 * Get the page node position and the page node itself.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {pagePos: number, pageNode: Node} The position and the node of the page.
 */
export const getPageNodeAndPosition = (doc: Node, pos: ResolvedPos | number): { pagePos: number; pageNode: Nullable<Node> } => {
    if (typeof pos === "number") {
        return getPageNodeAndPosition(doc, doc.resolve(pos));
    }

    const pagePos = getThisPageNodePosition(doc, pos);
    const pageNode = doc.nodeAt(pagePos);

    return { pagePos, pageNode };
};

/**
 * Get the paragraph node position and the paragraph node itself.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {paragraphPos: number, paragraphNode: Node} The position and the node of the paragraph.
 */
export const getParagraphNodeAndPosition = (
    doc: Node,
    pos: ResolvedPos | number
): { paragraphPos: number; paragraphNode: Nullable<Node> } => {
    if (typeof pos === "number") {
        return getParagraphNodeAndPosition(doc, doc.resolve(pos));
    }

    const paragraphPos = getThisParagraphNodePosition(doc, pos);
    const paragraphNode = doc.nodeAt(paragraphPos);

    return { paragraphPos, paragraphNode };
};

/**
 * Get the start of the page position.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {number} The start position of the page.
 */
export const getStartOfPagePosition = (doc: Node, pos: ResolvedPos | number): number => {
    if (typeof pos === "number") {
        return getStartOfPagePosition(doc, doc.resolve(pos));
    }

    const { pagePos, pageNode } = getPageNodeAndPosition(doc, pos);
    if (!pageNode) {
        console.warn("No page node found");
        return -1;
    }

    return pagePos;
};

/**
 * Get the start of the paragraph position.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {number} The start position of the paragraph.
 */
export const getStartOfParagraphPosition = (doc: Node, pos: ResolvedPos | number): number => {
    if (typeof pos === "number") {
        return getStartOfParagraphPosition(doc, doc.resolve(pos));
    }

    const { paragraphPos, paragraphNode } = getParagraphNodeAndPosition(doc, pos);
    if (!paragraphNode) {
        console.warn("No paragraph node found");
        return -1;
    }

    return paragraphPos;
};

/**
 * Get the start of the page and paragraph positions.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {startOfPagePos: number, startOfParagraphPos: number} The start positions of the page and paragraph.
 */
export const getStartOfPageAndParagraphPosition = (
    doc: Node,
    pos: ResolvedPos | number
): { startOfPagePos: number; startOfParagraphPos: number } => {
    const startOfParagraphPos = getStartOfParagraphPosition(doc, pos);
    const startOfPagePos = getStartOfPagePosition(doc, pos);

    return { startOfPagePos, startOfParagraphPos };
};

/**
 * Get the end of the page position.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {number} The end position of the page.
 */
export const getEndOfPagePosition = (doc: Node, pos: ResolvedPos | number): number => {
    if (typeof pos === "number") {
        return getEndOfPagePosition(doc, doc.resolve(pos));
    }

    const { pagePos, pageNode } = getPageNodeAndPosition(doc, pos);
    if (!pageNode) {
        console.warn("No page node found");
        return -1;
    }

    return pagePos + pageNode.content.size;
};

/**
 * Get the end of the paragraph position.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {number} The end position of the paragraph.
 */
export const getEndOfParagraphPosition = (doc: Node, $pos: ResolvedPos | number): number => {
    if (typeof $pos === "number") {
        return getEndOfParagraphPosition(doc, doc.resolve($pos));
    }

    const { paragraphPos, paragraphNode } = getParagraphNodeAndPosition(doc, $pos);
    if (!paragraphNode) {
        console.warn("No paragraph node found");
        return -1;
    }

    return paragraphPos + paragraphNode.content.size;
};

/**
 * Get the end of the page and paragraph positions.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {endOfPagePos: number, endOfParagraphPos: number} The end positions of the page and paragraph.
 */
export const getEndOfPageAndParagraphPosition = (
    doc: Node,
    $pos: ResolvedPos | number
): { endOfPagePos: number; endOfParagraphPos: number } => {
    const endOfParagraphPos = getEndOfParagraphPosition(doc, $pos);
    const endOfPagePos = getEndOfPagePosition(doc, $pos);

    return { endOfPagePos, endOfParagraphPos };
};

/**
 * Check if the editor is currently highlighting text.
 * @param state - The current editor state.
 * @returns True if text is currently highlighted, false otherwise.
 */
const isPosMatchingStartOfPageCondition = (doc: Node, $pos: ResolvedPos | number, checkExactStart: boolean): boolean => {
    // Resolve position if given as a number
    if (typeof $pos === "number") {
        return isPosMatchingStartOfPageCondition(doc, doc.resolve($pos), checkExactStart);
    }

    // Ensure that the position is within a valid block (paragraph)
    if (getPositionNodeType($pos) !== "paragraph") {
        console.warn("Not inside a paragraph node");
        return false;
    }

    // Get positions for paragraph and page
    const { startOfPagePos, startOfParagraphPos } = getStartOfPageAndParagraphPosition(doc, $pos);
    if (startOfPagePos < 0) {
        console.warn("Invalid page position");
        return false;
    }

    if (startOfParagraphPos < 0) {
        console.warn("Invalid paragraph position");
        return false;
    }

    // Determine the condition to check
    const isFirstParagraph = startOfPagePos + 1 === startOfParagraphPos;
    if (checkExactStart) {
        // Check if position is exactly at the start of the page
        // First position of page will always be 1 more than the paragraph position
        const isPosAtStartOfParagraph = $pos.pos - 1 === startOfParagraphPos;
        if (isFirstParagraph && isPosAtStartOfParagraph) {
            console.log("At the start of the page");
            return true;
        }
        console.log("Not at the start of the page");
        return false;
    } else {
        // Check if position is at the first child of the page
        if (isFirstParagraph) {
            console.log("In the first child of the page");
            return true;
        }
        console.log("Not in the first child of the page");
        return false;
    }
};

/**
 * Check if the given position is at the start of the page or the first child of the page.
 * @param doc - The document node.
 * @param $pos - The resolved position in the document or the absolute position of the node.
 * @returns {boolean} True if the condition is met, false otherwise.
 */
export const isPosAtStartOfPage = (doc: Node, $pos: ResolvedPos | number): boolean => {
    return isPosMatchingStartOfPageCondition(doc, $pos, true);
};

/**
 * Check if the given position is at the first paragraph child of the page.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {boolean} True if the position is at the start of the page, false otherwise.
 */
export const isPosAtFirstChildOfPage = (doc: Node, $pos: ResolvedPos | number): boolean => {
    return isPosMatchingStartOfPageCondition(doc, $pos, false);
};

/**
 * Check if the given position is at the end of the page or the last child of the page.
 * @param doc - The document node.
 * @param $pos - The resolved position in the document or the absolute position of the node.
 * @param checkExactEnd - Whether to check for the exact end of the page (true) or the last child of the page (false).
 * @returns {boolean} True if the condition is met, false otherwise.
 */
const isPosMatchingEndOfPageCondition = (doc: Node, $pos: ResolvedPos | number, checkExactEnd: boolean): boolean => {
    // Resolve position if given as a number
    if (typeof $pos === "number") {
        return isPosMatchingEndOfPageCondition(doc, doc.resolve($pos), checkExactEnd);
    }

    // Ensure that the position is within a valid block (paragraph)
    if (getPositionNodeType($pos) !== "paragraph") {
        console.warn("Not inside a paragraph node");
        return false;
    }

    // Get positions for paragraph and page
    const { endOfParagraphPos, endOfPagePos } = getEndOfPageAndParagraphPosition(doc, $pos);
    if (endOfParagraphPos < 0) {
        console.warn("Invalid end of paragraph position");
        return false;
    }

    if (endOfPagePos < 0) {
        console.warn("Invalid end of page position");
        return false;
    }

    // Determine the condition to check
    if (checkExactEnd) {
        // Check if position is exactly at the end of the page
        if ($pos.pos === endOfPagePos) {
            console.log("At the end of the page");
            return true;
        }
        console.log("Not at the end of the page");
        return false;
    } else {
        // Check if position is at the last child of the page
        if (endOfParagraphPos + 1 === endOfPagePos) {
            console.log("In the last child of the page");
            return true;
        }
        console.log("Not in the last child of the page");
        return false;
    }
};

/**
 * Check if the given position is exactly at the end of the page.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {boolean} True if the position is at the end of the page, false otherwise.
 */
export const isPosAtEndOfPage = (doc: Node, $pos: ResolvedPos | number): boolean => {
    return isPosMatchingEndOfPageCondition(doc, $pos, true);
};

/**
 * Check if the given position is at the last paragraph child of the page.
 * @param doc - The document node.
 * @param pos - The resolved position in the document or the absolute position of the node.
 * @returns {boolean} True if the position is at the end of the page, false otherwise.
 */
export const isPosAtLastChildOfPage = (doc: Node, $pos: ResolvedPos | number): boolean => {
    return isPosMatchingEndOfPageCondition(doc, $pos, false);
};

/**
 * Get the previous paragraph node.
 * @param doc - The document node.
 * @param pos - The position in the document.
 * @returns {Node} The previous paragraph node.
 */
export const getPreviousParagraph = (doc: Node, pos: number): { prevParagraphPos: number; prevParagraphNode: Nullable<Node> } => {
    let prevParagraphPos = pos;
    let prevParagraphNode = null;
    while (prevParagraphNode === null && prevParagraphPos > 0) {
        prevParagraphPos -= 1;
        const node = doc.nodeAt(prevParagraphPos);
        if (!node) {
            continue;
        }

        if (isParagraphNode(node)) {
            prevParagraphNode = node;
            prevParagraphPos = prevParagraphPos;
        }
    }

    return { prevParagraphPos, prevParagraphNode };
};

/**
 * Get the next paragraph node.
 * @param doc - The document node.
 * @param pos - The position in the document.
 * @returns {Node} The next paragraph node.
 */
export const getNextParagraph = (doc: Node, pos: number): { nextParagraphPos: number; nextParagraphNode: Nullable<Node> } => {
    const documentLength = doc.nodeSize;
    let nextParagraphPos = pos;
    let nextParagraphNode = null;
    while (nextParagraphNode === null && nextParagraphPos < documentLength) {
        nextParagraphPos += 1;
        const node = doc.no

[Message truncated - exceeded 50,000 character limit]
Show less
