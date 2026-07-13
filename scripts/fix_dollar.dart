import 'dart:io';

void main() {
  final dir = Directory('lib/src/prosemirror/state');
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      if (content.contains(r'\$')) {
        file.writeAsStringSync(content.replaceAll(r'\$', r'$'));
      }
    }
  }
}
