/// Exportação DOCX (§5.1 do plano): travessia direta do AST ProseMirror
/// emitindo WordprocessingML e empacotando com o `ZipArchive` próprio do
/// repositório — **zero dependências além de `package:web`** (e aqui nem
/// ela: o gerador é Dart puro e roda na VM, JS e Wasm).
///
/// Mapa implementado:
/// - `paragraph`                → `<w:p>` (+ `<w:jc>` para alinhamento)
/// - `heading[level]`           → `<w:pStyle w:val="Heading{n}"/>`
/// - `bulletList`/`orderedList` → `<w:numPr>` + `word/numbering.xml`
/// - `table`                    → `<w:tbl>` com grid, bordas e gridSpan
/// - `image` (data URI)         → `<w:drawing>` + `word/media/*` + rels
/// - `hardBreak`                → `<w:br/>`
/// - marcas bold/italic/underline/strike/textStyle(color/font/size)/highlight
///
/// Perdas documentadas (plano §9): links viram texto simples,
/// `horizontalRule` vira parágrafo vazio, rowspan não é emitido
/// (colspan sim, via gridSpan), imagens por URL http(s) são ignoradas
/// (exigiriam fetch assíncrono).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../docx_rendering/zip/zip_archive.dart';
import '../../prosemirror/model/index.dart' as model;

typedef DocxExportProgress = void Function(int done, int total);

class DocxExporter {
  /// Blocos processados entre cada yield do event loop (pipeline
  /// cooperativo — requisito R2 sem travar a UI).
  final int chunkSize;
  final DocxExportProgress? onProgress;

  DocxExporter({this.chunkSize = 50, this.onProgress});

