import 'pdf_security.dart';
import 'libs/zlib_codec.dart';
import 'utils.dart';

/// Construtor de objetos e estrutura interna do documento PDF.
///
/// Gerencia a criação de objetos PDF, tabela xref, streams,
/// e a montagem final do documento.
///
/// Portado das funções internas do jspdf.js:
/// newObject, newObjectDeferred, putStream, putPages, buildDocument, etc.

/// Representa uma caixa delimitadora de página PDF.
class MediaBox {
  double bottomLeftX;
  double bottomLeftY;
  double topRightX;
  double topRightY;

  MediaBox(this.bottomLeftX, this.bottomLeftY, this.topRightX, this.topRightY);

  MediaBox.fromDimensions(double width, double height)
      : bottomLeftX = 0,
        bottomLeftY = 0,
        topRightX = width,
        topRightY = height;

  MediaBox clone() => MediaBox(bottomLeftX, bottomLeftY, topRightX, topRightY);
}

/// Contexto de uma página no documento PDF.
class PageContext {
  /// Número do objeto da página.
  int objId = 0;

  /// Número do objeto de conteúdo da página.
  int contentsObjId = 0;

  /// Caixa de mídia (tamanho da página).
  MediaBox mediaBox;

  /// Caixas opcionais de recorte.
  MediaBox? cropBox;
  MediaBox? bleedBox;
  MediaBox? trimBox;
  MediaBox? artBox;

  /// Unidade do usuário (padrão 1.0).
  double userUnit;

  /// Anotações da página.
  List<Map<String, dynamic>> annotations = [];

  PageContext({required this.mediaBox, this.userUnit = 1.0});
}

/// Mecanismo de construção de documentos PDF.
///
/// Mantém o estado de objetos, offsets, conteúdo e permite
/// montar o documento completo (header, pages, xref, trailer).
class PdfDocumentBuilder {
  int _objectNumber = 0;
  final List<dynamic> _offsets = []; // int ou Function
  final List<String> _content = [];
  int _contentLength = 0;
  final List<_AdditionalObject> _additionalObjects = [];

  final List<List<String>> _pages = [[]]; // index 0 unused (1-based)
  final List<PageContext?> _pagesContext = [null]; // index 0 unused

  int _currentPage = 0;
  bool _hasCustomDestination = false;
  List<String> _outputDestination;

  late int _rootDictionaryObjId;
  late int _resourceDictionaryObjId;

  final String Function(num) _hpf;
  final String _pdfVersion;
  final bool _compress;

  PdfDocumentBuilder({
    String pdfVersion = '1.3',
    String Function(num)? hpf,
    bool compress = false,
  })  : _pdfVersion = pdfVersion,
        _hpf = hpf ?? createHpf(16),
        _compress = compress,
        _outputDestination = [] {
    _outputDestination = _content;
    _rootDictionaryObjId = newObjectDeferred();
    _resourceDictionaryObjId = newObjectDeferred();
  }

  // --- Object Management ---

  /// Cria um novo objeto PDF e emite seu cabeçalho.
  int newObject() {
    final oid = newObjectDeferred();
    newObjectDeferredBegin(oid, doOutput: true);
    return oid;
  }

  /// Reserva um ID de objeto sem emitir dados.
  int newObjectDeferred() {
    _objectNumber++;
    // Armazena uma função que retorna contentLength no momento do cálculo
    while (_offsets.length <= _objectNumber) {
      _offsets.add(null);
    }
    _offsets[_objectNumber] = () => _contentLength;
    return _objectNumber;
  }

  /// Marca o início de um objeto reservado.
  int newObjectDeferredBegin(int oid, {bool doOutput = false}) {
    while (_offsets.length <= oid) {
      _offsets.add(null);
    }
    _offsets[oid] = _contentLength;
    if (doOutput) {
      out('$oid 0 obj');
    }
    return oid;
  }

  /// Cria um objeto adicional (após as páginas).
  _AdditionalObject newAdditionalObject() {
    final objId = newObjectDeferred();
    final obj = _AdditionalObject(objId: objId);
    _additionalObjects.add(obj);
    return obj;
  }

  // --- Output ---

  /// Adiciona uma string ao destino de saída atual.
  void out(String string) {
    _contentLength += string.length + 1;
    _outputDestination.add(string);
  }

  /// Escreve múltiplos argumentos como uma linha.
  void write(List<String> values) {
    out(values.join(' '));
  }

  /// Define destino de saída customizado.
  void setCustomOutputDestination(List<String> destination) {
    _hasCustomDestination = true;
    _outputDestination = destination;
  }

  /// Define destino de saída (respeitando destino custom).
  void setOutputDestination(List<String> destination) {
    if (!_hasCustomDestination) {
      _outputDestination = destination;
    }
  }

