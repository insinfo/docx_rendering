import 'dart:io';

void main() {
  var tsFile = File('referencias/docxjs-master/src/document-parser.ts');
  var tsContent = tsFile.readAsStringSync();

  // Basic replacements
  var dartContent = tsContent
      .replaceAll('export class ', 'class ')
      .replaceAll('export interface ', 'class ')
      .replaceAll('export function ', 'function ')
      .replaceAll('export var ', 'var ')
      .replaceAll('export const ', 'const ')
      .replaceAll(' = {} as any;', ' = {};')
      .replaceAll(' = <any>{};', ' = {};')
      .replaceAll(' = <any>[];', ' = [];')
      .replaceAll(': any', '')
      .replaceAll(': string', ': String')
      .replaceAll(': boolean', ': bool')
      .replaceAll(': number', ': double')
      .replaceAll(': Element', ': web.Element')
      .replaceAll(': Node', ': web.Node')
      .replaceAll('Array<', 'List<')
      .replaceAll('[]', 'List')
      .replaceAll(' Record<', ' Map<')
      .replaceAll('import ', '// import ')
      .replaceAll('xml.', 'xmlParser.')
      .replaceAll('xmlUtil.', 'xmlParser.')
      .replaceAll('console.warn', 'print')
      .replaceAll('console.log', 'print')
      .replaceAll('===', '==')
      .replaceAll('!==', '!=')
      .replaceAll('let ', 'var ')
      .replaceAll('const ', 'final ')
      .replaceAll('of xmlParser.elements', 'in xmlParser.elements');

  // Fix function signatures (basic)
  dartContent = dartContent.replaceAllMapped(
      RegExp(r'(\w+)\(([^)]+)\):\s*([a-zA-Z<>\[\]]+)\s*\{'),
      (match) => '${match.group(3)} ${match.group(1)}(${match.group(2)}) {');
  
  dartContent = dartContent.replaceAllMapped(
      RegExp(r'(\w+)\(([^)]+)\)\s*\{'),
      (match) => '${match.group(1)}(${match.group(2)}) {');

  // Prefix with imports
  var header = '''
import 'package:web/web.dart' as web;
import 'document/dom.dart';
import 'document/paragraph.dart';
import 'document/section.dart';
import 'document/run.dart';
import 'document/bookmarks.dart';
import 'document/style.dart';
import 'document/fields.dart';
import 'document/common.dart';
import 'vml/vml.dart';
import 'comments/elements.dart';
import 'parser/xml_parser.dart';
import 'utils.dart';
import 'document/document.dart';

final xmlParser = globalXmlParser;

''';

  File('lib/src/document_parser.dart').writeAsStringSync(header + dartContent);
  print('Done parsing document-parser.ts');
}
