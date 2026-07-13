/// Minimal deep-equality helper replacing `package:collection`'s
/// `DeepCollectionEquality`, so the Delta core keeps the project's
/// "runtime depends only on package:web" constraint.
bool deepEquals(Object? a, Object? b, {bool unordered = false}) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!deepEquals(a[key], b[key], unordered: unordered)) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    return _unorderedEquals(a.toList(), b.toList());
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    if (unordered) return _unorderedEquals(a, b);
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

bool _unorderedEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  final used = List<bool>.filled(b.length, false);
  for (final itemA in a) {
    var found = false;
    for (var j = 0; j < b.length; j++) {
      if (!used[j] && deepEquals(itemA, b[j], unordered: true)) {
        used[j] = true;
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}
