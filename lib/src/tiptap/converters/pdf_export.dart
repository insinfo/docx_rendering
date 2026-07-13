/// Exportação PDF vetorial do AST ProseMirror, sem dependências de runtime.
///
/// O gerador usa as fontes base do PDF (Helvetica, Times e Courier), portanto
/// texto permanece selecionável e não há custo de embedding para documentos
/// que não exigem uma fonte customizada. [PdfLayoutPlan] permite reutilizar a
/// geometria medida pela UI; sem plano, um layout determinístico é calculado.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../prosemirror/model/index.dart' as model;
import '../../jspdf/jspdf.dart';
import '../../jspdf/modules/standard_fonts_metrics.dart';

typedef PdfExportProgress = void Function(int done, int total);

class PdfPageFormat {
  final double width;
  final double height;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;

  const PdfPageFormat({
    this.width = 595.28,
    this.height = 841.89,
    this.marginTop = 72,
    this.marginRight = 72,
    this.marginBottom = 72,
    this.marginLeft = 72,
  });
}

/// Geometria pronta, normalmente capturada durante a paginação da UI.
class PdfLayoutPlan {
  final List<PdfLayoutPage> pages;
  const PdfLayoutPlan(this.pages);
}

class PdfLayoutPage {
  final List<PdfLayoutItem> items;
  const PdfLayoutPage(this.items);
}

sealed class PdfLayoutItem {
  const PdfLayoutItem();
}

class PdfTextItem extends PdfLayoutItem {
  final String text;
  final double x;
  final double y;
  final double fontSize;
  final bool bold;
  final bool italic;
  final String? color;
  final String? fontFamily;

  const PdfTextItem(this.text, this.x, this.y,
      {this.fontSize = 11,
      this.bold = false,
      this.italic = false,
      this.color,
      this.fontFamily});
}

class PdfImageItem extends PdfLayoutItem {
  /// `Uint8List`, data URI ou string base64 aceita pelo porte jsPDF.
  final Object data;
  final double x, y, width, height;
  final String? format;
  final String? alias;

  const PdfImageItem(this.data, this.x, this.y, this.width, this.height,
      {this.format, this.alias});
}

class PdfLineItem extends PdfLayoutItem {
  final double x1, y1, x2, y2;
  final double width;
  const PdfLineItem(this.x1, this.y1, this.x2, this.y2, {this.width = .5});
}

class PdfRectItem extends PdfLayoutItem {
  final double x, y, width, height;
  final double strokeWidth;
  const PdfRectItem(this.x, this.y, this.width, this.height,
      {this.strokeWidth = .5});
}

/// Uma variante TTF registrada uma vez no documento e subsetada pelo jsPDF.
class PdfFontAsset {
  final String family;
  final String style;
  final Uint8List bytes;
  final String filename;

  const PdfFontAsset(this.family, this.bytes,
      {this.style = 'normal', this.filename = 'font.ttf'});
}

class PdfExporter {
  final PdfPageFormat pageFormat;
  final PdfExportProgress? onProgress;
  final List<PdfFontAsset> fonts;
  final int layoutChunkSize;

  const PdfExporter({
    this.pageFormat = const PdfPageFormat(),
    this.onProgress,
    this.fonts = const [],
    this.layoutChunkSize = 50,
  });

  Future<Uint8List> export(model.PMNode pmDoc, {PdfLayoutPlan? layout}) async {
    final pages = layout ??
        await _FallbackLayout(pageFormat)
            .layoutAsync(pmDoc, chunkSize: layoutChunkSize);
    final pdf = JsPdf(JsPdfOptions(
      unit: 'pt',
      format: [pageFormat.width, pageFormat.height],
      putOnlyUsedFonts: true,
      fontSize: 11,
    ));
    final registeredFonts = <String, Set<String>>{};
    for (var i = 0; i < fonts.length; i++) {
      final font = fonts[i];
      final filename = '${i + 1}-${font.filename}';
      pdf
        ..addFileToVFS(filename, base64.encode(font.bytes))
        ..addFont(filename, font.family, fontStyle: font.style);
      registeredFonts
          .putIfAbsent(font.family.toLowerCase(), () => <String>{})
          .add(font.style.toLowerCase());
    }

    final pageList = pages.pages.isEmpty
        ? const <PdfLayoutPage>[PdfLayoutPage([])]
        : pages.pages;
    for (var i = 0; i < pageList.length; i++) {
      if (i > 0) pdf.addPage([pageFormat.width, pageFormat.height]);
      _renderPage(pdf, pageList[i], registeredFonts);
      onProgress?.call(i + 1, pageList.length);
      // Uma página por volta do event loop: permite paint/input entre páginas.
      await Future<void>.delayed(Duration.zero);
    }
    return Uint8List.view(pdf.output('arraybuffer') as ByteBuffer);
  }

