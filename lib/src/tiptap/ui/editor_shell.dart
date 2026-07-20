import 'dart:async';

import 'package:web/web.dart' as web;

import 'component_framework.dart';
import 'icons.dart';

/// Product layouts exposed by the embeddable editor shell.
enum TiptapEditorMode { compact, simple, word, viewer }

class TiptapEditorShellOptions {
  final TiptapEditorMode initialMode;
  final String title;
  final String locale;
  final String width;
  final String height;
  final String? maxWidth;
  final String margin;
  final Map<String, String> hostStyles;
  final bool showTitleBar;
  final bool showStatusBar;
  final bool enableDocumentStatistics;

  const TiptapEditorShellOptions({
    this.initialMode = TiptapEditorMode.word,
    this.title = 'Documento sem título',
    this.locale = 'Português (Brasil)',
    this.width = '100%',
    this.height = '720px',
    this.maxWidth,
    this.margin = '0',
    this.hostStyles = const {},
    this.showTitleBar = true,
    this.showStatusBar = true,
    this.enableDocumentStatistics = false,
  });
}

/// Framework-independent editor chrome built entirely from Dart DOM APIs.
///
/// The host application owns only a mount element. This component creates the
/// title bar, mode picker, ribbon/compact toolbars, document viewport, status
/// bar, menus and file inputs. It has no Angular dependency, so the same class
/// can be mounted from plain Dart web or from an AngularDart component hook.
class TiptapEditorShell {
  final web.HTMLElement host;
  final TiptapEditorShellOptions options;
  final StreamController<TiptapEditorMode> _modeChanges =
      StreamController<TiptapEditorMode>.broadcast(sync: true);
  final List<TiptapComponent> _components = [];

  late final web.HTMLElement root;
  late final web.HTMLElement editorElement;
  late final web.HTMLElement editorFrame;
  late final web.HTMLElement pageScale;
  late final web.HTMLElement documentViewport;
  late final TiptapSelect modeSelect;
  late final TiptapRibbon ribbon;
  late final TiptapDropdown exportDropdown;
  late final TiptapModal pageMarginsModal;
  late final TiptapModal pageSizeModal;
  late final TiptapModal tabStopsModal;
  late TiptapEditorMode _mode;

  TiptapEditorShell._(this.host, this.options) {
    _mode = options.initialMode;
    _build();
  }

  factory TiptapEditorShell.mount(
    web.HTMLElement host, {
    TiptapEditorShellOptions options = const TiptapEditorShellOptions(),
  }) =>
      TiptapEditorShell._(host, options);

  TiptapEditorMode get mode => _mode;
  Stream<TiptapEditorMode> get modeChanges => _modeChanges.stream;

  void setMode(TiptapEditorMode value, {bool notify = true}) {
    _mode = value;
    for (final mode in TiptapEditorMode.values) {
      root.classList.toggle('tiptap-mode-${mode.name}', mode == value);
    }
    modeSelect.value = value.name;
    final label = root.querySelector('#view-mode-label');
    if (label != null) {
      final nextLabel =
          value == TiptapEditorMode.viewer ? 'Somente visualização' : 'Edição';
      if (label.textContent != nextLabel) label.textContent = nextLabel;
    }
    if (notify) _modeChanges.add(value);
  }

  void activateRibbon(String name) {
    ribbon.activate(name);
  }

  void setContextualContext(String? context, {bool activate = true}) {
    final visible = context != null;
    ribbon.setContextual('contextual', visible);
    final panel = root.querySelector('[data-ribbon-panel="contextual"]');
    if (panel is web.HTMLElement) {
      if (context == null) {
        panel.removeAttribute('data-context-kind');
      } else {
        panel.setAttribute('data-context-kind', context);
      }
    }
    ribbon.setTabLabel(
      'contextual',
      switch (context) {
        'image' => 'Formato da Imagem',
        'table' => 'Design da Tabela',
        'header' => 'Cabeçalho e Rodapé',
        'footer' => 'Cabeçalho e Rodapé',
        _ => 'Formato',
      },
    );
    if (visible && activate) {
      ribbon.activate('contextual');
    } else if (!visible && ribbon.active == 'contextual') {
      ribbon.activate('home');
    }
  }

  void destroy() {
    _modeChanges.close();
    for (final component in _components.reversed) {
      component.dispose();
    }
    _components.clear();
    root.remove();
  }

  void _build() {
    host.textContent = '';
    for (final entry in options.hostStyles.entries) {
      host.style.setProperty(entry.key, entry.value);
    }
    root = _el('div',
        classes: 'app-shell tiptap-shell tiptap-ui'
            '${options.showTitleBar ? '' : ' tiptap-hide-titlebar'}'
            '${options.showStatusBar ? '' : ' tiptap-hide-statusbar'}'
            '${options.enableDocumentStatistics ? '' : ' tiptap-statistics-disabled'}');
    root.style
      ..width = options.width
      ..height = options.height
      ..margin = options.margin;
    if (options.maxWidth != null) root.style.maxWidth = options.maxWidth!;
    root.appendChild(_buildHeader());
    root.appendChild(_buildRibbonTabs());
    editorFrame = _buildEditorFrame();
    root.appendChild(editorFrame);
    root
      ..appendChild(_buildPageMarginsModal())
      ..appendChild(_buildPageSizeModal())
      ..appendChild(_buildTabStopsModal());
    root.appendChild(_el('div', classes: 'toast', id: 'toast', attrs: {
      'role': 'status',
      'aria-live': 'polite',
    }));
    root
      ..appendChild(_fileInput('open-docx-input',
          '.docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document'))
      ..appendChild(_fileInput('open-delta-input', '.json,application/json'))
      ..appendChild(_fileInput('insert-image-input', 'image/png,image/jpeg'))
      ..appendChild(_button('insert-image-button', '',
          icon: 'image', classes: 'ribbon-control-proxy'));
    host.appendChild(root);
    TiptapIcons.hydrate(root);
    setMode(_mode, notify: false);
  }

