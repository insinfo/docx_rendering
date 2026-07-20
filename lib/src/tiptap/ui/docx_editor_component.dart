import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../../docx_rendering.dart';
import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';
import '../../quill_delta/index.dart';
import '../converters/docx_export.dart';
import '../converters/docx_import.dart';
import '../converters/pdf_export.dart';
import '../converters/pdf_layout_capture.dart';
import '../converters/quill_delta.dart';
import '../core/index.dart';
import 'editor_shell.dart';
import 'icons.dart';
import 'toolbar_controller.dart';

class TiptapDocxEditorOptions {
  final TiptapEditorShellOptions shell;
  final bool showWelcomeDocument;
  final bool exposeDebugApi;

  const TiptapDocxEditorOptions({
    this.shell = const TiptapEditorShellOptions(),
    this.showWelcomeDocument = true,
    this.exposeDebugApi = false,
  });
}

/// Complete embeddable DOCX editor/viewer component.
///
/// Mounting this class is sufficient for plain Dart web. AngularDart hosts can
/// call [mount] from `ngAfterViewInit` using an `ElementRef` and call [destroy]
/// from `ngOnDestroy`; no generated HTML or Angular-specific dependency is
/// required by the library.
class TiptapDocxEditorComponent {
  final web.HTMLElement host;
  final TiptapDocxEditorOptions options;

  late final TiptapEditor editor;
  late final TiptapToolbarController toolbarController;
  late final TiptapEditorShell shell;
  Timer? _toastTimer;
  Timer? _saveTimer;
  List<Map<String, dynamic>> _pendingTabStops = [];
  int? _tabStopTargetPos;

  TiptapDocxEditorComponent._(this.host, this.options) {
    _initialize();
  }

  factory TiptapDocxEditorComponent.mount(
    web.HTMLElement host, {
    TiptapDocxEditorOptions options = const TiptapDocxEditorOptions(),
  }) =>
      TiptapDocxEditorComponent._(host, options);

  web.HTMLElement get _body => web.document.body!;

  T _element<T extends web.Element>(String id) {
    final element = shell.root.querySelector('#$id');
    if (element == null) {
      throw StateError(
          'TiptapEditorShell não criou o controle obrigatório #$id.');
    }
    return element as T;
  }

  void _initialize() {
    shell = TiptapEditorShell.mount(
      host,
      options: options.shell,
    );
    final mount = shell.editorElement;
    editor = TiptapEditor(EditorOptions(
      element: mount,
      extensions: const [
        DocumentExtension(),
        ParagraphExtension(),
        TextExtension(),
        BoldExtension(),
        ItalicExtension(),
        UnderlineExtension(),
        StrikeExtension(),
        CodeExtension(),
        LinkExtension(),
        TextStyleExtension(),
        HighlightExtension(),
        HeadingExtension(),
        BulletListExtension(),
        OrderedListExtension(),
        ListItemExtension(),
        TextAlignExtension(),
        ImageExtension(),
        TableExtension(),
        TableRowExtension(),
        TableCellExtension(),
        TableHeaderExtension(),
        HardBreakExtension(),
        HorizontalRuleExtension(),
        TabRenderingExtension(),
        TableResizingExtension(),
        TableOfContentsExtension(),
        PaginationExtension(),
        DropcursorExtension(),
        HistoryExtension(),
      ],
    ));

    if (options.showWelcomeDocument) _insertWelcomeDocument();
    TiptapIcons.hydrate(_body);
    toolbarController = TiptapToolbarController(
      editor: editor,
      root: _element<web.HTMLElement>('editor-frame'),
      requestLink: () => web.window.prompt('Endereço do link', 'https://'),
      onZoomChanged: (zoom) => _element<web.HTMLElement>('page-scale')
          .style
          .setProperty('zoom', '$zoom'),
    );
    _bindFileActions();
    _bindShellActions();
    _bindPageSetupActions();
    _bindTabStopActions();
    _bindContextualActions();
    _bindInsertActions();
    shell.modeChanges.listen(_applyEditorMode);
    _applyEditorMode(shell.mode, announce: false);
    if (options.exposeDebugApi) _exposeDebugApi();

    editor.onUpdate.listen((_) {
      _updateDocumentStats();
      _markChanged();
      _syncPageSetupControls();
      _syncContextualRibbon(activate: false);
    });
    editor.onSelectionUpdate.listen((_) => _syncContextualRibbon());
    editor.onFocus.listen((_) => _setStatus('Editando'));
    editor.onBlur.listen((_) => _setStatus('Pronto'));
    _updateDocumentStats();
    _syncPageSetupControls();
    toolbarController.sync();
    _syncContextualRibbon(activate: false);
  }

  void destroy() {
    _toastTimer?.cancel();
    _saveTimer?.cancel();
    editor.destroy();
    shell.destroy();
  }

  void _insertWelcomeDocument() {
    final schema = editor.state.schema;
    final bold = schema.mark('bold');
    final muted = schema.mark('textStyle', {'color': '#5f6570'});
    final accent = schema.mark('textStyle', {'color': '#315bd6'});

    final content = [
      schema.node('paragraph', {
        'textAlign': 'left'
      }, [
        schema.text('Documento de exemplo · Editor DOCX', [muted]),
      ]),
      schema.node('heading', {
        'level': 1
      }, [
        schema.text('ACORDO DE CONFIDENCIALIDADE'),
      ]),
      schema.node('paragraph', null, [
        schema.text('Este documento demonstra o editor '),
        schema.text('Tiptap em Dart puro', [bold]),
        schema.text(
            ', com formatação rica, importação de DOCX e exportação vetorial para PDF.'),
      ]),
      schema.node('heading', {'level': 2}, [schema.text('1. Objeto')]),
      schema.node('paragraph', null, [
        schema.text(
            'As partes concordam em proteger toda informação confidencial compartilhada durante a avaliação do projeto, incluindo dados técnicos, comerciais e operacionais.'),
      ]),
      schema.node('orderedList', {
        'start': 1
      }, [
        _listItem(schema,
            'Usar as informações exclusivamente para a finalidade acordada.'),
        _listItem(schema,
            'Restringir o acesso às pessoas diretamente envolvidas no projeto.'),
        _listItem(schema,
            'Manter controles adequados de segurança, privacidade e auditoria.'),
      ]),
      schema.node('heading', {
        'level': 2
      }, [
        schema.text('2. Edição e conversão'),
      ]),
      schema.node('paragraph', null, [
        schema
            .text('Use a barra acima para formatar este conteúdo. Você pode '),
        schema.text('abrir um DOCX', [accent]),
        schema.text(
            ', editar no navegador e exportar novamente como DOCX, PDF ou Quill Delta.'),
      ]),
    ];
    final doc = schema.node('doc', null, content);
    final tr = editor.state.tr;
    tr.replaceWith(0, editor.state.doc.content.size, doc.content);
    editor.dispatchTransaction(tr);
  }

  PMNode _listItem(Schema schema, String text) =>
      schema.node('listItem', null, [
        schema.node('paragraph', null, [schema.text(text)])
      ]);