  /// Exporta o documento ProseMirror para bytes de um arquivo .docx.
  Future<Uint8List> export(model.PMNode pmDoc) async {
    final writer = _DocumentWriter(pmDoc.attrs);
    final blocks = pmDoc.children;
    for (var i = 0; i < blocks.length; i++) {
      writer.writeBlock(blocks[i]);
      if ((i + 1) % chunkSize == 0) {
        onProgress?.call(i + 1, blocks.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgress?.call(blocks.length, blocks.length);
    return writer.package();
  }
}

/// Uma imagem embutida (extraída de um data URI).
class _MediaImage {
  final String filename;
  final String relId;
  final Uint8List bytes;

  _MediaImage(this.filename, this.relId, this.bytes);
}

class _DocumentWriter {
  final Map<String, dynamic> _documentAttrs;
  final StringBuffer _body = StringBuffer();
  final List<_MediaImage> _images = [];
  var _usesBulletList = false;
  var _usesOrderedList = false;
  var _drawingId = 0;

  _DocumentWriter(this._documentAttrs);

  // ------------------------------------------------------------- blocos

  void writeBlock(model.PMNode node) {
    switch (node.type.name) {
      case 'paragraph':
        _writeParagraph(node);
        break;
      case 'heading':
        final level = (node.attrs['level'] as int? ?? 1).clamp(1, 9);
        _writeParagraph(node, styleId: 'Heading$level');
        break;
      case 'bulletList':
        _usesBulletList = true;
        _writeList(node, numId: 1);
        break;
      case 'orderedList':
        _usesOrderedList = true;
        _writeList(node, numId: 2);
        break;
      case 'image':
        _body.write('<w:p><w:r>');
        _writeDrawing(node);
        _body.write('</w:r></w:p>');
        break;
      case 'horizontalRule':
        _body.write('<w:p/>');
        break;
      case 'table':
        _writeTable(node);
        break;
      default:
        if (node.isTextblock) {
          _writeParagraph(node);
        } else {
          for (final child in node.children) {
            writeBlock(child);
          }
        }
    }
  }

  void _writeList(model.PMNode list, {required int numId}) {
    for (final item in list.children) {
      var first = true;
      for (final block in item.children) {
        final name = block.type.name;
        if (name == 'bulletList' || name == 'orderedList') {
          // Lista aninhada: achata um nível (perda documentada).
          writeBlock(block);
          continue;
        }
        if (!block.isTextblock) continue;
        _writeParagraph(block,
            styleId: first ? 'ListParagraph' : null,
            numId: first ? numId : null);
        first = false;
      }
    }
  }

  void _writeParagraph(model.PMNode block, {String? styleId, int? numId}) {
    _body.write('<w:p>');
    final align = _jcFor(block.attrs['textAlign']);
    final indentLeft = _lengthTwips(block.attrs['marginLeft']);
    final indentRight = _lengthTwips(block.attrs['marginRight']);
    final textIndent = _lengthTwips(block.attrs['textIndent']);
    final tabStops = block.attrs['tabStops'];
    if (styleId != null ||
        numId != null ||
        align != null ||
        indentLeft != null ||
        indentRight != null ||
        textIndent != null ||
        tabStops is List) {
      _body.write('<w:pPr>');
      if (styleId != null) _body.write('<w:pStyle w:val="$styleId"/>');
      if (numId != null) {
        _body.write(
            '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>');
      }
      if (align != null) _body.write('<w:jc w:val="$align"/>');
      if (indentLeft != null || indentRight != null || textIndent != null) {
        final attributes = StringBuffer();
        if (indentLeft != null) attributes.write(' w:left="$indentLeft"');
        if (indentRight != null) attributes.write(' w:right="$indentRight"');
        if (textIndent != null) {
          if (textIndent < 0) {
            attributes.write(' w:hanging="${-textIndent}"');
          } else {
            attributes.write(' w:firstLine="$textIndent"');
          }
        }
        _body.write('<w:ind$attributes/>');
      }
      if (tabStops is List && tabStops.isNotEmpty) {
        _body.write('<w:tabs>');
        for (final stop in tabStops) {
          if (stop is! Map) continue;
          final position = _lengthTwips(stop['position']);
          if (position == null) continue;
          final type = '${stop['type'] ?? 'left'}';
          final leader = '${stop['leader'] ?? 'none'}';
          _body.write(
              '<w:tab w:val="$type" w:leader="$leader" w:pos="$position"/>');
        }
        _body.write('</w:tabs>');
      }
      _body.write('</w:pPr>');
    }
    for (final child in block.children) {
      if (child.isText) {
        _writeRun(child.text!, child.marks);
      } else if (child.type.name == 'hardBreak') {
        _body.write('<w:r><w:br/></w:r>');
      } else if (child.type.name == 'image') {
        _body.write('<w:r>');
        _writeDrawing(child);
        _body.write('</w:r>');
      }
    }
    _body.write('</w:p>');
  }

  void _writeRun(String text, List<model.Mark> marks) {
    final props = _runProperties(marks);
    final parts = text.split('\t');
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      if (part.isNotEmpty) {
        _body.write('<w:r>');
        if (props.isNotEmpty) _body.write('<w:rPr>$props</w:rPr>');
        _body.write('<w:t xml:space="preserve">${_escape(part)}</w:t></w:r>');
      }
      if (index < parts.length - 1) {
        _body.write('<w:r>');
        if (props.isNotEmpty) _body.write('<w:rPr>$props</w:rPr>');
        _body.write('<w:tab/></w:r>');
      }
    }
  }

  String _runProperties(List<model.Mark> marks) {
    final props = StringBuffer();
    for (final mark in marks) {
      switch (mark.type.name) {
        case 'bold':
          props.write('<w:b/>');
          break;
        case 'italic':
          props.write('<w:i/>');
          break;
        case 'underline':
          props.write('<w:u w:val="single"/>');
          break;
        case 'strike':
          props.write('<w:strike/>');
          break;
        case 'code':
          props.write('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>');
          break;
        case 'textStyle':
          final color = _parseColorHex(mark.attrs['color']);
          if (color != null) props.write('<w:color w:val="$color"/>');
          final family = mark.attrs['fontFamily'];
          if (family is String && family.isNotEmpty) {
            final name =
                _escape(family.split(',').first.trim().replaceAll('"', ''));
            props.write('<w:rFonts w:ascii="$name" w:hAnsi="$name"/>');
          }
          final halfPoints = _fontSizeHalfPoints(mark.attrs['fontSize']);
          if (halfPoints != null) {
            props.write('<w:sz w:val="$halfPoints"/>'
                '<w:szCs w:val="$halfPoints"/>');
          }
          break;
        case 'highlight':
          props.write(
              '<w:highlight w:val="${_highlightFor(mark.attrs['color'])}"/>');
          break;
      }
    }
    return props.toString();
  }

  void _writeTable(model.PMNode table) {
    var colCount = 0;
    for (final row in table.children) {
      var cols = 0;
      for (final cell in row.children) {
        cols += (cell.attrs['colspan'] as int? ?? 1);
      }
      if (cols > colCount) colCount = cols;
    }
    if (table.childCount == 0 || colCount == 0) return;

    const border = 'w:val="single" w:sz="4" w:space="0" w:color="auto"';
    _body.write('<w:tbl><w:tblPr>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '<w:top $border/><w:left $border/><w:bottom $border/>'
        '<w:right $border/><w:insideH $border/><w:insideV $border/>'
        '</w:tblBorders>'
        '</w:tblPr><w:tblGrid>');
    for (var c = 0; c < colCount; c++) {
      _body.write('<w:gridCol/>');
    }
    _body.write('</w:tblGrid>');

    for (final row in table.children) {
      _body.write('<w:tr>');
      for (final cell in row.children) {
        final colspan = cell.attrs['colspan'] as int? ?? 1;
        _body.write('<w:tc><w:tcPr>');
        if (colspan > 1) {
          _body.write('<w:gridSpan w:val="$colspan"/>');
        }
        _body.write('</w:tcPr>');
        var wroteBlock = false;
        for (final block in cell.children) {
          if (!block.isTextblock) continue;
          _writeParagraph(block);
          wroteBlock = true;
        }
        // Célula DOCX exige ao menos um parágrafo.
        if (!wroteBlock) _body.write('<w:p/>');
        _body.write('</w:tc>');
      }
      _body.write('</w:tr>');
    }
    _body.write('</w:tbl>');
  }

  // ------------------------------------------------------------ imagens

  void _writeDrawing(model.PMNode imageNode) {
    final data = _decodeDataUri(imageNode.attrs['src']);
    if (data == null) return;
    final (bytes, extension) = data;
    final index = _images.length + 1;
    final relId = 'rIdImage$index';
    _images.add(_MediaImage('image$index.$extension', relId, bytes));

    final widthPx = _parsePx(imageNode.attrs['width']) ?? 300;
    final heightPx = _parsePx(imageNode.attrs['height']) ?? 200;
    // CSS px → EMU (1px = 9525 EMU a 96dpi).
    final cx = (widthPx * 9525).round();
    final cy = (heightPx * 9525).round();
    final id = ++_drawingId;

    _body.write('<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:docPr id="$id" name="Imagem $id"/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$id" name="Imagem $id"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>');
  }

  (Uint8List, String)? _decodeDataUri(dynamic src) {
    if (src is! String) return null;
    final match = RegExp(r'^data:image/([a-zA-Z+]+);base64,(.*)$', dotAll: true)
        .firstMatch(src);
    if (match == null) return null;
    final subtype = match.group(1)!.toLowerCase();
    final extension = switch (subtype) {
      'jpeg' || 'jpg' => 'jpeg',
      'gif' => 'gif',
      'bmp' => 'bmp',
      _ => 'png',
    };
    try {
      return (base64Decode(match.group(2)!.trim()), extension);
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------- empacotar

  /// Monta o pacote OPC (.docx) com as partes geradas.
  Uint8List package() {
    final archive = ZipArchive();
    void put(String name, String content) =>
        archive.setFile(name, utf8.encode(content));

    put('[Content_Types].xml', _contentTypesXml());
    put('_rels/.rels', _packageRelsXml());
    put('word/document.xml', _documentXml());
    put('word/styles.xml', _stylesXml());
    put('word/settings.xml', _settingsXml());
    if (_usesBulletList || _usesOrderedList) {
      put('word/numbering.xml', _numberingXml());
    }
    put('word/_rels/document.xml.rels', _documentRelsXml());
    for (final image in _images) {
      archive.setFile('word/media/${image.filename}', image.bytes);
    }
    return archive.encode();
  }

  String _documentXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document'
      ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
      ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
      ' xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
      '<w:body>$_body'
      '${_sectionPropertiesXml()}'
      '</w:body></w:document>';

  String _sectionPropertiesXml() {
    final width = _lengthTwips(_documentAttrs['pageWidth']) ?? 11906;
    final height = _lengthTwips(_documentAttrs['pageHeight']) ?? 16838;
    final top = _lengthTwips(_documentAttrs['pageMarginTop']) ?? 1440;
    final right = _lengthTwips(_documentAttrs['pageMarginRight']) ?? 1440;
    final bottom = _lengthTwips(_documentAttrs['pageMarginBottom']) ?? 1440;
    final left = _lengthTwips(_documentAttrs['pageMarginLeft']) ?? 1440;
    final header = _lengthTwips(_documentAttrs['pageMarginHeader']) ?? 708;
    final footer = _lengthTwips(_documentAttrs['pageMarginFooter']) ?? 708;
    final gutter = _lengthTwips(_documentAttrs['pageMarginGutter']) ?? 0;
    final orientation = _documentAttrs['pageOrientation'] == 'landscape'
        ? ' w:orient="landscape"'
        : '';
    return '<w:sectPr><w:pgSz w:w="$width" w:h="$height"$orientation/>'
        '<w:pgMar w:top="$top" w:right="$right" w:bottom="$bottom" '
        'w:left="$left" w:header="$header" w:footer="$footer" '
        'w:gutter="$gutter"/></w:sectPr>';
  }

  String _contentTypesXml() {
    final overrides = StringBuffer();
    overrides.write('<Override PartName="/word/document.xml" ContentType='
        '"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>');
    overrides.write('<Override PartName="/word/styles.xml" ContentType='
        '"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>');
    overrides.write('<Override PartName="/word/settings.xml" ContentType='
        '"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>');
    if (_usesBulletList || _usesOrderedList) {
      overrides.write('<Override PartName="/word/numbering.xml" ContentType='
          '"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType='
        '"application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="png" ContentType="image/png"/>'
        '<Default Extension="jpeg" ContentType="image/jpeg"/>'
        '<Default Extension="gif" ContentType="image/gif"/>'
        '<Default Extension="bmp" ContentType="image/bmp"/>'
        '$overrides</Types>';
  }

  String _packageRelsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type='
      '"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"'
      ' Target="word/document.xml"/></Relationships>';

  String _documentRelsXml() {
    final rels = StringBuffer();
    rels.write('<Relationship Id="rIdStyles" Type='
        '"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"'
        ' Target="styles.xml"/>');
    rels.write('<Relationship Id="rIdSettings" Type='
        '"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"'
        ' Target="settings.xml"/>');
    if (_usesBulletList || _usesOrderedList) {
      rels.write('<Relationship Id="rIdNumbering" Type='
          '"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering"'
          ' Target="numbering.xml"/>');
    }
    for (final image in _images) {
      rels.write('<Relationship Id="${image.relId}" Type='
          '"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'
          ' Target="media/${image.filename}"/>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>';
  }

  String _stylesXml() {
    final styles = StringBuffer();
    styles.write('<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/></w:style>');
    // Tamanhos padrão do Word para Heading 1..6 (half-points).
    const headingSizes = [32, 26, 24, 22, 22, 22];
    for (var level = 1; level <= 9; level++) {
      final halfPoints = level <= 6 ? headingSizes[level - 1] : 22;
      styles.write('<w:style w:type="paragraph" w:styleId="Heading$level">'
          '<w:name w:val="heading $level"/>'
          '<w:basedOn w:val="Normal"/>'
          '<w:pPr><w:outlineLvl w:val="${level - 1}"/></w:pPr>'
          '<w:rPr><w:b/><w:sz w:val="$halfPoints"/></w:rPr>'
          '</w:style>');
    }
    styles.write('<w:style w:type="paragraph" w:styleId="ListParagraph">'
        '<w:name w:val="List Paragraph"/>'
        '<w:basedOn w:val="Normal"/>'
        '<w:pPr><w:ind w:left="720"/></w:pPr></w:style>');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w='
        '"http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '$styles</w:styles>';
  }

  String _settingsXml() {
    final defaultTabStop =
        _lengthTwips(_documentAttrs['defaultTabStop']) ?? 708;
    final evenAndOdd = _documentAttrs['evenAndOddHeaders'] == true
        ? '<w:evenAndOddHeaders/>'
        : '';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:settings xmlns:w='
        '"http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:defaultTabStop w:val="$defaultTabStop"/>'
        '$evenAndOdd'
        '</w:settings>';
  }

  String _numberingXml() {
    String level(int ilvl, String format, String text) =>
        '<w:lvl w:ilvl="$ilvl"><w:start w:val="1"/>'
        '<w:numFmt w:val="$format"/><w:lvlText w:val="$text"/>'
        '<w:lvlJc w:val="left"/>'
        '<w:pPr><w:ind w:left="${720 * (ilvl + 1)}" w:hanging="360"/></w:pPr>'
        '</w:lvl>';
    final bulletLevels =
        [for (var i = 0; i < 9; i++) level(i, 'bullet', '•')].join();
    final decimalLevels =
        [for (var i = 0; i < 9; i++) level(i, 'decimal', '%${i + 1}.')].join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering xmlns:w='
        '"http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:abstractNum w:abstractNumId="0">$bulletLevels</w:abstractNum>'
        '<w:abstractNum w:abstractNumId="1">$decimalLevels</w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
        '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>'
        '</w:numbering>';
  }

  // ------------------------------------------------------------ helpers

  static String? _jcFor(dynamic textAlign) => switch (textAlign) {
        'left' => 'left',
        'center' => 'center',
        'right' => 'right',
        'justify' => 'both',
        _ => null,
      };

  static String _highlightFor(dynamic color) {
    switch (color?.toString().toLowerCase()) {
      case 'green':
        return 'green';
      case 'cyan':
        return 'cyan';
      case 'magenta':
      case 'pink':
        return 'magenta';
      case 'red':
        return 'red';
      case 'blue':
        return 'blue';
      case 'gray':
      case 'grey':
        return 'lightGray';
      default:
        return 'yellow';
    }
  }

  /// Cor CSS (`#rgb`, `#rrggbb`, `rgb(...)`) → hex RRGGBB do OOXML.
  static String? _parseColorHex(dynamic value) {
    if (value is! String) return null;
    var hex = value.trim();
    final rgbMatch =
        RegExp(r'^rgba?\((\d+)[,\s]+(\d+)[,\s]+(\d+)').firstMatch(hex);
    if (rgbMatch != null) {
      String component(String s) =>
          int.parse(s).clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return (component(rgbMatch.group(1)!) +
              component(rgbMatch.group(2)!) +
              component(rgbMatch.group(3)!))
          .toUpperCase();
    }
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return hex.toUpperCase();
  }

  /// `12pt`/`16px`/número → half-points do OOXML.
  static int? _fontSizeHalfPoints(dynamic value) {
    if (value is num) return (value * 2).round();
    if (value is! String) return null;
    final match = RegExp(r'^([\d.]+)\s*(pt|px)?$').firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    final points = match.group(2) == 'px' ? number * 0.75 : number;
    return (points * 2).round();
  }

  static double? _parsePx(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final match = RegExp(r'^([\d.]+)').firstMatch(value.toString().trim());
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  /// CSS length used by paragraph geometry → OOXML twips.
  static int? _lengthTwips(dynamic value) {
    if (value == null) return null;
    if (value is num) return (value * 15).round();
    final match = RegExp(r'^(-?[\d.]+)\s*(px|pt|in|cm|mm)?$')
        .firstMatch(value.toString().trim().toLowerCase());
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    final twips = switch (match.group(2)) {
      'pt' => number * 20,
      'in' => number * 1440,
      'cm' => number * 1440 / 2.54,
      'mm' => number * 1440 / 25.4,
      _ => number * 15,
    };
    return twips.round();
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
