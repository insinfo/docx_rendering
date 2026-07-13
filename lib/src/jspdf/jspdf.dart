import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'color.dart';
import 'fonts.dart';

import 'gstate.dart';
import 'matrix.dart';
import 'modules/context2d.dart';
import 'modules/addimage.dart';
import 'modules/jpeg_support.dart';
import 'modules/png_support.dart';
import 'modules/standard_fonts_metrics.dart';
import 'modules/utf8.dart';
import 'modules/setlanguage.dart';
import 'modules/filters.dart';
import 'modules/rgba_support.dart';
import 'modules/bmp_support.dart';
import 'modules/canvas.dart';
import 'modules/xmp_metadata.dart';
import 'page_formats.dart';
import 'pattern.dart';
import 'platform/browser_platform.dart' as browser;
import 'pdf_document.dart';
import 'pdf_security.dart';
import 'pubsub.dart';
import 'utils.dart';
import 'libs/ttffont.dart';

/// Opções de configuração do documento JsPdf.
class JsPdfOptions {
  /// Orientação: 'portrait'/'p' ou 'landscape'/'l'.
  final String orientation;

  /// Unidade de medida: 'pt', 'mm', 'cm', 'in', 'px', 'pc', 'em', 'ex'.
  final String unit;

  /// Formato da página: nome (ex: 'a4') ou dimensões [largura, altura].
  final dynamic format;

  /// Compressão (FlateEncode). Nota: não implementado neste porte inicial.
  final bool compress;

  /// Precisão de posições de elementos.
  final int? precision;

  /// Precisão de floats.
  final dynamic floatPrecision;

  /// Unidade do usuário (não confundir com unit base).
  final double userUnit;

  /// Apenas incluir fontes usadas.
  final bool putOnlyUsedFonts;

  /// Operação de path padrão.
  final String defaultPathOperation;

  /// Tamanho da fonte inicial.
  final double fontSize;

  /// Right-to-left.
  final bool r2l;

  /// Hotfixes habilitados.
  final List<String> hotfixes;

  /// Configuração opcional de criptografia PDF Standard Security R2.
  final PdfEncryptionOptions? encryption;

  const JsPdfOptions({
    this.orientation = 'portrait',
    this.unit = 'mm',
    this.format = 'a4',
    this.compress = false,
    this.precision,
    this.floatPrecision = 16,
    this.userUnit = 1.0,
    this.putOnlyUsedFonts = false,
    this.defaultPathOperation = 'S',
    this.fontSize = 16,
    this.r2l = false,
    this.hotfixes = const [],
    this.encryption,
  });
}

/// Modo da API (compatível ou avançado).
enum ApiMode { compat, advanced }

/// Gerador de documentos PDF para Dart/Web.
///
/// Porte completo do jsPDF para Dart, compilando na Web e na Dart VM.
/// Oferece API fluente para criação de PDFs no navegador.
///
/// Exemplo de uso:
/// ```dart
/// final pdf = JsPdf();
/// pdf.text('Hello World!', 10, 10);
/// pdf.save('test.pdf');
/// ```
class JsPdf {
  late final PdfDocumentBuilder _doc;
  late final PubSub _events;
  late final Context2D _context2d;
  late final PdfCanvas _canvas;
  late final String Function(num) _hpf;

  // --- State ---
  String _pdfVersion = '1.3';
  ApiMode _apiMode = ApiMode.compat;
  // ignore: unused_field
  String _defaultPathOperation = 'S';
  // ignore: unused_field
  int? _precision;
  late double _scaleFactor;
  late double _userUnit;
  late bool _compress;
  late bool _putOnlyUsedFonts;
  // ignore: unused_field
  late bool _r2l;
  // ignore: unused_field
  late List<String> _hotfixes;

  // XMP Metadata
  XmpMetadataConfig? _xmpMetadata;

  // Font state
  final Map<String, PdfFont> _fonts = {};
  final Map<String, Map<String, String>> _fontmap = {};
  final Map<String, String> _vfs = {};
  String _activeFontKey = '';
  double _activeFontSize = 16;
  // ignore: unused_field
  final List<Map<String, dynamic>> _fontStateStack = [];

  // Color state
  String _textColor = '0 g';
  String _drawColor = '0 G';
  String _fillColor = '0 g';

  // Graphics state
  double _lineWidth = 0.200025;
  // ignore: unused_field
  String _lineJoin = 'miter';
  // ignore: unused_field
  String _lineCap = 'butt';
  // ignore: unused_field
  double _miterLimit = 10.0;
  // ignore: unused_field
  List<List<num>> _dashPattern = [];
  double _lineHeightFactor = 1.15;
  double _charSpace = 0;

  final Map<String, GState> _gStates = {};
  final Map<String, String> _gStatesMap = {};
  GState? _activeGState;

  // Patterns - reservados para uso futuro
  // ignore: unused_field
  final Map<String, PdfPattern> _patterns = {};
  // ignore: unused_field
  final Map<String, String> _patternMap = {};

  // Document properties
  final Map<String, String> _documentProperties = {
    'title': '',
    'subject': '',
    'author': '',
    'keywords': '',
    'creator': '',
  };

  // Display mode
  String? _zoomMode;
  String? _pageMode;
  String? _layoutMode;
  String? _languageCode;

  // Creation date
  late String _creationDate;
  late String _fileId;
  PdfEncryptionOptions? _encryptionOptions;

  // Used fonts tracking
  final Map<String, bool> _usedFonts = {};

  // Graphics state stack
  final List<Map<String, dynamic>> _graphicsStateStack = [];

  // Image resources
  final List<PdfImage> _images = <PdfImage>[];
  final Map<String, PdfImage> _imagesByAlias = <String, PdfImage>{};