  void _bindFileActions() {
    final openInput = _element<web.HTMLInputElement>('open-docx-input');
    _element<web.HTMLButtonElement>('open-docx-button').addEventListener(
        'click',
        (web.Event _) {
          openInput.click();
        }.toJS);
    openInput.addEventListener(
        'change',
        (web.Event _) {
          final file = openInput.files?.item(0);
          if (file != null) _openDocx(file);
          openInput.value = '';
        }.toJS);

    final deltaInput = _element<web.HTMLInputElement>('open-delta-input');
    _element<web.HTMLButtonElement>('open-delta-button').addEventListener(
        'click',
        (web.Event _) {
          deltaInput.click();
        }.toJS);
    deltaInput.addEventListener(
        'change',
        (web.Event _) {
          final file = deltaInput.files?.item(0);
          if (file != null) unawaited(_openDelta(file));
          deltaInput.value = '';
        }.toJS);

    final imageInput = _element<web.HTMLInputElement>('insert-image-input');
    _element<web.HTMLButtonElement>('insert-image-button').addEventListener(
        'click',
        (web.Event _) {
          imageInput.click();
        }.toJS);
    imageInput.addEventListener(
        'change',
        (web.Event _) {
          final file = imageInput.files?.item(0);
          if (file != null) _insertImage(file);
          imageInput.value = '';
        }.toJS);

    _element<web.HTMLButtonElement>('export-docx').addEventListener(
        'click',
        (web.Event _) {
          unawaited(_exportDocx());
        }.toJS);
    _element<web.HTMLButtonElement>('export-pdf').addEventListener(
        'click',
        (web.Event _) {
          unawaited(_exportPdf());
        }.toJS);
    _element<web.HTMLButtonElement>('copy-delta').addEventListener(
        'click',
        (web.Event _) {
          unawaited(_copyDelta());
        }.toJS);
  }

  void _bindShellActions() {
    _element<web.HTMLButtonElement>('theme-toggle').addEventListener(
        'click',
        (web.Event _) {
          final dark = !_body.classList.contains('dark');
          _body.classList.toggle('dark', dark);
          final icon = _element<web.HTMLButtonElement>('theme-toggle')
              .querySelector('[data-tiptap-icon]');
          if (icon is web.HTMLElement) {
            TiptapIcons.set(icon, dark ? 'moon' : 'sun');
          }
        }.toJS);

    for (final id in ['view-mode-toggle', 'ribbon-view-mode']) {
      _element<web.HTMLElement>(id).addEventListener(
          'click',
          ((web.Event _) => shell.setMode(
                shell.mode == TiptapEditorMode.viewer
                    ? TiptapEditorMode.word
                    : TiptapEditorMode.viewer,
              )).toJS);
    }
    _element<web.HTMLElement>('ribbon-insert-image').addEventListener(
        'click',
        ((web.Event _) =>
            _element<web.HTMLElement>('insert-image-button').click()).toJS);

    final styles = shell.root.querySelectorAll('[data-ribbon-style]');
    for (var index = 0; index < styles.length; index++) {
      final card = styles.item(index);
      if (card is! web.HTMLElement) continue;
      card.addEventListener(
          'click',
          (web.Event _) {
            final select = _element<web.HTMLSelectElement>('block-style');
            select.value =
                card.getAttribute('data-ribbon-style') ?? 'paragraph';
            select.dispatchEvent(
                web.Event('change', web.EventInit(bubbles: true)));
          }.toJS);
    }
  }

  void _bindPageSetupActions() {
    _bindPageSetupItems('[data-page-margins]', (value) {
      final values = _numberList(value);
      if (values.length == 4) _applyPageMargins(values);
    });
    _bindPageSetupItems('[data-page-orientation]', _applyPageOrientation);
    _bindPageSetupItems('[data-page-size]', (value) {
      final values = _numberList(value);
      if (values.length == 2) _applyPageSize(values[0], values[1]);
    });
    _bindPageSetupItems(
      '[data-page-margins-custom]',
      (_) => _showCustomMargins(),
    );
    _bindPageSetupItems(
      '[data-page-size-custom]',
      (_) => _showCustomPageSize(),
    );
    _element<web.HTMLElement>('custom-margins-cancel').addEventListener(
      'click',
      ((web.Event _) => shell.pageMarginsModal.hide()).toJS,
    );
    _element<web.HTMLElement>('custom-margins-apply').addEventListener(
      'click',
      ((web.Event _) => _applyCustomMargins()).toJS,
    );
    _element<web.HTMLElement>('custom-size-cancel').addEventListener(
      'click',
      ((web.Event _) => shell.pageSizeModal.hide()).toJS,
    );
    _element<web.HTMLElement>('custom-size-apply').addEventListener(
      'click',
      ((web.Event _) => _applyCustomPageSize()).toJS,
    );
  }

  void _bindTabStopActions() {
    _element<web.HTMLElement>('tab-stops-dialog-button').addEventListener(
      'click',
      ((web.Event _) => _showTabStopsDialog()).toJS,
    );
    _element<web.HTMLSelectElement>('tab-stop-list').addEventListener(
      'change',
      ((web.Event _) => _loadSelectedTabStop()).toJS,
    );
    _element<web.HTMLElement>('tab-stop-set').addEventListener(
      'click',
      ((web.Event _) => _definePendingTabStop()).toJS,
    );
    _element<web.HTMLElement>('tab-stop-clear').addEventListener(
      'click',
      ((web.Event _) => _clearPendingTabStop()).toJS,
    );
    _element<web.HTMLElement>('tab-stop-clear-all').addEventListener(
      'click',
      ((web.Event _) {
        _pendingTabStops = [];
        _renderPendingTabStops();
      }).toJS,
    );
    _element<web.HTMLElement>('tab-stops-cancel').addEventListener(
      'click',
      ((web.Event _) => shell.tabStopsModal.hide()).toJS,
    );
    _element<web.HTMLElement>('tab-stops-apply').addEventListener(
      'click',
      ((web.Event _) => _applyPendingTabStops()).toJS,
    );
  }

  void _showTabStopsDialog() {
    final target = _textblockAtSelection();
    if (target == null) {
      _toast('Posicione o cursor em um parágrafo para configurar tabulações.');
      return;
    }
    _tabStopTargetPos = target.pos;
    final rawStops = target.node.attrs['tabStops'];
    _pendingTabStops = rawStops is List
        ? rawStops
            .whereType<Map>()
            .map((stop) => Map<String, dynamic>.from(stop))
            .where((stop) =>
                _lengthMillimeters(stop['position'], double.nan).isFinite)
            .toList(growable: true)
        : [];
    _sortPendingTabStops();
    _setNumberInput(
      'default-tab-stop',
      _lengthMillimeters(editor.state.doc.attrs['defaultTabStop'], 12.5) / 10,
    );
    _element<web.HTMLInputElement>('tab-stop-position').value = '';
    _checkTabRadio('tab-alignment', 'left');
    _checkTabRadio('tab-leader', 'none');
    _renderPendingTabStops();
    shell.tabStopsModal.show();
    _element<web.HTMLInputElement>('tab-stop-position').focus();
  }

