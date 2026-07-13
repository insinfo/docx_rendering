/// Plugin Context2D — emula CanvasRenderingContext2D para geração de PDF.
///
/// Permite usar a API de Canvas 2D (moveTo, lineTo, arc, bezierCurveTo,
/// fillRect, stroke, fill, text, transform, etc.) para gerar conteúdo
/// PDF diretamente, sem precisar de um canvas HTML real.
///
/// Portado de modules/context2d.js do jsPDF (~2692 linhas).

import 'dart:math';
import '../gstate.dart';
import '../rgb_color.dart';
import '../matrix.dart';
import '../geometry.dart';
import '../utils.dart';

// ============================================================================
// ContextLayer — Estado do contexto gráfico
// ============================================================================

/// Estado de renderização salvo/restaurado via save()/restore().
class ContextLayer {
  bool isStrokeTransparent;
  double strokeOpacity;
  String strokeStyle;
  String fillStyle;
  bool isFillTransparent;
  double fillOpacity;
  String font;
  String? fontFamily;
  String fontStyle;
  String fontWeight;
  String textBaseline;
  String textAlign;
  double lineWidth;
  String lineJoin;
  String lineCap;
  List<Map<String, dynamic>> path;
  PdfMatrix transform;
  String globalCompositeOperation;
  double globalAlpha;
  List<Map<String, dynamic>> clipPath;
  PdfPoint currentPoint;
  double miterLimit;
  PdfPoint lastPoint;
  double lineDashOffset;
  List<double> lineDash;
  List<double> margin;
  double prevPageLastElemOffset;
  bool ignoreClearRect;
  double? fontSize;

  ContextLayer({
    ContextLayer? from,
  })  : isStrokeTransparent = from?.isStrokeTransparent ?? false,
        strokeOpacity = from?.strokeOpacity ?? 1,
        strokeStyle = from?.strokeStyle ?? '#000000',
        fillStyle = from?.fillStyle ?? '#000000',
        isFillTransparent = from?.isFillTransparent ?? false,
        fillOpacity = from?.fillOpacity ?? 1,
        font = from?.font ?? '10px sans-serif',
        fontFamily = from?.fontFamily,
        fontStyle = from?.fontStyle ?? 'normal',
        fontWeight = from?.fontWeight ?? 'normal',
        textBaseline = from?.textBaseline ?? 'alphabetic',
        textAlign = from?.textAlign ?? 'left',
        lineWidth = from?.lineWidth ?? 1,
        lineJoin = from?.lineJoin ?? 'miter',
        lineCap = from?.lineCap ?? 'butt',
        path = from?.path != null ? List.from(from!.path) : [],
        transform = from?.transform.clone() ?? PdfMatrix(1, 0, 0, 1, 0, 0),
        globalCompositeOperation = from?.globalCompositeOperation ?? 'normal',
        globalAlpha = from?.globalAlpha ?? 1.0,
        clipPath = from?.clipPath != null ? List.from(from!.clipPath) : [],
        currentPoint = from?.currentPoint ?? PdfPoint(0, 0),
        miterLimit = from?.miterLimit ?? 10.0,
        lastPoint = from?.lastPoint ?? PdfPoint(0, 0),
        lineDashOffset = from?.lineDashOffset ?? 0.0,
        lineDash = from?.lineDash != null ? List.from(from!.lineDash) : [],
        margin = from?.margin != null ? List.from(from!.margin) : [0, 0, 0, 0],
        prevPageLastElemOffset = from?.prevPageLastElemOffset ?? 0,
        ignoreClearRect = from?.ignoreClearRect ?? true;
}

// ============================================================================
// RGBA color helper
// ============================================================================

/// Resultado de parsing de cor CSS.
class RGBAColor {
  final int r, g, b;
  final double a;
  final String style;
  const RGBAColor(this.r, this.g, this.b, this.a, this.style);
}

