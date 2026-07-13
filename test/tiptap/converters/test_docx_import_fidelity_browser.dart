@TestOn('browser')
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'package:docx_rendering/docx_rendering.dart';
import 'package:docx_rendering/src/docx_rendering/zip/zip_archive.dart';
import 'package:docx_rendering/src/tiptap/converters/docx_export.dart';
import 'package:docx_rendering/src/tiptap/converters/docx_import.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';
import 'package:docx_rendering/src/prosemirror/model/from_dom.dart';
import 'package:docx_rendering/src/prosemirror/model/to_dom.dart';
import 'package:web/web.dart' as web;

void main() {
  final editor = TiptapEditor(EditorOptions(extensions: const [
    DocumentExtension(),
    ParagraphExtension(),
    TextExtension(),
    BoldExtension(),
    ItalicExtension(),
    UnderlineExtension(),
    StrikeExtension(),
    TextStyleExtension(),
    HeadingExtension(),
    BulletListExtension(),
    OrderedListExtension(),
    ListItemExtension(),
    ImageExtension(),
    TableExtension(),
    TableRowExtension(),
    TableCellExtension(),
    TableHeaderExtension(),
    HardBreakExtension(),
  ]));
  final schema = editor.state.schema;

  test('achata cascata de estilos, seção e numbering de DOCX realista',
      () async {
    // Start with a package produced by the real exporter so all OPC
    // relationships/content-types are valid, then replace the three OOXML
    // parts relevant to this importer fixture.
    final seed = schema.node('doc', null, [
      schema.node('bulletList', null, [
        schema.node('listItem', null, [
          schema.node('paragraph', null, [schema.text('seed')])
        ])
      ])
    ]);
    final archive = ZipArchive.decodeBytes(await DocxExporter().export(seed));
    archive.setFile('word/styles.xml', utf8.encode(_stylesXml));
    archive.setFile('word/numbering.xml', utf8.encode(_numberingXml));
    archive.setFile('word/document.xml', utf8.encode(_documentXml));

    final word = await parseAsync(archive.encode());
    final imported = DocxImporter(word, schema).importDocument();

    expect(imported.attrs['pageWidth'], '595.30pt');
    expect(imported.attrs['pageHeight'], '841.90pt');
    expect(imported.attrs['pageMarginLeft'], '56.70pt');

    final body = imported.child(0);
    expect(body.type.name, 'paragraph');
    expect(body.attrs['styleName'], 'Textosimples');
    expect(body.attrs['textAlign'], 'justify');
    expect(body.attrs['marginTop'], '6.00pt');
    expect(body.attrs['marginBottom'], '6.00pt');
    expect(body.attrs['marginLeft'], '18.00pt');
    expect(body.attrs['textIndent'], '9.00pt');
    expect(body.attrs['lineHeight'], '1.15');
    final bodyTextStyle =
        body.child(0).marks.firstWhere((mark) => mark.type.name == 'textStyle');
    expect(bodyTextStyle.attrs['fontFamily'], contains('Arial'));
    expect(bodyTextStyle.attrs['fontSize'], '10.00pt');
    expect(bodyTextStyle.attrs['color'], '#112233');

    final headingOne = imported.child(1);
    expect(headingOne.type.name, 'orderedList');
    expect(headingOne.attrs['start'], 1);
    final headingParagraph = headingOne.child(0).child(0);
    expect(headingParagraph.attrs['numberingId'], '11');
    expect(headingParagraph.attrs['numberingFormat'], 'decimal');
    expect(
        headingParagraph.child(0).marks.any((mark) => mark.type.name == 'bold'),
        isTrue);
    expect(
        headingParagraph
            .child(0)
            .marks
            .firstWhere((mark) => mark.type.name == 'textStyle')
            .attrs['fontSize'],
        '10.00pt');

    expect(imported.child(2).textContent, 'interrupção');
    final headingTwo = imported.child(3);
    expect(headingTwo.type.name, 'orderedList');
    expect(headingTwo.attrs['start'], 2,
        reason: 'a sequência continua após um bloco não numerado');

    final bullets = imported.child(4);
    expect(bullets.type.name, 'bulletList');
    expect(bullets.childCount, 2);
    expect(bullets.child(0).child(0).textContent, 'item A');
    expect(bullets.child(1).child(0).textContent, 'item B');
    expect(bullets.child(0).attrs['numberingLabel'], '•');
    expect(bullets.child(1).attrs['numberingLabel'], '•');
    final bulletDom =
        DOMSerializer.fromSchema(schema).serializeNode(bullets) as web.Element;
    expect(
      bulletDom.querySelector('li')!.getAttribute('data-docx-numbering-label'),
      '•',
      reason: 'o marcador explícito também precisa entrar no PDF vetorial',
    );

    final direct = imported.child(5).child(0);
    expect(direct.marks.any((mark) => mark.type.name == 'bold'), isTrue);
    final directTextStyle =
        direct.marks.firstWhere((mark) => mark.type.name == 'textStyle');
    expect(directTextStyle.attrs['fontFamily'], contains('Courier New'));
    expect(directTextStyle.attrs['fontSize'], '14.00pt');

    final vmlBox = imported.child(7);
    expect(vmlBox.type.name, 'table');
    expect(vmlBox.attrs['position'], 'absolute');
    expect(vmlBox.attrs['right'], '0');
    expect(vmlBox.attrs['width'], '130.5pt');
    expect(vmlBox.attrs['height'], '59.25pt');
    expect(vmlBox.attrs['fontFamily'], contains('Arial'));
    expect(vmlBox.attrs['fontSize'], '10.00pt');
    expect(vmlBox.attrs['lineHeight'], 'normal');
    expect(vmlBox.attrs['textBox'], isTrue);
    expect(vmlBox.textContent, contains('Processo 44505/2025'));
    expect(vmlBox.child(0).child(0).attrs['borderTop'], contains('solid'));

    final table = imported.children
        .firstWhere((node) => node.type.name == 'table' && node != vmlBox);
    expect(table.attrs['columnWidths'], [67, 133]);
    expect(table.child(0).attrs['columnWidths'], [67, 133]);
    expect(table.child(0).attrs['height'], '14.50pt');
    expect(table.child(0).attrs['heightRule'], 'atLeast');
    expect(table.child(1).attrs['height'], '18.00pt');
    expect(table.child(1).attrs['heightRule'], 'exact');
    expect(table.child(0).child(0).attrs['width'], isNull,
        reason: 'tcW=0 não pode colapsar a coluna definida por tblGrid');
    expect(table.child(0).child(0).attrs['rowspan'], 2);
    expect(table.child(1).childCount, 1,
        reason:
            'continuação de vMerge deve usar rowspan, não célula duplicada');

    final tableDom =
        DOMSerializer.fromSchema(schema).serializeNode(table) as web.Element;
    expect(tableDom.getAttribute('data-column-widths'), '67,133');
    expect(
      (tableDom.querySelector('tr') as web.HTMLElement)
          .style
          .getPropertyValue('grid-template-columns'),
      contains('67px 133px'),
    );
    final importedRows = tableDom.querySelectorAll('tr');
    expect(
      (importedRows.item(0)! as web.HTMLElement).style.minHeight,
      '14.5pt',
    );
    expect(
      (importedRows.item(0)! as web.Element).getAttribute('data-height-rule'),
      'atLeast',
    );
    expect(
      (importedRows.item(1)! as web.HTMLElement).style.height,
      '18pt',
    );
    expect(
      (importedRows.item(1)! as web.Element).getAttribute('data-height-rule'),
      'exact',
    );
    expect(
      ((tableDom.querySelectorAll('tr').item(1)! as web.Element)
              .querySelector('td') as web.HTMLElement)
          .style
          .getPropertyValue('grid-column-start'),
      '2',
    );
  });

  test('preserva tblGrid subpixelar sem produzir track ou colwidth zero',
      () async {
    final seed = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('seed')])
    ]);
    final archive = ZipArchive.decodeBytes(await DocxExporter().export(seed));
    archive.setFile(
        'word/document.xml', utf8.encode(_subpixelTableDocumentXml));

    final word = await parseAsync(archive.encode());
    final imported = DocxImporter(word, schema).importDocument();
    final table =
        imported.children.firstWhere((node) => node.type.name == 'table');
    final row = table.child(0);
    final firstCell = row.child(0);
    final secondCell = row.child(1);

    expect(table.attrs['columnWidths'], [46, 3, 584, 1]);
    expect(row.attrs['columnWidths'], [46, 3, 584, 1]);
    expect(firstCell.attrs['colspan'], 2);
    expect(firstCell.attrs['colwidth'], [46, 3]);
    expect(secondCell.attrs['colspan'], 2);
    expect(secondCell.attrs['colwidth'], [584, 1]);

    final tableDom =
        DOMSerializer.fromSchema(schema).serializeNode(table) as web.Element;
    final rowDom = tableDom.querySelector('tr') as web.HTMLElement;
    expect(
      rowDom.style.getPropertyValue('grid-template-columns'),
      contains('46px 3px 584px 1px'),
    );
    expect(tableDom.querySelector('[data-colwidth="584,1"]'), isNotNull);
  });

  test('preserva tracking negativo de run como letterSpacing', () async {
    final seed = schema.node('doc', null, [
      schema.node('paragraph', null, [schema.text('seed')])
    ]);
    final archive = ZipArchive.decodeBytes(await DocxExporter().export(seed));
    archive.setFile(
      'word/document.xml',
      utf8.encode(_letterSpacingDocumentXml),
    );

    final word = await parseAsync(archive.encode());
    final imported = DocxImporter(word, schema).importDocument();
    final text = imported.child(0).child(0);
    final textStyle =
        text.marks.firstWhere((mark) => mark.type.name == 'textStyle');

    expect(textStyle.attrs['letterSpacing'], '-0.10pt');

    final paragraphDom = DOMSerializer.fromSchema(schema)
        .serializeNode(imported.child(0)) as web.HTMLElement;
    final span = paragraphDom.querySelector('span') as web.HTMLElement;
    expect(span.style.letterSpacing, '-0.1pt');

    final host = web.document.createElement('div') as web.HTMLElement
      ..style.position = 'absolute'
      ..style.visibility = 'hidden'
      ..append(paragraphDom);
    web.document.body!.append(host);
    addTearDown(() => host.remove());

    final computed = web.window.getComputedStyle(span).letterSpacing;
    expect(
      double.parse(computed.replaceAll('px', '')),
      closeTo(-0.133333, 0.001),
      reason: '2 twips = 0,10 pt = 0,133333 px no CSS do navegador',
    );
  });

  test('resolve labels hierárquicos Word sem afetar listas comuns', () async {
    final seed = schema.node('doc', null, [
      schema.node('orderedList', null, [
        schema.node('listItem', null, [
          schema.node('paragraph', null, [schema.text('seed')])
        ])
      ])
    ]);
    final archive = ZipArchive.decodeBytes(await DocxExporter().export(seed));
    archive.setFile(
      'word/numbering.xml',
      utf8.encode(_hierarchicalNumberingXml),
    );
    archive.setFile(
      'word/document.xml',
      utf8.encode(_hierarchicalListDocumentXml),
    );

    final word = await parseAsync(archive.encode());
    final imported = DocxImporter(word, schema).importDocument();
    final numberedItems = imported.children
        .where((node) => node.type.name == 'orderedList')
        .expand((list) => list.children)
        .toList(growable: false);

    expect(
      numberedItems.map((item) => item.attrs['numberingLabel']),
      ['1.', '1.1.', '1.1.a)', '1.2.', '2.', '3.'],
    );
    expect(
      numberedItems.map((item) => item.attrs['numberingLevel']),
      [0, 1, 2, 1, 0, 0],
    );
    expect(imported.children[5].textContent, 'interrupção');
    expect(imported.children[6].attrs['start'], 3,
        reason: 'o contador Word continua depois de bloco não numerado');

    final firstListDom = DOMSerializer.fromSchema(schema)
        .serializeNode(imported.child(0)) as web.Element;
    final firstItemDom = firstListDom.querySelector('li')!;
    expect(firstItemDom.getAttribute('data-docx-numbering-label'), '1.');
    expect(firstItemDom.getAttribute('data-docx-numbering-level'), '0');

    final wrapper = web.document.createElement('div')..append(firstListDom);
    final reparsed = DOMParser.fromSchema(schema).parse(wrapper);
    expect(reparsed.child(0).child(0).attrs['numberingLabel'], '1.');
    expect(reparsed.child(0).child(0).attrs['numberingLevel'], 0);

    final ordinaryList = schema.node('orderedList', null, [
      schema.node('listItem', null, [
        schema.node('paragraph', null, [schema.text('lista comum')])
      ])
    ]);
    final ordinaryDom = DOMSerializer.fromSchema(schema)
        .serializeNode(ordinaryList) as web.Element;
    expect(
      ordinaryDom
          .querySelector('li')!
          .hasAttribute('data-docx-numbering-label'),
      isFalse,
      reason: 'listas criadas no editor/Quill mantêm o marcador nativo',
    );
  });
}