  /// Reseta destino de saída para o content principal.
  void resetCustomOutputDestination() {
    _hasCustomDestination = false;
    _outputDestination = _content;
  }

  // --- Page Management ---

  int get currentPage => _currentPage;
  int get objectNumber => _objectNumber;
  int get rootDictionaryObjId => _rootDictionaryObjId;
  int get resourceDictionaryObjId => _resourceDictionaryObjId;

  List<List<String>> get pages => _pages;
  List<PageContext?> get pagesContext => _pagesContext;

  /// Adiciona uma nova página ao documento.
  void addPage(MediaBox mediaBox, {double userUnit = 1.0}) {
    _currentPage++;
    _pages.add([]);
    _pagesContext.add(PageContext(mediaBox: mediaBox, userUnit: userUnit));
    setOutputDestination(_pages[_currentPage]);
  }

  int get numberOfPages => _pages.length - 1; // -1 porque index 0 não é usado

  // --- Stream ---

  /// Emite um stream PDF com dados e filtros.
  void putStream({
    required String data,
    List<String>? filters,
    List<String>? alreadyAppliedFilters,
    bool addLength1 = false,
    int? objectId,
    List<Map<String, String>>? additionalKeyValues,
    String Function(String)? encryptor,
  }) {
    final effectiveEncryptor = encryptor ?? (String d) => d;
    // filters serão usados quando suporte a compressão for adicionado
    final keyValues = <Map<String, String>>[
      ...?additionalKeyValues,
    ];

    var processedData = data;
    final reverseChain = <String>[];

    if (_compress &&
        processedData.isNotEmpty &&
        alreadyAppliedFilters?.contains('FlateDecode') != true) {
      final compressed = ZLibCodec().encode(
        processedData.codeUnits.map((int codeUnit) => codeUnit & 0xff).toList(),
      );
      processedData = String.fromCharCodes(compressed);
      reverseChain.add('FlateDecode');
    }

    final valueOfLength1 = data.length;

    if (processedData.isNotEmpty) {
      keyValues
          .add({'key': 'Length', 'value': processedData.length.toString()});
      if (addLength1) {
        keyValues.add({'key': 'Length1', 'value': valueOfLength1.toString()});
      }
    }

    // Monta filter string
    final filterParts = [
      ...reverseChain,
      ...?alreadyAppliedFilters,
    ];
    final filterAsString = filterParts.map((f) => '/$f').join(' ');

    if (filterAsString.isNotEmpty) {
      final slashCount = '/'.allMatches(filterAsString).length;
      if (slashCount == 1) {
        keyValues.add({'key': 'Filter', 'value': filterAsString});
      } else {
        keyValues.add({'key': 'Filter', 'value': '[$filterAsString]'});
      }
    }

    out('<<');
    for (final kv in keyValues) {
      out('/${kv['key']} ${kv['value']}');
    }
    out('>>');
    if (processedData.isNotEmpty) {
      out('stream');
      out(effectiveEncryptor(processedData));
      out('endstream');
    }
  }

  // --- Build Document ---

  /// Emite uma única página no documento.
  int putPage(int pageNumber, {PdfSecurity? security}) {
    final ctx = _pagesContext[pageNumber]!;
    final data = _pages[pageNumber];

    newObjectDeferredBegin(ctx.objId, doOutput: true);
    out('<</Type /Page');
    out('/Parent $_rootDictionaryObjId 0 R');
    out('/Resources $_resourceDictionaryObjId 0 R');
    out(
      '/MediaBox [${_parseFloat(_hpf(ctx.mediaBox.bottomLeftX))} '
      '${_parseFloat(_hpf(ctx.mediaBox.bottomLeftY))} '
      '${_hpf(ctx.mediaBox.topRightX)} '
      '${_hpf(ctx.mediaBox.topRightY)}]',
    );

    if (ctx.cropBox != null) {
      out(
        '/CropBox [${_hpf(ctx.cropBox!.bottomLeftX)} '
        '${_hpf(ctx.cropBox!.bottomLeftY)} '
        '${_hpf(ctx.cropBox!.topRightX)} '
        '${_hpf(ctx.cropBox!.topRightY)}]',
      );
    }
    if (ctx.bleedBox != null) {
      out(
        '/BleedBox [${_hpf(ctx.bleedBox!.bottomLeftX)} '
        '${_hpf(ctx.bleedBox!.bottomLeftY)} '
        '${_hpf(ctx.bleedBox!.topRightX)} '
        '${_hpf(ctx.bleedBox!.topRightY)}]',
      );
    }
    if (ctx.trimBox != null) {
      out(
        '/TrimBox [${_hpf(ctx.trimBox!.bottomLeftX)} '
        '${_hpf(ctx.trimBox!.bottomLeftY)} '
        '${_hpf(ctx.trimBox!.topRightX)} '
        '${_hpf(ctx.trimBox!.topRightY)}]',
      );
    }
    if (ctx.artBox != null) {
      out(
        '/ArtBox [${_hpf(ctx.artBox!.bottomLeftX)} '
        '${_hpf(ctx.artBox!.bottomLeftY)} '
        '${_hpf(ctx.artBox!.topRightX)} '
        '${_hpf(ctx.artBox!.topRightY)}]',
      );
    }

    if (ctx.userUnit != 1.0) {
      out('/UserUnit ${ctx.userUnit}');
    }

    if (ctx.annotations.isNotEmpty) {
      final annotationObjects = ctx.annotations
          .map((Map<String, dynamic> annotation) => annotation['pdf'] as String)
          .join(' ');
      out('/Annots [$annotationObjects]');
    }

    out('/Contents ${ctx.contentsObjId} 0 R');
    out('>>');
    out('endobj');

    // Conteúdo da página
    final pageContent = data.join('\n');

    newObjectDeferredBegin(ctx.contentsObjId, doOutput: true);
    putStream(
      data: pageContent,
      objectId: ctx.contentsObjId,
      encryptor: security?.encryptor(ctx.contentsObjId, 0),
    );
    out('endobj');

    return ctx.objId;
  }

