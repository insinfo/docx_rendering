import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:docx_rendering/docx_rendering.dart';
import 'package:docx_rendering/quill_delta.dart';
import 'package:docx_rendering/tiptap.dart';
import 'package:ngdart/angular.dart';
import 'package:web/web.dart' as web;

import 'tiptap_toolbar_attributes.dart';

var _nextEditorInstance = 1;

/// AngularDart wrapper around the framework-independent Tiptap editor.
///
/// Each instance creates unique DOM ids, resolves its hosts with `package:web`
/// after Angular has rendered the view and owns the complete editor lifecycle.
@Component(
  selector: 'tiptap-docx-editor',
  templateUrl: 'tiptap_docx_editor_component.html',
  styleUrls: <String>['tiptap_docx_editor_component.css'],
  directives: <Object>[
    TiptapIconAttributeDirective,
    TiptapThemeIconAttributeDirective,
    TiptapActionAttributeDirective,
    TiptapCommandAttributeDirective,
    TiptapControlAttributeDirective,
    TiptapColorIndicatorAttributeDirective,
    TiptapZoomValueAttributeDirective,
    TiptapPreserveSelectionAttributeDirective,
  ],
  changeDetection: ChangeDetectionStrategy.onPush,
)
class TiptapDocxEditorComponent implements AfterViewInit, OnDestroy {
  final ChangeDetectorRef _changeDetector;
  final int _instance = _nextEditorInstance++;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  TiptapEditor? _editor;
  TiptapToolbarController? _toolbarController;

  bool busy = false;
  bool editable = true;
  bool darkTheme = false;
  String status = 'Inicializando editor…';
  String documentTitle = 'Documento AngularDart';
  int wordCount = 0;
  int characterCount = 0;

  TiptapDocxEditorComponent(this._changeDetector);

  String get shellId => 'tiptap-angular-shell-$_instance';
  String get editorHostId => 'tiptap-angular-editor-$_instance';
  String get pageScaleId => 'tiptap-angular-page-scale-$_instance';
  String get docxInputId => 'tiptap-angular-docx-input-$_instance';
  String get deltaInputId => 'tiptap-angular-delta-input-$_instance';
  String get imageInputId => 'tiptap-angular-image-input-$_instance';
  String get modeLabel => editable ? 'Somente leitura' : 'Habilitar edição';

