import 'gstate.dart';
import 'matrix.dart';

/// Classe base para padrões PDF.
///
/// Padrões são usados para preenchimento de formas com gradientes
/// ou repetições (tiling).
class PdfPattern {
  /// Estado gráfico associado ao padrão.
  GState? gState;

  /// Transformação do padrão.
  PdfMatrix? matrix;

  /// ID atribuído por addPattern().
  String id = '';

  /// Número do objeto PDF (atribuído por putPattern()).
  int objectNumber = -1;

  PdfPattern({this.gState, this.matrix});
}

/// Padrão de sombreamento (gradiente) PDF.
///
/// Suporta gradientes axiais (lineares) e radiais.
class ShadingPattern extends PdfPattern {
  /// Tipo do gradiente: 2 = axial, 3 = radial.
  final int type;

  /// Coordenadas do gradiente.
  /// - Axial: [x1, y1, x2, y2]
  /// - Radial: [x1, y1, r1, x2, y2, r2]
  final List<double> coords;

  /// Lista de cores com offset.
  /// Cada item: {'offset': double, 'color': [r, g, b]}
  final List<Map<String, dynamic>> colors;

  ShadingPattern({
    required String gradientType,
    required this.coords,
    required this.colors,
    GState? gState,
    PdfMatrix? matrix,
  })  : type = gradientType == 'axial' ? 2 : 3,
        super(gState: gState, matrix: matrix);
}

/// Padrão de tiling (repetição) PDF.
///
/// Permite preencher áreas com padrões repetidos.
class TilingPattern extends PdfPattern {
  /// Caixa delimitadora do padrão.
  final List<double> boundingBox;

  /// Espaçamento horizontal entre células do padrão.
  final double xStep;

  /// Espaçamento vertical entre células do padrão.
  final double yStep;

  /// Stream de conteúdo (definido por endTilingPattern).
  String stream = '';

  /// Índice de clone para padrões duplicados.
  int cloneIndex = 0;

  TilingPattern({
    required this.boundingBox,
    required this.xStep,
    required this.yStep,
    GState? gState,
    PdfMatrix? matrix,
  }) : super(gState: gState, matrix: matrix);
}
