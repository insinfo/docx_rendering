import 'dart:io';
import 'package:docx_rendering/src/zip/zip_archive.dart';

void main() {
  final file = File('c:\\MyDartProjects\\docx_rendering\\test\\test.docx');
  final bytes = file.readAsBytesSync();
  final zip = ZipArchive.decodeBytes(bytes);
  final docXml = zip.readString('word/document.xml')!;

  print('document.xml length: ${docXml.length}');
  
  final query = 'básicas';
  final idx = docXml.indexOf(query);
  if (idx == -1) {
    print('Text "$query" not found in document.xml');
    return;
  }
  
  // Print 600 characters before and 600 characters after
  final start = (idx - 600).clamp(0, docXml.length);
  final end = (idx + 600).clamp(0, docXml.length);
  
  print('--- document.xml context around "$query" ---');
  print(docXml.substring(start, end));
}