  web.HTMLElement _buildHeader() {
    final header = _el('header', classes: 'app-header');
    final brand = _el('div', classes: 'brand')
      ..appendChild(_el('span', text: 'Tiptap Dart'));
    final identity = _el('div', classes: 'document-identity');
    final title = _el('input', id: 'document-title') as web.HTMLInputElement
      ..value = options.title
      ..setAttribute('aria-label', 'Nome do documento');
    final save = _el('span', classes: 'save-state', id: 'save-state')
      ..appendChild(_el('span', classes: 'status-dot'))
      ..appendChild(web.document.createTextNode('Salvo localmente'));
    identity
      ..appendChild(title)
      ..appendChild(save);

    header
      ..appendChild(brand)
      ..appendChild(identity);
    return header;
  }

  web.HTMLElement _buildFileControls() {
    final controls = _el('div', classes: 'file-mode-controls');
    modeSelect = _own(TiptapSelect(
      id: 'editor-mode-picker',
      classes: 'mode-picker',
      ariaLabel: 'Modo do editor',
      value: _mode.name,
      items: const {
        'word': 'Word completo',
        'compact': 'Editor compacto',
        'simple': 'Editor simples',
        'viewer': 'Somente visualização',
      },
    ));
    modeSelect.changes.listen((_) {
      final selected = TiptapEditorMode.values
          .where((mode) => mode.name == modeSelect.value)
          .firstOrNull;
      if (selected != null) setMode(selected);
    });
    controls
      ..appendChild(modeSelect.root)
      ..appendChild(_button('view-mode-toggle', 'Edição',
          icon: 'view',
          classes: 'header-button view-mode-button',
          labelId: 'view-mode-label'))
      ..appendChild(_button('theme-toggle', '',
          icon: 'sun', classes: 'icon-button header-icon'));
    return controls;
  }

  web.HTMLElement _buildExportMenu() {
    final trigger = _button('export-menu-button', 'Exportar',
        icon: 'download', classes: 'header-button primary');
    final menu = _el('div', classes: 'menu-panel', id: 'export-menu', attrs: {
      'role': 'menu',
    });
    for (final item in const [
      ('export-docx', 'W', 'Documento DOCX', 'Editável no Word', 'docx'),
      ('export-pdf', 'P', 'Documento PDF', 'Texto vetorial', 'pdf'),
      ('copy-delta', '{}', 'Copiar Quill Delta', 'JSON de integração', 'json'),
    ]) {
      final button = _el('button', id: item.$1, attrs: {'role': 'menuitem'});
      final description = _el('span')
        ..appendChild(_el('strong', text: item.$3))
        ..appendChild(_el('small', text: item.$4));
      button
        ..appendChild(
            _el('span', classes: 'file-badge ${item.$5}', text: item.$2))
        ..appendChild(description);
      menu.appendChild(button);
    }
    exportDropdown = _own(TiptapDropdown(
      trigger: trigger,
      panel: menu,
      portalHost: root,
      classes: 'export-menu',
    ));
    return exportDropdown.root;
  }

  web.HTMLElement _buildRibbonTabs() {
    ribbon = _own(TiptapRibbon(tabs: const {
      'file': 'Arquivo',
      'home': 'Página Inicial',
      'insert': 'Inserir',
      'design': 'Design',
      'layout': 'Layout',
      'review': 'Revisão',
      'view': 'Exibir',
      'contextual': 'Formato',
    }));
    ribbon.root
        .querySelector('[data-ribbon-tab="contextual"]')
        ?.classList
        .add('contextual-tab');
    return ribbon.root;
  }

  web.HTMLElement _buildEditorFrame() {
    final frame = _el('main', classes: 'editor-frame', id: 'editor-frame');
    frame
        .appendChild(_el('div', classes: 'progress-strip', id: 'progress-strip')
          ..setAttribute('aria-hidden', 'true')
          ..appendChild(_el('span')));
    frame
      ..appendChild(_buildHomePanel())
      ..appendChild(_buildFilePanel())
      ..appendChild(_buildInsertPanel())
      ..appendChild(_buildDesignPanel())
      ..appendChild(_buildLayoutPanel())
      ..appendChild(_messagePanel(
          'review',
          [
            ('Idioma', options.locale),
            if (options.enableDocumentStatistics)
              ('Estatísticas', '0 palavras'),
          ],
          countId:
              options.enableDocumentStatistics ? 'ribbon-word-count' : null))
      ..appendChild(_buildViewPanel())
      ..appendChild(_buildContextualPanel());

    documentViewport =
        _el('section', classes: 'document-viewport', id: 'document-viewport');
    pageScale = _el('div', classes: 'page-scale', id: 'page-scale');
    final sheet = _el('article', classes: 'page-sheet', id: 'page-sheet');
    editorElement = _el('div', id: 'editor', attrs: {
      'aria-label': 'Conteúdo do documento',
    });
    sheet.appendChild(editorElement);
    pageScale.appendChild(sheet);
    documentViewport.appendChild(pageScale);
    frame
      ..appendChild(documentViewport)
      ..appendChild(_buildStatusBar());
    return frame;
  }