  JsPdf([JsPdfOptions? options]) {
    options ??= const JsPdfOptions();

    _defaultPathOperation = options.defaultPathOperation;
    _userUnit = options.userUnit.abs();
    _compress = options.compress;
    _putOnlyUsedFonts = options.putOnlyUsedFonts;
    _r2l = options.r2l;
    _hotfixes = List.from(options.hotfixes);
    _encryptionOptions = options.encryption;

    if (options.precision != null) {
      _precision = options.precision;
    }

    _hpf = createHpf(options.floatPrecision);

    // Configurar unidade e fator de escala
    _scaleFactor = getScaleFactor(options.unit);

    // Configurar formato de página
    List<double> dimensions;
    if (options.format is String) {
      final fmt = getPageFormat(options.format as String);
      if (fmt == null) {
        throw ArgumentError('Invalid format: ${options.format}');
      }
      dimensions = fmt;
    } else if (options.format is List) {
      final List<dynamic> customFormat = options.format as List;
      dimensions = <double>[
        (customFormat[0] as num).toDouble() * _scaleFactor,
        (customFormat[1] as num).toDouble() * _scaleFactor,
      ];
    } else {
      dimensions = getPageFormat('a4')!;
    }

    // Criar o builder de documento
    _doc = PdfDocumentBuilder(
      pdfVersion: _pdfVersion,
      hpf: _hpf,
      compress: options.compress,
    );
    _events = PubSub();
    _context2d = Context2D(this);
    _canvas = PdfCanvas()..attachContext(_context2d);

    // Configurar fontes padrão
    _addStandardFonts();
    _activeFontKey = 'F1';
    _activeFontSize = options.fontSize;

    // Configurar data e ID
    _creationDate = convertDateToPDFDate(DateTime.now());
    _fileId = normalizeFileId(null);

    // Orientação
    final orientLower = options.orientation.toLowerCase();
    final isLandscape = orientLower == 'l' || orientLower == 'landscape';

    double pageWidth, pageHeight;
    if (isLandscape) {
      pageWidth = math.max(dimensions[0], dimensions[1]);
      pageHeight = math.min(dimensions[0], dimensions[1]);
    } else {
      pageWidth = math.min(dimensions[0], dimensions[1]);
      pageHeight = math.max(dimensions[0], dimensions[1]);
    }

    // Adicionar primeira página
    _doc.addPage(MediaBox.fromDimensions(pageWidth, pageHeight),
        userUnit: _userUnit);
  }

  // ==========================================================================
  // PDF Version
  // ==========================================================================

  String get pdfVersion => _pdfVersion;
  set pdfVersion(String v) => _pdfVersion = v;

  /// Contexto Canvas 2D compatível com o plugin `context2d` do jsPDF.
  Context2D get context2d => _context2d;

  /// Alias Dart-style para [context2d].
  Context2D get context2D => _context2d;

  /// Canvas wrapper compatível com o plugin `canvas` do jsPDF.
  ///
  /// Uso: `pdf.canvas.getContext('2d')` retorna o mesmo [Context2D] que
  /// `pdf.context2d`.
  PdfCanvas get canvas => _canvas;

  /// ExtGState ativo na página atual, quando definido por [setGState].
  GState? get activeGState => _activeGState;

  // ==========================================================================
  // Font Management
  // ==========================================================================

  void _addStandardFonts() {
    var keyIndex = 1;
    for (final sf in standardFonts) {
      final key = 'F$keyIndex';
      final font = PdfFont(
        key: key,
        fontName: sf.fontName,
        fontStyle: sf.fontStyle,
        encoding: sf.encoding,
        postScriptName: sf.postScriptName,
      );
      _fonts[key] = font;

      _fontmap.putIfAbsent(sf.fontName, () => {});
      _fontmap[sf.fontName]![sf.fontStyle] = key;

      keyIndex++;
    }
  }

  /// Define a fonte ativa.
  JsPdf setFont(String fontName, {String fontStyle = 'normal'}) {
    final nameLower = fontName.toLowerCase();
    final styleLower = fontStyle.toLowerCase();
    String? key;

    if (_fontmap.containsKey(nameLower) &&
        _fontmap[nameLower]!.containsKey(styleLower)) {
      key = _fontmap[nameLower]![styleLower];
    } else if (_fontmap.containsKey(fontName) &&
        _fontmap[fontName]!.containsKey(styleLower)) {
      key = _fontmap[fontName]![styleLower];
    }

    if (key == null) {
      // Fallback para times normal
      key = _fontmap['times']?['normal'] ?? 'F1';
    }

    _activeFontKey = key;
    if (_putOnlyUsedFonts) {
      _usedFonts[key] = true;
    }

    return this;
  }

  /// Retorna a fonte ativa.
  PdfFont getFont() => _fonts[_activeFontKey]!;

  /// Define o tamanho da fonte em pontos.
  JsPdf setFontSize(double size) {
    if (_apiMode == ApiMode.advanced) {
      _activeFontSize = size / _scaleFactor;
    } else {
      _activeFontSize = size;
    }
    return this;
  }

  /// Retorna o tamanho da fonte atual.
  double getFontSize() {
    if (_apiMode == ApiMode.compat) {
      return _activeFontSize;
    } else {
      return _activeFontSize * _scaleFactor;
    }
  }

  /// Retorna lista de fontes disponíveis.
  Map<String, List<String>> getFontList() {
    final result = <String, List<String>>{};
    for (final entry in _fontmap.entries) {
      result[entry.key] = entry.value.keys.toList();
    }
    return result;
  }

  /// Define a linguagem do documento PDF, emitida como `/Lang` no catálogo.
  JsPdf setLanguage(String languageCode) {
    if (isValidPdfLanguageCode(languageCode)) {
      _languageCode = languageCode;
    }
    return this;
  }

  /// Adiciona metadados XMP ao documento PDF.
  ///
  /// [metadata] — conteúdo XMP (XML ou valor simples).
  /// [namespaceUriOrRawXml]:
  ///   - `String` → URI do namespace para empacotar o valor como XMP simples.
  ///   - `true` → [metadata] é XML completo e será incluído verbatim.
  ///   - `false` / `null` → [metadata] é escapado e empacotado com
  ///     namespace padrão.
  ///
  /// Chamadas repetidas sobrescrevem os metadados anteriores.
  JsPdf addMetadata(String metadata, [dynamic namespaceUriOrRawXml]) {
    bool rawXml = false;
    String namespaceUri = 'http://jspdf.default.namespaceuri/';

    if (namespaceUriOrRawXml is String) {
      namespaceUri = namespaceUriOrRawXml;
    } else if (namespaceUriOrRawXml is bool) {
      rawXml = namespaceUriOrRawXml;
    }

    _xmpMetadata = XmpMetadataConfig(
      metadata: metadata,
      namespaceUri: namespaceUri,
      rawXml: rawXml,
    );
    return this;
  }