  /// Emite todas as páginas.
  List<int> putPages({PdfSecurity? security}) {
    final pageObjectNumbers = <int>[];

    // Reserva IDs
    for (var n = 1; n <= numberOfPages; n++) {
      _pagesContext[n]!.objId = newObjectDeferred();
      _pagesContext[n]!.contentsObjId = newObjectDeferred();
    }

    // Emite cada página
    for (var n = 1; n <= numberOfPages; n++) {
      pageObjectNumbers.add(putPage(n, security: security));
    }

    // Emite dicionário de páginas raiz
    newObjectDeferredBegin(_rootDictionaryObjId, doOutput: true);
    out('<</Type /Pages');
    final kids =
        '/Kids [${pageObjectNumbers.map((id) => '$id 0 R').join(' ')}]';
    out(kids);
    out('/Count $numberOfPages');
    out('>>');
    out('endobj');

    return pageObjectNumbers;
  }

  /// Emite objetos adicionais.
  void putAdditionalObjects() {
    for (final obj in _additionalObjects) {
      newObjectDeferredBegin(obj.objId, doOutput: true);
      out(obj.content);
      out('endobj');
    }
  }

  /// Emite o cabeçalho PDF.
  void putHeader() {
    out('%PDF-$_pdfVersion');
    out('%\xBA\xDF\xAC\xE0');
  }

  /// Emite o Info dictionary.
  void putEncryption(PdfSecurity security) {
    newObject();
    out(security.encryptionDictionary(objectNumber));
    out('endobj');
  }

  void putInfo({
    Map<String, String>? documentProperties,
    required String creationDate,
    PdfSecurity? security,
  }) {
    final int infoObjectId = newObject();
    final enc = security?.encryptor(infoObjectId, 0) ?? (String d) => d;
    out('<<');
    out('/Producer (${pdfEscape(enc("jsPDF Dart Port 1.0.0"))})');
    if (documentProperties != null) {
      for (final entry in documentProperties.entries) {
        if (entry.value.isNotEmpty) {
          final key = entry.key[0].toUpperCase() + entry.key.substring(1);
          out('/$key (${pdfEscape(enc(entry.value))})');
        }
      }
    }
    out('/CreationDate (${pdfEscape(enc(creationDate))})');
    out('>>');
    out('endobj');
  }