  web.HTMLElement _buildHomePanel() {
    final panel = _panel('home', active: true, id: 'toolbar');
    final styleProxy = _selectControl('block-style', 'block-style', const {
      'paragraph': 'Texto normal',
      'heading-1': 'Título 1',
      'heading-2': 'Título 2',
      'heading-3': 'Título 3',
    })
      ..classList.add('ribbon-control-proxy');
    final fontTop = _ribbonRow([
      _selectControl('font-family', 'font-family', const {
        'Arial': 'Arial',
        'Times New Roman': 'Times New Roman',
        'Courier New': 'Courier New',
        'Inter': 'Inter',
      }),
      _selectControl(
          'font-size',
          'font-size',
          const {
            '10': '10',
            '11': '11',
            '12': '12',
            '14': '14',
            '16': '16',
            '18': '18',
            '24': '24',
            '32': '32',
            '48': '48',
          },
          selected: '12'),
      _plainTool('A↑'),
      _plainTool('A↓'),
    ]);
    final fontBottom = _ribbonRow([
      for (final command in const [
        ('bold', 'bold'),
        ('italic', 'italic'),
        ('underline', 'underline'),
        ('strike', 'strike'),
        ('code', 'code'),
      ])
        _iconTool(command.$2, attrs: {'data-tiptap-command': command.$1}),
      ..._colorControlButtons(),
    ]);
    final paragraphTop = _ribbonRow([
      _iconTool('list-bullet', attrs: {'data-tiptap-command': 'bulletList'}),
      _iconTool('list-number', attrs: {'data-tiptap-command': 'orderedList'}),
      _plainTool('⇤'),
      _plainTool('⇥'),
      _plainTool('A↕'),
    ]);
    final paragraphBottom = _ribbonRow([
      for (final command in const [
        ('align-left', 'align-left'),
        ('align-center', 'align-center'),
        ('align-right', 'align-right'),
      ])
        _iconTool(command.$2, attrs: {'data-tiptap-command': command.$1}),
      _plainTool('≡'),
      _plainTool('↕'),
      _plainTool('↘')
        ..id = 'tab-stops-dialog-button'
        ..classList.add('ribbon-dialog-launcher')
        ..setAttribute('title', 'Tabulação…')
        ..setAttribute('aria-label', 'Abrir diálogo Tabulação'),
    ]);

    panel
      ..appendChild(styleProxy)
      ..appendChild(_ribbonSection(
          'Área de Transferência',
          [
            _largeCommand(null, 'open', 'Colar', ''),
            _ribbonRows([
              _ribbonRow([_plainTool('Recortar'), _plainTool('Copiar')]),
              _ribbonRow([_plainTool('Pincel de Formatação')]),
            ], compact: true),
          ],
          classes: 'clipboard-section'))
      ..appendChild(_ribbonSection(
          'Fonte',
          [
            _ribbonRows([fontTop, fontBottom])
          ],
          classes: 'font-section'))
      ..appendChild(_ribbonSection(
          'Parágrafo',
          [
            _ribbonRows([paragraphTop, paragraphBottom])
          ],
          classes: 'paragraph-section'))
      ..appendChild(_ribbonSection('Estilos', [_styleGallery()],
          classes: 'styles-section'))
      ..appendChild(_ribbonSection(
          'Editando',
          [
            _ribbonRows([
              _ribbonRow([_plainTool('Localizar')]),
              _ribbonRow([_plainTool('Substituir'), _plainTool('Selecionar')]),
            ], compact: true),
          ],
          classes: 'editing-section'));
    return panel;
  }

  web.HTMLElement _buildFilePanel() {
    final panel = _panel('file');
    panel
      ..appendChild(_ribbonSection('Documento', [
        _largeCommand('open-docx-button', 'open', 'Abrir DOCX', ''),
        _largeCommand('open-delta-button', 'code', 'Abrir Delta', ''),
        _buildExportMenu(),
      ]))
      ..appendChild(_ribbonSection('Modo e Aparência', [
        _buildFileControls(),
      ]));
    return panel;
  }

  web.HTMLElement _buildInsertPanel() {
    final panel = _panel('insert');
    panel
      ..appendChild(_ribbonSection('Páginas', [
        _largeCommand(null, null, 'Folha de Rosto', ''),
        _largeCommand(null, null, 'Página em Branco', ''),
        _largeCommand(null, 'horizontal-rule', 'Quebra de Página', '',
            action: 'horizontal-rule'),
      ]))
      ..appendChild(_ribbonSection('Tabelas', [
        _buildTableGridPicker(),
      ]))
      ..appendChild(_ribbonSection('Sumário', [
        _largeCommand('insert-toc-button', 'list-number', 'Sumário', ''),
        _largeCommand('update-toc-button', 'redo', 'Atualizar Sumário', ''),
      ]))
      ..appendChild(_ribbonSection(
          'Ilustrações',
          [
            _largeCommand('ribbon-insert-image', 'image', 'Imagens', ''),
            _largeCommand('insert-textbox-button', null, 'Caixa de Texto', ''),
            _largeCommand(null, null, 'Formas', ''),
            _largeCommand(null, null, 'Ícones', ''),
            _largeCommand(null, null, 'Modelos 3D', ''),
            _largeCommand(null, null, 'SmartArt', ''),
            _largeCommand(null, null, 'Gráfico', ''),
          ],
          classes: 'insert-illustrations'))
      ..appendChild(_ribbonSection('Links', [
        _largeCommand(null, 'link', 'Link', '', action: 'link'),
        _largeCommand(null, null, 'Indicador', ''),
        _largeCommand(null, null, 'Referência Cruzada', ''),
      ]))
      ..appendChild(_ribbonSection(
          'Cabeçalho e Rodapé',
          [
            _largeCommand('edit-header-button', null, 'Cabeçalho', ''),
            _largeCommand('edit-footer-button', null, 'Rodapé', ''),
            _buildPageNumberMenu(),
          ],
          classes: 'insert-header-footer'));
    return panel;
  }