const _stylesXml = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/></w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr/></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:customStyle="1" w:styleId="Textosimples">
    <w:name w:val="Texto simples"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="120" w:after="120" w:line="276" w:lineRule="auto"/><w:ind w:left="360" w:firstLine="180"/><w:jc w:val="both"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:color w:val="112233"/><w:sz w:val="20"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:customStyle="1" w:styleId="Nivel01">
    <w:name w:val="Nivel 01"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="11"/></w:numPr><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="auto"/><w:sz w:val="20"/></w:rPr>
  </w:style>
</w:styles>''';

const _numberingXml =
    r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="27"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
  <w:abstractNum w:abstractNumId="6"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl></w:abstractNum>
  <w:num w:numId="11"><w:abstractNumId w:val="27"/></w:num>
  <w:num w:numId="13"><w:abstractNumId w:val="6"/></w:num>
</w:numbering>''';

const _documentXml = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body>
  <w:p><w:pPr><w:pStyle w:val="Textosimples"/></w:pPr><w:r><w:t>corpo justificado</w:t></w:r></w:p>
  <w:p><w:pPr><w:pStyle w:val="Nivel01"/></w:pPr><w:r><w:t>Título A</w:t></w:r></w:p>
  <w:p><w:pPr><w:pStyle w:val="Textosimples"/></w:pPr><w:r><w:t>interrupção</w:t></w:r></w:p>
  <w:p><w:pPr><w:pStyle w:val="Nivel01"/></w:pPr><w:r><w:t>Título B</w:t></w:r></w:p>
  <w:p><w:pPr><w:pStyle w:val="Textosimples"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="13"/></w:numPr></w:pPr><w:r><w:t>item A</w:t></w:r></w:p>
  <w:p><w:pPr><w:pStyle w:val="Textosimples"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="13"/></w:numPr></w:pPr><w:r><w:t>item B</w:t></w:r></w:p>
  <w:p><w:pPr><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:b/><w:sz w:val="28"/></w:rPr></w:pPr><w:r><w:t>formatação direta herdada</w:t></w:r></w:p>
  <w:p><w:r><w:pict><v:shape style="position:absolute;margin-top:-7.8pt;width:130.5pt;height:59.25pt;mso-position-horizontal:right"><v:textbox><w:txbxContent><w:p><w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="20"/></w:rPr><w:t>Processo 44505/2025</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>
  <w:tbl>
    <w:tblPr><w:tblW w:w="3000" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="8" w:color="333333"/><w:left w:val="single" w:sz="8" w:color="333333"/><w:bottom w:val="single" w:sz="8" w:color="333333"/><w:right w:val="single" w:sz="8" w:color="333333"/><w:insideH w:val="single" w:sz="8" w:color="333333"/><w:insideV w:val="single" w:sz="8" w:color="333333"/></w:tblBorders></w:tblPr>
    <w:tblGrid><w:gridCol w:w="1000"/><w:gridCol w:w="2000"/></w:tblGrid>
    <w:tr><w:trPr><w:trHeight w:val="290"/></w:trPr>
      <w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc>
      <w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc>
    </w:tr>
    <w:tr><w:trPr><w:trHeight w:val="360" w:hRule="exact"/></w:trPr>
      <w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:vMerge/></w:tcPr><w:p/></w:tc>
      <w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr><w:p><w:r><w:t>B2</w:t></w:r></w:p></w:tc>
    </w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1418" w:right="1134" w:bottom="1418" w:left="1134" w:header="426" w:footer="454" w:gutter="0"/></w:sectPr>