/// Faz parsing de uma string de cor CSS (hex, rgb, rgba, named).
RGBAColor getRGBA(String style) {
  final rxRgb = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
  final rxRgba =
      RegExp(r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)');
  final rxTransparent =
      RegExp(r'transparent|rgba\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*0+\s*\)');

  if (style.isEmpty) return const RGBAColor(0, 0, 0, 0, '');

  if (rxTransparent.hasMatch(style)) {
    return RGBAColor(0, 0, 0, 0, style);
  }

  var match = rxRgb.firstMatch(style);
  if (match != null) {
    return RGBAColor(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      1,
      style,
    );
  }

  match = rxRgba.firstMatch(style);
  if (match != null) {
    return RGBAColor(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      double.parse(match.group(4)!),
      style,
    );
  }

  // Hex ou named color
  var hex = style;
  if (!hex.startsWith('#')) {
    final rgb = RGBColor(hex);
    hex = rgb.ok ? rgb.toHex() : '#000000';
  }
  int r, g, b;
  if (hex.length == 4) {
    r = int.parse('${hex[1]}${hex[1]}', radix: 16);
    g = int.parse('${hex[2]}${hex[2]}', radix: 16);
    b = int.parse('${hex[3]}${hex[3]}', radix: 16);
  } else {
    r = int.parse(hex.substring(1, 3), radix: 16);
    g = int.parse(hex.substring(3, 5), radix: 16);
    b = int.parse(hex.substring(5, 7), radix: 16);
  }
  return RGBAColor(r, g, b, 1, hex);
}

/// Converte radianos para graus.
double rad2deg(double rad) => rad * 180 / pi;

// ============================================================================
// Mapa de fallback de fontes
// ============================================================================

/// Mapa de nomes de fontes CSS → nomes PDF padrão.
const fallbackFonts = <String, String>{
  'arial': 'Helvetica',
  'Arial': 'Helvetica',
  'verdana': 'Helvetica',
  'Verdana': 'Helvetica',
  'helvetica': 'Helvetica',
  'Helvetica': 'Helvetica',
  'sans-serif': 'Helvetica',
  'fixed': 'Courier',
  'monospace': 'Courier',
  'terminal': 'Courier',
  'cursive': 'Times',
  'fantasy': 'Times',
  'serif': 'Times',
};

// ============================================================================
// TextMetrics
// ============================================================================

/// Resultado de measureText().
class Context2dTextMetrics {
  final double width;
  final double actualBoundingBoxAscent;
  final double actualBoundingBoxDescent;
  final double fontBoundingBoxAscent;
  final double fontBoundingBoxDescent;

  const Context2dTextMetrics(
    this.width, {
    this.actualBoundingBoxAscent = 0,
    this.actualBoundingBoxDescent = 0,
    this.fontBoundingBoxAscent = 0,
    this.fontBoundingBoxDescent = 0,
  });
}

// ============================================================================
// Context2D — Classe principal
// ============================================================================

/// Emulação de CanvasRenderingContext2D para geração de PDF.
///
/// Implementa as operações de drawing da API Canvas 2D
/// (path, fill, stroke, text, transformations, clipping)
/// gerando operadores PDF na saída.
class Context2D {
  /// Referência ao documento PDF (genérica, para desacoplamento).
  final dynamic pdf;

  /// Estado do contexto gráfico.
  ContextLayer _ctx;

  /// Pilha de estados salvos.
  final List<ContextLayer> _ctxStack = [];

  // Paginação automática
  bool pageWrapXEnabled = false;
  bool pageWrapYEnabled = false;
  double posX = 0;
  double posY = 0;
  dynamic autoPaging = false;
  double lastBreak = 0;
  List<double> pageBreaks = [];
  List<dynamic>? fontFaces;

  Context2D(this.pdf) : _ctx = ContextLayer();

  /// Contexto atual.
  ContextLayer get ctx => _ctx;

  /// Path atual.
  List<Map<String, dynamic>> get path => _ctx.path;
  set path(List<Map<String, dynamic>> v) => _ctx.path = v;

  // ---- Style properties ----

  String get fillStyle => _ctx.fillStyle;
  set fillStyle(String value) {
    final rgba = getRGBA(value);
    _ctx.fillStyle = rgba.style;
    _ctx.isFillTransparent = rgba.a == 0;
    _ctx.fillOpacity = rgba.a;
  }

  String get strokeStyle => _ctx.strokeStyle;
  set strokeStyle(String value) {
    final rgba = getRGBA(value);
    _ctx.strokeStyle = rgba.style;
    _ctx.isStrokeTransparent = rgba.a == 0;
    _ctx.strokeOpacity = rgba.a;
  }

  String get lineCap => _ctx.lineCap;
  set lineCap(String value) {
    if (['butt', 'round', 'square'].contains(value)) _ctx.lineCap = value;
  }

  double get lineWidth => _ctx.lineWidth;
  set lineWidth(double value) {
    if (!value.isNaN) _ctx.lineWidth = value;
  }

  String get lineJoin => _ctx.lineJoin;
  set lineJoin(String value) {
    if (['bevel', 'round', 'miter'].contains(value)) _ctx.lineJoin = value;
  }

  double get miterLimit => _ctx.miterLimit;
  set miterLimit(double value) {
    if (!value.isNaN) _ctx.miterLimit = value;
  }