  web.HTMLElement _buildTableGridPicker() {
    final trigger = _largeCommand('insert-table-button', 'table', 'Tabela', '')
      ..setAttribute('aria-haspopup', 'menu')
      ..setAttribute('aria-controls', 'insert-table-menu');
    final menu = _el('div',
        classes: 'menu-panel table-grid-menu',
        id: 'insert-table-menu',
        attrs: {'role': 'menu', 'aria-label': 'Inserir tabela'});
    final caption = _el('div',
        classes: 'table-grid-caption',
        id: 'table-grid-caption',
        text: 'Inserir tabela');
    final grid = _el('div', classes: 'table-grid-cells', attrs: {
      'data-table-grid-host': '',
    });
    for (var row = 1; row <= 8; row++) {
      for (var col = 1; col <= 10; col++) {
        grid.appendChild(_el('button', classes: 'table-grid-cell', attrs: {
          'type': 'button',
          'data-table-grid': '$row,$col',
          'aria-label': 'Tabela ${row}x$col',
        }));
      }
    }
    menu
      ..appendChild(caption)
      ..appendChild(grid);
    final dropdown = _own(TiptapDropdown(
      trigger: trigger,
      panel: menu,
      portalHost: root,
      classes: 'table-grid-dropdown',
    ));
    return dropdown.root;
  }

  web.HTMLElement _buildPageNumberMenu() {
    final trigger =
        _largeCommand('page-number-button', null, 'Número de Página', '')
          ..setAttribute('aria-haspopup', 'menu')
          ..setAttribute('aria-controls', 'page-number-menu');
    final menu = _el('div',
        classes: 'menu-panel page-number-menu',
        id: 'page-number-menu',
        attrs: {'role': 'menu', 'aria-label': 'Número de página'});
    for (final item in const [
      ('footer-center', 'Fim da Página — Centralizado'),
      ('footer-right', 'Fim da Página — À direita'),
      ('footer-left', 'Fim da Página — À esquerda'),
      ('header-center', 'Início da Página — Centralizado'),
      ('header-right', 'Início da Página — À direita'),
      ('remove', 'Remover Números de Página'),
    ]) {
      menu.appendChild(_el('button',
          classes: 'ribbon-text-command',
          text: item.$2,
          attrs: {'role': 'menuitem', 'data-page-number-action': item.$1}));
    }
    final dropdown = _own(TiptapDropdown(
      trigger: trigger,
      panel: menu,
      portalHost: root,
      classes: 'page-number-dropdown',
    ));
    return dropdown.root;
  }

  web.HTMLElement _buildDesignPanel() {
    final panel = _panel('design');
    panel
      ..appendChild(_ribbonSection(
          'Formatação do Documento',
          [
            _largeCommand(null, null, 'Temas', ''),
            _styleGallery(),
            _largeCommand(null, null, 'Cores', ''),
            _largeCommand(null, null, 'Fontes', ''),
            _largeCommand(null, null, 'Espaçamento entre Parágrafos', ''),
            _largeCommand(null, null, 'Efeitos', ''),
          ],
          classes: 'design-formatting'))
      ..appendChild(_ribbonSection(
          'Plano de Fundo da Página',
          [
            _largeCommand(null, null, "Marca d'água", ''),
            _largeCommand(null, null, 'Cor da Página', ''),
            _largeCommand(null, null, 'Bordas de Página', ''),
          ],
          classes: 'design-background'));
    return panel;
  }

  web.HTMLElement _buildLayoutPanel() {
    final panel = _panel('layout');
    panel
      ..appendChild(_ribbonSection('Configurar Página', [
        _buildPageMarginsMenu(),
        _buildPageOrientationMenu(),
        _buildPageSizeMenu(),
        _largeCommand(null, null, 'Colunas', ''),
        _ribbonRows([
          _ribbonRow([_plainTool('Quebras')]),
          _ribbonRow(
              [_plainTool('Números de Linha'), _plainTool('Hifenização')]),
        ], compact: true),
      ]))
      ..appendChild(_ribbonSection(
          'Parágrafo',
          [
            _ribbonRows([
              _ribbonRow([
                _plainTool('Recuar  Esquerda: 0 cm'),
                _plainTool('Antes: 12 pt')
              ]),
              _ribbonRow(
                  [_plainTool('Direita: 0 cm'), _plainTool('Depois: 6 pt')]),
            ], compact: true),
          ],
          classes: 'layout-paragraph'))
      ..appendChild(_ribbonSection(
          'Organizar',
          [
            _largeCommand(null, null, 'Posição', ''),
            _largeCommand(null, null, 'Quebra de Texto Automática', ''),
            _largeCommand(null, null, 'Avançar', ''),
            _largeCommand(null, null, 'Recuar', ''),
          ],
          classes: 'layout-arrange'));
    return panel;
  }

