/// Ponto 2D usado internamente pelo jsPDF.
class PdfPoint {
  double x;
  double y;

  PdfPoint(this.x, this.y);

  @override
  String toString() => 'PdfPoint($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPoint && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Retângulo usado internamente pelo jsPDF.
class PdfRectangle {
  double x;
  double y;
  double w;
  double h;

  PdfRectangle(this.x, this.y, this.w, this.h);

  @override
  String toString() => 'PdfRectangle($x, $y, $w, $h)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfRectangle &&
          x == other.x &&
          y == other.y &&
          w == other.w &&
          h == other.h;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ w.hashCode ^ h.hashCode;
}