  /// Emite o catálogo PDF.
  void putCatalog({
    String? zoomMode,
    String? layoutMode,
    String? pageMode,
    String? languageCode,
    int? metadataObjectNumber,
  }) {
    newObject();
    out('<<');
    out('/Type /Catalog');
    out('/Pages $_rootDictionaryObjId 0 R');

    // Zoom
    final zoom = zoomMode ?? 'fullwidth';
    switch (zoom) {
      case 'fullwidth':
        out('/OpenAction [3 0 R /FitH null]');
        break;
      case 'fullheight':
        out('/OpenAction [3 0 R /FitV null]');
        break;
      case 'fullpage':
        out('/OpenAction [3 0 R /Fit]');
        break;
      case 'original':
        out('/OpenAction [3 0 R /XYZ null null 1]');
        break;
      default:
        var pcn = zoom;
        if (pcn.endsWith('%')) {
          final zoomNum = int.parse(pcn.replaceAll('%', '')) / 100;
          out('/OpenAction [3 0 R /XYZ null null ${f2(zoomNum)}]');
        } else {
          final zoomNum = double.tryParse(pcn);
          if (zoomNum != null) {
            out('/OpenAction [3 0 R /XYZ null null ${f2(zoomNum)}]');
          }
        }
    }

    // Layout
    final layout = layoutMode ?? 'continuous';
    switch (layout) {
      case 'continuous':
        out('/PageLayout /OneColumn');
        break;
      case 'single':
        out('/PageLayout /SinglePage');
        break;
      case 'two':
      case 'twoleft':
        out('/PageLayout /TwoColumnLeft');
        break;
      case 'tworight':
        out('/PageLayout /TwoColumnRight');
        break;
    }

    // Page mode
    if (pageMode != null) {
      out('/PageMode /$pageMode');
    }

    if (languageCode != null) {
      out('/Lang (${pdfEscape(languageCode)})');
    }

    if (metadataObjectNumber != null && metadataObjectNumber > 0) {
      out('/Metadata $metadataObjectNumber 0 R');
    }

    out('>>');
    out('endobj');
  }

  /// Emite a tabela xref.
  void putXRef() {
    const p = '0000000000';

    out('xref');
    out('0 ${_objectNumber + 1}');
    out('0000000000 65535 f ');

    for (var i = 1; i <= _objectNumber; i++) {
      if (i < _offsets.length && _offsets[i] != null) {
        int offset;
        if (_offsets[i] is Function) {
          offset = (_offsets[i] as Function)() as int;
        } else {
          offset = _offsets[i] as int;
        }
        out('${(p + offset.toString()).substring((p + offset.toString()).length - 10)} 00000 n ');
      } else {
        out('0000000000 00000 n ');
      }
    }
  }

  /// Emite o trailer.
  void putTrailer({required String fileId, int? encryptionOid}) {
    out('trailer');
    out('<<');
    out('/Size ${_objectNumber + 1}');
    out('/Root $_objectNumber 0 R');
    out('/Info ${_objectNumber - 1} 0 R');
    if (encryptionOid != null) {
      out('/Encrypt $encryptionOid 0 R');
    }
    out('/ID [ <$fileId> <$fileId> ]');
    out('>>');
  }

  /// Reconstrói o documento completamente (reset + build).
  void resetDocument() {
    _objectNumber = 0;
    _contentLength = 0;
    _content.clear();
    _offsets.clear();
    _additionalObjects.clear();
    _rootDictionaryObjId = newObjectDeferred();
    _resourceDictionaryObjId = newObjectDeferred();
  }

  /// Monta e retorna o documento PDF completo como string.
  String buildDocument({
    required String fileId,
    required String creationDate,
    Map<String, String>? documentProperties,
    String? zoomMode,
    String? layoutMode,
    String? pageMode,
    String? languageCode,
    void Function()? putResourcesCallback,
    PdfSecurity? security,

    /// Optional XMP metadata content string (already built by [buildXmpContent]).
    String? xmpMetadataContent,
  }) {
    resetDocument();
    setOutputDestination(_content);

    putHeader();
    putPages(security: security);
    putAdditionalObjects();

    // Recursos (fontes, images, etc.) — delegado via callback
    putResourcesCallback?.call();

    int? encryptionOid;
    if (security != null) {
      putEncryption(security);
      encryptionOid = objectNumber;
    }

    // XMP Metadata stream (emitted before Info/Catalog so object numbers are known)
    int? metadataObjectNumber;
    if (xmpMetadataContent != null && xmpMetadataContent.isNotEmpty) {
      metadataObjectNumber = newObject();
      out('<< /Type /Metadata /Subtype /XML /Length ${xmpMetadataContent.length} >>');
      out('stream');
      out(xmpMetadataContent);
      out('endstream');
      out('endobj');
    }

    putInfo(
      documentProperties: documentProperties,
      creationDate: creationDate,
      security: security,
    );
    putCatalog(
      zoomMode: zoomMode,
      layoutMode: layoutMode,
      pageMode: pageMode,
      languageCode: languageCode,
      metadataObjectNumber: metadataObjectNumber,
    );

    final offsetOfXRef = _contentLength;
    putXRef();
    putTrailer(fileId: fileId, encryptionOid: encryptionOid);
    out('startxref');
    out('$offsetOfXRef');
    out('%%EOF');

    if (_currentPage > 0 && _currentPage < _pages.length) {
      setOutputDestination(_pages[_currentPage]);
    }

    return _content.join('\n');
  }

  String _parseFloat(String value) {
    return double.parse(value).toString();
  }
}

class _AdditionalObject {
  final int objId;
  String content = '';

  _AdditionalObject({required this.objId});
}