  web.HTMLElement _buildPageMarginsMenu() => _buildPageSetupMenu(
        trigger: _largeCommand(
          'page-margins-button',
          'page-margins',
          'Margens',
          '',
        ),
        panelId: 'page-margins-menu',
        panelLabel: 'Margens da página',
        items: const [
          (
            label: 'Normal',
            detail: 'Sup. 2,5 · Esq. 3 · Inf. 2,5 · Dir. 3 cm',
            attribute: 'data-page-margins',
            value: '25,30,25,30'
          ),
          (
            label: 'Estreita',
            detail: '1,27 cm em todos os lados',
            attribute: 'data-page-margins',
            value: '12.7,12.7,12.7,12.7'
          ),
          (
            label: 'Moderada',
            detail: 'Sup./Inf. 2,54 · Esq./Dir. 1,91 cm',
            attribute: 'data-page-margins',
            value: '25.4,19.1,25.4,19.1'
          ),
          (
            label: 'Larga',
            detail: 'Sup./Inf. 2,54 · Esq./Dir. 5,08 cm',
            attribute: 'data-page-margins',
            value: '25.4,50.8,25.4,50.8'
          ),
          (
            label: 'Margens Personalizadas…',
            detail: 'Definir cada lado em centímetros',
            attribute: 'data-page-margins-custom',
            value: 'open'
          ),
        ],
      );

  web.HTMLElement _buildPageOrientationMenu() => _buildPageSetupMenu(
        trigger: _largeCommand(
          'page-orientation-button',
          'orientation',
          'Orientação',
          '',
        ),
        panelId: 'page-orientation-menu',
        panelLabel: 'Orientação da página',
        items: const [
          (
            label: 'Retrato',
            detail: 'Página vertical',
            attribute: 'data-page-orientation',
            value: 'portrait'
          ),
          (
            label: 'Paisagem',
            detail: 'Página horizontal',
            attribute: 'data-page-orientation',
            value: 'landscape'
          ),
        ],
      );

  web.HTMLElement _buildPageSizeMenu() => _buildPageSetupMenu(
        trigger: _largeCommand(
          'page-size-button',
          'page-size',
          'Tamanho',
          '',
        ),
        panelId: 'page-size-menu',
        panelLabel: 'Tamanho da página',
        scrollable: true,
        items: const [
          (
            label: 'Carta',
            detail: '21,59 × 27,94 cm',
            attribute: 'data-page-size',
            value: '215.9,279.4'
          ),
          (
            label: 'Legal',
            detail: '21,59 × 35,56 cm',
            attribute: 'data-page-size',
            value: '215.9,355.6'
          ),
          (
            label: 'Ofício (Brasil)',
            detail: '21,6 × 33 cm',
            attribute: 'data-page-size',
            value: '216,330'
          ),
          (
            label: 'A4',
            detail: '21 × 29,7 cm',
            attribute: 'data-page-size',
            value: '210,297'
          ),
          (
            label: 'A5',
            detail: '14,8 × 21 cm',
            attribute: 'data-page-size',
            value: '148,210'
          ),
          (
            label: 'B5',
            detail: '17,6 × 25 cm',
            attribute: 'data-page-size',
            value: '176,250'
          ),
          (
            label: 'Envelope nº 10',
            detail: '10,48 × 24,13 cm',
            attribute: 'data-page-size',
            value: '104.8,241.3'
          ),
          (
            label: 'Envelope DL',
            detail: '11 × 22 cm',
            attribute: 'data-page-size',
            value: '110,220'
          ),
          (
            label: 'Tabloide',
            detail: '27,94 × 43,18 cm',
            attribute: 'data-page-size',
            value: '279.4,431.8'
          ),
          (
            label: 'A3',
            detail: '29,7 × 42 cm',
            attribute: 'data-page-size',
            value: '297,420'
          ),
          (
            label: 'Tabloide extra',
            detail: '29,69 × 45,72 cm',
            attribute: 'data-page-size',
            value: '296.9,457.2'
          ),
          (
            label: 'ROC 16K',
            detail: '19,68 × 27,3 cm',
            attribute: 'data-page-size',
            value: '196.8,273'
          ),
          (
            label: 'Envelope Choukei 3',
            detail: '12 × 23,5 cm',
            attribute: 'data-page-size',
            value: '120,235'
          ),
          (
            label: 'Super B/A3',
            detail: '30,5 × 48,7 cm',
            attribute: 'data-page-size',
            value: '305,487'
          ),
          (
            label: 'Mais Tamanhos de Papel…',
            detail: 'Definir largura e altura',
            attribute: 'data-page-size-custom',
            value: 'open'
          ),
        ],
      );

  web.HTMLElement _buildPageMarginsModal() {
    pageMarginsModal = _own(TiptapModal(
      title: 'Configurar Página — Margens',
      classes: 'page-setup-modal',
    ));
    final grid = _el('div', classes: 'page-setup-form-grid');
    for (final field in const [
      ('custom-margin-top', 'Superior'),
      ('custom-margin-bottom', 'Inferior'),
      ('custom-margin-left', 'Esquerda'),
      ('custom-margin-right', 'Direita'),
    ]) {
      grid.appendChild(_numberField(field.$1, field.$2, suffix: 'cm'));
    }
    pageMarginsModal.body
      ..appendChild(_el('p', classes: 'modal-help', text: 'Margens da página'))
      ..appendChild(grid);
    pageMarginsModal.footer
      ..appendChild(_el('button',
          id: 'custom-margins-cancel',
          text: 'Cancelar',
          classes: 'dialog-button'))
      ..appendChild(_el('button',
          id: 'custom-margins-apply',
          text: 'OK',
          classes: 'dialog-button primary'));
    return pageMarginsModal.root;
  }

