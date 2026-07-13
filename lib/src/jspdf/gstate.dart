/// Estado gráfico (Graphics State) do PDF.
///
/// Controla opacity e stroke-opacity para objetos gráficos.
/// Portado de GState no jspdf.js original.
class GState {
  /// Opacidade do preenchimento (0.0 a 1.0).
  double? opacity;

  /// Opacidade do traço (0.0 a 1.0).
  double? strokeOpacity;

  /// ID atribuído pelo addGState().
  String id = '';

  /// Número do objeto PDF (atribuído por putGState()).
  int objectNumber = -1;

  GState({this.opacity, this.strokeOpacity});

  /// Cria GState a partir de um mapa de parâmetros.
  ///
  /// Apenas 'opacity' e 'stroke-opacity' são suportados.
  factory GState.fromMap(Map<String, dynamic> parameters) {
    return GState(
      opacity: parameters.containsKey('opacity')
          ? (parameters['opacity'] as num).toDouble()
          : null,
      strokeOpacity: parameters.containsKey('stroke-opacity')
          ? (parameters['stroke-opacity'] as num).toDouble()
          : null,
    );
  }

  /// Compara este GState com [other] ignorando id e objectNumber.
  bool equals(GState? other) {
    if (other == null) return false;
    if (identical(this, other)) return true;
    return opacity == other.opacity && strokeOpacity == other.strokeOpacity;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GState &&
          opacity == other.opacity &&
          strokeOpacity == other.strokeOpacity;

  @override
  int get hashCode => Object.hash(opacity, strokeOpacity);

  @override
  String toString() =>
      'GState(opacity: $opacity, strokeOpacity: $strokeOpacity, id: $id)';
}