</w:body></w:document>''';

const _subpixelTableDocumentXml =
    r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
  <w:tbl>
    <w:tblPr><w:tblW w:w="9500" w:type="dxa"/></w:tblPr>
    <w:tblGrid>
      <w:gridCol w:w="683"/>
      <w:gridCol w:w="44"/>
      <w:gridCol w:w="8766"/>
      <w:gridCol w:w="6"/>
    </w:tblGrid>
    <w:tr>
      <w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr><w:p><w:r><w:t>Chave</w:t></w:r></w:p></w:tc>
      <w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr><w:p><w:r><w:t>Descrição longa</w:t></w:r></w:p></w:tc>
    </w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1418" w:right="1134" w:bottom="1418" w:left="1134"/></w:sectPr>
</w:body></w:document>''';

const _letterSpacingDocumentXml =
    r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
  <w:p><w:r><w:rPr><w:spacing w:val="-2"/></w:rPr><w:t>tracking negativo</w:t></w:r></w:p>
  <w:sectPr/>
</w:body></w:document>''';

const _hierarchicalNumberingXml =
    r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="42">
    <w:lvl w:ilvl="0"><w:start w:val="9"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl>
    <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1.%2."/></w:lvl>
    <w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/><w:lvlText w:val="%1.%2.%3)"/></w:lvl>
  </w:abstractNum>
  <w:num w:numId="21"><w:abstractNumId w:val="42"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>
  <w:num w:numId="22"><w:abstractNumId w:val="42"/></w:num>
</w:numbering>''';

const _hierarchicalListDocumentXml =
    r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="21"/></w:numPr></w:pPr><w:r><w:t>um</w:t></w:r></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="21"/></w:numPr></w:pPr><w:r><w:t>um um</w:t></w:r></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="2"/><w:numId w:val="21"/></w:numPr></w:pPr><w:r><w:t>um um a</w:t></w:r></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="21"/></w:numPr></w:pPr><w:r><w:t>um dois</w:t></w:r></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="21"/></w:numPr></w:pPr><w:r><w:t>dois</w:t></w:r></w:p>
  <w:p><w:r><w:t>interrupção</w:t></w:r></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="21"/></w:numPr></w:pPr><w:r><w:t>três</w:t></w:r></w:p>
  <w:sectPr/>
</w:body></w:document>''';