  web.HTMLElement _buildPageSizeModal() {
    pageSizeModal = _own(TiptapModal(
      title: 'Configurar Página — Papel',
      classes: 'page-setup-modal',
    ));
    final grid = _el('div', classes: 'page-setup-form-grid');
    grid
      ..appendChild(_numberField('custom-page-width', 'Largura', suffix: 'cm'))
      ..appendChild(_numberField('custom-page-height', 'Altura', suffix: 'cm'));
    pageSizeModal.body
      ..appendChild(_el('p', classes: 'modal-help', text: 'Tamanho do papel'))
      ..appendChild(grid);
    pageSizeModal.footer
      ..appendChild(_el('button',
          id: 'custom-size-cancel', text: 'Cancelar', classes: 'dialog-button'))
      ..appendChild(_el('button',
          id: 'custom-size-apply',
          text: 'OK',
          classes: 'dialog-button primary'));
    return pageSizeModal.root;
  }

  web.HTMLElement _buildTabStopsModal() {
    tabStopsModal = _own(TiptapModal(
      title: 'Tabulação',
      classes: 'tab-stops-modal',
    ));
    final form = _el('div', classes: 'tab-dialog-layout');
    final positions = _el('section', classes: 'tab-dialog-positions')
      ..appendChild(_numberField(
        'tab-stop-position',
        'Posição da parada de tabulação:',
        suffix: 'cm',
      ))
      ..appendChild(_el('select', id: 'tab-stop-list', attrs: {
        'size': '8',
        'aria-label': 'Paradas de tabulação definidas',
      }));
    final positionActions = _el('div', classes: 'tab-dialog-actions')
      ..appendChild(_el('button',
          id: 'tab-stop-set', text: 'Definir', classes: 'dialog-button'))
      ..appendChild(_el('button',
          id: 'tab-stop-clear', text: 'Limpar', classes: 'dialog-button'))
      ..appendChild(_el('button',
          id: 'tab-stop-clear-all',
          text: 'Limpar tudo',
          classes: 'dialog-button'));
    positions.appendChild(positionActions);
    final settings = _el('section', classes: 'tab-dialog-settings')
      ..appendChild(_numberField(
        'default-tab-stop',
        'Tabulação padrão:',
        suffix: 'cm',
      ))
      ..appendChild(_tabRadioGroup('Alinhamento', 'tab-alignment', const {
        'left': 'Esquerdo',
        'center': 'Centralizado',
        'right': 'Direito',
        'decimal': 'Decimal',
      }))
      ..appendChild(_tabRadioGroup('Preenchimento', 'tab-leader', const {
        'none': '1 Nenhum',
        'dot': '2 .......',
        'hyphen': '3 -------',
        'underscore': '4 _______',
        'middleDot': '5 ·······',
      }));
    form
      ..appendChild(positions)
      ..appendChild(settings);
    tabStopsModal.body.appendChild(form);
    tabStopsModal.footer
      ..appendChild(_el('button',
          id: 'tab-stops-cancel', text: 'Cancelar', classes: 'dialog-button'))
      ..appendChild(_el('button',
          id: 'tab-stops-apply', text: 'OK', classes: 'dialog-button primary'));
    return tabStopsModal.root;
  }

  web.HTMLElement _tabRadioGroup(
    String label,
    String name,
    Map<String, String> options,
  ) {
    final fieldset = _el('fieldset', classes: 'tab-dialog-radio-group')
      ..appendChild(_el('legend', text: label));
    for (final option in options.entries) {
      final input = _el('input', attrs: {
        'type': 'radio',
        'name': name,
        'value': option.key,
      });
      fieldset.appendChild(_el('label')
        ..appendChild(input)
        ..appendChild(_el('span', text: option.value)));
    }
    return fieldset;
  }

  web.HTMLElement _numberField(String id, String label, {String suffix = ''}) {
    final wrapper = _el('label', classes: 'page-setup-number-field')
      ..appendChild(_el('span', text: label));
    final control = _el('span', classes: 'page-setup-number-control');
    final input = _el('input', id: id, attrs: {
      'type': 'number',
      'min': '0',
      'max': '200',
      'step': '0.01',
      'inputmode': 'decimal',
    });
    control
      ..appendChild(input)
      ..appendChild(_el('span', text: suffix));
    wrapper.appendChild(control);
    return wrapper;
  }

  web.HTMLElement _buildPageSetupMenu({
    required web.HTMLElement trigger,
    required String panelId,
    required String panelLabel,
    required List<
            ({String label, String detail, String attribute, String value})>
        items,
    bool scrollable = false,
  }) {
    trigger
      ..setAttribute('aria-haspopup', 'menu')
      ..setAttribute('aria-controls', panelId);
    final menu = _el(
      'div',
      classes:
          'menu-panel page-setup-menu${scrollable ? ' is-scrollable' : ''}',
      id: panelId,
      attrs: {'role': 'menu', 'aria-label': panelLabel},
    );
    for (final item in items) {
      final button = _el('button', attrs: {
        'role': 'menuitemradio',
        'aria-checked': 'false',
        item.attribute: item.value,
      })
        ..appendChild(_el('span', classes: 'page-setup-preview'))
        ..appendChild(_el('span', classes: 'page-setup-copy')
          ..appendChild(_el('strong', text: item.label))
          ..appendChild(_el('small', text: item.detail)));
      menu.appendChild(button);
    }
    final dropdown = _own(TiptapDropdown(
      trigger: trigger,
      panel: menu,
      portalHost: root,
      classes: 'page-setup-dropdown',
    ));
    return dropdown.root;
  }

  web.HTMLElement _buildViewPanel() {
    final panel = _panel('view');
    panel
      ..appendChild(_largeCommand('ribbon-view-mode', 'view',
          'Modo de exibição', 'Alternar edição/leitura'))
      ..appendChild(_zoomGroup());
    return panel;
  }