  String get textBaseline => _ctx.textBaseline;
  set textBaseline(String value) => _ctx.textBaseline = value;

  String get textAlign => _ctx.textAlign;
  set textAlign(String value) {
    if (['right', 'end', 'center', 'left', 'start'].contains(value)) {
      _ctx.textAlign = value;
    }
  }

  String get font => _ctx.font;
  set font(String value) {
    _ctx.font = value;
    final parsed = _parseCssFont(value);
    if (parsed == null) return;
    _ctx.fontSize = parsed.size;
    _ctx.fontFamily = parsed.family;
    _ctx.fontStyle = parsed.style;
    _ctx.fontWeight = parsed.weight;
  }

  String get globalCompositeOperation => _ctx.globalCompositeOperation;
  set globalCompositeOperation(String value) =>
      _ctx.globalCompositeOperation = value;

  double get globalAlpha => _ctx.globalAlpha;
  set globalAlpha(double value) => _ctx.globalAlpha = value;

  double get lineDashOffset => _ctx.lineDashOffset;
  set lineDashOffset(double value) => _ctx.lineDashOffset = value;

  List<double> get lineDash => _ctx.lineDash;
  set lineDash(List<double> value) => _ctx.lineDash = value;

  bool get ignoreClearRect => _ctx.ignoreClearRect;
  set ignoreClearRect(bool value) => _ctx.ignoreClearRect = value;

  List<double> get margin => _ctx.margin;
  set margin(dynamic value) {
    if (value is num) {
      _ctx.margin = [
        value.toDouble(),
        value.toDouble(),
        value.toDouble(),
        value.toDouble()
      ];
    } else if (value is List) {
      final m = List<double>.filled(4, 0);
      m[0] = (value[0] as num).toDouble();
      m[1] = value.length >= 2 ? (value[1] as num).toDouble() : m[0];
      m[2] = value.length >= 3 ? (value[2] as num).toDouble() : m[0];
      m[3] = value.length >= 4 ? (value[3] as num).toDouble() : m[1];
      _ctx.margin = m;
    }
  }

  // ---- Line dash ----

  void setLineDash(List<double> dashArray) => lineDash = dashArray;

  List<double> getLineDash() {
    if (lineDash.length % 2 != 0) return [...lineDash, ...lineDash];
    return List.from(lineDash);
  }

  // ---- Path operations ----

  void beginPath() {
    path = [
      {'type': 'begin'}
    ];
  }

  void moveTo(double x, double y) {
    if (x.isNaN || y.isNaN) throw ArgumentError('Invalid moveTo arguments');
    final pt = _ctx.transform.applyToPoint(PdfPoint(x, y));
    path.add({'type': 'mt', 'x': pt.x, 'y': pt.y});
    _ctx.lastPoint = PdfPoint(x, y);
  }

  void lineTo(double x, double y) {
    if (x.isNaN || y.isNaN) throw ArgumentError('Invalid lineTo arguments');
    final pt = _ctx.transform.applyToPoint(PdfPoint(x, y));
    path.add({'type': 'lt', 'x': pt.x, 'y': pt.y});
    _ctx.lastPoint = PdfPoint(pt.x, pt.y);
  }

  void closePath() {
    var pathBegin = PdfPoint(0, 0);
    for (var i = path.length - 1; i >= 0; i--) {
      if (path[i]['type'] == 'begin') {
        if (i + 1 < path.length && path[i + 1]['x'] is num) {
          pathBegin = PdfPoint(
            (path[i + 1]['x'] as num).toDouble(),
            (path[i + 1]['y'] as num).toDouble(),
          );
        }
        break;
      }
    }
    path.add({'type': 'close'});
    _ctx.lastPoint = pathBegin;
  }

  void quadraticCurveTo(double cpx, double cpy, double x, double y) {
    if (x.isNaN || y.isNaN || cpx.isNaN || cpy.isNaN) {
      throw ArgumentError('Invalid quadraticCurveTo arguments');
    }
    final pt0 = _ctx.transform.applyToPoint(PdfPoint(x, y));
    final pt1 = _ctx.transform.applyToPoint(PdfPoint(cpx, cpy));
    path.add({'type': 'qct', 'x1': pt1.x, 'y1': pt1.y, 'x': pt0.x, 'y': pt0.y});
    _ctx.lastPoint = PdfPoint(pt0.x, pt0.y);
  }

