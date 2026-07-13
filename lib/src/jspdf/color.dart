import 'rgb_color.dart';
import 'utils.dart';

/// Codificação e decodificação de cores para o formato PDF.
///
/// Suporta espaços de cor: Grayscale, RGB e CMYK.
/// Portado de encodeColorString/decodeColorString do jspdf.js.

/// Decodifica uma string de cor PDF para formato hex (#RRGGBB).
///
/// Aceita espaços de cor:
/// - "0.5 g" → grayscale
/// - "0.1 0.2 0.3 rg" → RGB
/// - "0.1 0.2 0.3 0.4 k" → CMYK
String decodeColorString(String color) {
  final colorEncoded = color.split(' ');
  List<String> components;

  if (colorEncoded.length == 2 &&
      (colorEncoded[1] == 'g' || colorEncoded[1] == 'G')) {
    // Grayscale → RGB
    final floatVal = double.parse(colorEncoded[0]);
    components = [
      floatVal.toString(),
      floatVal.toString(),
      floatVal.toString(),
      'r'
    ];
  } else if (colorEncoded.length == 5 &&
      (colorEncoded[4] == 'k' || colorEncoded[4] == 'K')) {
    // CMYK → RGB
    final c = double.parse(colorEncoded[0]);
    final m = double.parse(colorEncoded[1]);
    final y = double.parse(colorEncoded[2]);
    final k = double.parse(colorEncoded[3]);
    final red = (1.0 - c) * (1.0 - k);
    final green = (1.0 - m) * (1.0 - k);
    final blue = (1.0 - y) * (1.0 - k);
    components = [red.toString(), green.toString(), blue.toString(), 'r'];
  } else {
    components = colorEncoded;
  }

  var colorAsRGB = '#';
  for (var i = 0; i < 3; i++) {
    colorAsRGB += (double.parse(components[i]) * 255)
        .floor()
        .toRadixString(16)
        .padLeft(2, '0');
  }
  return colorAsRGB;
}

/// Opções para codificação de cor PDF.
class ColorOptions {
  /// Canal 1 (pode ser string hex/nome de cor ou valor numérico 0-255).
  final dynamic ch1;

  /// Canal 2 (0-255 para RGB, ou fração para CMYK).
  final dynamic ch2;

  /// Canal 3.
  final dynamic ch3;

  /// Canal 4 (para CMYK, ou objeto com {a: opacity}).
  final dynamic ch4;

  /// 'draw' para operações de stroke, outro para fill.
  final String pdfColorType;

  /// Precisão do número (2 ou 3).
  final int precision;

  const ColorOptions({
    required this.ch1,
    this.ch2,
    this.ch3,
    this.ch4,
    this.pdfColorType = 'fill',
    this.precision = 3,
  });
}

/// Codifica uma cor para o formato de string PDF.
///
/// Retorna strings como:
/// - "0.5 g" (grayscale fill)
/// - "0.5 G" (grayscale stroke)
/// - "0.1 0.2 0.3 rg" (RGB fill)
/// - "0.1 0.2 0.3 RG" (RGB stroke)
/// - "0.1 0.2 0.3 0.4 k" (CMYK fill)
/// - "0.1 0.2 0.3 0.4 K" (CMYK stroke)
String encodeColorString(ColorOptions options) {
  final letterArray =
      options.pdfColorType == 'draw' ? ['G', 'RG', 'K'] : ['g', 'rg', 'k'];

  dynamic ch1 = options.ch1;
  dynamic ch2 = options.ch2;
  dynamic ch3 = options.ch3;
  dynamic ch4 = options.ch4;

  // Tenta parser de nome de cor CSS
  if (ch1 is String && !ch1.startsWith('#')) {
    final rgbColor = RGBColor(ch1);
    if (rgbColor.ok) {
      ch1 = rgbColor.toHex();
    } else if (!RegExp(r'^\d*\.?\d*$').hasMatch(ch1)) {
      throw ArgumentError(
        'Invalid color "$ch1" passed to encodeColorString.',
      );
    }
  }

  // Converte hex curto (#RGB) para longo (#RRGGBB)
  if (ch1 is String && RegExp(r'^#[0-9A-Fa-f]{3}$').hasMatch(ch1)) {
    ch1 = '#${ch1[1]}${ch1[1]}${ch1[2]}${ch1[2]}${ch1[3]}${ch1[3]}';
  }

  // Converte hex #RRGGBB para componentes numéricos
  if (ch1 is String && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(ch1)) {
    final hex = int.parse(ch1.substring(1), radix: 16);
    ch1 = (hex >> 16) & 255;
    ch2 = (hex >> 8) & 255;
    ch3 = hex & 255;
  }

  // Determina espaço de cor e formata
  if (ch2 == null || (ch4 == null && ch1 == ch2 && ch2 == ch3)) {
    // Grayscale
    if (ch1 is String) {
      return '$ch1 ${letterArray[0]}';
    } else {
      final formatter = options.precision == 2 ? f2 : f3;
      return '${formatter((ch1 as num) / 255)} ${letterArray[0]}';
    }
  } else if (ch4 == null || ch4 is Map) {
    // RGB (possivelmente com alpha)
    if (ch4 is Map && ch4['a'] != null) {
      if ((ch4['a'] as num) == 0) {
        return '1. 1. 1. ${letterArray[1]}';
      }
    }

    if (ch1 is String) {
      return '$ch1 $ch2 $ch3 ${letterArray[1]}';
    } else {
      final formatter = options.precision == 2 ? f2 : f3;
      return '${formatter((ch1 as num) / 255)} ${formatter((ch2 as num) / 255)} ${formatter((ch3 as num) / 255)} ${letterArray[1]}';
    }
  } else {
    // CMYK
    if (ch1 is String) {
      return '$ch1 $ch2 $ch3 $ch4 ${letterArray[2]}';
    } else {
      final formatter = options.precision == 2 ? f2 : f3;
      return '${formatter(ch1 as num)} ${formatter(ch2 as num)} ${formatter(ch3 as num)} ${formatter(ch4 as num)} ${letterArray[2]}';
    }
  }
}
