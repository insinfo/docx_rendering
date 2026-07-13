/// Parser de cores CSS para valores RGB.
///
/// Suporta:
/// - Nomes de cores CSS (red, blue, etc.)
/// - Formato hex (#RGB, #RRGGBB)
/// - rgb(r, g, b)
/// - rgba(r, g, b, a)
///
/// Portado de libs/rgbcolor.js do jsPDF.
class RGBColor {
  int r = 0;
  int g = 0;
  int b = 0;
  double a = 1.0;
  bool ok = false;

  RGBColor(String colorString) {
    _parse(colorString.trim().toLowerCase());
  }

  void _parse(String color) {
    // Tenta nomes de cores CSS
    if (_cssColors.containsKey(color)) {
      color = _cssColors[color]!;
    }

    // Remove espaços extras
    color = color.replaceAll(RegExp(r'\s+'), ' ');

    // Tenta hex #RRGGBB ou #RGB
    var match = RegExp(r'^#([0-9a-f]{6})$').firstMatch(color);
    if (match != null) {
      final hex = match.group(1)!;
      r = int.parse(hex.substring(0, 2), radix: 16);
      g = int.parse(hex.substring(2, 4), radix: 16);
      b = int.parse(hex.substring(4, 6), radix: 16);
      ok = true;
      return;
    }

    match = RegExp(r'^#([0-9a-f]{3})$').firstMatch(color);
    if (match != null) {
      final hex = match.group(1)!;
      r = int.parse('${hex[0]}${hex[0]}', radix: 16);
      g = int.parse('${hex[1]}${hex[1]}', radix: 16);
      b = int.parse('${hex[2]}${hex[2]}', radix: 16);
      ok = true;
      return;
    }

    // Tenta rgb(r, g, b)
    match = RegExp(r'^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$')
        .firstMatch(color);
    if (match != null) {
      r = int.parse(match.group(1)!).clamp(0, 255);
      g = int.parse(match.group(2)!).clamp(0, 255);
      b = int.parse(match.group(3)!).clamp(0, 255);
      ok = true;
      return;
    }

    // Tenta rgba(r, g, b, a)
    match = RegExp(
      r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
    ).firstMatch(color);
    if (match != null) {
      r = int.parse(match.group(1)!).clamp(0, 255);
      g = int.parse(match.group(2)!).clamp(0, 255);
      b = int.parse(match.group(3)!).clamp(0, 255);
      a = double.parse(match.group(4)!).clamp(0.0, 1.0);
      ok = true;
      return;
    }

    // Tenta rgb com percentuais
    match = RegExp(
      r'^rgb\(\s*([\d.]+)%\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*\)$',
    ).firstMatch(color);
    if (match != null) {
      r = (double.parse(match.group(1)!) * 2.55).round().clamp(0, 255);
      g = (double.parse(match.group(2)!) * 2.55).round().clamp(0, 255);
      b = (double.parse(match.group(3)!) * 2.55).round().clamp(0, 255);
      ok = true;
      return;
    }
  }

  /// Retorna a cor no formato hex (#RRGGBB).
  String toHex() {
    final rh = r.toRadixString(16).padLeft(2, '0');
    final gh = g.toRadixString(16).padLeft(2, '0');
    final bh = b.toRadixString(16).padLeft(2, '0');
    return '#$rh$gh$bh';
  }

  /// Retorna a cor no formato rgb(r, g, b).
  String toRGB() => 'rgb($r, $g, $b)';

  @override
  String toString() => toHex();