  /// Processa [data] através de uma cadeia de filtros PDF.
  ///
  /// Delega para [processDataByFilters] do módulo `filters.dart`.
  FilterResult applyFilters(String data, List<String> filterChain) {
    return processDataByFilters(data, filterChain);
  }

  /// Adiciona um arquivo ao Virtual File System interno.
  JsPdf addFileToVFS(String filename, String filecontent) {
    _vfs[filename] = filecontent;
    return this;
  }

  /// Retorna um arquivo do Virtual File System interno, ou null.
  String? getFileFromVFS(String filename) => _vfs[filename];

  /// Verifica se um arquivo existe no Virtual File System interno.
  bool existsFileInVFS(String filename) => _vfs.containsKey(filename);

  /// Registra uma fonte TrueType armazenada na vFS.
  JsPdf addFont(
    String postScriptName,
    String fontName, {
    String fontStyle = 'normal',
    String encoding = 'Identity-H',
  }) {
    final String? file = getFileFromVFS(postScriptName);
    if (file == null) {
      throw ArgumentError(
        "Font does not exist in vFS, import fonts or remove declaration doc.addFont('$postScriptName').",
      );
    }

    final List<int> bytes = _decodeFontFile(file);
    final TTFFont ttfFont = TTFFont.open(bytes);
    ttfFont.glyIdsUsed
      ..clear()
      ..add(0);

    final String normalizedName = fontName.toLowerCase();
    final String key = 'F${_fonts.length + 1}';
    final PdfFont font = PdfFont(
      key: key,
      fontName: normalizedName,
      fontStyle: fontStyle.toLowerCase(),
      encoding: encoding,
      postScriptName: postScriptName,
    )..metadata['ttf'] = ttfFont;

    _fonts[key] = font;
    _fontmap.putIfAbsent(normalizedName, () => <String, String>{});
    _fontmap[normalizedName]![fontStyle.toLowerCase()] = key;
    return this;
  }

  // ==========================================================================
  // Font Size, Color, Style
  // ==========================================================================

  /// Define a cor do texto.
  JsPdf setTextColor(dynamic ch1, [dynamic ch2, dynamic ch3]) {
    _textColor = _buildColorString(ch1, ch2, ch3, pdfColorType: 'fill');
    return this;
  }

  /// Define a cor do traçado.
  JsPdf setDrawColor(dynamic ch1, [dynamic ch2, dynamic ch3]) {
    _drawColor = _buildColorString(ch1, ch2, ch3, pdfColorType: 'draw');
    _doc.out(_drawColor);
    return this;
  }

  /// Define a cor de preenchimento.
  JsPdf setFillColor(dynamic ch1, [dynamic ch2, dynamic ch3]) {
    _fillColor = _buildColorString(ch1, ch2, ch3, pdfColorType: 'fill');
    _doc.out(_fillColor);
    return this;
  }

  String _buildColorString(
    dynamic ch1,
    dynamic ch2,
    dynamic ch3, {
    String pdfColorType = 'fill',
  }) {
    return encodeColorString(
      ColorOptions(ch1: ch1, ch2: ch2, ch3: ch3, pdfColorType: pdfColorType),
    );
  }

  // ==========================================================================
  // Line Style
  // ==========================================================================

  /// Define a largura da linha.
  JsPdf setLineWidth(double width) {
    _lineWidth = width;
    _doc.out('${_hpf(width * _scaleFactor)} w');
    return this;
  }

  /// Define o padrão de traço (dash).
  JsPdf setLineDash(List<num> dashArray, [num dashPhase = 0]) {
    _dashPattern = [
      dashArray,
      [dashPhase]
    ];
    final scaled = dashArray.map((d) => _hpf(d * _scaleFactor)).join(' ');
    _doc.out('[$scaled] ${_hpf(dashPhase * _scaleFactor)} d');
    return this;
  }

  /// Define o estilo de junção de linhas.
  JsPdf setLineJoin(dynamic style) {
    int joinCode;
    if (style is int) {
      joinCode = style;
    } else {
      switch (style.toString()) {
        case 'miter':
          joinCode = 0;
          break;
        case 'round':
          joinCode = 1;
          break;
        case 'bevel':
          joinCode = 2;
          break;
        default:
          joinCode = 0;
      }
    }
    _doc.out('$joinCode j');
    return this;
  }

  /// Define o estilo de terminação de linha.
  JsPdf setLineCap(dynamic style) {
    int capCode;
    if (style is int) {
      capCode = style;
    } else {
      switch (style.toString()) {
        case 'butt':
          capCode = 0;
          break;
        case 'round':
          capCode = 1;
          break;
        case 'square':
          capCode = 2;
          break;
        default:
          capCode = 0;
      }
    }
    _doc.out('$capCode J');
    return this;
  }

  // ==========================================================================
  // Drawing Primitives
  // ==========================================================================

  /// Estilo de desenho PDF.
  String _getStyle(String? style) {
    switch (style) {
      case 'D':
      case null:
        return 'S'; // stroke
      case 'F':
        return 'f'; // fill
      case 'FD':
      case 'DF':
        return 'B'; // fill + stroke
      case 'f':
      case 'f*':
      case 'B':
      case 'B*':
        return style;
      default:
        return 'S';
    }
  }

  /// Desenha uma linha de (x1,y1) a (x2,y2).
  JsPdf line(double x1, double y1, double x2, double y2) {
    if (_apiMode == ApiMode.compat) {
      _doc.out(
        '${_hpf(x1 * _scaleFactor)} ${_hpf(_transformY(y1) * _scaleFactor)} m '
        '${_hpf(x2 * _scaleFactor)} ${_hpf(_transformY(y2) * _scaleFactor)} l S',
      );
    } else {
      _doc.out(
        '${_hpf(x1)} ${_hpf(y1)} m ${_hpf(x2)} ${_hpf(y2)} l S',
      );
    }
    return this;
  }

  /// Desenha um retângulo.
  JsPdf rect(double x, double y, double w, double h, [String? style]) {
    final op = _getStyle(style);
    if (_apiMode == ApiMode.compat) {
      _doc.out(
        '${_hpf(x * _scaleFactor)} ${_hpf(_transformY(y) * _scaleFactor)} '
        '${_hpf(w * _scaleFactor)} ${_hpf(-h * _scaleFactor)} re $op',
      );
    } else {
      _doc.out('${_hpf(x)} ${_hpf(y)} ${_hpf(w)} ${_hpf(h)} re $op');
    }
    return this;
  }

