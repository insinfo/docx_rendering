import 'dart:math' as math;
import 'geometry.dart';
import 'utils.dart';

/// Matriz 2D homogênea para transformações PDF.
///
/// Representa a matriz:
/// ```
/// | a  b  0 |     | sx  shy  0 |
/// | c  d  0 |  =  | shx  sy  0 |
/// | e  f  1 |     | tx   ty  1 |
/// ```
///
/// O PDF multiplica matrizes pela direita: v' = v × m1 × m2 × ...
class PdfMatrix {
  final List<double> _m;

  PdfMatrix([
    double sx = 1,
    double shy = 0,
    double shx = 0,
    double sy = 1,
    double tx = 0,
    double ty = 0,
  ]) : _m = [
          sx.isNaN ? 1 : sx,
          shy.isNaN ? 0 : shy,
          shx.isNaN ? 0 : shx,
          sy.isNaN ? 1 : sy,
          tx.isNaN ? 0 : tx,
          ty.isNaN ? 0 : ty,
        ];

  // --- Accessors sx/shy/shx/sy/tx/ty ---

  double get sx => _m[0];
  set sx(double v) => _m[0] = v;

  double get shy => _m[1];
  set shy(double v) => _m[1] = v;

  double get shx => _m[2];
  set shx(double v) => _m[2] = v;

  double get sy => _m[3];
  set sy(double v) => _m[3] = v;

  double get tx => _m[4];
  set tx(double v) => _m[4] = v;

  double get ty => _m[5];
  set ty(double v) => _m[5] = v;

  // --- Aliases a/b/c/d/e/f ---

  double get a => _m[0];
  set a(double v) => _m[0] = v;

  double get b => _m[1];
  set b(double v) => _m[1] = v;

  double get c => _m[2];
  set c(double v) => _m[2] = v;

  double get d => _m[3];
  set d(double v) => _m[3] = v;

  double get e => _m[4];
  set e(double v) => _m[4] = v;

  double get f => _m[5];
  set f(double v) => _m[5] = v;

  // --- Computed properties ---

  /// Ângulo de rotação em radianos.
  double get rotation => math.atan2(shx, sx);

  /// Fator de escala X após decomposição.
  double get scaleX => decompose().scale.sx;

  /// Fator de escala Y após decomposição.
  double get scaleY => decompose().scale.sy;

  /// Verifica se é a matriz identidade.
  bool get isIdentity =>
      sx == 1 && shy == 0 && shx == 0 && sy == 1 && tx == 0 && ty == 0;

  // --- Methods ---

  /// Junta os valores da matriz com [separator].
  String join(String separator, {String Function(num)? formatter}) {
    final fmt = formatter ?? createHpf(16);
    return [sx, shy, shx, sy, tx, ty].map((v) => fmt(v)).join(separator);
  }

  /// Multiplica esta matriz por [matrix].
  /// Retorna uma nova PdfMatrix resultado da multiplicação.
  PdfMatrix multiply(PdfMatrix matrix) {
    final newSx = matrix.sx * sx + matrix.shy * shx;
    final newShy = matrix.sx * shy + matrix.shy * sy;
    final newShx = matrix.shx * sx + matrix.sy * shx;
    final newSy = matrix.shx * shy + matrix.sy * sy;
    final newTx = matrix.tx * sx + matrix.ty * shx + tx;
    final newTy = matrix.tx * shy + matrix.ty * sy + ty;
    return PdfMatrix(newSx, newShy, newShx, newSy, newTx, newTy);
  }

  /// Decompõe a matriz em scale, translate, rotate e skew.
  MatrixDecomposition decompose() {
    var aVal = sx;
    var bVal = shy;
    var cVal = shx;
    var dVal = sy;
    final eVal = tx;
    final fVal = ty;

    var scX = math.sqrt(aVal * aVal + bVal * bVal);
    aVal /= scX;
    bVal /= scX;

    var shear = aVal * cVal + bVal * dVal;
    cVal -= aVal * shear;
    dVal -= bVal * shear;

    var scY = math.sqrt(cVal * cVal + dVal * dVal);
    cVal /= scY;
    dVal /= scY;
    shear /= scY;

    if (aVal * dVal < bVal * cVal) {
      aVal = -aVal;
      bVal = -bVal;
      shear = -shear;
      scX = -scX;
    }

    return MatrixDecomposition(
      scale: PdfMatrix(scX, 0, 0, scY, 0, 0),
      translate: PdfMatrix(1, 0, 0, 1, eVal, fVal),
      rotate: PdfMatrix(aVal, bVal, -bVal, aVal, 0, 0),
      skew: PdfMatrix(1, 0, shear, 1, 0, 0),
    );
  }

  /// Retorna a matriz inversa.
  PdfMatrix inversed() {
    final aVal = sx;
    final bVal = shy;
    final cVal = shx;
    final dVal = sy;
    final eVal = tx;
    final fVal = ty;

    final quot = 1 / (aVal * dVal - bVal * cVal);

    final aInv = dVal * quot;
    final bInv = -bVal * quot;
    final cInv = -cVal * quot;
    final dInv = aVal * quot;
    final eInv = -aInv * eVal - cInv * fVal;
    final fInv = -bInv * eVal - dInv * fVal;

    return PdfMatrix(aInv, bInv, cInv, dInv, eInv, fInv);
  }

  /// Aplica a transformação a um ponto.
  PdfPoint applyToPoint(PdfPoint pt) {
    final x = pt.x * sx + pt.y * shx + tx;
    final y = pt.x * shy + pt.y * sy + ty;
    return PdfPoint(x, y);
  }

  /// Aplica a transformação a um retângulo.
  PdfRectangle applyToRectangle(PdfRectangle rect) {
    final pt1 = applyToPoint(PdfPoint(rect.x, rect.y));
    final pt2 = applyToPoint(PdfPoint(rect.x + rect.w, rect.y + rect.h));
    return PdfRectangle(pt1.x, pt1.y, pt2.x - pt1.x, pt2.y - pt1.y);
  }

  /// Clona esta matriz.
  PdfMatrix clone() => PdfMatrix(sx, shy, shx, sy, tx, ty);

  @override
  String toString() => join(' ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfMatrix &&
          sx == other.sx &&
          shy == other.shy &&
          shx == other.shx &&
          sy == other.sy &&
          tx == other.tx &&
          ty == other.ty;

  @override
  int get hashCode => Object.hashAll(_m);

  /// Matriz identidade estática.
  static final PdfMatrix identity = PdfMatrix(1, 0, 0, 1, 0, 0);
}

/// Resultado da decomposição de uma PdfMatrix.
class MatrixDecomposition {
  final PdfMatrix scale;
  final PdfMatrix translate;
  final PdfMatrix rotate;
  final PdfMatrix skew;

  const MatrixDecomposition({
    required this.scale,
    required this.translate,
    required this.rotate,
    required this.skew,
  });
}
