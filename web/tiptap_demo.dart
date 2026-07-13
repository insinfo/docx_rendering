import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:docx_rendering/docx_rendering.dart';
import 'package:docx_rendering/quill_delta.dart';
import 'package:docx_rendering/src/prosemirror/model/index.dart';
import 'package:docx_rendering/tiptap.dart';
import 'package:web/web.dart' as web;

late final TiptapEditor editor;
late final TiptapToolbarController toolbarController;
Timer? _toastTimer;
Timer? _saveTimer;

web.HTMLElement get _body => web.document.body!;

T _element<T extends web.Element>(String id) =>
    web.document.getElementById(id) as T;

void main() {
  final mount = _element<web.HTMLElement>('editor');
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
      PaginationExtension(),
      DropcursorExtension(),
      HistoryExtension(),
    ],
  ));

  _insertWelcomeDocument();
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
  _exposeDebugApi();

  editor.onUpdate.listen((_) {
    _updateDocumentStats();
    _markChanged();
  });
  editor.onFocus.listen((_) => _setStatus('Editando'));
  editor.onBlur.listen((_) => _setStatus('Pronto'));
  _updateDocumentStats();
  toolbarController.sync();
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
      schema.text('Use a barra acima para formatar este conteúdo. Você pode '),
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

PMNode _listItem(Schema schema, String text) => schema.node('listItem', null, [
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
  final menuButton = _element<web.HTMLButtonElement>('export-menu-button');
  final menu = _element<web.HTMLElement>('export-menu');
  menuButton.addEventListener(
      'click',
      (web.Event event) {
        event.stopPropagation();
        final open = !menu.classList.contains('open');
        menu.classList.toggle('open', open);
        menuButton.setAttribute('aria-expanded', '$open');
      }.toJS);
  web.document.addEventListener(
      'click',
      (web.Event _) {
        menu.classList.remove('open');
        menuButton.setAttribute('aria-expanded', 'false');
      }.toJS);
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
    final imported = QuillDeltaConverter(editor.state.schema).fromDelta(delta);
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
  final text = editor.state.doc.textContent.trim();
  final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
  _element<web.HTMLElement>('word-count').textContent =
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
  _element<web.HTMLElement>('document-status').textContent = message;
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
  _element<web.HTMLElement>('export-menu').classList.remove('open');
  _element<web.HTMLButtonElement>('export-menu-button')
      .setAttribute('aria-expanded', 'false');
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
    (() => _generatePdfBytes().then((bytes) => base64.encode(bytes).toJS).toJS)
        .toJS,
  );
  window.setProperty('toggleTiptapBulletList'.toJS,
      (() => editor.chain.focus().toggleBulletList().run()).toJS);
  window.setProperty('toggleTiptapHeading'.toJS,
      ((int level) => editor.chain.focus().toggleHeading(level).run()).toJS);
}