  /// Desenha um retângulo arredondado.
  JsPdf roundedRect(
    double x,
    double y,
    double w,
    double h,
    double rx,
    double ry, [
    String? style,
  ]) {
    final op = _getStyle(style);
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final MyArc = 4 / 3 * (math.sqrt(2) - 1);

    final xVal = x * k;
    final yVal = ((_apiMode == ApiMode.compat) ? _transformY(y) : y) * k;
    final wVal = w * k;
    final hVal = ((_apiMode == ApiMode.compat) ? -h : h) * k;
    final rxVal = rx * k;
    final ryVal = ry * k;

    _doc.out('${_hpf(xVal + rxVal)} ${_hpf(yVal)} m');
    _doc.out('${_hpf(xVal + wVal - rxVal)} ${_hpf(yVal)} l');
    _doc.out(
      '${_hpf(xVal + wVal - rxVal + MyArc * rxVal)} ${_hpf(yVal)} '
      '${_hpf(xVal + wVal)} ${_hpf(yVal + ryVal - MyArc * ryVal)} '
      '${_hpf(xVal + wVal)} ${_hpf(yVal + ryVal)} c',
    );
    _doc.out('${_hpf(xVal + wVal)} ${_hpf(yVal + hVal - ryVal)} l');
    _doc.out(
      '${_hpf(xVal + wVal)} ${_hpf(yVal + hVal - ryVal + MyArc * ryVal)} '
      '${_hpf(xVal + wVal - rxVal + MyArc * rxVal)} ${_hpf(yVal + hVal)} '
      '${_hpf(xVal + wVal - rxVal)} ${_hpf(yVal + hVal)} c',
    );
    _doc.out('${_hpf(xVal + rxVal)} ${_hpf(yVal + hVal)} l');
    _doc.out(
      '${_hpf(xVal + rxVal - MyArc * rxVal)} ${_hpf(yVal + hVal)} '
      '${_hpf(xVal)} ${_hpf(yVal + hVal - ryVal + MyArc * ryVal)} '
      '${_hpf(xVal)} ${_hpf(yVal + hVal - ryVal)} c',
    );
    _doc.out('${_hpf(xVal)} ${_hpf(yVal + ryVal)} l');
    _doc.out(
      '${_hpf(xVal)} ${_hpf(yVal + ryVal - MyArc * ryVal)} '
      '${_hpf(xVal + rxVal - MyArc * rxVal)} ${_hpf(yVal)} '
      '${_hpf(xVal + rxVal)} ${_hpf(yVal)} c',
    );
    _doc.out(op);
    return this;
  }

  /// Desenha uma elipse.
  JsPdf ellipse(double x, double y, double rx, double ry, [String? style]) {
    final op = _getStyle(style);
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final lx = 4 / 3 * (math.sqrt(2) - 1) * rx * k;
    final ly = 4 / 3 * (math.sqrt(2) - 1) * ry * k;
    final xk = x * k;
    final yk = ((_apiMode == ApiMode.compat) ? _transformY(y) : y) * k;
    final rxk = rx * k;
    final ryk = ry * k;

    _doc.out('${_hpf(xk + rxk)} ${_hpf(yk)} m');
    _doc.out(
      '${_hpf(xk + rxk)} ${_hpf(yk - ly)} '
      '${_hpf(xk + lx)} ${_hpf(yk - ryk)} '
      '${_hpf(xk)} ${_hpf(yk - ryk)} c',
    );
    _doc.out(
      '${_hpf(xk - lx)} ${_hpf(yk - ryk)} '
      '${_hpf(xk - rxk)} ${_hpf(yk - ly)} '
      '${_hpf(xk - rxk)} ${_hpf(yk)} c',
    );
    _doc.out(
      '${_hpf(xk - rxk)} ${_hpf(yk + ly)} '
      '${_hpf(xk - lx)} ${_hpf(yk + ryk)} '
      '${_hpf(xk)} ${_hpf(yk + ryk)} c',
    );
    _doc.out(
      '${_hpf(xk + lx)} ${_hpf(yk + ryk)} '
      '${_hpf(xk + rxk)} ${_hpf(yk + ly)} '
      '${_hpf(xk + rxk)} ${_hpf(yk)} c',
    );
    _doc.out(op);
    return this;
  }

  /// Desenha um círculo.
  JsPdf circle(double x, double y, double r, [String? style]) {
    return ellipse(x, y, r, r, style);
  }

  /// Desenha um triângulo.
  JsPdf triangle(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3, [
    String? style,
  ]) {
    final op = _getStyle(style);
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final ty = _apiMode == ApiMode.compat
        ? (double y) => _transformY(y)
        : (double y) => y;

    _doc.out(
      '${_hpf(x1 * k)} ${_hpf(ty(y1) * k)} m '
      '${_hpf(x2 * k)} ${_hpf(ty(y2) * k)} l '
      '${_hpf(x3 * k)} ${_hpf(ty(y3) * k)} l h $op',
    );
    return this;
  }

  // ==========================================================================
  // Images
  // ==========================================================================