  void _renderPage(
      JsPdf pdf, PdfLayoutPage page, Map<String, Set<String>> registeredFonts) {
    for (final item in page.items) {
      switch (item) {
        case PdfTextItem():
          final style = item.bold
              ? (item.italic ? 'bolditalic' : 'bold')
              : (item.italic ? 'italic' : 'normal');
          final requested = item.fontFamily?.toLowerCase();
          final custom =
              requested != null && registeredFonts.containsKey(requested);
          final family = custom ? requested : _baseFontFamily(requested);
          final availableStyles = registeredFonts[family];
          final resolvedStyle =
              availableStyles == null || availableStyles.contains(style)
                  ? style
                  : availableStyles.contains('normal')
                      ? 'normal'
                      : availableStyles.first;
          pdf
            ..setFont(family, fontStyle: resolvedStyle)
            ..setFontSize(item.fontSize)
            ..setTextColor(item.color ?? '#000000')
            ..text(custom ? item.text : _winAnsi(item.text), item.x, item.y);
        case PdfLineItem():
          pdf
            ..setLineWidth(item.width)
            ..line(item.x1, item.y1, item.x2, item.y2);
        case PdfRectItem():
          pdf
            ..setLineWidth(item.strokeWidth)
            ..rect(item.x, item.y, item.width, item.height);
        case PdfImageItem():
          if (item.format != null) {
            pdf.addImage(item.data, item.format!, item.x, item.y, item.width,
                item.height, item.alias);
          } else {
            pdf.addImage(
                item.data, item.x, item.y, item.width, item.height, item.alias);
          }
      }
    }
  }
}

class _FallbackLayout {
  final PdfPageFormat f;
  final List<PdfLayoutPage> _pages = [];
  List<PdfLayoutItem> _items = [];
  late double y;

  _FallbackLayout(this.f);

