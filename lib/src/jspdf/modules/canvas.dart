import 'context2d.dart';

/// jsPDF Canvas wrapper module — Dart port.
///
/// Provides a [PdfCanvas] class that mimics the HTML5 Canvas API surface
/// used by jsPDF's `canvas.js` plugin, allowing code written against the
/// browser canvas interface to target a PDF document instead.
///
/// Usage:
/// ```dart
/// final pdf = JsPdf();
/// final canvas = pdf.canvas;
/// final ctx = canvas.getContext('2d');   // returns pdf.context2d
/// ctx.fillText('Hello', 10, 20);
/// ```
///
/// Ported from modules/canvas.js of jsPDF.
class PdfCanvas {
  /// Back-reference to the owning PDF document.
  ///
  /// Must be set by [JsPdf] immediately after construction.
  late Context2D _context2d;

  int _width = 150;
  int _height = 300;
  final List<dynamic> _childNodes = [];
  final Map<String, dynamic> style = {};

  /// Width of the canvas in CSS pixels.
  ///
  /// Setting this to a non-positive integer resets to the default of 150.
  int get width => _width;
  set width(int value) {
    _width = (value <= 0) ? 150 : value;
  }

  /// Height of the canvas in CSS pixels.
  ///
  /// Setting this to a non-positive integer resets to the default of 300.
  int get height => _height;
  set height(int value) {
    _height = (value <= 0) ? 300 : value;
  }

  /// Child nodes (mirrors the HTML canvas `childNodes` property).
  List<dynamic> get childNodes => _childNodes;

  /// Returns the drawing context for the given [contextType].
  ///
  /// Only `'2d'` is supported; all other values return `null`.
  ///
  /// [contextAttributes] keys that match properties on [Context2D] are
  /// applied to the context before returning it.
  Context2D? getContext(
    String contextType, [
    Map<String, dynamic>? contextAttributes,
  ]) {
    if (contextType != '2d') return null;

    if (contextAttributes != null) {
      for (final entry in contextAttributes.entries) {
        _context2d.applyAttribute(entry.key, entry.value);
      }
    }

    return _context2d;
  }

  /// Not supported — always throws [UnsupportedError].
  String toDataURL([String type = 'image/png', dynamic encoderOptions]) {
    throw UnsupportedError('toDataURL is not implemented for PdfCanvas.');
  }

  /// Internal: called by [JsPdf] to wire up the context after construction.
  void attachContext(Context2D ctx) {
    _context2d = ctx;
  }
}
