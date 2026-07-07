import 'dart:io';
import 'package:docx_rendering/src/zip/zip_archive.dart';

void main() {
  final file = File('c:\\MyDartProjects\\docx_rendering\\test\\test.docx');
  final bytes = file.readAsBytesSync();
  final zip = ZipArchive.decodeBytes(bytes);
  final numberingXml = zip.readString('word/numbering.xml');
  
  if (numberingXml == null) {
    print('word/numbering.xml not found!');
    return;
  }
  
  print('numbering.xml length: ${numberingXml.length}');
  
  // Find all pStyle tags in numbering.xml
  var start = 0;
  while (true) {
    final idx = numberingXml.indexOf('pStyle', start);
    if (idx == -1) break;
    
    final contextStart = (idx - 150).clamp(0, numberingXml.length);
    final contextEnd = (idx + 150).clamp(0, numberingXml.length);
    print('--- Occurrence ---');
    print(numberingXml.substring(contextStart, contextEnd));
    start = idx + 6;
  }
}