  void _renderPendingTabStops({int? selectedIndex}) {
    final list = _element<web.HTMLSelectElement>('tab-stop-list');
    list.textContent = '';
    for (var index = 0; index < _pendingTabStops.length; index++) {
      final centimetres =
          _lengthMillimeters(_pendingTabStops[index]['position'], 0) / 10;
      final label = centimetres
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '')
          .replaceAll('.', ',');
      final option =
          web.document.createElement('option') as web.HTMLOptionElement
            ..value = '$index'
            ..textContent = '$label cm';
      list.appendChild(option);
    }
    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < _pendingTabStops.length) {
      list.value = '$selectedIndex';
      _loadSelectedTabStop();
    }
  }

  void _loadSelectedTabStop() {
    final index =
        int.tryParse(_element<web.HTMLSelectElement>('tab-stop-list').value);
    if (index == null || index < 0 || index >= _pendingTabStops.length) return;
    final stop = _pendingTabStops[index];
    _setNumberInput(
      'tab-stop-position',
      _lengthMillimeters(stop['position'], 0) / 10,
    );
    _checkTabRadio('tab-alignment', '${stop['type'] ?? 'left'}');
    _checkTabRadio('tab-leader', '${stop['leader'] ?? 'none'}');
  }

  void _definePendingTabStop() {
    final centimetres = _numberInput('tab-stop-position');
    if (centimetres == null) {
      _toast('Informe uma posição de tabulação válida.');
      return;
    }
    final contentWidth = _pageDimensionsMm().$1 -
        _lengthMillimeters(editor.state.doc.attrs['pageMarginLeft'], 25.4) -
        _lengthMillimeters(editor.state.doc.attrs['pageMarginRight'], 25.4);
    final millimetres = centimetres * 10;
    if (millimetres > contentWidth) {
      _toast('A tabulação deve ficar dentro da largura útil da página.');
      return;
    }
    final type = _checkedTabRadio('tab-alignment') ?? 'left';
    final leader = _checkedTabRadio('tab-leader') ?? 'none';
    var index = _pendingTabStops.indexWhere((stop) =>
        (_lengthMillimeters(stop['position'], -1000) - millimetres).abs() < .1);
    final next = <String, dynamic>{
      'position': _millimeters(millimetres),
      'type': type,
      'leader': leader,
    };
    if (index < 0) {
      _pendingTabStops.add(next);
    } else {
      _pendingTabStops[index] = next;
    }
    _sortPendingTabStops();
    index = _pendingTabStops.indexWhere((stop) =>
        (_lengthMillimeters(stop['position'], -1000) - millimetres).abs() < .1);
    _renderPendingTabStops(selectedIndex: index);
  }

  void _clearPendingTabStop() {
    final list = _element<web.HTMLSelectElement>('tab-stop-list');
    final index = int.tryParse(list.value);
    if (index == null || index < 0 || index >= _pendingTabStops.length) return;
    _pendingTabStops.removeAt(index);
    _renderPendingTabStops(
      selectedIndex: _pendingTabStops.isEmpty
          ? null
          : math.min(index, _pendingTabStops.length - 1),
    );
  }

  void _applyPendingTabStops() {
    final targetPos = _tabStopTargetPos;
    final defaultCentimetres = _numberInput('default-tab-stop');
    if (targetPos == null ||
        defaultCentimetres == null ||
        defaultCentimetres <= 0) {
      _toast('A tabulação padrão deve ser maior que zero.');
      return;
    }
    final node = editor.state.doc.nodeAt(targetPos);
    if (node == null || !node.isTextblock) {
      _toast('O parágrafo selecionado não está mais disponível.');
      return;
    }
    final attrs = Map<String, dynamic>.from(node.attrs)
      ..['tabStops'] = _pendingTabStops.isEmpty
          ? null
          : _pendingTabStops
              .map((stop) => Map<String, dynamic>.from(stop))
              .toList(growable: false);
    final tr = editor.state.tr
      ..setDocAttribute('defaultTabStop', _millimeters(defaultCentimetres * 10))
      ..setNodeMarkup(targetPos, null, attrs, node.marks);
    editor.view?.dispatch(tr.scrollIntoView());
    shell.tabStopsModal.hide();
    _toast('Tabulações do parágrafo atualizadas');
  }

  void _sortPendingTabStops() =>
      _pendingTabStops.sort((a, b) => _lengthMillimeters(a['position'], 0)
          .compareTo(_lengthMillimeters(b['position'], 0)));

  void _checkTabRadio(String name, String value) {
    final radios = shell.root.querySelectorAll('input[name="$name"]');
    for (var index = 0; index < radios.length; index++) {
      final radio = radios.item(index);
      if (radio is web.HTMLInputElement) radio.checked = radio.value == value;
    }
  }

  String? _checkedTabRadio(String name) {
    final selected = shell.root.querySelector('input[name="$name"]:checked');
    return selected is web.HTMLInputElement ? selected.value : null;
  }

  ({PMNode node, int pos})? _textblockAtSelection() {
    final resolved = editor.state.selection.fromRes;
    for (var depth = resolved.depth; depth > 0; depth--) {
      final node = resolved.node(depth);
      if (node.isTextblock) {
        return (node: node, pos: resolved.before(depth));
      }
    }
    return null;
  }

  void _bindPageSetupItems(
    String selector,
    void Function(String value) onSelected,
  ) {
    final buttons = shell.root.querySelectorAll(selector);
    for (var index = 0; index < buttons.length; index++) {
      final button = buttons.item(index);
      if (button is! web.HTMLElement) continue;
      button
        ..addEventListener(
          'mousedown',
          ((web.Event event) => event.preventDefault()).toJS,
        )
        ..addEventListener(
          'click',
          ((web.Event event) {
            event.preventDefault();
            final value = button.getAttribute(
              selector.substring(1, selector.length - 1),
            );
            if (value != null) onSelected(value);
          }).toJS,
        );
    }
  }

  void _applyPageMargins(List<double> values) {
    final dimensions = _pageDimensionsMm();
    final top = values[0];
    final right = values[1];
    final bottom = values[2];
    final left = values[3];
    if (left + right >= dimensions.$1 - 25.4 ||
        top + bottom >= dimensions.$2 - 25.4) {
      _toast('As margens deixam uma área útil pequena demais.');
      return;
    }
    final tr = editor.state.tr
      ..setDocAttribute('pageMarginTop', _millimeters(top))
      ..setDocAttribute('pageMarginRight', _millimeters(right))
      ..setDocAttribute('pageMarginBottom', _millimeters(bottom))
      ..setDocAttribute('pageMarginLeft', _millimeters(left));
    editor.view?.dispatch(tr.scrollIntoView());
    _toast('Margens da página atualizadas');
  }

  void _showCustomMargins() {
    final attrs = editor.state.doc.attrs;
    _setNumberInput(
      'custom-margin-top',
      _lengthMillimeters(attrs['pageMarginTop'], 25.4) / 10,
    );
    _setNumberInput(
      'custom-margin-bottom',
      _lengthMillimeters(attrs['pageMarginBottom'], 25.4) / 10,
    );
    _setNumberInput(
      'custom-margin-left',
      _lengthMillimeters(attrs['pageMarginLeft'], 25.4) / 10,
    );
    _setNumberInput(
      'custom-margin-right',
      _lengthMillimeters(attrs['pageMarginRight'], 25.4) / 10,
    );
    shell.pageMarginsModal.show();
    _element<web.HTMLInputElement>('custom-margin-top').focus();
  }

  void _applyCustomMargins() {
    final top = _numberInput('custom-margin-top');
    final right = _numberInput('custom-margin-right');
    final bottom = _numberInput('custom-margin-bottom');
    final left = _numberInput('custom-margin-left');
    if ([top, right, bottom, left].any((value) => value == null)) {
      _toast('Preencha todas as margens com valores válidos.');
      return;
    }
    final before = editor.state.doc;
    _applyPageMargins([
      top! * 10,
      right! * 10,
      bottom! * 10,
      left! * 10,
    ]);
    if (!identical(before, editor.state.doc)) shell.pageMarginsModal.hide();
  }

  void _applyPageOrientation(String orientation) {
    if (orientation != 'portrait' && orientation != 'landscape') return;
    final dimensions = _pageDimensionsMm();
    final shortSide = math.min(dimensions.$1, dimensions.$2);
    final longSide = math.max(dimensions.$1, dimensions.$2);
    final width = orientation == 'landscape' ? longSide : shortSide;
    final height = orientation == 'landscape' ? shortSide : longSide;
    final tr = editor.state.tr
      ..setDocAttribute('pageWidth', _millimeters(width))
      ..setDocAttribute('pageHeight', _millimeters(height))
      ..setDocAttribute('pageOrientation', orientation);
    editor.view?.dispatch(tr.scrollIntoView());
    _toast(orientation == 'landscape'
        ? 'Orientação Paisagem aplicada'
        : 'Orientação Retrato aplicada');
  }

  void _applyPageSize(double portraitWidth, double portraitHeight) {
    final landscape = _pageOrientation() == 'landscape';
    final width = landscape ? portraitHeight : portraitWidth;
    final height = landscape ? portraitWidth : portraitHeight;
    final tr = editor.state.tr
      ..setDocAttribute('pageWidth', _millimeters(width))
      ..setDocAttribute('pageHeight', _millimeters(height))
      ..setDocAttribute(
        'pageOrientation',
        landscape ? 'landscape' : 'portrait',
      );
    editor.view?.dispatch(tr.scrollIntoView());
    _toast('Tamanho da página atualizado');
  }

  void _showCustomPageSize() {
    final dimensions = _pageDimensionsMm();
    _setNumberInput('custom-page-width', dimensions.$1 / 10);
    _setNumberInput('custom-page-height', dimensions.$2 / 10);
    shell.pageSizeModal.show();
    _element<web.HTMLInputElement>('custom-page-width').focus();
  }

  void _applyCustomPageSize() {
    final widthCm = _numberInput('custom-page-width');
    final heightCm = _numberInput('custom-page-height');
    if (widthCm == null ||
        heightCm == null ||
        widthCm < 2.54 ||
        heightCm < 2.54) {
      _toast('Largura e altura devem ter pelo menos 2,54 cm.');
      return;
    }
    final width = widthCm * 10;
    final height = heightCm * 10;
    final attrs = editor.state.doc.attrs;
    final horizontalMargins =
        _lengthMillimeters(attrs['pageMarginLeft'], 25.4) +
            _lengthMillimeters(attrs['pageMarginRight'], 25.4);
    final verticalMargins = _lengthMillimeters(attrs['pageMarginTop'], 25.4) +
        _lengthMillimeters(attrs['pageMarginBottom'], 25.4);
    if (horizontalMargins >= width - 25.4 || verticalMargins >= height - 25.4) {
      _toast('O papel é pequeno demais para as margens atuais.');
      return;
    }
    final orientation = width > height ? 'landscape' : 'portrait';
    final tr = editor.state.tr
      ..setDocAttribute('pageWidth', _millimeters(width))
      ..setDocAttribute('pageHeight', _millimeters(height))
      ..setDocAttribute('pageOrientation', orientation);
    editor.view?.dispatch(tr.scrollIntoView());
    shell.pageSizeModal.hide();
    _toast('Tamanho personalizado aplicado');
  }

  void _syncPageSetupControls() {
    final attrs = editor.state.doc.attrs;
    final margins = [
      _lengthMillimeters(attrs['pageMarginTop'], 25.4),
      _lengthMillimeters(attrs['pageMarginRight'], 25.4),
      _lengthMillimeters(attrs['pageMarginBottom'], 25.4),
      _lengthMillimeters(attrs['pageMarginLeft'], 25.4),
    ];
    _syncPageSetupRadio('[data-page-margins]', (value) {
      final candidate = _numberList(value);
      return candidate.length == 4 &&
          List.generate(4, (index) => index)
              .every((index) => (candidate[index] - margins[index]).abs() < .2);
    });
    final orientation = _pageOrientation();
    _syncPageSetupRadio(
      '[data-page-orientation]',
      (value) => value == orientation,
    );
    final dimensions = _pageDimensionsMm();
    final shortSide = math.min(dimensions.$1, dimensions.$2);
    final longSide = math.max(dimensions.$1, dimensions.$2);
    _syncPageSetupRadio('[data-page-size]', (value) {
      final candidate = _numberList(value);
      return candidate.length == 2 &&
          (candidate[0] - shortSide).abs() < .25 &&
          (candidate[1] - longSide).abs() < .25;
    });
  }

  void _syncPageSetupRadio(
    String selector,
    bool Function(String value) selected,
  ) {
    final attribute = selector.substring(1, selector.length - 1);
    final buttons = shell.root.querySelectorAll(selector);
    for (var index = 0; index < buttons.length; index++) {
      final button = buttons.item(index);
      if (button is! web.HTMLElement) continue;
      final active = selected(button.getAttribute(attribute) ?? '');
      button
        ..setAttribute('aria-checked', '$active')
        ..classList.toggle('is-selected', active);
    }
  }

  (double, double) _pageDimensionsMm() {
    final attrs = editor.state.doc.attrs;
    return (
      _lengthMillimeters(attrs['pageWidth'], 210),
      _lengthMillimeters(attrs['pageHeight'], 297),
    );
  }

  String _pageOrientation() {
    final explicit = editor.state.doc.attrs['pageOrientation'];
    if (explicit == 'landscape' || explicit == 'portrait') return '$explicit';
    final dimensions = _pageDimensionsMm();
    return dimensions.$1 > dimensions.$2 ? 'landscape' : 'portrait';
  }

  List<double> _numberList(String value) => value
      .split(',')
      .map(double.tryParse)
      .whereType<double>()
      .toList(growable: false);

  String _millimeters(double value) {
    final text = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '${text}mm';
  }

  void _setNumberInput(String id, double value) {
    _element<web.HTMLInputElement>(id).value =
        value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double? _numberInput(String id) {
    final input = _element<web.HTMLInputElement>(id);
    final value = double.tryParse(input.value.replaceAll(',', '.'));
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  double _lengthMillimeters(dynamic value, double fallback) {
    if (value is num && value.isFinite) return value.toDouble() * 25.4 / 96;
    final match = RegExp(
      r'^\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*(px|pt|pc|in|cm|mm)?\s*$',
      caseSensitive: false,
    ).firstMatch('$value');
    if (match == null) return fallback;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite) return fallback;
    return switch ((match.group(2) ?? 'px').toLowerCase()) {
      'pt' => amount * 25.4 / 72,
      'pc' => amount * 25.4 / 6,
      'in' => amount * 25.4,
      'cm' => amount * 10,
      'mm' => amount,
      _ => amount * 25.4 / 96,
    };
  }

  void _bindContextualActions() {
    shell.editorElement.addEventListener(
        'mousedown',
        (web.Event rawEvent) {
          final target = rawEvent.target;
          if (target is! web.Element ||
              target.closest('.tiptap-page-header, .tiptap-page-footer') !=
                  null) {
            return;
          }
          final image = target.closest('img');
          if (image is! web.HTMLElement) return;
          final images =
              shell.editorElement.querySelectorAll('.ProseMirror img');
          var imageIndex = -1;
          var bodyImageIndex = 0;
          for (var index = 0; index < images.length; index++) {
            final candidate = images.item(index);
            if (candidate is web.Element &&
                candidate.closest('.tiptap-page-header, .tiptap-page-footer') !=
                    null) {
              continue;
            }
            if (identical(candidate, image)) {
              imageIndex = bodyImageIndex;
              break;
            }
            bodyImageIndex++;
          }
          if (imageIndex < 0) return;
          var seen = 0;
          int? position;
          editor.state.doc.descendants((node, pos, parent, index) {
            if (node.type.name != 'image') return true;
            if (seen++ == imageIndex) {
              position = pos;
              return false;
            }
            return true;
          });
          if (position == null) return;
          rawEvent.preventDefault();
          editor.view?.dispatch(
            editor.state.tr
                .setSelection(NodeSelection.create(editor.state.doc, position!))
                .scrollIntoView(),
          );
        }.toJS);
    shell.root.addEventListener(
      'tiptap-context-change',
      ((web.Event _) => _syncContextualRibbon()).toJS,
    );
    final shading =
        shell.root.querySelector('[data-context-color="cell-shading"]');
    if (shading is web.HTMLInputElement) {
      shading.addEventListener(
          'change',
          ((web.Event _) => editor.chain.setCellBackground(shading.value).run())
              .toJS);
    }

    final buttons = shell.root.querySelectorAll('[data-context-action]');
    for (var index = 0; index < buttons.length; index++) {
      final button = buttons.item(index);
      if (button is! web.HTMLElement) continue;
      button
        ..addEventListener(
          'mousedown',
          ((web.Event event) => event.preventDefault()).toJS,
        )
        ..addEventListener(
            'click',
            (web.Event event) {
              event.preventDefault();
              final context = button.getAttribute('data-context-for');
              final action = button.getAttribute('data-context-action');
              if (context == null || action == null) return;
              if (context == 'image') {
                _runImageContextAction(action);
              } else if (context == 'table') {
                _runTableContextAction(action);
              } else if (context == 'header' || context == 'footer') {
                _runPageRegionContextAction(action);
              }
            }.toJS);
    }
  }

  void _bindInsertActions() {
    // ------------------------------------------------ grid picker de tabela
    final gridHost = shell.root.querySelector('[data-table-grid-host]');
    final caption = shell.root.querySelector('#table-grid-caption');
    if (gridHost is web.HTMLElement) {
      (int, int)? parseSpec(web.EventTarget? target) {
        if (target is! web.Element) return null;
        final cell = target.closest('[data-table-grid]');
        final spec = cell?.getAttribute('data-table-grid');
        if (spec == null) return null;
        final parts = spec.split(',');
        if (parts.length != 2) return null;
        final rows = int.tryParse(parts[0]);
        final cols = int.tryParse(parts[1]);
        if (rows == null || cols == null) return null;
        return (rows, cols);
      }

      gridHost.addEventListener(
          'pointerover',
          (web.Event event) {
            final spec = parseSpec(event.target);
            if (spec == null) return;
            final cells = gridHost.querySelectorAll('[data-table-grid]');
            for (var i = 0; i < cells.length; i++) {
              final cell = cells.item(i);
              if (cell is! web.Element) continue;
              final own =
                  (cell.getAttribute('data-table-grid') ?? '').split(',');
              final r = int.tryParse(own.first) ?? 99;
              final c = int.tryParse(own.last) ?? 99;
              cell.classList.toggle('active', r <= spec.$1 && c <= spec.$2);
            }
            caption?.textContent = 'Tabela ${spec.$1}x${spec.$2}';
          }.toJS);
      gridHost.addEventListener(
          'click',
          (web.Event event) {
            final spec = parseSpec(event.target);
            if (spec == null) return;
            editor.chain
                .focus()
                .insertTable(rows: spec.$1, cols: spec.$2, withHeaderRow: false)
                .run();
          }.toJS);
    }

    // ---------------------------------------------------------------- TOC
    _element<web.HTMLElement>('insert-toc-button').addEventListener(
        'click',
        (web.Event _) {
          final handled = editor.chain
              .focus()
              .command(insertTableOfContentsCommand(
                pageOf: _pageNumberAt,
                contentWidth: _contentWidthPx(),
              ))
              .run();
          if (handled) _toast('Sumário inserido');
        }.toJS);
    _element<web.HTMLElement>('update-toc-button').addEventListener(
        'click',
        (web.Event _) {
          final handled = editor.chain
              .focus()
              .command(updateTableOfContentsCommand(
                pageOf: _pageNumberAt,
                contentWidth: _contentWidthPx(),
              ))
              .run();
          _toast(handled
              ? 'Sumário atualizado'
              : 'Nenhum sumário no documento. Use Inserir → Sumário.');
        }.toJS);

    // ------------------------------------------------------ caixa de texto
    _element<web.HTMLElement>('insert-textbox-button')
        .addEventListener('click', ((web.Event _) => _insertTextBox()).toJS);

    // ---------------------------------------- navegação pelo sumário
    shell.editorElement.addEventListener(
        'click',
        (web.Event event) {
          final target = event.target;
          if (target is! web.Element) return;
          final entry = target.closest('div[data-docx-toc] > p');
          if (entry is! web.HTMLElement) return;
          final toc = entry.closest('div[data-docx-toc]')!;
          var index = -1;
          var i = 0;
          for (var child = toc.firstElementChild;
              child != null;
              child = child.nextElementSibling) {
            if (child.tagName == 'P') {
              // O primeiro parágrafo é o título "Sumário".
              if (identical(child, entry)) {
                index = i - 1;
                break;
              }
              i++;
            }
          }
          if (index < 0) return;
          final maxLevel =
              int.tryParse(toc.getAttribute('data-docx-toc') ?? '') ?? 3;
          _navigateToHeading(index, maxLevel);
        }.toJS);

    // -------------------------------------------------- cabeçalho e rodapé
    _element<web.HTMLElement>('edit-header-button').addEventListener(
        'click', ((web.Event _) => _openPageRegion('header')).toJS);
    _element<web.HTMLElement>('edit-footer-button').addEventListener(
        'click', ((web.Event _) => _openPageRegion('footer')).toJS);

    final pageNumberItems =
        shell.root.querySelectorAll('[data-page-number-action]');
    for (var i = 0; i < pageNumberItems.length; i++) {
      final item = pageNumberItems.item(i);
      if (item is! web.HTMLElement) continue;
      item.addEventListener(
          'click',
          (web.Event _) {
            final action = item.getAttribute('data-page-number-action');
            if (action != null) _applyPageNumberAction(action);
          }.toJS);
    }
  }

  void _insertTextBox() {
    final schema = editor.state.schema;
    final table = schema.nodes['table'];
    final row = schema.nodes['tableRow'];
    final cell = schema.nodes['tableCell'];
    final paragraph = schema.nodes['paragraph'];
    if (table == null || row == null || cell == null || paragraph == null) {
      return;
    }
    final content = paragraph.create(
        null, Fragment.from(schema.text('Digite o texto aqui')));
    final node = table.create(
      {'textBox': true, 'width': '240px'},
      Fragment.from(row.create(
          null,
          Fragment.from(cell.create(
            {
              'borderTop': '1px solid #000000',
              'borderRight': '1px solid #000000',
              'borderBottom': '1px solid #000000',
              'borderLeft': '1px solid #000000',
              'paddingTop': '4px',
              'paddingRight': '7px',
              'paddingBottom': '4px',
              'paddingLeft': '7px',
            },
            Fragment.from(content),
          )))),
    );
    final handled = editor.chain.focus().command(insertNodeCommand(node)).run();
    if (handled) _toast('Caixa de texto inserida');
  }

  void _navigateToHeading(int index, int maxLevel) {
    // Mesma regra de coleta usada por collectOutline na geração do sumário.
    var seen = 0;
    int? target;
    editor.state.doc.descendants((node, pos, parent, i) {
      if (node.type.name != 'heading') return true;
      final level = node.attrs['level'] is int ? node.attrs['level'] as int : 1;
      if (level > maxLevel) return false;
      if (node.textContent.trim().isEmpty) return false;
      if (seen++ == index) {
        target = pos;
        return false;
      }
      return true;
    });
    if (target == null) return;
    final tr = editor.state.tr;
    tr.setSelection(Selection.near(editor.state.doc.resolve(target! + 1)));
    editor.view?.dispatch(tr.scrollIntoView());
    final dom = editor.view?.nodeDOM(target!);
    if (dom is web.HTMLElement) {
      dom.scrollIntoView(
          web.ScrollIntoViewOptions(block: 'start', behavior: 'smooth'));
    }
  }

  void _openPageRegion(String kind) {
    final region = shell.editorElement.querySelector('.tiptap-page-$kind');
    if (region is! web.HTMLElement) {
      _toast('A paginação ainda não materializou o $kind desta página.');
      return;
    }
    region.scrollIntoView(
        web.ScrollIntoViewOptions(block: 'center', behavior: 'smooth'));
    region.dispatchEvent(web.MouseEvent(
      'dblclick',
      web.MouseEventInit(bubbles: true, cancelable: true),
    ));
  }

  static const _pageFieldPattern = r'\{\{DOCX_(PAGE|NUMPAGES)\}\}';

  void _applyPageNumberAction(String action) {
    final tr = editor.state.tr;
    if (action == 'remove') {
      for (final attribute in const ['headers', 'footers']) {
        final current = _payloadStringMap(editor.state.doc.attrs[attribute]);
        if (current.isEmpty) continue;
        final next = <String, dynamic>{};
        var changed = false;
        current.forEach((key, value) {
          final filtered = _withoutPageFieldBlocks(value);
          if (!identical(filtered, value)) changed = true;
          next[key] = filtered;
        });
        if (changed) tr.setDocAttribute(attribute, next);
      }
      editor.view?.dispatch(tr);
      _toast('Números de página removidos');
      return;
    }
    final parts = action.split('-');
    if (parts.length != 2) return;
    final attribute = parts[0] == 'header' ? 'headers' : 'footers';
    final align = parts[1];
    final current = _payloadStringMap(editor.state.doc.attrs[attribute]);
    final key = current.containsKey('default')
        ? 'default'
        : (current.keys.isEmpty ? 'default' : current.keys.first);
    final blocks = _withoutPageFieldBlocks(current[key] ?? const []);
    final nextBlocks = List<dynamic>.from(blocks)
      ..add({
        'type': 'paragraph',
        'attrs': {'textAlign': align == 'left' ? null : align},
        'content': [
          {'type': 'text', 'text': 'Página {{DOCX_PAGE}} | {{DOCX_NUMPAGES}}'}
        ],
      });
    final next = Map<String, dynamic>.from(current)..[key] = nextBlocks;
    tr.setDocAttribute(attribute, next);
    editor.view?.dispatch(tr);
    _toast('Número de página inserido');
  }

  Map<String, dynamic> _payloadStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return <String, dynamic>{};
  }

  /// Removes blocks whose serialized JSON contains PAGE/NUMPAGES fields.
  /// Returns the original list when nothing changes.
  dynamic _withoutPageFieldBlocks(dynamic blocks) {
    if (blocks is! List) return blocks;
    final pattern = RegExp(_pageFieldPattern);
    final filtered = [
      for (final block in blocks)
        if (!pattern.hasMatch(jsonEncode(block))) block
    ];
    return filtered.length == blocks.length ? blocks : filtered;
  }

  /// Page number of the rendered page containing [pos], derived from the
  /// materialized per-page headers, or null before pagination settles.
  int? _pageNumberAt(int pos) {
    final view = editor.view;
    if (view == null) return null;
    try {
      final domPos = view.domAtPos(pos, 1);
      final node = domPos.node;
      final element = node is web.Element ? node : node.parentElement;
      if (element == null) return null;
      final headers =
          view.dom.querySelectorAll('.tiptap-page-header[data-page-number]');
      var page = 1;
      for (var i = 0; i < headers.length; i++) {
        final header = headers.item(i);
        if (header is! web.Element) continue;
        final relation = element.compareDocumentPosition(header);
        if ((relation & 2) != 0) {
          // header precede o elemento → estamos naquela página (ou depois).
          page = int.tryParse(header.getAttribute('data-page-number') ?? '') ??
              page;
        }
      }
      return page;
    } catch (_) {
      return null;
    }
  }

  /// Usable content width in CSS px (page width minus side margins).
  double _contentWidthPx() {
    final attrs = editor.state.doc.attrs;
    final width = _cssLengthPx(attrs['pageWidth']) ?? 794;
    final left = _cssLengthPx(attrs['pageMarginLeft']) ?? 75.6;
    final right = _cssLengthPx(attrs['pageMarginRight']) ?? 75.6;
    final content = width - left - right;
    return content > 100 ? content : 644;
  }

  double? _cssLengthPx(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    final match = RegExp(
      r'^\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*(px|pt|pc|in|cm|mm)?\s*$',
      caseSensitive: false,
    ).firstMatch('$value');
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite) return null;
    return switch ((match.group(2) ?? 'px').toLowerCase()) {
      'pt' => amount * 96 / 72,
      'pc' => amount * 16,
      'in' => amount * 96,
      'cm' => amount * 96 / 2.54,
      'mm' => amount * 96 / 25.4,
      _ => amount,
    };
  }

  void _syncContextualRibbon({bool activate = true}) {
    final activeRegion = shell.root.querySelector('.tiptap-page-region-active');
    if (activeRegion is web.HTMLElement) {
      shell.setContextualContext(
        activeRegion.classList.contains('tiptap-page-footer')
            ? 'footer'
            : 'header',
        activate: activate,
      );
      return;
    }
    final selection = editor.state.selection;
    if (selection is NodeSelection && selection.node.type.name == 'image') {
      shell.setContextualContext('image', activate: activate);
      return;
    }
    if (_tableAtSelection() != null) {
      shell.setContextualContext('table', activate: activate);
      return;
    }
    shell.setContextualContext(null, activate: false);
  }

  void _runImageContextAction(String action) {
    final selection = editor.state.selection;
    if (selection is! NodeSelection || selection.node.type.name != 'image') {
      return;
    }
    final tr = editor.state.tr;
    if (action == 'delete') {
      tr.deleteSelection();
    } else {
      final attrs = Map<String, dynamic>.from(selection.node.attrs);
      if (action.startsWith('align-')) {
        attrs['alignment'] = action.substring('align-'.length);
      } else if (action == 'larger' || action == 'smaller') {
        final current = _numericLength(attrs['width']) ?? 300;
        final factor = action == 'larger' ? 1.1 : 0.9;
        attrs['width'] = '${(current * factor).round()}px';
      } else {
        return;
      }
      tr.setNodeMarkup(selection.from, null, attrs, selection.node.marks);
    }
    editor.view?.dispatch(tr.scrollIntoView());
  }

  void _runTableContextAction(String action) {
    final table = _tableAtSelection();
    if (table == null) return;
    switch (action) {
      case 'row-above':
        editor.chain.focus().addRowBefore().run();
        return;
      case 'row-below':
        editor.chain.focus().addRowAfter().run();
        return;
      case 'col-left':
        editor.chain.focus().addColumnBefore().run();
        return;
      case 'col-right':
        editor.chain.focus().addColumnAfter().run();
        return;
      case 'del-row':
        editor.chain.focus().deleteRow().run();
        return;
      case 'del-col':
        editor.chain.focus().deleteColumn().run();
        return;
      case 'merge':
        final handled = editor.chain.focus().mergeCells().run();
        if (!handled) {
          _toast('Selecione um retângulo de células para mesclar.',
              error: true);
        }
        return;
      case 'split':
        final handled = editor.chain.focus().splitCell().run();
        if (!handled) {
          _toast('O cursor precisa estar numa célula mesclada.', error: true);
        }
        return;
      case 'header-row':
        editor.chain.focus().toggleHeaderRow().run();
        return;
      case 'shading-clear':
        editor.chain.focus().setCellBackground(null).run();
        return;
      case 'borders-all':
      case 'borders-outer':
      case 'borders-inner':
        final color = _contextColorValue('cell-border-color') ?? '#000000';
        editor.chain
            .focus()
            .setCellBorders(
                action.substring('borders-'.length), '1px solid $color')
            .run();
        return;
      case 'borders-none':
        editor.chain.focus().setCellBorders('none', 'none').run();
        return;
    }
    final tr = editor.state.tr;
    if (action == 'delete') {
      tr.deleteRange(table.pos, table.pos + table.node.nodeSize);
    } else if (action.startsWith('align-')) {
      final attrs = Map<String, dynamic>.from(table.node.attrs)
        ..['alignment'] = action.substring('align-'.length);
      tr.setNodeMarkup(table.pos, null, attrs, table.node.marks);
    } else {
      return;
    }
    editor.view?.dispatch(tr.scrollIntoView());
  }

  String? _contextColorValue(String control) {
    final input = shell.root.querySelector('[data-context-color="$control"]');
    return input is web.HTMLInputElement ? input.value : null;
  }

  void _runPageRegionContextAction(String action) {
    final region = shell.root.querySelector('.tiptap-page-region-active');
    if (region is! web.HTMLElement) return;
    final pageAction = switch (action) {
      'align-left' => 'left',
      'align-center' => 'center',
      'align-right' => 'right',
      'close' => 'close',
      _ => null,
    };
    if (pageAction == null) return;
    final button =
        region.querySelector('[data-page-object-action="$pageAction"]');
    if (button is web.HTMLElement) button.click();
  }

  ({PMNode node, int pos})? _tableAtSelection() {
    final resolved = editor.state.selection.fromRes;
    for (var depth = resolved.depth; depth > 0; depth--) {
      final node = resolved.node(depth);
      if (node.type.name == 'table') {
        return (node: node, pos: resolved.before(depth));
      }
    }
    return null;
  }

  double? _numericLength(dynamic value) {
    if (value is num) return value.toDouble();
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch('$value');
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  void _applyEditorMode(TiptapEditorMode mode, {bool announce = true}) {
    final value = mode == TiptapEditorMode.viewer;
    editor.setEditable(!value);
    _body.classList.toggle('view-only', value);
    final toggle = _element<web.HTMLElement>('view-mode-toggle');
    toggle.setAttribute('aria-pressed', '$value');
    _element<web.HTMLInputElement>('document-title').readOnly = value;
    _setStatus(value ? 'Somente visualização' : 'Pronto');
    if (announce) {
      _toast(value ? 'Modo somente visualização' : 'Modo de edição ativado');
    }
  }

  Future<void> _openDocx(web.File file) async {
    _busy(true, 'Abrindo ${file.name}…');
    try {
      final buffer = await file.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      final wordDocument = await parseAsync(
        bytes,
        Options(
          parseChunkSize: 50,
          onParseProgress: (parsed) => _setStatus('Lendo bloco $parsed…'),
        ),
      );
      _setStatus('Convertendo para o editor…');
      await Future<void>.delayed(Duration.zero);
      final imported = await DocxImporter(
        wordDocument,
        editor.state.schema,
      ).importDocumentAsync();
      editor.setDocument(imported);
      _element<web.HTMLInputElement>('document-title').value =
          file.name.replaceFirst(RegExp(r'\.docx$', caseSensitive: false), '');
      _toast('DOCX aberto com sucesso');
    } catch (error) {
      _toast('Não foi possível abrir o DOCX: $error', error: true);
    } finally {
      _busy(false, 'Pronto');
    }
  }

  Future<void> _insertImage(web.File file) async {
    try {
      final buffer = await file.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      final mime = file.type.isEmpty ? 'image/png' : file.type;
      final src = 'data:$mime;base64,${base64.encode(bytes)}';
      editor.chain.focus().setImage(src, alt: file.name).run();
    } catch (error) {
      _toast('Falha ao inserir imagem: $error', error: true);
    }
  }

  Future<void> _openDelta(web.File file) async {
    _busy(true, 'Importando Quill Delta…');
    try {
      final buffer = await file.arrayBuffer().toDart;
      final decoded = jsonDecode(utf8.decode(buffer.toDart.asUint8List()));
      final dynamic rawOps = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
              ? decoded['ops']
              : null;
      if (rawOps is! List) {
        throw const FormatException(
            'JSON deve ser uma lista de ops ou {"ops": [...]}');
      }
      final delta = Delta.fromJson(rawOps);
      final imported =
          QuillDeltaConverter(editor.state.schema).fromDelta(delta);
      editor.setDocument(imported);
      _element<web.HTMLInputElement>('document-title').value =
          file.name.replaceFirst(RegExp(r'\.json$', caseSensitive: false), '');
      _toast('Quill Delta importado');
    } catch (error) {
      _toast('Não foi possível importar o Delta: $error', error: true);
    } finally {
      _busy(false, 'Pronto');
    }
  }

  Future<void> _exportDocx() async {
    _closeExportMenu();
    _busy(true, 'Gerando DOCX…');
    try {
      final bytes = await DocxExporter(
        onProgress: (done, total) =>
            _setStatus('Gerando DOCX ${_percent(done, total)}'),
      ).export(editor.state.doc);
      _download(bytes, '${_filename()}.docx',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      _toast('DOCX exportado');
    } catch (error) {
      _toast('Falha ao exportar DOCX: $error', error: true);
    } finally {
      _busy(false, 'Pronto');
    }
  }

  Future<void> _exportPdf() async {
    _closeExportMenu();
    _busy(true, 'Gerando PDF vetorial…');
    try {
      final bytes = await _generatePdfBytes();
      _download(bytes, '${_filename()}.pdf', 'application/pdf');
      _toast('PDF vetorial exportado');
    } catch (error) {
      _toast('Falha ao exportar PDF: $error', error: true);
    } finally {
      _busy(false, 'Pronto');
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final pageFormat = pdfPageFormatForDocument(editor.state.doc);
    final view = editor.view;
    final layout = view == null
        ? null
        : await capturePaginatedPdfLayout(
            view.dom,
            pageFormat: pageFormat,
          );
    return PdfExporter(
      pageFormat: pageFormat,
      onProgress: (done, total) =>
          _setStatus('Gerando PDF ${_percent(done, total)}'),
    ).export(editor.state.doc, layout: layout);
  }

  Future<void> _copyDelta() async {
    _closeExportMenu();
    try {
      final converter = QuillDeltaConverter(editor.state.schema);
      final json = jsonEncode(converter.toDelta(editor.state.doc).toJson());
      await web.window.navigator.clipboard.writeText(json).toDart;
      _toast('Quill Delta copiado');
    } catch (error) {
      _toast('Não foi possível copiar o Delta: $error', error: true);
    }
  }

  void _download(Uint8List bytes, String filename, String mime) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename
      ..style.display = 'none';
    _body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    // Chrome headless (and some slower embedded WebViews) may not have started
    // consuming the Blob when click() returns. Revoking synchronously can abort
    // an otherwise successful download.
    Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }

  void _updateDocumentStats() {
    if (!options.shell.enableDocumentStatistics) return;
    final text = editor.state.doc.textContent.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    _element<web.HTMLElement>('word-count').textContent =
        '$words ${words == 1 ? 'palavra' : 'palavras'}';
    _element<web.HTMLElement>('ribbon-word-count').textContent =
        '$words ${words == 1 ? 'palavra' : 'palavras'}';
    _element<web.HTMLElement>('character-count').textContent =
        '${text.length} caracteres';
  }

  void _markChanged() {
    final state = _element<web.HTMLElement>('save-state');
    state.innerHTML = '<span class="status-dot"></span>Alterações locais'.toJS;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      state.innerHTML = '<span class="status-dot"></span>Editor local'.toJS;
    });
  }

  void _busy(bool active, String message) {
    _element<web.HTMLElement>('progress-strip')
        .classList
        .toggle('active', active);
    _element<web.HTMLElement>('progress-strip')
        .setAttribute('aria-hidden', '${!active}');
    _setStatus(message);
  }

  void _setStatus(String message) {
    final status = _element<web.HTMLElement>('document-status');
    if (status.textContent != message) status.textContent = message;
  }

  void _toast(String message, {bool error = false}) {
    final toast = _element<web.HTMLElement>('toast');
    toast.textContent = message;
    toast.classList
      ..toggle('error', error)
      ..add('show');
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      toast.classList.remove('show');
    });
  }

  void _closeExportMenu() {
    shell.exportDropdown.setOpen(false);
  }

  String _filename() {
    final title = _element<web.HTMLInputElement>('document-title').value.trim();
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return safe.isEmpty ? 'documento' : safe;
  }

  String _percent(int done, int total) =>
      total <= 0 ? '' : '${(done * 100 / total).round()}%';

  void _exposeDebugApi() {
    final window = web.window as JSObject;
    window.setProperty('getTiptapHTML'.toJS, (() => editor.getHTML()).toJS);
    window.setProperty(
        'getTiptapJSON'.toJS, (() => jsonEncode(editor.getJSON())).toJS);
    window.setProperty(
      'setTiptapJSON'.toJS,
      ((String value) {
        final document =
            PMNode.fromJSON(editor.state.schema, jsonDecode(value));
        editor.setDocument(document);
      }).toJS,
    );
    window.setProperty('setTiptapEditable'.toJS,
        ((bool editable) => editor.setEditable(editable)).toJS);
    window.setProperty(
        'getTiptapDelta'.toJS,
        (() {
          final converter = QuillDeltaConverter(editor.state.schema);
          return jsonEncode(converter.toDelta(editor.state.doc).toJson());
        }).toJS);
    window.setProperty(
      'getTiptapPdfBase64'.toJS,
      (() => _generatePdfBytes()
          .then((bytes) => base64.encode(bytes).toJS)
          .toJS).toJS,
    );
    window.setProperty('toggleTiptapBulletList'.toJS,
        (() => editor.chain.focus().toggleBulletList().run()).toJS);
    window.setProperty('toggleTiptapHeading'.toJS,
        ((int level) => editor.chain.focus().toggleHeading(level).run()).toJS);
  }
}