  web.HTMLElement _buildContextualPanel() {
    final panel = _panel('contextual', extraClasses: 'contextual-panel');
    panel
      ..appendChild(_contextCommands('image', 'Organizar', [
        ('align-left', 'Alinhar à esquerda'),
        ('align-center', 'Centralizar'),
        ('align-right', 'Alinhar à direita'),
      ]))
      ..appendChild(_contextCommands('image', 'Tamanho', [
        ('smaller', 'Diminuir'),
        ('larger', 'Aumentar'),
        ('delete', 'Remover imagem'),
      ]))
      ..appendChild(_contextCommands('table', 'Linhas e Colunas', [
        ('row-above', 'Inserir Acima'),
        ('row-below', 'Inserir Abaixo'),
        ('col-left', 'Inserir à Esquerda'),
        ('col-right', 'Inserir à Direita'),
      ]))
      ..appendChild(_contextCommands('table', 'Excluir', [
        ('del-row', 'Excluir Linha'),
        ('del-col', 'Excluir Coluna'),
        ('delete', 'Excluir Tabela'),
      ]))
      ..appendChild(_contextCommands('table', 'Mesclar', [
        ('merge', 'Mesclar Células'),
        ('split', 'Dividir Célula'),
        ('header-row', 'Linha de Cabeçalho'),
      ]))
      ..appendChild(_buildTableStylingGroup())
      ..appendChild(_contextCommands('table', 'Tabela', [
        ('align-left', 'Alinhar à esquerda'),
        ('align-center', 'Centralizar'),
        ('align-right', 'Alinhar à direita'),
      ]))
      ..appendChild(_contextCommands('header', 'Posição', [
        ('align-left', 'Alinhar à esquerda'),
        ('align-center', 'Centralizar'),
        ('align-right', 'Alinhar à direita'),
        ('close', 'Fechar Cabeçalho'),
      ]))
      ..appendChild(_contextCommands('footer', 'Posição', [
        ('align-left', 'Alinhar à esquerda'),
        ('align-center', 'Centralizar'),
        ('align-right', 'Alinhar à direita'),
        ('close', 'Fechar Rodapé'),
      ]));
    return panel;
  }

  web.HTMLElement _contextCommands(
      String context, String label, List<(String, String)> actions) {
    return _ribbonSection(
      label,
      [
        _ribbonRows([
          _ribbonRow([
            for (final action in actions.take(2))
              _contextButton(context, action.$1, action.$2),
          ]),
          _ribbonRow([
            for (final action in actions.skip(2))
              _contextButton(context, action.$1, action.$2),
          ]),
        ], compact: true),
      ],
      classes: 'context-command-group',
    )..setAttribute('data-context-for', context);
  }

  web.HTMLElement _buildTableStylingGroup() {
    final section = _ribbonSection(
      'Sombreamento e Bordas',
      [
        _ribbonRows([
          _ribbonRow([
            _colorField('table-shading-color', 'Sombreamento', '#ffff00',
                control: 'cell-shading'),
            _contextButton('table', 'shading-clear', 'Sem Sombreamento'),
          ]),
          _ribbonRow([
            _colorField('table-border-color', 'Cor da Borda', '#000000',
                control: 'cell-border-color'),
            _contextButton('table', 'borders-all', 'Todas'),
            _contextButton('table', 'borders-outer', 'Externas'),
            _contextButton('table', 'borders-inner', 'Internas'),
            _contextButton('table', 'borders-none', 'Sem Borda'),
          ]),
        ], compact: true),
      ],
      classes: 'context-command-group table-styling-group',
    )..setAttribute('data-context-for', 'table');
    return section;
  }

  web.HTMLElement _colorField(String id, String label, String initial,
      {required String control}) {
    final wrapper = _el('label',
        classes: 'ribbon-color-field',
        attrs: {'title': label, 'aria-label': label});
    final input = _el('input', id: id, attrs: {
      'type': 'color',
      'value': initial,
      'data-context-color': control,
    });
    wrapper
      ..appendChild(_el('span', classes: 'ribbon-color-label', text: label))
      ..appendChild(input);
    return wrapper;
  }

  web.HTMLElement _contextButton(String context, String action, String label) =>
      _el('button', classes: 'ribbon-text-command', text: label, attrs: {
        'data-context-for': context,
        'data-context-action': action,
      });

  web.HTMLElement _messagePanel(String name, List<(String, String)> items,
      {String? countId, bool contextual = false}) {
    final panel = _panel(name,
        extraClasses:
            'ribbon-message-panel${contextual ? ' contextual-panel' : ''}');
    for (var index = 0; index < items.length; index++) {
      final command =
          _largeCommand(null, null, items[index].$1, items[index].$2);
      if (countId != null && index == items.length - 1) {
        command.querySelector('small')?.id = countId;
      }
      panel.appendChild(command);
    }
    return panel;
  }

  web.HTMLElement _panel(String name,
      {bool active = false, String? id, String extraClasses = ''}) {
    final panel = _el('div',
        classes: 'toolbar ribbon-panel${active ? ' active' : ''} $extraClasses',
        id: id,
        attrs: {
          'data-ribbon-panel': name,
          'role': 'toolbar',
          'aria-label': name,
        });
    ribbon.registerPanel(name, panel);
    return panel;
  }

  web.HTMLElement _zoomGroup() {
    final group = _el('div', classes: 'tool-group zoom-group', attrs: {
      'data-group-label': 'Zoom',
    });
    group
      ..appendChild(_actionButton('zoom-out', 'minus', compact: true))
      ..appendChild(_el('button', classes: 'zoom-value', text: '100%', attrs: {
        'data-tiptap-zoom-value': '',
      }))
      ..appendChild(_actionButton('zoom-in', 'plus', compact: true));
    return group;
  }

