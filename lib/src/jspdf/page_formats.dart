/// Formatos de página padrão em pontos (pt).
///
/// Cada formato é representado por [largura, altura] em pontos.
/// 1 ponto = 1/72 polegadas.
const Map<String, List<double>> pageFormats = {
  'a0': [2383.94, 3370.39],
  'a1': [1683.78, 2383.94],
  'a2': [1190.55, 1683.78],
  'a3': [841.89, 1190.55],
  'a4': [595.28, 841.89],
  'a5': [419.53, 595.28],
  'a6': [297.64, 419.53],
  'a7': [209.76, 297.64],
  'a8': [147.4, 209.76],
  'a9': [104.88, 147.4],
  'a10': [73.7, 104.88],
  'b0': [2834.65, 4008.19],
  'b1': [2004.09, 2834.65],
  'b2': [1417.32, 2004.09],
  'b3': [1000.63, 1417.32],
  'b4': [708.66, 1000.63],
  'b5': [498.9, 708.66],
  'b6': [354.33, 498.9],
  'b7': [249.45, 354.33],
  'b8': [175.75, 249.45],
  'b9': [124.72, 175.75],
  'b10': [87.87, 124.72],
  'c0': [2599.37, 3676.54],
  'c1': [1836.85, 2599.37],
  'c2': [1298.27, 1836.85],
  'c3': [918.43, 1298.27],
  'c4': [649.13, 918.43],
  'c5': [459.21, 649.13],
  'c6': [323.15, 459.21],
  'c7': [229.61, 323.15],
  'c8': [161.57, 229.61],
  'c9': [113.39, 161.57],
  'c10': [79.37, 113.39],
  'dl': [311.81, 623.62],
  'letter': [612, 792],
  'government-letter': [576, 756],
  'legal': [612, 1008],
  'junior-legal': [576, 360],
  'ledger': [1224, 792],
  'tabloid': [792, 1224],
  'credit-card': [153, 243],
};

/// Retorna as dimensões [largura, altura] de um formato de página.
///
/// Retorna null se o formato não for reconhecido.
List<double>? getPageFormat(String format) {
  return pageFormats[format.toLowerCase()];
}

/// Fator de escala para conversão de unidades.
///
/// Converte diferentes unidades de medida para pontos (pt).
double getScaleFactor(String unit) {
  switch (unit.toLowerCase()) {
    case 'pt':
      return 1;
    case 'mm':
      return 72 / 25.4;
    case 'cm':
      return 72 / 2.54;
    case 'in':
      return 72;
    case 'px':
      return 96 / 72;
    case 'pc':
      return 12;
    case 'em':
      return 12;
    case 'ex':
      return 6;
    default:
      throw ArgumentError('Invalid unit: $unit');
  }
}