  /// Adiciona uma imagem PNG/JPEG ao PDF e a desenha na página atual.
  ///
  /// Assinaturas aceitas:
  /// - `addImage(data, x, y, width, height)`
  /// - `addImage(data, format, x, y, width, height, alias)`
  /// - `addImage(data, x, y, width, height, alias, sx, sy, swidth, sheight)`
  JsPdf addImage(
    dynamic imageData,
    dynamic formatOrX, [
    dynamic xOrY,
    dynamic yOrWidth,
    dynamic widthOrHeight,
    dynamic heightOrAlias,
    dynamic alias,
    double? sourceX,
    double? sourceY,
    double? sourceWidth,
    double? sourceHeight,
  ]) {
    String? format;
    double x;
    double y;
    double width;
    double height;

    if (formatOrX is String) {
      format = formatOrX;
      x = (xOrY as num).toDouble();
      y = (yOrWidth as num).toDouble();
      width = (widthOrHeight as num).toDouble();
      height = (heightOrAlias as num).toDouble();
    } else {
      x = (formatOrX as num).toDouble();
      y = (xOrY as num).toDouble();
      width = (yOrWidth as num).toDouble();
      height = (widthOrHeight as num).toDouble();
      if (heightOrAlias is String) {
        alias = heightOrAlias;
      }
    }

    String? imageAlias;
    if (alias is String) {
      imageAlias = alias;
    } else if (alias is num) {
      sourceHeight = sourceWidth;
      sourceWidth = sourceY;
      sourceY = sourceX;
      sourceX = alias.toDouble();
    }

    final PdfImage image =
        _processImage(imageData, format: format, alias: imageAlias);
    _drawImage(
      image,
      x,
      y,
      width,
      height,
      sourceX: sourceX,
      sourceY: sourceY,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    return this;
  }

  /// Adiciona e desenha uma imagem a partir de dados RGBA crus.
  ///
  /// [imageData] — pixels RGBA (4 bytes por pixel).
  /// [x], [y] — posição no documento.
  /// [width], [height] — tamanho no documento.
  /// [alias] — alias opcional para cache.
  JsPdf addImageFromRGBA(
    RgbaImageData imageData,
    double x,
    double y,
    double width,
    double height, [
    String? alias,
  ]) {
    final String imageAlias =
        alias ?? sHashCode(imageData.data).toRadixString(16);
    PdfImage? image = _imagesByAlias[imageAlias];
    if (image == null) {
      image = processRGBA(imageData, _images.length + 1, imageAlias);
      _images.add(image);
      _imagesByAlias[imageAlias] = image;
    }
    _drawImage(image, x, y, width, height);
    return this;
  }

  // ==========================================================================
  // Text
  // ==========================================================================

  /// Insere texto no PDF.
  ///
  /// [text] pode ser uma string ou lista de strings (multilinha).
  /// [x], [y] posição em unidades do documento.
  JsPdf text(
    dynamic text,
    double x,
    double y, {
    double? angle,
    String? align,
    double? maxWidth,
    double? lineHeightFactor,
  }) {
    final lines = text is List<String> ? text : [text.toString()];
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final fontSize = _activeFontSize;

    // Calcular posição
    var xPos = x * k;
    var yPos = (_apiMode == ApiMode.compat ? _transformY(y) : y) * k;

    final lhf = lineHeightFactor ?? _lineHeightFactor;
    final lineHeight = fontSize * lhf;

    // Alinhamento
    // (simplificado para o porte inicial)

    // Transformação por ângulo
    PdfMatrix? tm;
    if (angle != null && angle != 0) {
      final rad = angle * math.pi / 180;
      final c = math.cos(rad);
      final s = math.sin(rad);
      tm = PdfMatrix(c, s, -s, c, xPos, yPos);
    }

    _doc.out('BT');
    _doc.out(_textColor);

    if (tm != null) {
      _doc.out('${tm.toString()} Tm');
    } else {
      _doc.out('${_hpf(xPos)} ${_hpf(yPos)} Td');
    }

    _doc.out('/${_activeFontKey} ${f2(fontSize)} Tf');

    if (_charSpace != 0) {
      _doc.out('${_hpf(_charSpace)} Tc');
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final processedLine = _processTextLine(line);

      if (i == 0) {
        _doc.out(processedLine);
      } else {
        _doc.out('0 ${_hpf(-lineHeight)} Td $processedLine');
      }
    }

    _doc.out('ET');
    return this;
  }

  // ==========================================================================
  // Page Management
  // ==========================================================================

  /// Adiciona uma nova página ao documento.
  JsPdf addPage([dynamic format, String? orientation]) {
    final List<double> dimensions = _resolvePageDimensions(format);

    final orientLower = (orientation ?? 'portrait').toLowerCase();
    final isLandscape = orientLower == 'l' || orientLower == 'landscape';

    double pageWidth, pageHeight;
    if (isLandscape) {
      pageWidth = math.max(dimensions[0], dimensions[1]);
      pageHeight = math.min(dimensions[0], dimensions[1]);
    } else {
      pageWidth = math.min(dimensions[0], dimensions[1]);
      pageHeight = math.max(dimensions[0], dimensions[1]);
    }

    _doc.addPage(
      MediaBox.fromDimensions(pageWidth, pageHeight),
      userUnit: _userUnit,
    );

    // Emitir estados gráficos padrão na nova página
    _doc.out('${_hpf(_lineWidth * _scaleFactor)} w');
    _doc.out(_drawColor);

    return this;
  }

  /// Define a página ativa por número (1-based).
  JsPdf setPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= _doc.numberOfPages) {
      _doc.setOutputDestination(_doc.pages[pageNumber]);
    }
    return this;
  }

  /// Retorna o número de páginas.
  int getNumberOfPages() => _doc.numberOfPages;

  /// Retorna largura da página atual (em unidades do documento).
  double getPageWidth([int? pageNumber]) {
    pageNumber ??= _doc.currentPage;
    final ctx = _doc.pagesContext[pageNumber]!;
    return (ctx.mediaBox.topRightX - ctx.mediaBox.bottomLeftX) / _scaleFactor;
  }

  /// Retorna altura da página atual (em unidades do documento).
  double getPageHeight([int? pageNumber]) {
    pageNumber ??= _doc.currentPage;
    final ctx = _doc.pagesContext[pageNumber]!;
    return (ctx.mediaBox.topRightY - ctx.mediaBox.bottomLeftY) / _scaleFactor;
  }

  // ==========================================================================
  // Document Properties
  // ==========================================================================

  /// Define propriedades do documento.
  JsPdf setDocumentProperties(Map<String, String> properties) {
    for (final entry in properties.entries) {
      if (_documentProperties.containsKey(entry.key)) {
        _documentProperties[entry.key] = entry.value;
      }
    }
    return this;
  }

  /// Alias para setDocumentProperties.
  JsPdf setProperties(Map<String, String> properties) =>
      setDocumentProperties(properties);

  /// Define zoom e layout de exibição.
  JsPdf setDisplayMode(dynamic zoom, [String? layout, String? pmode]) {
    if (zoom is String || zoom is int) {
      _zoomMode = zoom.toString();
    }
    if (layout != null) _layoutMode = layout;
    if (pmode != null) _pageMode = pmode;
    return this;
  }

  // ==========================================================================
  // Graphics State
  // ==========================================================================

  /// Salva o estado gráfico atual.
  JsPdf saveGraphicsState() {
    _doc.out('q');
    _graphicsStateStack.add({
      'textColor': _textColor,
      'drawColor': _drawColor,
      'fillColor': _fillColor,
      'lineWidth': _lineWidth,
      'activeFontKey': _activeFontKey,
      'activeFontSize': _activeFontSize,
    });
    return this;
  }

  /// Restaura o estado gráfico anterior.
  JsPdf restoreGraphicsState() {
    _doc.out('Q');
    if (_graphicsStateStack.isNotEmpty) {
      final state = _graphicsStateStack.removeLast();
      _textColor = state['textColor'] as String;
      _drawColor = state['drawColor'] as String;
      _fillColor = state['fillColor'] as String;
      _lineWidth = state['lineWidth'] as double;
      _activeFontKey = state['activeFontKey'] as String;
      _activeFontSize = state['activeFontSize'] as double;
    }
    return this;
  }

  /// Registra um ExtGState PDF e retorna seu identificador de recurso.
  String addGState(GState gState, [String? key]) {
    for (final entry in _gStates.entries) {
      if (entry.value.equals(gState)) {
        return entry.key;
      }
    }

    final String id = key ?? 'GS${_gStates.length + 1}';
    gState.id = id;
    _gStates[id] = gState;
    _gStatesMap[gState.toString()] = id;
    return id;
  }

  /// Ativa um ExtGState no conteúdo da página atual.
  JsPdf setGState(GState gState) {
    final String id = addGState(gState);
    _activeGState = _gStates[id];
    _doc.out('/$id gs');
    return this;
  }

  // ==========================================================================
  // Output & Save
  // ==========================================================================

  /// Monta e retorna o documento PDF.
  ///
  /// [type] pode ser:
  /// - null/undefined: retorna raw string
  /// - 'arraybuffer': retorna ByteBuffer
  /// - 'blob': retorna Blob
  /// - 'bloburl'/'bloburi': retorna URL do blob
  /// - 'dataurlstring'/'datauristring': retorna data URI
  dynamic output([String? type]) {
    final pdfString = _buildDocument();

    switch (type) {
      case null:
        return pdfString;
      case 'arraybuffer':
        return _getArrayBuffer(pdfString);
      case 'blob':
        return _getBlob(pdfString);
      case 'bloburl':
      case 'bloburi':
        return browser.createPdfBlobUrl(_getArrayBuffer(pdfString));
      case 'datauristring':
      case 'dataurlstring':
        final encoded = base64.encode(utf8.encode(pdfString));
        return 'data:application/pdf;base64,$encoded';
      default:
        return pdfString;
    }
  }

  /// Salva o PDF fazendo download no browser.
  void save([String filename = 'generated.pdf']) {
    browser.savePdfBytes(_getArrayBuffer(_buildDocument()), filename);
  }

  // ==========================================================================
  // Internal Helpers
  // ==========================================================================

  double _transformY(double y) {
    if (_apiMode == ApiMode.compat) {
      return getPageHeight() - y;
    }
    return y;
  }

  List<double> _resolvePageDimensions(dynamic format) {
    if (format == null) {
      final ctx = _doc.pagesContext[_doc.currentPage]!;
      return <double>[
        ctx.mediaBox.topRightX - ctx.mediaBox.bottomLeftX,
        ctx.mediaBox.topRightY - ctx.mediaBox.bottomLeftY,
      ];
    }
    if (format is String) {
      final List<double>? dimensions = getPageFormat(format);
      if (dimensions == null) {
        throw ArgumentError('Invalid format: $format');
      }
      return dimensions;
    }
    if (format is List && format.length >= 2) {
      return <double>[
        (format[0] as num).toDouble() * _scaleFactor,
        (format[1] as num).toDouble() * _scaleFactor,
      ];
    }
    throw ArgumentError.value(
        format, 'format', 'Expected page format name or [width, height].');
  }

  String _buildDocument() {
    final PdfSecurity? security = _encryptionOptions == null
        ? null
        : PdfSecurity(
            permissions: _encryptionOptions!.userPermissions,
            userPassword: _encryptionOptions!.userPassword,
            ownerPassword: _encryptionOptions!.ownerPassword,
            fileId: _fileId,
          );

    final String? xmpContent =
        _xmpMetadata != null ? buildXmpContent(_xmpMetadata!) : null;

    return _doc.buildDocument(
      fileId: _fileId,
      creationDate: _creationDate,
      documentProperties: _documentProperties,
      zoomMode: _zoomMode,
      layoutMode: _layoutMode,
      pageMode: _pageMode,
      languageCode: _languageCode,
      putResourcesCallback: _putResources,
      security: security,
      xmpMetadataContent: xmpContent,
    );
  }

  void _putResources() {
    _putFonts();
    _putGStates();
    _putImages();
    _doc.newObjectDeferredBegin(
      _doc.resourceDictionaryObjId,
      doOutput: true,
    );
    _doc.out('<<');
    _putResourceDictionary();
    _doc.out('>>');
    _doc.out('endobj');
  }

  /// Retorna métricas Canvas-like para o texto no contexto 2D.
  Map<String, double> measureTextMetrics(
    String text,
    String fontName,
    String fontStyle,
    double fontSize,
  ) {
    final PdfFont font = _resolveFont(fontName, fontStyle);
    final TTFFont? ttfFont = font.metadata['ttf'] as TTFFont?;
    double width;
    double ascent;
    double descent;

    if (ttfFont != null) {
      width = ttfFont.widthOfString(text, fontSize, _charSpace);
      ascent = ttfFont.ascender / 1000 * fontSize;
      descent = ttfFont.decender.abs() / 1000 * fontSize;
    } else {
      width =
          getStringWidthForFont(text, font.postScriptName) / 1000 * fontSize;
      ascent = fontSize * 0.8;
      descent = fontSize * 0.2;
    }

    return <String, double>{
      'width': width / _scaleFactor,
      'actualBoundingBoxAscent': ascent / _scaleFactor,
      'actualBoundingBoxDescent': descent / _scaleFactor,
      'fontBoundingBoxAscent': ascent / _scaleFactor,
      'fontBoundingBoxDescent': descent / _scaleFactor,
    };
  }

  PdfFont _resolveFont(String fontName, String fontStyle) {
    final String nameLower = fontName.toLowerCase();
    final String styleLower = fontStyle.toLowerCase();
    final String? key = _fontmap[nameLower]?[styleLower] ??
        _fontmap[nameLower]?['normal'] ??
        _fontmap[fontName]?[styleLower] ??
        _fontmap[fontName]?['normal'];
    return _fonts[key ?? _activeFontKey] ?? getFont();
  }

  void _putGStates() {
    for (final GState gState in _gStates.values) {
      gState.objectNumber = _doc.newObject();
      _doc.out('<<');
      _doc.out('/Type /ExtGState');
      if (gState.opacity != null) {
        _doc.out('/ca ${f2(gState.opacity!)}');
      }
      if (gState.strokeOpacity != null) {
        _doc.out('/CA ${f2(gState.strokeOpacity!)}');
      }
      _doc.out('>>');
      _doc.out('endobj');
    }
  }

  void _putImages() {
    for (final PdfImage image in _images) {
      if (image.sMask != null) {
        image.sMaskObjectId = _doc.newObject();
        _doc.out('<<');
        _doc.out('/Type /XObject');
        _doc.out('/Subtype /Image');
        _doc.out('/Width ${image.width}');
        _doc.out('/Height ${image.height}');
        _doc.out('/ColorSpace /DeviceGray');
        _doc.out('/BitsPerComponent ${image.bitsPerComponent}');
        if (image.filter != null) {
          _doc.out('/Filter /${image.filter}');
          if (image.decodeParameters != null) {
            _doc.out('/DecodeParms <<${image.decodeParameters}>>');
          }
        }
        _doc.out('/Length ${image.sMask!.length}');
        _doc.out('>>');
        _doc.out('stream');
        _doc.out(uint8ArrayToBinaryString(image.sMask!));
        _doc.out('endstream');
        _doc.out('endobj');
      }

      image.objectId = _doc.newObject();
      _doc.out('<<');
      _doc.out('/Type /XObject');
      _doc.out('/Subtype /Image');
      _doc.out('/Width ${image.width}');
      _doc.out('/Height ${image.height}');
      _doc.out('/ColorSpace ${_imageColorSpace(image)}');
      _doc.out('/BitsPerComponent ${image.bitsPerComponent}');
      if (image.filter != null) {
        _doc.out('/Filter /${image.filter}');
      }
      if (image.decodeParameters != null) {
        _doc.out('/DecodeParms <<${image.decodeParameters}>>');
      }
      if (image.transparency != null && image.transparency!.isNotEmpty) {
        _doc.out('/Mask [${image.transparency!.join(' ')}]');
      }
      if (image.sMaskObjectId > 0) {
        _doc.out('/SMask ${image.sMaskObjectId} 0 R');
      }
      _doc.out('/Length ${image.data.length}');
      _doc.out('>>');
      _doc.out('stream');
      _doc.out(uint8ArrayToBinaryString(image.data));
      _doc.out('endstream');
      _doc.out('endobj');
    }
  }

  void _putFonts() {
    for (final font in _fonts.values) {
      if (_putOnlyUsedFonts && !_usedFonts.containsKey(font.key)) {
        continue;
      }
      final TTFFont? ttfFont = font.metadata['ttf'] as TTFFont?;
      if (ttfFont != null) {
        final FontPutData fontData = FontPutData(
          metadata: ttfFont,
          fontName: font.postScriptName,
          encoding: font.encoding ?? 'Identity-H',
        );
        if (fontData.encoding == 'Identity-H') {
          writeIdentityHFont(
            font: fontData,
            out: _doc.out,
            newObject: _doc.newObject,
            putStream: ({
              required String data,
              bool addLength1 = false,
              required int objectId,
            }) =>
                _doc.putStream(
              data: data,
              addLength1: addLength1,
              objectId: objectId,
            ),
          );
        } else {
          writeWinAnsiFFont(
            font: fontData,
            out: _doc.out,
            newObject: _doc.newObject,
            putStream: ({
              required String data,
              bool addLength1 = false,
              required int objectId,
            }) =>
                _doc.putStream(
              data: data,
              addLength1: addLength1,
              objectId: objectId,
            ),
          );
        }
        font.objectNumber = fontData.objectNumber ?? -1;
        continue;
      }
      font.objectNumber = _doc.newObject();
      _doc.out('<<');
      _doc.out('/Type /Font');
      _doc.out('/BaseFont /${font.postScriptName}');
      _doc.out('/Subtype /Type1');
      if (font.encoding != null) {
        _doc.out('/Encoding /${font.encoding}');
      }
      _doc.out('>>');
      _doc.out('endobj');
    }
  }

  void _putResourceDictionary() {
    _doc.out('/ProcSet [/PDF /Text /ImageB /ImageC /ImageI]');

    // Fonts
    _doc.out('/Font <<');
    for (final font in _fonts.values) {
      if (_putOnlyUsedFonts && !_usedFonts.containsKey(font.key)) {
        continue;
      }
      _doc.out('/${font.key} ${font.objectNumber} 0 R');
    }
    _doc.out('>>');

    if (_gStates.isNotEmpty) {
      _doc.out('/ExtGState <<');
      for (final entry in _gStates.entries) {
        _doc.out('/${entry.key} ${entry.value.objectNumber} 0 R');
      }
      _doc.out('>>');
    }

    // XObjects (imagens, etc.) - placeholder
    _doc.out('/XObject <<');
    for (final PdfImage image in _images) {
      _doc.out('/I${image.index} ${image.objectId} 0 R');
    }
    _doc.out('>>');
  }

  PdfImage _processImage(dynamic imageData, {String? format, String? alias}) {
    final Uint8List bytes = _normalizeImageBytes(imageData);
    final String imageAlias = alias ?? sHashCode(bytes).toRadixString(16);
    final PdfImage? cached = _imagesByAlias[imageAlias];
    if (cached != null) {
      return cached;
    }

    final String imageType =
        (format ?? getImageFileTypeByImageData(bytes)).toUpperCase();
    PdfImage image;
    if (imageType == 'JPEG' || imageType == 'JPG') {
      final JpegProcessResult? result = processJpeg(
        data: bytes,
        index: _images.length + 1,
        alias: imageAlias,
      );
      if (result == null) {
        throw const FormatException('Invalid JPEG image data.');
      }
      image = PdfImage(
        data: result.data,
        width: result.width,
        height: result.height,
        colorSpace: result.colorSpace,
        bitsPerComponent: result.bitsPerComponent,
        filter: result.filter,
        alias: imageAlias,
      )..index = result.index;
    } else if (imageType == 'PNG') {
      final PngProcessResult result = processPNG(
        bytes,
        index: _images.length + 1,
        alias: imageAlias,
        compression: _compress ? PngCompression.fast : PngCompression.none,
      );
      image = PdfImage(
        data: result.data,
        width: result.width,
        height: result.height,
        colorSpace: result.colorSpace,
        bitsPerComponent: result.bitsPerComponent,
        filter: result.filter,
        decodeParameters: result.decodeParameters,
        sMask: result.sMask,
        palette:
            result.palette == null ? null : Uint8List.fromList(result.palette!),
        transparency: result.mask,
        alias: imageAlias,
      )..index = result.index;
    } else if (imageType == 'BMP') {
      image = processBMP(bytes, _images.length + 1, imageAlias);
    } else {
      throw UnsupportedError('Unsupported image format: $imageType.');
    }

    _images.add(image);
    _imagesByAlias[imageAlias] = image;
    return image;
  }

  Uint8List _normalizeImageBytes(dynamic imageData) {
    final Uint8List? browserBytes = browser.extractImageBytes(imageData);
    if (browserBytes != null) {
      return browserBytes;
    }
    if (imageData is Uint8List) {
      return imageData;
    }
    if (imageData is ByteBuffer) {
      return Uint8List.view(imageData);
    }
    if (imageData is String) {
      final String? dataUrlPayload = extractImageFromDataUrl(imageData);
      if (dataUrlPayload != null) {
        return base64.decode(dataUrlPayload);
      }
      final String compact = imageData.replaceAll(RegExp(r'\s+'), '');
      if (validateStringAsBase64(compact)) {
        return base64.decode(compact);
      }
      return binaryStringToUint8Array(imageData);
    }
    throw ArgumentError.value(imageData, 'imageData',
        'Expected Uint8List, ByteBuffer, data URL, base64, or binary string.');
  }

  void _drawImage(
    PdfImage image,
    double x,
    double y,
    double width,
    double height, {
    double? sourceX,
    double? sourceY,
    double? sourceWidth,
    double? sourceHeight,
  }) {
    final double scaledX = x * _scaleFactor;
    final double scaledY = (getPageHeight() - y - height) * _scaleFactor;
    final double scaledWidth = width * _scaleFactor;
    final double scaledHeight = height * _scaleFactor;

    final bool crop = sourceX != null &&
        sourceY != null &&
        sourceWidth != null &&
        sourceHeight != null &&
        sourceWidth > 0 &&
        sourceHeight > 0;

    _doc.out('q');
    if (crop) {
      _doc.out(
          '${_hpf(scaledX)} ${_hpf(scaledY)} ${_hpf(scaledWidth)} ${_hpf(scaledHeight)} re W n');
      final double cropScaleX = width / sourceWidth;
      final double cropScaleY = height / sourceHeight;
      final double croppedWidth = image.width * cropScaleX * _scaleFactor;
      final double croppedHeight = image.height * cropScaleY * _scaleFactor;
      final double cropX = (x - sourceX * cropScaleX) * _scaleFactor;
      final double cropY =
          (getPageHeight() - y - height + (sourceY * cropScaleY)) *
              _scaleFactor;
      _doc.out(
          '${_hpf(croppedWidth)} 0 0 ${_hpf(croppedHeight)} ${_hpf(cropX)} ${_hpf(cropY)} cm');
    } else {
      _doc.out(
          '${_hpf(scaledWidth)} 0 0 ${_hpf(scaledHeight)} ${_hpf(scaledX)} ${_hpf(scaledY)} cm');
    }
    _doc.out('/I${image.index} Do');
    _doc.out('Q');
  }

  String _imageColorSpace(PdfImage image) {
    if (image.colorSpace == ColorSpaces.indexed && image.palette != null) {
      final int maxIndex = (image.palette!.length ~/ 3) - 1;
      final String paletteHex = image.palette!
          .map((int value) => value.toRadixString(16).padLeft(2, '0'))
          .join();
      return '[/Indexed /DeviceRGB $maxIndex <$paletteHex>]';
    }
    return '/${image.colorSpace}';
  }

  Object _getBlob(String data) => browser.createPdfBlob(_getArrayBuffer(data));

  List<int> _decodeFontFile(String file) {
    if (file.length >= 4 &&
        file.codeUnitAt(0) == 0x00 &&
        file.codeUnitAt(1) == 0x01 &&
        file.codeUnitAt(2) == 0x00 &&
        file.codeUnitAt(3) == 0x00) {
      return file.codeUnits.map((int codeUnit) => codeUnit & 0xff).toList();
    }
    return base64.decode(file.replaceAll(RegExp(r'\s+'), ''));
  }

  String _processTextLine(String line) {
    final PdfFont font = getFont();
    final TTFFont? ttfFont = font.metadata['ttf'] as TTFFont?;
    if (ttfFont != null && font.encoding == 'Identity-H') {
      return '<${pdfEscape16(line, ttfFont)}> Tj';
    }
    return '(${pdfEscape(line)}) Tj';
  }

  ByteBuffer _getArrayBuffer(String data) {
    final len = data.length;
    final ab = Uint8List(len);
    for (var i = 0; i < len; i++) {
      ab[i] = data.codeUnitAt(i) & 0xFF;
    }
    return ab.buffer;
  }

  // ==========================================================================
  // Internal API (para uso dos módulos/plugins)
  // ==========================================================================

  /// Acesso interno para os módulos.
  PdfDocumentBuilder get internal => _doc;
  PubSub get events => _events;
  double get scaleFactor => _scaleFactor;
  double get charSpace => _charSpace;
  String get textColor => _textColor;
  double get lineHeightFactor => _lineHeightFactor;

  /// Emite operadores PDF brutos na página atual.
  ///
  /// Usado por módulos portados que já produzem operadores PDF válidos.
  JsPdf addRawContent(String content) {
    _doc.out(content);
    return this;
  }
}
