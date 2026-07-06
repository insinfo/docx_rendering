/// Ported from docxjs src/utils.ts
/// Utility functions for the docx rendering library.

/// Escapes a class name for use as a CSS class.
String escapeClassName(String? className) {
  if (className == null) return '';
  return className
      .replaceAll(RegExp(r'[ .]+'), '-')
      .replaceAll(RegExp(r'[&]+'), 'and')
      .toLowerCase();
}

/// Encloses a font family name in quotes if it contains spaces.
String encloseFontFamily(String fontFamily) {
  if (RegExp(r'''^[^"'].*\s.*[^"']$''').hasMatch(fontFamily)) {
    return "'$fontFamily'";
  }
  return fontFamily;
}

/// Splits a path into [folder, fileName].
(String, String) splitPath(String path) {
  final si = path.lastIndexOf('/') + 1;
  final folder = si == 0 ? '' : path.substring(0, si);
  final fileName = si == 0 ? path : path.substring(si);
  return (folder, fileName);
}

/// Resolves a relative [path] against a [base] path.
String resolvePath(String path, String base) {
  try {
    const prefix = 'http://docx/';
    final url = Uri.parse('$prefix$base').resolve(path).toString();
    return url.substring(prefix.length);
  } catch (_) {
    return '$base$path';
  }
}

/// Creates a map from an array, using the given [by] function as the key.
Map<K, T> keyBy<K, T>(List<T> array, K Function(T) by) {
  final result = <K, T>{};
  for (final x in array) {
    result[by(x)] = x;
  }
  return result;
}

/// Converts bytes to a base64 data URL.
/// In the web context, this would use FileReader.
/// For now, returns a data URI from the bytes directly.
String bytesToBase64DataUrl(List<int> bytes, [String mimeType = '']) {
  final b64 = Uri.dataFromBytes(bytes, mimeType: mimeType).toString();
  return b64;
}

/// Deep merges maps, mutating [target].
Map<String, dynamic> mergeDeep(
    Map<String, dynamic> target, Map<String, dynamic> source) {
  for (final key in source.keys) {
    final sourceVal = source[key];
    final targetVal = target[key];
    if (sourceVal is Map<String, dynamic> && targetVal is Map<String, dynamic>) {
      mergeDeep(targetVal, sourceVal);
    } else {
      target[key] = sourceVal;
    }
  }
  return target;
}

/// Parses inline CSS rules into a map.
Map<String, String> parseCssRules(String text) {
  final result = <String, String>{};
  for (final rule in text.split(';')) {
    final parts = rule.split(':');
    if (parts.length >= 2) {
      result[parts[0].trim()] = parts.sublist(1).join(':').trim();
    }
  }
  return result;
}

/// Formats a CSS rules map back into a string.
String formatCssRules(Map<String, String> style) {
  return style.entries.map((e) => '${e.key}: ${e.value}').join(';');
}

/// Ensures the value is a list.
List<T> asArray<T>(dynamic val) {
  if (val is List<T>) return val;
  if (val is T) return [val];
  return <T>[];
}

/// Clamps a value between [min] and [max].
num clamp(num val, num min, num max) {
  return min > val ? min : (max < val ? max : val);
}

/// Extension for firstWhereOrNull (avoids depending on collection package).
extension ListFirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

String classNameOfCnfStyle(dynamic c) {
  final val = c is String ? c : (c.attributes['val']?.value ?? '');
  final classes = [
    'first-row', 'last-row', 'first-col', 'last-col',
    'odd-col', 'even-col', 'odd-row', 'even-row',
    'ne-cell', 'nw-cell', 'se-cell', 'sw-cell'
  ];

  final result = <String>[];
  for (var i = 0; i < classes.length; i++) {
    if (i < val.length && val[i] == '1') {
      result.add(classes[i]);
    }
  }
  return result.join(' ');
}