  void bezierCurveTo(
      double cp1x, double cp1y, double cp2x, double cp2y, double x, double y) {
    final pt0 = _ctx.transform.applyToPoint(PdfPoint(x, y));
    final pt1 = _ctx.transform.applyToPoint(PdfPoint(cp1x, cp1y));
    final pt2 = _ctx.transform.applyToPoint(PdfPoint(cp2x, cp2y));
    path.add({
      'type': 'bct',
      'x1': pt1.x,
      'y1': pt1.y,
      'x2': pt2.x,
      'y2': pt2.y,
      'x': pt0.x,
      'y': pt0.y,
    });
    _ctx.lastPoint = PdfPoint(pt0.x, pt0.y);
  }

  void arc(
      double x, double y, double radius, double startAngle, double endAngle,
      [bool counterclockwise = false]) {
    if (!_ctx.transform.isIdentity) {
      final xpt = _ctx.transform.applyToPoint(PdfPoint(x, y));
      x = xpt.x;
      y = xpt.y;
      final radPt = _ctx.transform.applyToPoint(PdfPoint(0, radius));
      final radPt0 = _ctx.transform.applyToPoint(PdfPoint(0, 0));
      radius = sqrt(pow(radPt.x - radPt0.x, 2) + pow(radPt.y - radPt0.y, 2));
    }
    if ((endAngle - startAngle).abs() >= 2 * pi) {
      startAngle = 0;
      endAngle = 2 * pi;
    }
    path.add({
      'type': 'arc',
      'x': x,
      'y': y,
      'radius': radius,
      'startAngle': startAngle,
      'endAngle': endAngle,
      'counterclockwise': counterclockwise,
    });
  }

  void rect(double x, double y, double w, double h) {
    moveTo(x, y);
    lineTo(x + w, y);
    lineTo(x + w, y + h);
    lineTo(x, y + h);
    lineTo(x, y);
    lineTo(x + w, y);
    lineTo(x, y);
  }

  // ---- Drawing operations ----

  bool get _isFillTransparent => _ctx.isFillTransparent || globalAlpha == 0;
  bool get _isStrokeTransparent => _ctx.isStrokeTransparent || globalAlpha == 0;

  void fill() => _pathPreProcess('fill');
  void stroke() => _pathPreProcess('stroke');
  void clip() {
    _ctx.clipPath = List.from(path.map((e) => Map<String, dynamic>.from(e)));
    _pathPreProcess(null, isClip: true);
  }

  void fillRect(double x, double y, double w, double h) {
    if (_isFillTransparent) return;
    final savedLineCap = lineCap;
    final savedLineJoin = lineJoin;
    lineCap = 'butt';
    lineJoin = 'miter';
    beginPath();
    rect(x, y, w, h);
    fill();
    lineCap = savedLineCap;
    lineJoin = savedLineJoin;
  }

  void strokeRect(double x, double y, double w, double h) {
    if (_isStrokeTransparent) return;
    beginPath();
    rect(x, y, w, h);
    stroke();
  }

  void clearRect(double x, double y, double w, double h) {
    if (ignoreClearRect) return;
    fillStyle = '#ffffff';
    fillRect(x, y, w, h);
  }

  // ---- Text ----

  void fillText(String text, double x, double y, [double? maxWidth]) {
    if (_isFillTransparent) return;
    _putText(text: text, x: x, y: y, maxWidth: maxWidth, renderingMode: 'fill');
  }

  void strokeText(String text, double x, double y, [double? maxWidth]) {
    if (_isStrokeTransparent) return;
    _putText(
        text: text, x: x, y: y, maxWidth: maxWidth, renderingMode: 'stroke');
  }

  Context2dTextMetrics measureText(String text) {
    final fontSize = _ctx.fontSize ?? _parseFontSizeFromFont(_ctx.font) ?? 10.0;
    final metrics = _callPdf('measureTextMetrics', <dynamic>[
      text,
      _ctx.fontFamily ?? _parseFontFamily(_ctx.font) ?? 'helvetica',
      _fontStyleForPdf(),
      fontSize,
    ]);

    if (metrics is Map) {
      return Context2dTextMetrics(
        _asDouble(metrics['width'], text.length * fontSize * 0.5),
        actualBoundingBoxAscent:
            _asDouble(metrics['actualBoundingBoxAscent'], fontSize * 0.8),
        actualBoundingBoxDescent:
            _asDouble(metrics['actualBoundingBoxDescent'], fontSize * 0.2),
        fontBoundingBoxAscent:
            _asDouble(metrics['fontBoundingBoxAscent'], fontSize * 0.8),
        fontBoundingBoxDescent:
            _asDouble(metrics['fontBoundingBoxDescent'], fontSize * 0.2),
      );
    }

    return Context2dTextMetrics(
      text.length * fontSize * 0.5,
      actualBoundingBoxAscent: fontSize * 0.8,
      actualBoundingBoxDescent: fontSize * 0.2,
      fontBoundingBoxAscent: fontSize * 0.8,
      fontBoundingBoxDescent: fontSize * 0.2,
    );
  }

