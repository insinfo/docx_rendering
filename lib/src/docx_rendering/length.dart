/// Ported from docxjs src/length.ts
/// CSS length value with optional unit type.

class Length {
  final double value;
  final String? type;

  const Length(this.value, [this.type]);

  /// Parses a length string like "12pt" or "100px".
  static Length parse(String text) {
    final value = double.tryParse(text.replaceAll(RegExp(r'[a-zA-Z%]+$'), '')) ?? 0;
    final match = RegExp(r'p[tx]$', caseSensitive: false).firstMatch(text);
    return Length(value, match?[0]);
  }

  /// Creates a Length from a dynamic value.
  static Length? from(dynamic val) {
    if (val is String) return Length.parse(val);
    if (val is Length) return val;
    return null;
  }

  /// Adds two lengths of the same type.
  Length add(Length other) {
    if (other.type != type) {
      throw ArgumentError("Can't do math on different types");
    }
    return Length(value + other.value, type);
  }

  /// Multiplies the length value by a scalar.
  Length mul(double val) {
    return Length(value * val, type);
  }

  @override
  String toString() {
    return '${value.toStringAsFixed(2)}${type ?? ''}';
  }
}
