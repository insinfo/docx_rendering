import 'dart:io';
import 'dart:typed_data';
import 'package:docx_rendering/src/docx_preview.dart';
import 'package:docx_rendering/src/document/dom.dart';
import 'package:docx_rendering/src/document/paragraph.dart';
import 'package:docx_rendering/src/document_parser.dart';
import 'package:docx_rendering/src/word_document.dart';

void main() async {
  final file = File('c:\\MyDartProjects\\docx_rendering\\test\\test.docx');
  final bytes = file.readAsBytesSync();
  
  final parser = DocumentParser();
  final doc = await WordDocument.load(bytes, parser, {'trimXmlDeclaration': true});
  
  final body = doc.documentPart!.body!;
  print('Total body elements: ${body.children!.length}');
  
  var count = 0;
  for (final el in body.children!) {
    if (el is WmlParagraph) {
      count++;
      final text = el.children!.map((c) => c.children?.map((gc) => gc.type == DomType.text ? (gc as WmlText).value : '').join('') ?? '').join('');
      
      final propsNum = (el.props as ParagraphProperties?)?.numbering;
      final styleName = el.styleName;
      final style = doc.stylesPart?.styles.firstWhere((s) => s.id == styleName, orElse: () => IDomStyle(id: ''));
      final styleNum = style?.paragraphProps?.numbering;
      
      print('Paragraph $count: "$text"');
      print('  styleName: $styleName');
      print('  el.props.numbering: id=${propsNum?.id}, level=${propsNum?.level}');
      print('  style.paragraphProps.numbering: id=${styleNum?.id}, level=${styleNum?.level}');
      
      if (count >= 10) break;
    }
  }
}