  web.HTMLElement _ribbonSection(String label, List<web.HTMLElement> children,
      {String classes = ''}) {
    final section = _el('section',
        classes: 'ribbon-section $classes', attrs: {'data-group-label': label});
    final content = _el('div', classes: 'ribbon-section-content');
    for (final child in children) {
      content.appendChild(child);
    }
    section.appendChild(content);
    return section;
  }

  web.HTMLElement _ribbonRows(List<web.HTMLElement> rows,
      {bool compact = false}) {
    final element = _el('div',
        classes: 'ribbon-rows${compact ? ' ribbon-rows-compact' : ''}');
    for (final row in rows) {
      element.appendChild(row);
    }
    return element;
  }

  web.HTMLElement _ribbonRow(List<web.HTMLElement> children) {
    final row = _el('div', classes: 'ribbon-row');
    for (final child in children) {
      row.appendChild(child);
    }
    return row;
  }

  web.HTMLElement _plainTool(String label) =>
      _el('button', classes: 'ribbon-text-command', text: label);

  List<web.HTMLElement> _colorControlButtons() {
    final buttons = <web.HTMLElement>[];
    for (final item in const [
      ('text-color', 'A', '#2563eb'),
      ('highlight-color', '◆', '#fef08a'),
    ]) {
      final label = _el('label', classes: 'color-button', text: item.$2);
      label
        ..appendChild((_el('input', id: item.$1) as web.HTMLInputElement)
          ..type = 'color'
          ..value = item.$3
          ..setAttribute('data-tiptap-control', item.$1))
        ..appendChild(_el('i', id: '${item.$1}-line', attrs: {
          'data-tiptap-color-indicator': item.$1,
        }));
      buttons.add(label);
    }
    return buttons;
  }

  web.HTMLElement _styleGallery() {
    final gallery = _el('div', classes: 'style-gallery', attrs: {
      'data-group-label': 'Estilos',
      'aria-label': 'Galeria de estilos',
    });
    for (final item in const [
      ('paragraph', 'AaBbCc', 'Normal'),
      ('heading-1', '1. AaBb', 'Título 1'),
      ('heading-2', 'AaBbCc', 'Título 2'),
      ('heading-3', 'AaBbCc', 'Título 3'),
    ]) {
      final button = _el('button', attrs: {'data-ribbon-style': item.$1})
        ..appendChild(_el('b', text: item.$2))
        ..appendChild(_el('small', text: item.$3));
      gallery.appendChild(button);
    }
    return gallery;
  }

  web.HTMLElement _selectControl(
      String id, String control, Map<String, String> values,
      {String? selected}) {
    final label = _el('label', classes: 'select-tool $control');
    final select = _own(TiptapSelect(
      id: id,
      items: values,
      value: selected,
      ariaLabel: control,
      attrs: {'data-tiptap-control': control},
    ));
    label.appendChild(select.root);
    return label;
  }

  web.HTMLElement _largeCommand(
      String? id, String? icon, String title, String subtitle,
      {String? action}) {
    final button = _el('button', classes: 'ribbon-large-command', id: id);
    if (action != null) button.setAttribute('data-tiptap-action', action);
    if (icon != null) button.appendChild(_icon(icon));
    button
      ..appendChild(_el('b', text: title))
      ..appendChild(_el('small', text: subtitle));
    return button;
  }

  web.HTMLElement _actionButton(String action, String icon,
          {bool compact = false}) =>
      _iconTool(icon,
          classes: compact ? ' compact' : '',
          attrs: {'data-tiptap-action': action});

  web.HTMLElement _iconTool(String icon,
      {String classes = '', Map<String, String> attrs = const {}}) {
    final button = _el('button', classes: 'tool-button$classes', attrs: attrs);
    button.appendChild(_icon(icon));
    return button;
  }

  web.HTMLElement _button(String id, String label,
      {String? icon, String classes = '', String? labelId}) {
    final button = _own(TiptapButton(
      id: id,
      label: label,
      icon: icon,
      classes: classes,
    )).root;
    if (labelId != null) button.lastElementChild?.id = labelId;
    return button;
  }

  web.HTMLElement _icon(String name) =>
      _el('span', classes: 'button-icon', attrs: {'data-tiptap-icon': name});

  web.HTMLElement _buildStatusBar() {
    final status = _el('footer', classes: 'status-bar');
    final counts = _el('div')
      ..appendChild(_el('span', id: 'word-count', text: '0 palavras'))
      ..appendChild(_el('span', classes: 'status-separator', text: '·'))
      ..appendChild(_el('span', id: 'character-count', text: '0 caracteres'));
    final state = _el('div')
      ..appendChild(_el('span', id: 'document-status', text: 'Pronto'))
      ..appendChild(_el('span', classes: 'status-separator', text: '·'))
      ..appendChild(_el('span', text: options.locale));
    status
      ..appendChild(counts)
      ..appendChild(state);
    return status;
  }

  web.HTMLInputElement _fileInput(String id, String accept) =>
      _el('input', id: id, attrs: {
        'type': 'file',
        'accept': accept,
        'hidden': '',
      }) as web.HTMLInputElement;

  T _own<T extends TiptapComponent>(T component) {
    _components.add(component);
    return component;
  }

  web.HTMLElement _el(String tag,
      {String classes = '',
      String? id,
      String? text,
      Map<String, String> attrs = const {}}) {
    final element = web.document.createElement(tag) as web.HTMLElement;
    if (classes.trim().isNotEmpty) element.className = classes.trim();
    if (id != null) element.id = id;
    if (text != null) element.textContent = text;
    for (final entry in attrs.entries) {
      element.setAttribute(entry.key, entry.value);
    }
    return element;
  }
}