  @override
  void ngAfterViewInit() {
    _setBootstrapStage('resolving-hosts');
    try {
      final shell = _requiredElement(shellId);
      final editorHost = _requiredElement(editorHostId);
      final pageScale = _requiredElement(pageScaleId);

      _setBootstrapStage('creating-editor');
      final editor = TiptapEditor(EditorOptions(
        element: editorHost,
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
      _editor = editor;
      _setBootstrapStage('inserting-welcome-document');
      _insertWelcomeDocument(editor);

      _setBootstrapStage('creating-toolbar');
      TiptapIcons.hydrate(shell);
      _toolbarController = TiptapToolbarController(
        editor: editor,
        root: shell,
        requestLink: () => web.window.prompt('Endereço do link', 'https://'),
        onZoomChanged: (zoom) => pageScale.style.setProperty('zoom', '$zoom'),
      );

      _subscriptions
        ..add(editor.onUpdate.listen((_) {
          _updateDocumentStats();
          _setStatus('Alterações locais');
        }))
        ..add(editor.onFocus.listen((_) => _setStatus('Editando')))
        ..add(editor.onBlur.listen((_) => _setStatus('Pronto')));

      _updateDocumentStats();
      _setStatus('Editor AngularDart pronto');
      _installTestHooks(editor);
      _setBootstrapStage('ready');
    } catch (error, stackTrace) {
      final window = web.window as JSObject;
      window.setProperty('__tiptapAngularBootstrapError'.toJS, '$error'.toJS);
      window.setProperty(
        '__tiptapAngularBootstrapStack'.toJS,
        '$stackTrace'.toJS,
      );
      status = 'Falha ao iniciar editor: $error';
      _changeDetector.markForCheck();
      rethrow;
    }
  }

  void _setBootstrapStage(String stage) {
    try {
      (web.window as JSObject).setProperty(
        '__tiptapAngularBootstrapStage'.toJS,
        stage.toJS,
      );
    } catch (_) {
      // Diagnostics must never block the production editor bootstrap.
    }
  }

  void _insertWelcomeDocument(TiptapEditor editor) {
    final schema = editor.state.schema;
    final bold = schema.mark('bold');
    final muted = schema.mark('textStyle', {'color': '#626874'});
    final accent = schema.mark('textStyle', {'color': '#315bd6'});
    final doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('Componente AngularDart · Editor DOCX', [muted]),
      ]),
      schema.node('heading', {
        'level': 1
      }, [
        schema.text('EDITOR TIPTAP EM DART PURO'),
      ]),
      schema.node('paragraph', null, [
        schema.text('Este documento é editado por uma instância de '),
        schema.text('TiptapEditor', [bold]),
        schema.text(
          ' criada no ngAfterViewInit e completamente liberada no ngOnDestroy.',
        ),
      ]),
      schema.node('heading', {
        'level': 2
      }, [
        schema.text('Integração correta com AngularDart'),
      ]),
      schema.node('paragraph', null, [
        schema.text(
          'A toolbar é declarativa, limitada à raiz deste componente e pode coexistir com outras instâncias na mesma página. ',
        ),
        schema.text('Abra um DOCX', [accent]),
        schema.text(
          ', edite o conteúdo e exporte novamente como DOCX, PDF vetorial ou Quill Delta.',
        ),
      ]),
      schema.node('heading', {
        'level': 2
      }, [
        schema.text('Sem canvas e sem runtime JavaScript externo'),
      ]),
      schema.node('paragraph', null, [
        schema.text(
          'O documento usa DOM contenteditable, seleção nativa, atalhos de teclado e os mesmos conversores públicos disponíveis para qualquer aplicação Dart Web.',
        ),
      ]),
    ]);
    final tr = editor.state.tr;
    tr.replaceWith(0, editor.state.doc.content.size, doc.content);
    editor.dispatchTransaction(tr);
  }

  void openDocx() {
    (_requiredElement(docxInputId) as web.HTMLInputElement).click();
  }

  Future<void> onDocxSelected() async {
    final input = _requiredElement(docxInputId) as web.HTMLInputElement;
    final file = input.files?.item(0);
    if (file == null) return;
    input.value = '';
    _setBusy(true, 'Abrindo ${file.name}…');
    try {
      final bytes = await _readFile(file);
      final wordDocument = await parseAsync(
        bytes,
        Options(
          parseChunkSize: 50,
          onParseProgress: (parsed) => _setStatus('Lendo bloco $parsed…'),
        ),
      );
      final editor = _requireEditor();
      _setStatus('Convertendo documento…');
      await Future<void>.delayed(Duration.zero);
      final imported = await DocxImporter(
        wordDocument,
        editor.state.schema,
      ).importDocumentAsync();
      editor.setDocument(imported);
      documentTitle = file.name.replaceFirst(
        RegExp(r'\.docx$', caseSensitive: false),
        '',
      );
      _setStatus('DOCX aberto com sucesso');
    } catch (error) {
      _setStatus('Falha ao abrir DOCX: $error');
    } finally {
      _setBusy(false);
    }
  }

  void openDelta() {
    (_requiredElement(deltaInputId) as web.HTMLInputElement).click();
  }

  Future<void> onDeltaSelected() async {
    final input = _requiredElement(deltaInputId) as web.HTMLInputElement;
    final file = input.files?.item(0);
    if (file == null) return;
    input.value = '';
    _setBusy(true, 'Importando Quill Delta…');
    try {
      final decoded = jsonDecode(utf8.decode(await _readFile(file)));
      final dynamic rawOps = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
              ? decoded['ops']
              : null;
      if (rawOps is! List) {
        throw const FormatException(
          'JSON deve ser uma lista de ops ou {"ops": [...]}',
        );
      }
      final editor = _requireEditor();
      final imported = QuillDeltaConverter(editor.state.schema)
          .fromDelta(Delta.fromJson(rawOps));
      editor.setDocument(imported);
      documentTitle =
          file.name.replaceFirst(RegExp(r'\.json$', caseSensitive: false), '');
      _setStatus('Quill Delta importado');
    } catch (error) {
      _setStatus('Falha ao importar Delta: $error');
    } finally {
      _setBusy(false);
    }
  }

  void insertImage() {
    (_requiredElement(imageInputId) as web.HTMLInputElement).click();
  }

  Future<void> onImageSelected() async {
    final input = _requiredElement(imageInputId) as web.HTMLInputElement;
    final file = input.files?.item(0);
    if (file == null) return;
    input.value = '';
    try {
      final bytes = await _readFile(file);
      final mime = file.type.isEmpty ? 'image/png' : file.type;
      final src = 'data:$mime;base64,${base64.encode(bytes)}';
      _requireEditor().chain.focus().setImage(src, alt: file.name).run();
      _setStatus('Imagem inserida');
    } catch (error) {
      _setStatus('Falha ao inserir imagem: $error');
    }
  }

  Future<void> exportDocx() async {
    _setBusy(true, 'Gerando DOCX…');
    try {
      final bytes = await DocxExporter(
        onProgress: (done, total) =>
            _setStatus('Gerando DOCX ${_percent(done, total)}'),
      ).export(_requireEditor().state.doc);
      _download(
        bytes,
        '${_safeFilename()}.docx',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      _setStatus('DOCX exportado');
    } catch (error) {
      _setStatus('Falha ao exportar DOCX: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> exportPdf() async {
    _setBusy(true, 'Gerando PDF vetorial…');
    try {
      final bytes = await _generatePdfBytes();
      _download(bytes, '${_safeFilename()}.pdf', 'application/pdf');
      _setStatus('PDF vetorial exportado');
    } catch (error) {
      _setStatus('Falha ao exportar PDF: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final editor = _requireEditor();
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

  Future<void> copyDelta() async {
    try {
      final editor = _requireEditor();
      final converter = QuillDeltaConverter(editor.state.schema);
      final value = jsonEncode(converter.toDelta(editor.state.doc).toJson());
      await web.window.navigator.clipboard.writeText(value).toDart;
      _setStatus('Quill Delta copiado');
    } catch (error) {
      _setStatus('Falha ao copiar Delta: $error');
    }
  }

  void toggleEditable() {
    editable = !editable;
    _requireEditor().setEditable(editable);
    _setStatus(editable ? 'Edição habilitada' : 'Modo somente leitura');
  }

  void toggleTheme() {
    darkTheme = !darkTheme;
    final icon =
        _requiredElement(shellId).querySelector('[data-tiptap-theme-icon]');
    if (icon != null && icon.isA<web.HTMLElement>()) {
      TiptapIcons.set(icon as web.HTMLElement, darkTheme ? 'moon' : 'sun');
    }
    _changeDetector.markForCheck();
  }

  Future<Uint8List> _readFile(web.File file) async {
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
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
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  void _updateDocumentStats() {
    final text = _requireEditor().state.doc.textContent.trim();
    wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    characterCount = text.length;
    _changeDetector.markForCheck();
  }

  void _setBusy(bool value, [String? message]) {
    busy = value;
    if (message != null) status = message;
    _changeDetector.markForCheck();
  }

  void _setStatus(String value) {
    status = value;
    _changeDetector.markForCheck();
  }

  String _safeFilename() {
    final value =
        documentTitle.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return value.isEmpty ? 'documento' : value;
  }

  String _percent(int done, int total) =>
      total <= 0 ? '' : '${(done * 100 / total).round()}%';

  web.HTMLElement _requiredElement(String id) {
    final element = web.document.getElementById(id);
    if (element == null || !element.isA<web.HTMLElement>()) {
      throw StateError('Elemento AngularDart #$id não foi renderizado.');
    }
    return element as web.HTMLElement;
  }

  TiptapEditor _requireEditor() {
    final editor = _editor;
    if (editor == null) throw StateError('Editor ainda não inicializado.');
    return editor;
  }

  void _installTestHooks(TiptapEditor editor) {
    final window = web.window as JSObject;
    window.setProperty('__tiptapAngularReady'.toJS, true.toJS);
    window.setProperty(
      'getAngularTiptapHTML'.toJS,
      (() => editor.getHTML()).toJS,
    );
    window.setProperty(
      'getAngularTiptapJSON'.toJS,
      (() => jsonEncode(editor.getJSON())).toJS,
    );
    window.setProperty(
      'getAngularTiptapPdfBase64'.toJS,
      (() => _generatePdfBytes()
          .then((bytes) => base64.encode(bytes).toJS)
          .toJS).toJS,
    );
  }

  @override
  void ngOnDestroy() {
    final window = web.window as JSObject;
    window.setProperty('__tiptapAngularReady'.toJS, false.toJS);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final toolbar = _toolbarController;
    if (toolbar != null) unawaited(toolbar.destroy());
    _toolbarController = null;
    _editor?.destroy();
    _editor = null;
  }
}
