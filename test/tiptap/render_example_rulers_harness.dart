import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Puppeteer regression for the real `example/` UI used with `webdev serve`.
///
/// It catches geometry bugs that DOM-only browser tests cannot see: ruler
/// overlap while scrolling, page alignment, and visibility of the active-page
/// vertical ruler.
Future<void> main(List<String> args) async {
  final root = Directory.current.absolute;
  final example = Directory('${root.path}/example/web');
  final output = Directory('${root.path}/test/output')
    ..createSync(recursive: true);
  final skipCompile = args.contains('--no-compile');
  final hostHtml = File('${example.path}/index.html').readAsStringSync();
  final bootstrap = File('${example.path}/main.dart').readAsStringSync();
  _check(
      hostHtml.contains('id="app"') &&
          !hostHtml.contains('class="toolbar"') &&
          !hostHtml.contains('app-header'),
      'O index do exemplo voltou a conter chrome estático.');
  _check(
      bootstrap.split('\n').length <= 30 &&
          bootstrap.contains('TiptapDocxEditorComponent.mount'),
      'O main do exemplo deixou de ser somente bootstrap.');

  if (!skipCompile) {
    final compile = await Process.run(
      'dart',
      ['compile', 'js', 'web/main.dart', '-o', 'web/main.dart.js'],
      workingDirectory: '${root.path}/example',
      runInShell: Platform.isWindows,
    );
    stdout.write(compile.stdout);
    if (compile.exitCode != 0) {
      stderr.write(compile.stderr);
      throw StateError('Falha ao compilar example/web/main.dart.');
    }
  }

  final exampleHandler =
      createStaticHandler(example.path, defaultDocument: 'index.html');
  FutureOr<shelf.Response> handler(shelf.Request request) {
    const prefix = 'packages/docx_rendering/assets/';
    if (request.url.path.startsWith(prefix)) {
      final relative = request.url.path.substring(prefix.length);
      if (relative.contains('..')) return shelf.Response.forbidden('');
      final asset = File('${root.path}/lib/assets/$relative');
      if (!asset.existsSync()) return shelf.Response.notFound('');
      final contentType = relative.endsWith('.css')
          ? 'text/css; charset=utf-8'
          : relative.endsWith('.woff2')
              ? 'font/woff2'
              : 'application/octet-stream';
      return shelf.Response.ok(
        asset.openRead(),
        headers: {'content-type': contentType},
      );
    }
    return exampleHandler(request);
  }

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    0,
  );
  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: _browserExecutable(),
      args: const ['--force-device-scale-factor=1', '--disable-gpu'],
    );
    final page = await browser.newPage();
    final pageErrors = <String>[];
    page.onError.listen((error) => pageErrors.add('$error'));
    await page.setViewport(DeviceViewport(width: 1600, height: 1000));
    await page.goto(
      'http://127.0.0.1:${server.port}',
      wait: Until.networkIdle,
    );
    await page.waitForSelector(
      '.tiptap-horizontal-ruler-track',
      visible: true,
      timeout: const Duration(seconds: 20),
    );

    final chrome = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const title = document.querySelector('.app-header');
        const tabs = document.querySelector('.ribbon-tabs');
        const home = document.querySelector('[data-ribbon-panel="home"]');
        const rgb = getComputedStyle(title).backgroundColor;
        return {
          titleHeight: title.getBoundingClientRect().height,
          tabsHeight: tabs.getBoundingClientRect().height,
          ribbonHeight: home.getBoundingClientRect().height,
          titleColor: rgb,
          activePanel: home.classList.contains('active'),
          ribbonFits: home.scrollWidth <= home.clientWidth,
          ribbonOverflowX: getComputedStyle(home).overflowX,
          fontRows: document.querySelectorAll(
            '[data-ribbon-panel="home"] .font-section .ribbon-row').length,
          paragraphRows: document.querySelectorAll(
            '[data-ribbon-panel="home"] .paragraph-section .ribbon-row').length,
          hasDesignTab:
            document.querySelector('[data-ribbon-tab="design"]') !== null,
          iconFont: getComputedStyle(document.querySelector('.tiptap-fluent-icon'))
            .fontFamily,
          fluentFontLoaded: document.fonts.check('18px FluentSystemIcons'),
        };
      }''') as Map,
    );
    _check(
        (chrome['titleHeight'] as num).abs() >= 47 &&
            (chrome['titleHeight'] as num) <= 49,
        'Barra de título fora de 48 px: $chrome');
    _check(
        (chrome['tabsHeight'] as num) >= 29 &&
            (chrome['tabsHeight'] as num) <= 31,
        'Guias fora de 30 px: $chrome');
    _check(
        (chrome['ribbonHeight'] as num) >= 99 &&
            (chrome['ribbonHeight'] as num) <= 101,
        'Ribbon fora de 100 px: $chrome');
    _check(
        chrome['ribbonFits'] == true &&
            chrome['fontRows'] == 2 &&
            chrome['paragraphRows'] == 2 &&
            chrome['hasDesignTab'] == true,
        'A ribbon voltou a rolar ou perdeu suas duas linhas: $chrome');
    _check(chrome['titleColor'] == 'rgb(24, 90, 189)',
        'Azul da barra de título divergente: $chrome');
    _check(
        (chrome['iconFont'] as String).contains('FluentSystemIcons') &&
            chrome['fluentFontLoaded'] == true,
        'A fonte Fluent UI System Icons não foi carregada: $chrome');

    await page.click('[data-ribbon-tab="file"]');
    await page.click('#export-menu-button');
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final exportMenu = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const shell = document.querySelector('.app-shell');
        const toolbar = document.querySelector('[data-ribbon-panel="file"]');
        const trigger = document.querySelector('#export-menu-button');
        const panel = document.querySelector('#export-menu');
        const item = panel.querySelector('[role="menuitem"]');
        const toolbarRect = toolbar.getBoundingClientRect();
        const triggerRect = trigger.getBoundingClientRect();
        const panelRect = panel.getBoundingClientRect();
        const itemRect = item.getBoundingClientRect();
        const hit = document.elementFromPoint(
          itemRect.left + itemRect.width / 2,
          itemRect.top + itemRect.height / 2);
        return {
          parentIsShell: panel.parentElement === shell,
          open: panel.classList.contains('open'),
          belowTrigger: panelRect.top >= triggerRect.bottom - 1,
          extendsPastRibbon: panelRect.bottom > toolbarRect.bottom,
          hitIsMenuItem: hit && hit.closest('[role="menuitem"]') === item,
          opacity: getComputedStyle(panel).opacity,
        };
      }''') as Map,
    );
    _check(
      exportMenu['parentIsShell'] == true &&
          exportMenu['open'] == true &&
          exportMenu['belowTrigger'] == true &&
          exportMenu['extendsPastRibbon'] == true &&
          exportMenu['hitIsMenuItem'] == true &&
          exportMenu['opacity'] == '1',
      'O menu Exportar está recortado ou atrás do stage: $exportMenu',
    );
    await page.click('[data-ribbon-tab="home"]');

    await page.click('[data-ribbon-tab="layout"]');
    await page.click('#page-margins-button');
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final marginsMenu = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const shell = document.querySelector('.app-shell');
        const panel = document.querySelector('#page-margins-menu');
        const trigger = document.querySelector('#page-margins-button');
        const panelRect = panel.getBoundingClientRect();
        const triggerRect = trigger.getBoundingClientRect();
        return {
          parentIsShell: panel.parentElement === shell,
          open: panel.classList.contains('open'),
          belowTrigger: panelRect.top >= triggerRect.bottom - 1,
          narrowExists:
            panel.querySelector('[data-page-margins="12.7,12.7,12.7,12.7"]') !== null,
        };
      }''') as Map,
    );
    _check(
      marginsMenu['parentIsShell'] == true &&
          marginsMenu['open'] == true &&
          marginsMenu['belowTrigger'] == true &&
          marginsMenu['narrowExists'] == true,
      'O menu funcional de margens está recortado ou incompleto: $marginsMenu',
    );
    await page.click(
      '[data-page-margins="12.7,12.7,12.7,12.7"]',
    );
    await _waitUntil(
      page,
      '''() => {
        const attrs = JSON.parse(globalThis.getTiptapJSON()).attrs;
        return attrs.pageMarginTop === '12.7mm' &&
          attrs.pageMarginRight === '12.7mm' &&
          attrs.pageMarginBottom === '12.7mm' &&
          attrs.pageMarginLeft === '12.7mm';
      }''',
      'preset funcional de margens estreitas',
    );
    await page.click('#page-margins-button');
    await page.click('[data-page-margins-custom="open"]');
    _check(
      await page.evaluate('''() => {
        const modal = document.querySelector('.page-setup-modal');
        return modal.parentElement === document.querySelector('.app-shell') &&
          modal.classList.contains('open');
      }''') == true,
      'O diálogo de margens personalizadas não ficou contido na shell.',
    );
    await page.evaluate('''() => {
      for (const id of ['custom-margin-top', 'custom-margin-right',
        'custom-margin-bottom', 'custom-margin-left']) {
        document.querySelector('#' + id).value = '2';
      }
    }''');
    await page.click('#custom-margins-apply');
    await _waitUntil(
      page,
      '''() => {
        const attrs = JSON.parse(globalThis.getTiptapJSON()).attrs;
        return attrs.pageMarginTop === '20mm' &&
          attrs.pageMarginRight === '20mm' &&
          attrs.pageMarginBottom === '20mm' &&
          attrs.pageMarginLeft === '20mm';
      }''',
      'diálogo funcional de margens personalizadas',
    );

    await page.click('#page-orientation-button');
    await page.click('[data-page-orientation="landscape"]');
    await _waitUntil(
      page,
      '''() => {
        const attrs = JSON.parse(globalThis.getTiptapJSON()).attrs;
        const style = getComputedStyle(document.querySelector('.ProseMirror'));
        const width = parseFloat(style.getPropertyValue('--tiptap-page-width'));
        const height = parseFloat(style.getPropertyValue('--tiptap-page-height'));
        return attrs.pageOrientation === 'landscape' && width > height;
      }''',
      'orientação Paisagem atualizar documento e paginação',
    );

    await page.click('#page-size-button');
    await page.click('[data-page-size="148,210"]');
    await _waitUntil(
      page,
      '''() => {
        const attrs = JSON.parse(globalThis.getTiptapJSON()).attrs;
        return attrs.pageWidth === '210mm' && attrs.pageHeight === '148mm' &&
          document.querySelector('[data-page-size="148,210"]')
            .getAttribute('aria-checked') === 'true';
      }''',
      'tamanho A5 preservar orientação Paisagem',
    );
    await page.click('#page-size-button');
    await page.click('[data-page-size-custom="open"]');
    await page.evaluate('''() => {
      document.querySelector('#custom-page-width').value = '25';
      document.querySelector('#custom-page-height').value = '20';
    }''');
    await page.click('#custom-size-apply');
    await _waitUntil(
      page,
      '''() => {
        const attrs = JSON.parse(globalThis.getTiptapJSON()).attrs;
        return attrs.pageWidth === '250mm' && attrs.pageHeight === '200mm' &&
          attrs.pageOrientation === 'landscape';
      }''',
      'diálogo funcional de tamanho personalizado',
    );

    // Restore the A4 geometry used by the ruler assertions below.
    await page.click('#page-size-button');
    await page.click('[data-page-size="210,297"]');
    await page.click('#page-orientation-button');
    await page.click('[data-page-orientation="portrait"]');
    await page.click('#page-margins-button');
    await page.click('[data-page-margins="25,30,25,30"]');
    await _waitUntil(
      page,
      '''() => {
        const attrs = JSON.parse(globalThis.getTiptapJSON()).attrs;
        return attrs.pageWidth === '210mm' && attrs.pageHeight === '297mm' &&
          attrs.pageOrientation === 'portrait';
      }''',
      'restauração A4 Retrato',
    );
    await page.click('[data-ribbon-tab="home"]');

    await page.evaluate('''() => globalThis.setTiptapJSON(JSON.stringify({
      type: 'doc',
      content: [{
        type: 'paragraph',
        attrs: {tabStops: [
          {position: '160px', type: 'left', leader: 'none'}
        ]},
        content: [{type: 'text', text: 'Rótulo\\t123,45'}]
      }]
    }))''');
    await page.click('.ProseMirror p');
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.tiptap-ruler-tab').length === 1 &&
        document.querySelector('.tiptap-tab-run')
          .getBoundingClientRect().width > 20''',
      'tabulação explícita renderizada e refletida na régua',
    );
    final tabDrag = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const marker = document.querySelector('.tiptap-ruler-tab');
        const ruler = document.querySelector('.tiptap-horizontal-ruler');
        const mr = marker.getBoundingClientRect();
        const rr = ruler.getBoundingClientRect();
        marker.dispatchEvent(new PointerEvent('pointerdown', {
          bubbles:true, cancelable:true, button:0,
          clientX:mr.left + mr.width / 2, clientY:mr.top + mr.height / 2
        }));
        window.dispatchEvent(new PointerEvent('pointermove', {
          bubbles:true, cancelable:true, buttons:1,
          clientX:rr.left + 240, clientY:rr.top + rr.height / 2
        }));
        const guide = document.querySelector('.tiptap-ruler-tab-guide');
        const tooltip = document.querySelector('.tiptap-ruler-tab-tooltip');
        return {
          guideVisible: guide.classList.contains('show'),
          tooltipVisible: tooltip.classList.contains('show'),
          tooltipText: tooltip.textContent
        };
      }''') as Map,
    );
    _check(
      tabDrag['guideVisible'] == true &&
          tabDrag['tooltipVisible'] == true &&
          (tabDrag['tooltipText'] as String).contains('Esquerdo'),
      'O arrasto da tabulação não exibiu guia e tooltip: $tabDrag',
    );
    await page.evaluate('''() => {
      const ruler = document.querySelector('.tiptap-horizontal-ruler');
      const rr = ruler.getBoundingClientRect();
      window.dispatchEvent(new PointerEvent('pointerup', {
        bubbles:true, cancelable:true, button:0,
        clientX:rr.left + 240, clientY:rr.top + rr.height / 2
      }));
      document.querySelector('.tiptap-ruler-tab').dispatchEvent(
        new MouseEvent('dblclick', {bubbles:true, cancelable:true}));
      ruler.dispatchEvent(new PointerEvent('pointerdown', {
        bubbles:true, cancelable:true, button:0,
        clientX:rr.left + 310, clientY:rr.top + rr.height / 2
      }));
    }''');
    await _waitUntil(
      page,
      '''() => {
        const tabs = JSON.parse(globalThis.getTiptapJSON())
          .content[0].attrs.tabStops;
        return tabs.length === 2 && tabs[0].leader === 'dot' &&
          document.querySelector('.tiptap-tab-run')
            .getAttribute('data-tab-leader') === 'dot';
      }''',
      'movimentação, leader e criação funcional de tab stop',
    );
    await page.click('#tab-stops-dialog-button');
    final tabDialog = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        open: document.querySelector('.tab-stops-modal').classList.contains('open'),
        parentIsShell: document.querySelector('.tab-stops-modal').parentElement ===
          document.querySelector('.app-shell'),
        initialCount: document.querySelector('#tab-stop-list').options.length,
        defaultValue: document.querySelector('#default-tab-stop').value,
      })''') as Map,
    );
    _check(
      tabDialog['open'] == true &&
          tabDialog['parentIsShell'] == true &&
          tabDialog['initialCount'] == 2 &&
          tabDialog['defaultValue'] == '1.25',
      'O diálogo Tabulação não refletiu o parágrafo atual: $tabDialog',
    );
    final tabDialogScreenshot = File('${output.path}/example_tab_dialog.png');
    await tabDialogScreenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png),
      flush: true,
    );
    await page.click('#tab-stop-clear-all');
    await page.evaluate('''() => {
      document.querySelector('#default-tab-stop').value = '1.5';
      document.querySelector('#tab-stop-position').value = '3';
      document.querySelector('input[name="tab-alignment"][value="center"]').checked = true;
      document.querySelector('input[name="tab-leader"][value="dot"]').checked = true;
    }''');
    await page.click('#tab-stop-set');
    await page.evaluate('''() => {
      document.querySelector('#tab-stop-position').value = '6';
      document.querySelector('input[name="tab-alignment"][value="right"]').checked = true;
      document.querySelector('input[name="tab-leader"][value="underscore"]').checked = true;
    }''');
    await page.click('#tab-stop-set');
    _check(
      await page.evaluate('''() =>
        document.querySelector('#tab-stop-list').options.length === 2''') ==
          true,
      'Definir não atualizou a lista temporária de tabulações.',
    );
    await page.click('#tab-stops-apply');
    await _waitUntil(
      page,
      '''() => {
        const json = JSON.parse(globalThis.getTiptapJSON());
        const tabs = json.content[0].attrs.tabStops;
        return json.attrs.defaultTabStop === '15mm' && tabs.length === 2 &&
          tabs[0].position === '30mm' && tabs[0].type === 'center' &&
          tabs[0].leader === 'dot' && tabs[1].position === '60mm' &&
          tabs[1].type === 'right' && tabs[1].leader === 'underscore' &&
          document.querySelectorAll('.tiptap-ruler-tab').length === 2;
      }''',
      'diálogo aplicar tab stops e tabulação padrão em uma transação',
    );
    await page.click('#tab-stops-dialog-button');
    await page.evaluate('''() => {
      const list = document.querySelector('#tab-stop-list');
      list.value = '0';
      list.dispatchEvent(new Event('change', {bubbles:true}));
    }''');
    await page.click('#tab-stop-clear');
    await page.click('#tab-stops-apply');
    await _waitUntil(
      page,
      '''() => JSON.parse(globalThis.getTiptapJSON())
        .content[0].attrs.tabStops.length === 1''',
      'Limpar remover somente a tabulação selecionada',
    );

    // ------------------------------------------------------------------
    // Interação HUMANA real (page.mouse): diferentemente dos PointerEvent
    // sintéticos acima, estes gestos passam pelo hit-testing do browser e
    // validam a prioridade Word entre controles empilhados:
    // tab stop > marcador de recuo > margem.
    // ------------------------------------------------------------------
    await page.evaluate('''() => globalThis.setTiptapJSON(JSON.stringify({
      type: 'doc',
      content: [{
        type: 'paragraph',
        attrs: {tabStops: [
          {position: '12px', type: 'left', leader: 'none'}
        ]},
        content: [{type: 'text', text: 'Hit\\tteste humano'}]
      }]
    }))''');
    await page.click('.ProseMirror p');
    await page.waitForSelector('.tiptap-ruler-tab');
    Future<Map<String, num>> centerOf(String selector) async {
      final result = await page.evaluate('''(sel) => {
        const r = document.querySelector(sel).getBoundingClientRect();
        return {x: r.left + r.width / 2, y: r.top + r.height / 2};
      }''', args: [selector]);
      final map = Map<String, dynamic>.from(result as Map);
      return {'x': map['x'] as num, 'y': map['y'] as num};
    }

    // O tab stop está a 12px da margem esquerda — dentro da zona estendida
    // do handle de margem. O hit-test tem de devolver o tab stop.
    final hitAtTab = await page.evaluate('''() => {
      const r = document.querySelector('.tiptap-ruler-tab').getBoundingClientRect();
      const el = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
      return el && el.closest('[data-ruler-tab]') !== null;
    }''');
    _check(hitAtTab == true,
        'elementFromPoint no tab stop não devolveu o tab stop.');

    final marginBefore = await page.evaluate(
        '''() => JSON.parse(globalThis.getTiptapJSON()).attrs.pageMarginLeft''');

    // Arrasto humano do tab stop: +120px para a direita.
    var point = await centerOf('.tiptap-ruler-tab');
    await page.mouse.move(Point(point['x']!, point['y']!));
    await page.mouse.down();
    await page.mouse.move(Point(point['x']! + 60, point['y']!), steps: 6);
    await page.mouse.move(Point(point['x']! + 120, point['y']!), steps: 6);
    await page.mouse.up();
    await _waitUntil(
      page,
      '''() => {
        const json = JSON.parse(globalThis.getTiptapJSON());
        const tabs = json.content[0].attrs.tabStops;
        return tabs.length === 1 && parseFloat(tabs[0].position) > 60 &&
          json.attrs.pageMarginLeft === ${jsonEncode(marginBefore)};
      }''',
      'arrasto humano do tab stop mover o tab (e nunca a margem)',
    );

    // Arrasto humano do marcador de primeira linha: ele fica exatamente na
    // fronteira da margem; a prioridade tem de ser do marcador.
    point = await centerOf('.tiptap-ruler-indent-first');
    await page.mouse.move(Point(point['x']!, point['y']!));
    await page.mouse.down();
    await page.mouse.move(Point(point['x']! + 47, point['y']!), steps: 8);
    await page.mouse.up();
    await _waitUntil(
      page,
      '''() => {
        const json = JSON.parse(globalThis.getTiptapJSON());
        const indent = parseFloat(json.content[0].attrs.textIndent || '0');
        return indent > 30 &&
          json.attrs.pageMarginLeft === ${jsonEncode(marginBefore)};
      }''',
      'arrasto humano do recuo de primeira linha (e nunca a margem)',
    );

    // Arrasto humano da margem DIREITA num trecho livre da fronteira (acima
    // do pentágono do recuo direito): só aqui a margem pode responder.
    final rightMarginBefore = await page.evaluate('''() => {
      const r = document.querySelector('[data-ruler-margin="right"]')
        .getBoundingClientRect();
      const ruler = document.querySelector('.tiptap-horizontal-ruler')
        .getBoundingClientRect();
      return {x: r.left + r.width / 2, y: ruler.top + 3};
    }''');
    final rightPoint = Map<String, dynamic>.from(rightMarginBefore as Map);
    await page.mouse
        .move(Point(rightPoint['x'] as num, rightPoint['y'] as num));
    await page.mouse.down();
    await page.mouse.move(
        Point((rightPoint['x'] as num) - 40, rightPoint['y'] as num),
        steps: 6);
    await page.mouse.up();
    await _waitUntil(
      page,
      '''() => {
        const value = JSON.parse(globalThis.getTiptapJSON())
          .attrs.pageMarginRight;
        return typeof value === 'string' && value.endsWith('px') &&
          parseFloat(value) > 90;
      }''',
      'arrasto humano da margem direita em área livre de marcadores',
    );
    // Seleção de VÁRIOS parágrafos e arrasto do recuo esquerdo: como no
    // Word, todos os parágrafos selecionados devem ser reposicionados de uma
    // vez. Recarrega a página primeiro: o cenário valida o gesto em estado
    // limpo, não a sequência específica de trocas de documento acima.
    await page.reload(wait: Until.networkIdle);
    await page.waitForSelector(
      '.tiptap-horizontal-ruler-track',
      visible: true,
      timeout: const Duration(seconds: 20),
    );
    await page.evaluate('''() => globalThis.setTiptapJSON(JSON.stringify({
      type: 'doc',
      content: [
        {type: 'paragraph', content: [{type: 'text', text: 'Primeiro parágrafo da seleção.'}]},
        {type: 'paragraph', content: [{type: 'text', text: 'Segundo parágrafo da seleção.'}]},
        {type: 'paragraph', content: [{type: 'text', text: 'Terceiro parágrafo da seleção.'}]}
      ]
    }))''');
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.ProseMirror > p').length === 3 &&
        globalThis.getTiptapHTML().includes('Terceiro parágrafo')''',
      'documento de três parágrafos renderizado',
    );
    await page.click('.ProseMirror > p');
    await page.keyboard.press(Key.home);
    await page.keyboard.down(Key.shift);
    await page.keyboard.press(Key.arrowDown);
    await page.keyboard.press(Key.arrowDown);
    await page.keyboard.press(Key.end);
    await page.keyboard.up(Key.shift);
    // Espera o ESTADO do ProseMirror (não apenas o DOM) refletir a seleção
    // multi-parágrafo antes do arrasto.
    await _waitUntil(
      page,
      '''() => {
        const sel = JSON.parse(globalThis.getTiptapSelection());
        return !sel.empty && (sel.to - sel.from) > 40;
      }''',
      'seleção real de três parágrafos sincronizada no estado',
    );
    point = await centerOf('.tiptap-ruler-indent-left');
    await page.mouse.move(Point(point['x']!, point['y']!));
    await page.mouse.down();
    await page.mouse.move(Point(point['x']! + 57, point['y']!), steps: 8);
    await page.mouse.up();
    await _waitUntil(
      page,
      '''() => {
        const json = JSON.parse(globalThis.getTiptapJSON());
        const margins = json.content
          .filter(b => b.type === 'paragraph')
          .map(b => parseFloat((b.attrs && b.attrs.marginLeft) || '0'));
        return margins.length === 3 && margins.every(m => m > 35) &&
          json.attrs.pageMarginLeft === ${jsonEncode(marginBefore)};
      }''',
      'arrasto humano do recuo aplicar a TODOS os parágrafos selecionados',
    );

    // Restaura as margens para as verificações seguintes.
    await page.click('[data-ribbon-tab="layout"]');
    await page.click('#page-margins-button');
    await page.click('[data-page-margins="25,30,25,30"]');
    await page.click('[data-ribbon-tab="home"]');

    await page.evaluate('''() => {
      globalThis.__editorNode = document.querySelector('.ProseMirror');
      globalThis.__childMutations = 0;
      globalThis.__shellObserver = new MutationObserver(records => {
        globalThis.__childMutations += records
          .filter(record => record.type === 'childList').length;
      });
      globalThis.__shellObserver.observe(document.querySelector('#editor-frame'), {
        subtree: true, childList: true, attributes: true
      });
    }''');

    final tableSeed = File('${output.path}/example_context_table.json');
    await tableSeed.writeAsString(jsonEncode({
      'ops': [
        {'insert': 'Tabela contextual\n'}
      ]
    }));
    final tableInput = await page.$('#open-delta-input');
    await tableInput.uploadFile([tableSeed]);
    await _waitUntil(
      page,
      '''() => globalThis.getTiptapHTML().includes('Tabela contextual')''',
      'importação do documento-base da tabela',
    );
    await page.click('.ProseMirror > p');
    await page.click('[data-ribbon-tab="insert"]');
    _check(
      await page.evaluate('''() =>
        document.querySelector('[data-ribbon-panel="insert"]')
          .classList.contains('active')''') == true,
      'A guia Inserir não ativou seu painel.',
    );
    await page.click('[data-ribbon-tab="home"]');
    await page.evaluate('''() => { globalThis.__childMutations = 0; }''');

    await page.evaluate('''() => {
      const picker = document.querySelector('#editor-mode-picker');
      picker.value = 'compact';
      picker.dispatchEvent(new Event('change', {bubbles: true}));
    }''');
    final compact = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        toolbarHeight: document.querySelector('[data-ribbon-panel="home"]')
          .getBoundingClientRect().height,
        tabsHidden: getComputedStyle(document.querySelector('.ribbon-tabs'))
          .display === 'none',
        sameEditor: globalThis.__editorNode === document.querySelector('.ProseMirror'),
        childMutations: globalThis.__childMutations,
      })''') as Map,
    );
    _check(
        (compact['toolbarHeight'] as num) >= 43 &&
            (compact['toolbarHeight'] as num) <= 45 &&
            compact['tabsHidden'] == true &&
            compact['sameEditor'] == true &&
            compact['childMutations'] == 0,
        'Modo compacto reconstruiu DOM ou ficou fora da geometria: $compact');
    await page.evaluate('''() => {
      const picker = document.querySelector('#editor-mode-picker');
      picker.value = 'word';
      picker.dispatchEvent(new Event('change', {bubbles: true}));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final viewToggleHit = await page.evaluate('''() => {
      const button = document.querySelector('#view-mode-toggle');
      const rect = button.getBoundingClientRect();
      const hit = document.elementFromPoint(
        rect.left + rect.width / 2, rect.top + rect.height / 2);
      return {id: hit && hit.id, tag: hit && hit.tagName,
        classes: hit && hit.className};
    }''');
    await page.evaluate(
        '''() => document.querySelector('#view-mode-toggle').click()''');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final readOnly = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        editable: document.querySelector('.ProseMirror')
          .getAttribute('contenteditable'),
        label: document.querySelector('#view-mode-label').textContent,
        horizontalHidden:
          getComputedStyle(document.querySelector('.tiptap-horizontal-ruler-track'))
            .display === 'none',
        verticalHidden:
          getComputedStyle(document.querySelector('.tiptap-vertical-ruler'))
            .display === 'none',
      })''') as Map,
    );
    _check(
        readOnly['editable'] == 'false' &&
            readOnly['horizontalHidden'] == true &&
            readOnly['verticalHidden'] == true,
        'Modo somente visualização incompleto: $readOnly; alvo: $viewToggleHit');
    await page.evaluate(
        '''() => document.querySelector('#view-mode-toggle').click()''');

    final initial = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const frame = document.querySelector('.editor-frame');
        const viewport = document.querySelector('.document-viewport');
        const track = document.querySelector('.tiptap-horizontal-ruler-track');
        const ruler = track.querySelector('.tiptap-horizontal-ruler');
        const page = document.querySelector('.page-scale');
        const vertical = document.querySelector('.tiptap-vertical-ruler');
        const verticalTrack = document.querySelector('.tiptap-vertical-ruler-track');
        const status = document.querySelector('.status-bar');
        const tr = track.getBoundingClientRect();
        const vr = viewport.getBoundingClientRect();
        const rr = ruler.getBoundingClientRect();
        const pr = page.getBoundingClientRect();
        return {
          trackParentIsFrame: track.parentElement === frame,
          trackBeforeViewport: track.nextElementSibling === viewport,
          noOverlap: tr.bottom <= vr.top + 1,
          horizontalAlignment: Math.abs(rr.left - pr.left),
          trackTop: tr.top,
          viewportTop: vr.top,
          verticalVisible: getComputedStyle(vertical).display !== 'none',
          verticalWorkspaceAlignment:
              Math.abs(vertical.getBoundingClientRect().left - vr.left),
          verticalPageTopAlignment:
              Math.abs(vertical.getBoundingClientRect().top - pr.top),
          verticalTrackTopAlignment:
              Math.abs(verticalTrack.getBoundingClientRect().top - vr.top),
          verticalTrackClearOfStatus:
              verticalTrack.getBoundingClientRect().bottom <=
                status.getBoundingClientRect().top + 1,
          outerScrollable:
              document.documentElement.scrollHeight >
                document.documentElement.clientHeight + 1 ||
              document.body.scrollHeight > document.body.clientHeight + 1,
          htmlHeight: [document.documentElement.clientHeight,
            document.documentElement.scrollHeight],
          bodyHeight: [document.body.clientHeight, document.body.scrollHeight],
          shellBounds: (() => { const r = frame.closest('.app-shell')
            .getBoundingClientRect(); return [r.top, r.bottom, r.height]; })(),
        };
      }''') as Map,
    );
    _check(initial['trackParentIsFrame'] == true,
        'A régua horizontal continua dentro do viewport rolável.');
    _check(initial['trackBeforeViewport'] == true,
        'A régua horizontal não está imediatamente acima do viewport.');
    _check(initial['noOverlap'] == true,
        'A régua horizontal sobrepõe o conteúdo antes do scroll.');
    _check((initial['horizontalAlignment'] as num).abs() <= 1,
        'A régua horizontal não está alinhada à folha: $initial');
    _check((initial['verticalWorkspaceAlignment'] as num).abs() <= 1,
        'A régua vertical não está na borda do workspace: $initial');
    _check((initial['verticalPageTopAlignment'] as num).abs() <= 1,
        'A régua vertical não começa no topo da página ativa: $initial');
    _check(
        (initial['verticalTrackTopAlignment'] as num).abs() <= 1 &&
            initial['verticalTrackClearOfStatus'] == true,
        'O track vertical invadiu ribbon ou status bar: $initial');
    _check(initial['outerScrollable'] == false,
        'A shell criou uma segunda barra de rolagem: $initial');

    final imageFixture = File('${output.path}/example_context_image.json');
    await imageFixture.writeAsString(jsonEncode({
      'ops': [
        {
          'insert': {
            'image':
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAEklEQVR42mP8z8AARAwMjDAGAC0AAf6n7bQAAAAASUVORK5CYII='
          }
        },
        {'insert': '\n'},
      ],
    }));
    final imageInput = await page.$('#open-delta-input');
    await imageInput.uploadFile([imageFixture]);
    await page.waitForSelector('.ProseMirror img', visible: true);
    await page.evaluate('''() => {
      const image = document.querySelector('.ProseMirror img');
      image.style.width = '120px';
      image.style.height = '80px';
    }''');
    await page.click('.ProseMirror img');
    await _waitUntil(
      page,
      '''() => document.querySelector('[data-ribbon-tab="contextual"]')
        .classList.contains('contextual-tab-visible')''',
      'guia contextual de imagem',
    );
    await page.click(
      'button[data-context-for="image"][data-context-action="align-center"]',
    );
    await _waitUntil(
      page,
      '''() => document.querySelector('.ProseMirror img')
        .getAttribute('data-object-align') === 'center' ''',
      'comando funcional de alinhamento da imagem',
    );
    final contextual = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        tab: document.querySelector('[data-ribbon-tab="contextual"]').textContent,
        panelContext: document.querySelector(
          '[data-ribbon-panel="contextual"]').dataset.contextKind,
        imageAlignment: document.querySelector(
          '.ProseMirror img').getAttribute('data-object-align'),
      })''') as Map,
    );
    _check(
      contextual['tab'] == 'Formato da Imagem' &&
          contextual['panelContext'] == 'image' &&
          contextual['imageAlignment'] == 'center',
      'A guia contextual de imagem não é funcional: $contextual',
    );

    await page.click('[data-ribbon-tab="insert"]');
    // O grid picker do Word: abre o dropdown e escolhe 3x3.
    await page.click('#insert-table-button');
    await page.waitForSelector('#insert-table-menu.open');
    await page.click('#insert-table-menu [data-table-grid="3,3"]');
    await _waitUntil(
      page,
      '''() => globalThis.getTiptapJSON().includes('"type":"table"')''',
      'comando Inserir tabela alterar o documento',
    );
    await page.waitForSelector('.ProseMirror table');
    await page.click('.ProseMirror td p');
    await _waitUntil(
      page,
      '''() => document.querySelector('[data-ribbon-panel="contextual"]')
        .dataset.contextKind === 'table' ''',
      'guia contextual de tabela',
    );
    await page.click(
      'button[data-context-for="table"][data-context-action="align-right"]',
    );
    await _waitUntil(
      page,
      '''() => document.querySelector('.ProseMirror table')
        .style.textAlign === 'right' ''',
      'comando funcional de alinhamento da tabela',
    );
    final contextualTable = Map<String, dynamic>.from(
      await page.evaluate('''() => ({
        tab: document.querySelector('[data-ribbon-tab="contextual"]').textContent,
        panelContext: document.querySelector(
          '[data-ribbon-panel="contextual"]').dataset.contextKind,
        alignment: document.querySelector('.ProseMirror table').style.textAlign,
      })''') as Map,
    );
    _check(
      contextualTable['tab'] == 'Design da Tabela' &&
          contextualTable['panelContext'] == 'table' &&
          contextualTable['alignment'] == 'right',
      'A guia contextual de tabela não é funcional: $contextualTable',
    );

    // Operações estruturais reais da guia contextual: inserir linha abaixo e
    // excluir a mesma linha em seguida.
    final rowsBefore = await page.evaluate(
        '''() => document.querySelectorAll('.ProseMirror tr').length''') as num;
    await page.click(
      'button[data-context-for="table"][data-context-action="row-below"]',
    );
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.ProseMirror tr').length ===
          ${rowsBefore.toInt() + 1}''',
      'inserir linha abaixo pela guia contextual',
    );
    await page.click(
      'button[data-context-for="table"][data-context-action="del-row"]',
    );
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.ProseMirror tr').length ===
          ${rowsBefore.toInt()}''',
      'excluir linha pela guia contextual',
    );

    // Modo tabela da régua: com o caret na tabela, cada fronteira de coluna
    // ganha um marcador arrastável (RULER_OBJECT_TYPE_TABLE do Word).
    await page.click('.ProseMirror td p');
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.tiptap-ruler-table-col').length === 3''',
      'marcadores de coluna da tabela na régua',
    );
    // Arrasto humano do primeiro marcador de coluna (+45px).
    final colMarker = Map<String, dynamic>.from(await page.evaluate('''() => {
      const r = document.querySelector('[data-ruler-table-col="1"]')
        .getBoundingClientRect();
      return {x: r.left + r.width / 2, y: r.top + r.height / 2};
    }''') as Map);
    await page.mouse
        .move(Point(colMarker['x'] as num, colMarker['y'] as num));
    await page.mouse.down();
    await page.mouse.move(
        Point((colMarker['x'] as num) + 45, colMarker['y'] as num),
        steps: 6);
    await page.mouse.up();
    await _waitUntil(
      page,
      '''() => {
        const table = JSON.parse(globalThis.getTiptapJSON()).content
          .find(b => b.type === 'table');
        const widths = table && table.attrs && table.attrs.columnWidths;
        return Array.isArray(widths) && widths.length === 3 &&
          widths[0] > widths[1] + 20;
      }''',
      'arrasto do marcador de coluna da régua gravar columnWidths',
    );

    // Mini-UI flutuante + âncoras: quickbar insere linha e o ⊞ seleciona a
    // tabela inteira.
    await _waitUntil(
      page,
      '''() => !!document.querySelector('.tiptap-table-overlay .tiptap-table-quickbar')''',
      'mini-UI flutuante da tabela',
    );
    final quickRows = await page.evaluate(
        '''() => document.querySelectorAll('.ProseMirror tr').length''') as num;
    await page.click('[data-table-quick="row-below"]');
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.ProseMirror tr').length ===
          ${quickRows.toInt() + 1}''',
      'quickbar inserir linha abaixo',
    );
    await page.click('[data-table-quick="del-row"]');
    await _waitUntil(
      page,
      '''() => document.querySelectorAll('.ProseMirror tr').length ===
          ${quickRows.toInt()}''',
      'quickbar excluir linha',
    );
    await page.click('[data-table-anchor="move"]');
    await _waitUntil(
      page,
      '''() => {
        const sel = JSON.parse(globalThis.getTiptapSelection());
        return !sel.empty && (sel.to - sel.from) > 10;
      }''',
      'âncora ⊞ selecionar a tabela inteira',
    );
    await page.click('.ProseMirror td p');

    final deltaFixture = File('${output.path}/example_rulers_delta.json');
    await deltaFixture.writeAsString(jsonEncode({
      'ops': [
        for (var index = 0; index < 220; index++)
          {
            'insert':
                'Parágrafo $index para validar réguas, scroll e página ativa no editor real.\n',
          },
      ],
    }));
    final deltaInput = await page.$('#open-delta-input');
    await deltaInput.uploadFile([deltaFixture]);
    await _waitUntil(
      page,
      '() => Number(document.querySelector(".ProseMirror").dataset.pageCount || 0) >= 3',
      'paginação do fixture',
    );
    await page.click('.ProseMirror p');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final ribbonScreenshot = File('${output.path}/example_word_ribbon.png');
    await ribbonScreenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png),
      flush: true,
    );

    await page.evaluate('''() => {
      const viewport = document.querySelector('.document-viewport');
      const editor = document.querySelector('.ProseMirror');
      const pageHeight = parseFloat(editor.style.getPropertyValue('--tiptap-page-height'));
      const pageGap = parseFloat(editor.style.getPropertyValue('--tiptap-page-gap')) || 0;
      viewport.scrollTop = pageHeight + pageGap + 120;
      viewport.dispatchEvent(new Event('scroll'));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final afterScroll = Map<String, dynamic>.from(
      await page.evaluate('''() => {
        const viewport = document.querySelector('.document-viewport');
        const track = document.querySelector('.tiptap-horizontal-ruler-track');
        const vertical = document.querySelector('.tiptap-vertical-ruler');
        const tr = track.getBoundingClientRect();
        const vr = viewport.getBoundingClientRect();
        return {
          trackTop: tr.top,
          noOverlap: tr.bottom <= vr.top + 1,
          verticalHidden: getComputedStyle(vertical).display === 'none',
          scrollTop: viewport.scrollTop,
        };
      }''') as Map,
    );
    _check(
      ((afterScroll['trackTop'] as num) - (initial['trackTop'] as num)).abs() <=
          1,
      'A régua horizontal se moveu com o conteúdo: $afterScroll',
    );
    _check(afterScroll['noOverlap'] == true,
        'A régua horizontal ficou sobre o documento após o scroll.');
    _check(afterScroll['verticalHidden'] == true,
        'A régua vertical ficou visível longe da página do caret.');

    final screenshot = File('${output.path}/example_rulers_after_scroll.png');
    await screenshot.writeAsBytes(
      await page.screenshot(format: ScreenshotFormat.png),
      flush: true,
    );
    await File('${output.path}/example_rulers_harness.json').writeAsString(
      const JsonEncoder.withIndent(' ').convert({
        'initial': initial,
        'chrome': chrome,
        'readOnly': readOnly,
        'compact': compact,
        'contextual': contextual,
        'contextualTable': contextualTable,
        'afterScroll': afterScroll,
        'pageErrors': pageErrors,
        'screenshot': screenshot.path,
        'ribbonScreenshot': ribbonScreenshot.path,
        'tabDialogScreenshot': tabDialogScreenshot.path,
      }),
    );
    _check(pageErrors.isEmpty, 'Erros no browser: $pageErrors');
    await page.close();
    stdout.writeln('UI das réguas validada com Puppeteer: ${screenshot.path}');
  } finally {
    await browser?.close();
    await server.close(force: true);
  }
}

Future<void> _waitUntil(
  Page page,
  String predicate,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await page.evaluate(predicate) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Timeout aguardando $description.');
}

String? _browserExecutable() {
  final configured = Platform.environment['CHROME_EXECUTABLE'];
  if (configured != null && File(configured).existsSync()) return configured;
  for (final candidate in const [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