  Future<PdfLayoutPlan> layoutAsync(model.PMNode doc,
      {required int chunkSize}) async {
    if (chunkSize <= 0) throw ArgumentError.value(chunkSize, 'chunkSize');
    _newPage();
    for (var i = 0; i < doc.children.length; i++) {
      _block(doc.children[i]);
      if ((i + 1) % chunkSize == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    _pages.add(PdfLayoutPage(_items));
    return PdfLayoutPlan(_pages);
  }

  void _newPage() {
    if (_items.isNotEmpty) _pages.add(PdfLayoutPage(_items));
    _items = [];
    y = f.marginTop;
  }

  void _ensure(double height) {
    if (y + height > f.height - f.marginBottom && _items.isNotEmpty) _newPage();
  }

  void _block(model.PMNode node, {double indent = 0, String prefix = ''}) {
    switch (node.type.name) {
      case 'paragraph':
        _paragraph(node, indent: indent, prefix: prefix);
      case 'heading':
        final level = (node.attrs['level'] as int? ?? 1).clamp(1, 6);
        _paragraph(node, size: 22 - level * 2, bold: true, spacing: 8);
      case 'bulletList':
        for (final item in node.children) {
          _listItem(item, indent, '\u2022 ');
        }
      case 'orderedList':
        var number = node.attrs['start'] as int? ?? 1;
        for (final item in node.children) {
          _listItem(item, indent, '$number. ');
          number++;
        }
      case 'image':
        _image(node);
      case 'table':
        _table(node);
      case 'horizontalRule':
        _ensure(14);
        _items.add(
            PdfLineItem(f.marginLeft, y + 5, f.width - f.marginRight, y + 5));
        y += 14;
      default:
        for (final child in node.children) {
          _block(child, indent: indent);
        }
    }
  }

  void _listItem(model.PMNode item, double indent, String prefix) {
    var first = true;
    for (final child in item.children) {
      _block(child, indent: indent + 18, prefix: first ? prefix : '');
      first = false;
    }
  }

  void _paragraph(model.PMNode node,
      {double size = 11,
      bool bold = false,
      double spacing = 4,
      double indent = 0,
      String prefix = ''}) {
    final runs = _runs(node, size, bold);
    if (prefix.isNotEmpty) {
      runs.insert(0, _Run(prefix, size, bold, false, null, null));
    }
    final left = f.marginLeft + indent;
    final maxWidth = f.width - f.marginRight - left;
    var line = <_Run>[];
    var width = 0.0;

    void flush() {
      if (line.isEmpty) {
        final lineHeight = size * 1.25;
        _ensure(lineHeight);
        y += lineHeight;
        return;
      }
      final lineHeight = line.map((run) => run.size).reduce(math.max) * 1.25;
      _ensure(lineHeight);
      final align = node.attrs['textAlign'];
      var x = align == 'center'
          ? left + (maxWidth - width) / 2
          : align == 'right'
              ? left + maxWidth - width
              : left;
      for (final run in line) {
        _items.add(PdfTextItem(run.text, x, y + run.size,
            fontSize: run.size,
            bold: run.bold,
            italic: run.italic,
            color: run.color,
            fontFamily: run.fontFamily));
        x += _textWidth(run.text, run.size, run.bold, run.italic);
      }
      y += lineHeight;
      line = [];
      width = 0;
    }

    for (final run in runs) {
      if (run.text == '\n') {
        flush();
        continue;
      }
      for (final token in run.text.split(RegExp(r'(?<=\s)|(?=\s)'))) {
        var remainder = token;
        var w = _textWidth(remainder, run.size, run.bold, run.italic);
        if (width + w > maxWidth &&
            line.isNotEmpty &&
            remainder.trim().isNotEmpty) {
          flush();
        }
        // Uma palavra maior que a linha é quebrada por caracteres.
        while (w > maxWidth && remainder.length > 1) {
          var cut = 1;
          while (cut < remainder.length &&
              _textWidth(remainder.substring(0, cut + 1), run.size, run.bold,
                      run.italic) <=
                  maxWidth) {
            cut++;
          }
          final head = remainder.substring(0, cut);
          line.add(run.copyWith(head));
          width += _textWidth(head, run.size, run.bold, run.italic);
          flush();
          remainder = remainder.substring(cut);
          w = _textWidth(remainder, run.size, run.bold, run.italic);
        }
        if (remainder.isNotEmpty) {
          line.add(run.copyWith(remainder));
          width += w;
        }
      }
    }
    if (line.isNotEmpty) flush();
    if (runs.isEmpty) flush();
    y += spacing;
  }

  List<_Run> _runs(model.PMNode node, double baseSize, bool baseBold) {
    final result = <_Run>[];
    for (final child in node.children) {
      if (child.isText) {
        var bold = baseBold, italic = false, size = baseSize;
        String? color, fontFamily;
        for (final mark in child.marks) {
          if (mark.type.name == 'bold') bold = true;
          if (mark.type.name == 'italic') italic = true;
          if (mark.type.name == 'textStyle') {
            color = mark.attrs['color'] as String?;
            fontFamily = mark.attrs['fontFamily'] as String?;
            size = _size(mark.attrs['fontSize'], size) ?? size;
          }
        }
        result.add(_Run(child.text!, size, bold, italic, color, fontFamily));
      } else if (child.type.name == 'hardBreak') {
        result.add(_Run('\n', baseSize, baseBold, false, null, null));
      }
    }
    return result;
  }

  void _table(model.PMNode table) {
    final cols = table.children.isEmpty
        ? 1
        : table.children
            .map((r) => r.children
                .fold<int>(0, (n, c) => n + (c.attrs['colspan'] as int? ?? 1)))
            .fold<int>(1, math.max);
    final cellWidth = (f.width - f.marginLeft - f.marginRight) / cols;
    const rowHeight = 26.0;
    for (final row in table.children) {
      _ensure(rowHeight);
      var col = 0;
      for (final cell in row.children) {
        final span = cell.attrs['colspan'] as int? ?? 1;
        final x = f.marginLeft + col * cellWidth;
        _items.add(PdfRectItem(x, y, cellWidth * span, rowHeight));
        final text = cell.textContent;
        _items.add(PdfTextItem(text, x + 4, y + 16,
            fontSize: 9, bold: cell.type.name == 'tableHeader'));
        col += span;
      }
      y += rowHeight;
    }
    y += 6;
  }

  void _image(model.PMNode image) {
    final src = image.attrs['src'];
    if (src is! String || !src.startsWith('data:image/')) return;
    var width = _dimension(image.attrs['width']) ?? 160;
    var height = _dimension(image.attrs['height']) ?? 120;
    final maxWidth = f.width - f.marginLeft - f.marginRight;
    if (width > maxWidth) {
      height *= maxWidth / width;
      width = maxWidth;
    }
    _ensure(height + 6);
    _items.add(PdfImageItem(src, f.marginLeft, y, width, height));
    y += height + 6;
  }
}

class _Run {
  final String text;
  final double size;
  final bool bold, italic;
  final String? color;
  final String? fontFamily;
  const _Run(this.text, this.size, this.bold, this.italic, this.color,
      this.fontFamily);
  _Run copyWith(String text) =>
      _Run(text, size, bold, italic, color, fontFamily);
}

double _textWidth(String text, double size, bool bold, bool italic) {
  final postScript = bold
      ? (italic ? 'Helvetica-BoldOblique' : 'Helvetica-Bold')
      : (italic ? 'Helvetica-Oblique' : 'Helvetica');
  // As tabelas comprimidas herdadas do jsPDF armazenam larguras em décimos
  // de unidade (ex.: espaço=28, equivalente a 278/1000 em AFM).
  return getStringWidthForFont(_winAnsi(text), postScript) * size / 100;
}

double? _size(dynamic value, double baseSize) {
  if (value is num) return value.toDouble();
  if (value is! String) return null;
  final number = double.tryParse(
      RegExp(r'-?[0-9]+(?:\.[0-9]+)?').firstMatch(value)?.group(0) ?? '');
  if (number == null) return null;
  if (value.trim().endsWith('px')) return number * .75;
  if (value.trim().endsWith('em')) return number * baseSize;
  return number;
}

double? _dimension(dynamic value) {
  if (value is num) return value.toDouble() * .75;
  if (value is! String) return null;
  final number = double.tryParse(
      RegExp(r'[0-9]+(?:\.[0-9]+)?').firstMatch(value)?.group(0) ?? '');
  if (number == null) return null;
  return value.trim().endsWith('pt') ? number : number * .75;
}

String _baseFontFamily(String? requested) {
  if (requested == null) return 'helvetica';
  if (requested.contains('courier') ||
      requested.contains('consolas') ||
      requested.contains('mono')) {
    return 'courier';
  }
  if (requested.contains('times') ||
      (requested.contains('serif') && !requested.contains('sans'))) {
    return 'times';
  }
  return 'helvetica'; // Arial, Inter e demais sans-serif sem TTF registrada.
}

/// Converte caracteres CP1252 especiais para os bytes de WinAnsiEncoding.
String _winAnsi(String value) {
  const cp1252 = <int, int>{
    0x20ac: 0x80,
    0x201a: 0x82,
    0x0192: 0x83,
    0x201e: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02c6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8a,
    0x2039: 0x8b,
    0x0152: 0x8c,
    0x017d: 0x8e,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201c: 0x93,
    0x201d: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02dc: 0x98,
    0x2122: 0x99,
    0x0161: 0x9a,
    0x203a: 0x9b,
    0x0153: 0x9c,
    0x017e: 0x9e,
    0x0178: 0x9f,
  };
  return String.fromCharCodes(
      value.runes.map((rune) => rune <= 0xff ? rune : (cp1252[rune] ?? 0x3f)));
}