  // ---- Transformations ----

  void scale(double scaleWidth, double scaleHeight) {
    final m = PdfMatrix(scaleWidth, 0, 0, scaleHeight, 0, 0);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  void rotate(double angle) {
    final m = PdfMatrix(cos(angle), sin(angle), -sin(angle), cos(angle), 0, 0);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  void translate(double x, double y) {
    final m = PdfMatrix(1, 0, 0, 1, x, y);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  void setTransformValues(
      double a, double b, double c, double d, double e, double f) {
    _ctx.transform = PdfMatrix(a, b, c, d, e, f);
  }

  void applyTransform(
      double a, double b, double c, double d, double e, double f) {
    final m = PdfMatrix(a, b, c, d, e, f);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  // ---- Save/Restore ----

  void save([bool doStackPush = true]) {
    if (doStackPush) {
      _ctxStack.add(_ctx);
      _ctx = ContextLayer(from: _ctx);
    }
  }

  void restore([bool doStackPop = true]) {
    if (doStackPop && _ctxStack.isNotEmpty) {
      _ctx = _ctxStack.removeLast();
    }
  }

  // ---- Image ----

  /// Draws an image (placeholder signature matching Canvas API).
  void drawImage(dynamic img,
      [double? sx,
      double? sy,
      double? swidth,
      double? sheight,
      double? dx,
      double? dy,
      double? dwidth,
      double? dheight]) {
    double targetX;
    double targetY;
    double targetWidth;
    double targetHeight;

    if (dx != null && dy != null && dwidth != null && dheight != null) {
      targetX = dx;
      targetY = dy;
      targetWidth = dwidth;
      targetHeight = dheight;
    } else if (sx != null && sy != null && swidth != null && sheight != null) {
      targetX = sx;
      targetY = sy;
      targetWidth = swidth;
      targetHeight = sheight;
    } else {
      throw ArgumentError('drawImage requires x, y, width and height.');
    }

    if (dx != null && dy != null && dwidth != null && dheight != null) {
      _callPdf('addImage', <dynamic>[
        img,
        targetX,
        targetY,
        targetWidth,
        targetHeight,
        null,
        sx,
        sy,
        swidth,
        sheight,
      ]);
    } else {
      _callPdf('addImage',
          <dynamic>[img, targetX, targetY, targetWidth, targetHeight]);
    }
  }

  // ---- Create gradient/pattern (stubs) ----

  dynamic createLinearGradient(double x0, double y0, double x1, double y1) =>
      null;
  dynamic createRadialGradient(
          double x0, double y0, double r0, double x1, double y1, double r1) =>
      null;
  dynamic createPattern(dynamic image, String repetition) => null;

  // ---- Private internals ----

  void _pathPreProcess(String? rule, {bool isClip = false}) {
    if (path.isEmpty) return;

    _applyOpacity(rule);

    final operators = <String>['q'];
    operators.addAll(_styleOperators(rule));
    operators.addAll(_pathOperators(path));
    if (isClip) {
      operators.add('W');
      operators.add('n');
    } else {
      operators.add(_paintOperator(rule));
    }
    operators.add('Q');
    _emitRaw(operators.join('\n'));
  }

  void _putText({
    required String text,
    required double x,
    required double y,
    double? maxWidth,
    String renderingMode = 'fill',
  }) {
    final point = _ctx.transform.applyToPoint(PdfPoint(x, y));
    final color =
        renderingMode == 'stroke' ? getRGBA(strokeStyle) : getRGBA(fillStyle);
    _callPdf('setTextColor', <dynamic>[color.r, color.g, color.b]);
    _applyOpacity(renderingMode);

    final fontSize = _ctx.fontSize ?? _parseFontSizeFromFont(_ctx.font);
    if (fontSize != null) {
      _callPdf('setFontSize', <dynamic>[fontSize]);
    }

    final family = _ctx.fontFamily ?? _parseFontFamily(_ctx.font);
    if (family != null) {
      _callPdf('setFont', <dynamic>[fallbackFonts[family] ?? family],
          <Symbol, dynamic>{#fontStyle: _fontStyleForPdf()});
    }

    _callPdf('text', <dynamic>[
      text,
      point.x,
      point.y
    ], <Symbol, dynamic>{
      if (maxWidth != null) #maxWidth: maxWidth,
      if (textAlign == 'center' || textAlign == 'right') #align: textAlign,
    });
  }

  List<String> _styleOperators(String? rule) {
    final operators = <String>[
      '${_format(lineWidth)} w',
      '${_lineCapCode(lineCap)} J',
      '${_lineJoinCode(lineJoin)} j',
      '${_format(miterLimit)} M',
    ];

    final dash = getLineDash();
    if (dash.isEmpty) {
      operators.add('[] ${_format(lineDashOffset)} d');
    } else {
      operators
          .add('[${dash.map(_format).join(' ')}] ${_format(lineDashOffset)} d');
    }

    if (rule == 'fill' || rule == null) {
      final color = getRGBA(fillStyle);
      operators.add(
          '${_formatColor(color.r)} ${_formatColor(color.g)} ${_formatColor(color.b)} rg');
    }
    if (rule == 'stroke' || rule == null) {
      final color = getRGBA(strokeStyle);
      operators.add(
          '${_formatColor(color.r)} ${_formatColor(color.g)} ${_formatColor(color.b)} RG');
    }
    return operators;
  }

  List<String> _pathOperators(List<Map<String, dynamic>> sourcePath) {
    final operators = <String>[];
    PdfPoint current = PdfPoint(0, 0);

    for (final element in sourcePath) {
      final type = element['type'] as String?;
      switch (type) {
        case 'begin':
          break;
        case 'mt':
          current = _pointFromElement(element);
          operators.add('${_format(current.x)} ${_format(_pdfY(current.y))} m');
          break;
        case 'lt':
          current = _pointFromElement(element);
          operators.add('${_format(current.x)} ${_format(_pdfY(current.y))} l');
          break;
        case 'close':
          operators.add('h');
          break;
        case 'bct':
          final cp1 = PdfPoint((element['x1'] as num).toDouble(),
              (element['y1'] as num).toDouble());
          final cp2 = PdfPoint((element['x2'] as num).toDouble(),
              (element['y2'] as num).toDouble());
          final end = _pointFromElement(element);
          operators.add(
            '${_format(cp1.x)} ${_format(_pdfY(cp1.y))} '
            '${_format(cp2.x)} ${_format(_pdfY(cp2.y))} '
            '${_format(end.x)} ${_format(_pdfY(end.y))} c',
          );
          current = end;
          break;
        case 'qct':
          final control = PdfPoint((element['x1'] as num).toDouble(),
              (element['y1'] as num).toDouble());
          final end = _pointFromElement(element);
          final cp1 = PdfPoint(
            current.x + (control.x - current.x) * 2 / 3,
            current.y + (control.y - current.y) * 2 / 3,
          );
          final cp2 = PdfPoint(
            end.x + (control.x - end.x) * 2 / 3,
            end.y + (control.y - end.y) * 2 / 3,
          );
          operators.add(
            '${_format(cp1.x)} ${_format(_pdfY(cp1.y))} '
            '${_format(cp2.x)} ${_format(_pdfY(cp2.y))} '
            '${_format(end.x)} ${_format(_pdfY(end.y))} c',
          );
          current = end;
          break;
        case 'arc':
          final arcOperators = _arcOperators(element, current);
          operators.addAll(arcOperators.operators);
          current = arcOperators.endPoint;
          break;
      }
    }

    return operators;
  }

  _ArcOperators _arcOperators(Map<String, dynamic> element, PdfPoint current) {
    final x = (element['x'] as num).toDouble();
    final y = (element['y'] as num).toDouble();
    final radius = (element['radius'] as num).toDouble();
    final startAngle = (element['startAngle'] as num).toDouble();
    final endAngle = (element['endAngle'] as num).toDouble();
    final counterclockwise = element['counterclockwise'] == true;

    double sweep = endAngle - startAngle;
    if (!counterclockwise && sweep < 0) sweep += 2 * pi;
    if (counterclockwise && sweep > 0) sweep -= 2 * pi;

    final segments = max(1, (sweep.abs() / (pi / 2)).ceil());
    final delta = sweep / segments;
    final start =
        PdfPoint(x + cos(startAngle) * radius, y + sin(startAngle) * radius);
    final operators = <String>[];
    if ((current.x - start.x).abs() > 0.0001 ||
        (current.y - start.y).abs() > 0.0001) {
      operators.add('${_format(start.x)} ${_format(_pdfY(start.y))} m');
    }

    double angle = startAngle;
    PdfPoint endPoint = start;
    for (int i = 0; i < segments; i++) {
      final nextAngle = angle + delta;
      final k = 4 / 3 * tan((nextAngle - angle) / 4);
      final cp1 = PdfPoint(
        x + radius * (cos(angle) - k * sin(angle)),
        y + radius * (sin(angle) + k * cos(angle)),
      );
      final cp2 = PdfPoint(
        x + radius * (cos(nextAngle) + k * sin(nextAngle)),
        y + radius * (sin(nextAngle) - k * cos(nextAngle)),
      );
      endPoint =
          PdfPoint(x + cos(nextAngle) * radius, y + sin(nextAngle) * radius);
      operators.add(
        '${_format(cp1.x)} ${_format(_pdfY(cp1.y))} '
        '${_format(cp2.x)} ${_format(_pdfY(cp2.y))} '
        '${_format(endPoint.x)} ${_format(_pdfY(endPoint.y))} c',
      );
      angle = nextAngle;
    }

    return _ArcOperators(operators, endPoint);
  }

  String _paintOperator(String? rule) {
    if (rule == 'fill') return 'f';
    if (rule == 'stroke') return 'S';
    return 'B';
  }

  PdfPoint _pointFromElement(Map<String, dynamic> element) => PdfPoint(
        (element['x'] as num).toDouble(),
        (element['y'] as num).toDouble(),
      );

  double _pdfY(double y) {
    final height = _callPdf('getPageHeight', const <dynamic>[]);
    if (height is num) return height.toDouble() - y;
    return y;
  }

  void _emitRaw(String content) {
    final result = _callPdf('addRawContent', <dynamic>[content]);
    if (result == null) {
      _callPdf('internal.out', <dynamic>[content]);
    }
  }

  dynamic _callPdf(String method, List<dynamic> positional,
      [Map<Symbol, dynamic>? named]) {
    try {
      switch (method) {
        case 'addRawContent':
          return Function.apply(pdf.addRawContent, positional);
        case 'getPageHeight':
          return Function.apply(pdf.getPageHeight, positional);
        case 'setTextColor':
          return Function.apply(pdf.setTextColor, positional);
        case 'setFontSize':
          return Function.apply(pdf.setFontSize, positional);
        case 'setFont':
          return Function.apply(
              pdf.setFont, positional, named ?? const <Symbol, dynamic>{});
        case 'setGState':
          return Function.apply(pdf.setGState, positional);
        case 'text':
          return Function.apply(
              pdf.text, positional, named ?? const <Symbol, dynamic>{});
        case 'addImage':
          return Function.apply(pdf.addImage, positional);
        case 'measureTextMetrics':
          return Function.apply(pdf.measureTextMetrics, positional);
        case 'internal.out':
          return Function.apply(pdf.internal.out, positional);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _applyOpacity(String? rule) {
    final double fillAlpha = (_ctx.fillOpacity * globalAlpha).clamp(0.0, 1.0);
    final double strokeAlpha =
        (_ctx.strokeOpacity * globalAlpha).clamp(0.0, 1.0);
    if (fillAlpha == 1.0 && strokeAlpha == 1.0) {
      return;
    }
    _callPdf('setGState', <dynamic>[
      GState(
        opacity: rule == 'stroke' ? null : fillAlpha,
        strokeOpacity: rule == 'fill' ? null : strokeAlpha,
      ),
    ]);
  }

  int _lineCapCode(String cap) {
    if (cap == 'round') return 1;
    if (cap == 'square') return 2;
    return 0;
  }

  int _lineJoinCode(String join) {
    if (join == 'round') return 1;
    if (join == 'bevel') return 2;
    return 0;
  }

  double? _parseFontSizeFromFont(String value) {
    final match = RegExp(r'(\d+(?:\.\d+)?)(px|pt)?').firstMatch(value);
    if (match == null) return null;
    return _parseCssFontSize(match.group(0)!);
  }

  _ParsedCssFont? _parseCssFont(String value) {
    final sizeMatch = RegExp(
      r'(xx-small|x-small|small|medium|large|x-large|xx-large|smaller|larger|\d+(?:\.\d+)?(?:%|in|cm|mm|em|rem|ex|pt|pc|px))',
      caseSensitive: false,
    ).firstMatch(value);
    if (sizeMatch == null) return null;

    final beforeSize = value.substring(0, sizeMatch.start).toLowerCase();
    String afterSize = value.substring(sizeMatch.end).trim();
    if (afterSize.startsWith('/')) {
      final lineHeightEnd = afterSize.indexOf(RegExp(r'\s'));
      afterSize =
          lineHeightEnd < 0 ? '' : afterSize.substring(lineHeightEnd).trim();
    }

    final style =
        beforeSize.contains('italic') || beforeSize.contains('oblique')
            ? 'italic'
            : 'normal';
    final weightMatch =
        RegExp(r'\b(bold(?:er)?|lighter|[1-9]00)\b').firstMatch(beforeSize);
    final weight = weightMatch?.group(1) ?? 'normal';
    final family = _firstFontFamily(afterSize) ?? 'sans-serif';
    return _ParsedCssFont(
      size: _parseCssFontSize(sizeMatch.group(0)!),
      family: family,
      style: style,
      weight: weight,
    );
  }

  double _parseCssFontSize(String value) {
    final normalized = value.toLowerCase();
    const namedSizes = <String, double>{
      'xx-small': 6.75,
      'x-small': 7.5,
      'small': 9.75,
      'medium': 12,
      'large': 13.5,
      'x-large': 18,
      'xx-large': 24,
      'smaller': 9.75,
      'larger': 13.5,
    };
    final named = namedSizes[normalized];
    if (named != null) return named;

    final match = RegExp(r'(\d+(?:\.\d+)?)(%|in|cm|mm|em|rem|ex|pt|pc|px)?')
        .firstMatch(value);
    if (match == null) return 10.0;
    final amount = double.parse(match.group(1)!);
    switch (match.group(2)) {
      case 'pt':
        return amount;
      case 'in':
        return amount * 72;
      case 'cm':
        return amount * 72 / 2.54;
      case 'mm':
        return amount * 72 / 25.4;
      case 'pc':
        return amount * 12;
      case 'em':
      case 'rem':
        return amount * 12;
      case 'ex':
        return amount * 6;
      case '%':
        return amount * 12 / 100;
      case 'px':
      default:
        return amount * 72 / 96;
    }
  }

  String? _parseFontFamily(String value) {
    final parsed = _parseCssFont(value);
    if (parsed != null) return parsed.family;
    final parts = value.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    return _cleanFontFamily(parts.last);
  }

  String? _firstFontFamily(String value) {
    if (value.trim().isEmpty) return null;
    final families = value.split(',');
    return _cleanFontFamily(families.first);
  }

  String _cleanFontFamily(String value) {
    return value.trim().replaceAll('"', '').replaceAll("'", '').toLowerCase();
  }

  String _fontStyleForPdf() {
    final bool italic =
        _ctx.fontStyle == 'italic' || _ctx.fontStyle == 'oblique';
    final bool bold = _ctx.fontWeight == 'bold' ||
        _ctx.fontWeight == 'bolder' ||
        (int.tryParse(_ctx.fontWeight) ?? 400) >= 600;
    if (bold && italic) return 'bolditalic';
    if (bold) return 'bold';
    if (italic) return 'italic';
    return 'normal';
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  String _format(num value) =>
      roundToPrecision(value, 4).replaceAll(RegExp(r'\.$'), '');

  String _formatColor(int channel) => _format(channel / 255);

  /// Sets a property on this context by name.
  ///
  /// Used by [PdfCanvas.getContext] to apply `contextAttributes` entries.
  /// Unknown property names are silently ignored.
  void applyAttribute(String key, dynamic value) {
    switch (key) {
      case 'fillStyle':
        if (value is String) fillStyle = value;
        break;
      case 'strokeStyle':
        if (value is String) strokeStyle = value;
        break;
      case 'lineWidth':
        if (value is num) lineWidth = value.toDouble();
        break;
      case 'font':
        if (value is String) font = value;
        break;
      case 'globalAlpha':
        if (value is num) globalAlpha = value.toDouble();
        break;
      case 'textAlign':
        if (value is String) textAlign = value;
        break;
      case 'textBaseline':
        if (value is String) textBaseline = value;
        break;
      case 'lineCap':
        if (value is String) lineCap = value;
        break;
      case 'lineJoin':
        if (value is String) lineJoin = value;
        break;
      case 'miterLimit':
        if (value is num) miterLimit = value.toDouble();
        break;
      case 'ignoreClearRect':
        if (value is bool) ignoreClearRect = value;
        break;
      // Additional known properties can be added here.
    }
  }
}

class _ArcOperators {
  final List<String> operators;
  final PdfPoint endPoint;

  const _ArcOperators(this.operators, this.endPoint);
}

class _ParsedCssFont {
  final double size;
  final String family;
  final String style;
  final String weight;

  const _ParsedCssFont({
    required this.size,
    required this.family,
    required this.style,
    required this.weight,
  });
}
