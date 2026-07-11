import 'dart:io';

void main() {
  final dir = Directory('lib/src/prosemirror/state');
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      
      content = content.replaceAll(r'$config', 'configObj');
      content = content.replaceAll(r'$from', 'fromRes');
      content = content.replaceAll(r'$to', 'toRes');
      content = content.replaceAll(r'$anchor', 'anchorRes');
      content = content.replaceAll(r'$head', 'headRes');
      content = content.replaceAll(r'$pos', 'posRes');
      
      // also fix mapResult returning MapResult
      content = content.replaceAll('StepMap mapped = mapping.mapResult', 'MapResult mapped = mapping.mapResult');
      
      // fix mapResult import
      if (file.path.endsWith('selection.dart') && !content.contains('MapResult')) {
        // MapResult is defined in map.dart which is exported by transform/index.dart
      }

      file.writeAsStringSync(content);
    }
  }
}