  // --- Cores CSS padrão ---
  static const Map<String, String> _cssColors = {
    'aliceblue': '#f0f8ff',
    'antiquewhite': '#faebd7',
    'aqua': '#00ffff',
    'aquamarine': '#7fffd4',
    'azure': '#f0ffff',
    'beige': '#f5f5dc',
    'bisque': '#ffe4c4',
    'black': '#000000',
    'blanchedalmond': '#ffebcd',
    'blue': '#0000ff',
    'blueviolet': '#8a2be2',
    'brown': '#a52a2a',
    'burlywood': '#deb887',
    'cadetblue': '#5f9ea0',
    'chartreuse': '#7fff00',
    'chocolate': '#d2691e',
    'coral': '#ff7f50',
    'cornflowerblue': '#6495ed',
    'cornsilk': '#fff8dc',
    'crimson': '#dc143c',
    'cyan': '#00ffff',
    'darkblue': '#00008b',
    'darkcyan': '#008b8b',
    'darkgoldenrod': '#b8860b',
    'darkgray': '#a9a9a9',
    'darkgreen': '#006400',
    'darkkhaki': '#bdb76b',
    'darkmagenta': '#8b008b',
    'darkolivegreen': '#556b2f',
    'darkorange': '#ff8c00',
    'darkorchid': '#9932cc',
    'darkred': '#8b0000',
    'darksalmon': '#e9967a',
    'darkseagreen': '#8fbc8f',
    'darkslateblue': '#483d8b',
    'darkslategray': '#2f4f4f',
    'darkturquoise': '#00ced1',
    'darkviolet': '#9400d3',
    'deeppink': '#ff1493',
    'deepskyblue': '#00bfff',
    'dimgray': '#696969',
    'dodgerblue': '#1e90ff',
    'feldspar': '#d19275',
    'firebrick': '#b22222',
    'floralwhite': '#fffaf0',
    'forestgreen': '#228b22',
    'fuchsia': '#ff00ff',
    'gainsboro': '#dcdcdc',
    'ghostwhite': '#f8f8ff',
    'gold': '#ffd700',
    'goldenrod': '#daa520',
    'gray': '#808080',
    'green': '#008000',
    'greenyellow': '#adff2f',
    'honeydew': '#f0fff0',
    'hotpink': '#ff69b4',
    'indianred': '#cd5c5c',
    'indigo': '#4b0082',
    'ivory': '#fffff0',
    'khaki': '#f0e68c',
    'lavender': '#e6e6fa',
    'lavenderblush': '#fff0f5',
    'lawngreen': '#7cfc00',
    'lemonchiffon': '#fffacd',
    'lightblue': '#add8e6',
    'lightcoral': '#f08080',
    'lightcyan': '#e0ffff',
    'lightgoldenrodyellow': '#fafad2',
    'lightgrey': '#d3d3d3',
    'lightgreen': '#90ee90',
    'lightpink': '#ffb6c1',
    'lightsalmon': '#ffa07a',
    'lightseagreen': '#20b2aa',
    'lightskyblue': '#87cefa',
    'lightslateblue': '#8470ff',
    'lightslategray': '#778899',
    'lightsteelblue': '#b0c4de',
    'lightyellow': '#ffffe0',
    'lime': '#00ff00',
    'limegreen': '#32cd32',
    'linen': '#faf0e6',
    'magenta': '#ff00ff',
    'maroon': '#800000',
    'mediumaquamarine': '#66cdaa',
    'mediumblue': '#0000cd',
    'mediumorchid': '#ba55d3',
    'mediumpurple': '#9370d8',
    'mediumseagreen': '#3cb371',
    'mediumslateblue': '#7b68ee',
    'mediumspringgreen': '#00fa9a',
    'mediumturquoise': '#48d1cc',
    'mediumvioletred': '#c71585',
    'midnightblue': '#191970',
    'mintcream': '#f5fffa',
    'mistyrose': '#ffe4e1',
    'moccasin': '#ffe4b5',
    'navajowhite': '#ffdead',
    'navy': '#000080',
    'oldlace': '#fdf5e6',
    'olive': '#808000',
    'olivedrab': '#6b8e23',
    'orange': '#ffa500',
    'orangered': '#ff4500',
    'orchid': '#da70d6',
    'palegoldenrod': '#eee8aa',
    'palegreen': '#98fb98',
    'paleturquoise': '#afeeee',
    'palevioletred': '#d87093',
    'papayawhip': '#ffefd5',
    'peachpuff': '#ffdab9',
    'peru': '#cd853f',
    'pink': '#ffc0cb',
    'plum': '#dda0dd',
    'powderblue': '#b0e0e6',
    'purple': '#800080',
    'red': '#ff0000',
    'rosybrown': '#bc8f8f',
    'royalblue': '#4169e1',
    'saddlebrown': '#8b4513',
    'salmon': '#fa8072',
    'sandybrown': '#f4a460',
    'seagreen': '#2e8b57',
    'seashell': '#fff5ee',
    'sienna': '#a0522d',
    'silver': '#c0c0c0',
    'skyblue': '#87ceeb',
    'slateblue': '#6a5acd',
    'slategray': '#708090',
    'snow': '#fffafa',
    'springgreen': '#00ff7f',
    'steelblue': '#4682b4',
    'tan': '#d2b48c',
    'teal': '#008080',
    'thistle': '#d8bfd8',
    'tomato': '#ff6347',
    'turquoise': '#40e0d0',
    'violet': '#ee82ee',
    'violetred': '#d02090',
    'wheat': '#f5deb3',
    'white': '#ffffff',
    'whitesmoke': '#f5f5f5',
    'yellow': '#ffff00',
    'yellowgreen': '#9acd32',
  };
}
