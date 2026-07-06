/// Ported from docxjs src/document/dom.ts
/// Core DOM types for the parsed DOCX document model.

/// Element type enum matching the docxjs DomType values.
enum DomType {
  document('document'),
  paragraph('paragraph'),
  run('run'),
  lineBreak('break'),
  noBreakHyphen('noBreakHyphen'),
  table('table'),
  row('row'),
  cell('cell'),
  hyperlink('hyperlink'),
  smartTag('smartTag'),
  drawing('drawing'),
  image('image'),
  text('text'),
  tab('tab'),
  symbol('symbol'),
  bookmarkStart('bookmarkStart'),
  bookmarkEnd('bookmarkEnd'),
  footer('footer'),
  header('header'),
  footnoteReference('footnoteReference'),
  endnoteReference('endnoteReference'),
  footnote('footnote'),
  endnote('endnote'),
  simpleField('simpleField'),
  complexField('complexField'),
  instruction('instruction'),
  vmlPicture('vmlPicture'),
  mmlMath('mmlMath'),
  mmlMathParagraph('mmlMathParagraph'),
  mmlFraction('mmlFraction'),
  mmlFunction('mmlFunction'),
  mmlFunctionName('mmlFunctionName'),
  mmlNumerator('mmlNumerator'),
  mmlDenominator('mmlDenominator'),
  mmlRadical('mmlRadical'),
  mmlBase('mmlBase'),
  mmlDegree('mmlDegree'),
  mmlSuperscript('mmlSuperscript'),
  mmlSubscript('mmlSubscript'),
  mmlPreSubSuper('mmlPreSubSuper'),
  mmlSubArgument('mmlSubArgument'),
  mmlSuperArgument('mmlSuperArgument'),
  mmlNary('mmlNary'),
  mmlDelimiter('mmlDelimiter'),
  mmlRun('mmlRun'),
  mmlEquationArray('mmlEquationArray'),
  mmlLimit('mmlLimit'),
  mmlLimitLower('mmlLimitLower'),
  mmlMatrix('mmlMatrix'),
  mmlMatrixRow('mmlMatrixRow'),
  mmlBox('mmlBox'),
  mmlBar('mmlBar'),
  mmlGroupChar('mmlGroupChar'),
  vmlElement('vmlElement'),
  inserted('inserted'),
  deleted('deleted'),
  deletedText('deletedText'),
  comment('comment'),
  commentReference('commentReference'),
  commentRangeStart('commentRangeStart'),
  commentRangeEnd('commentRangeEnd'),
  altChunk('altChunk'),
  ruby('ruby');

  final String value;
  const DomType(this.value);
}

/// Base interface for all parsed DOCX elements.
class OpenXmlElement {
  DomType type;
  List<OpenXmlElement>? children;
  Map<String, String>? cssStyle;
  dynamic props;

  String? styleName;
  String? className;

  OpenXmlElement? parent;

  OpenXmlElement({
    required this.type,
    this.children,
    this.cssStyle,
    this.props,
    this.styleName,
    this.className,
    this.parent,
  });
}

/// Base class for OpenXml elements with default field initialization.
class OpenXmlElementBase extends OpenXmlElement {
  OpenXmlElementBase({required super.type})
      : super(
          children: [],
          cssStyle: {},
        );
}

/// Hyperlink element.
class WmlHyperlink extends OpenXmlElement {
  String? id;
  String? anchor;

  WmlHyperlink({this.id, this.anchor})
      : super(type: DomType.hyperlink);
}

/// Alt chunk element.
class WmlAltChunk extends OpenXmlElement {
  String? id;

  WmlAltChunk({this.id})
      : super(type: DomType.altChunk);
}

/// Smart tag element.
class WmlSmartTag extends OpenXmlElement {
  String? uri;
  String? element;

  WmlSmartTag({this.uri, this.element})
      : super(type: DomType.smartTag);
}

/// Note reference element (footnote or endnote).
class WmlNoteReference extends OpenXmlElement {
  String id;

  WmlNoteReference(this.id, DomType type)
      : super(type: type);
}

/// Break element (page, lastRenderedPageBreak, textWrapping).
class WmlBreak extends OpenXmlElement {
  String breakType; // "page" | "lastRenderedPageBreak" | "textWrapping"
  bool? clear;

  WmlBreak({required this.breakType, this.clear})
      : super(type: DomType.lineBreak);
}

/// Text element.
class WmlText extends OpenXmlElement {
  String text;

  WmlText(this.text)
      : super(type: DomType.text);
}

/// Symbol element.
class WmlSymbol extends OpenXmlElement {
  String font;
  int char;

  WmlSymbol(this.font, this.char)
      : super(type: DomType.symbol);
}

/// Table element with column definitions and cell styles.
class WmlTable extends OpenXmlElement {
  List<WmlTableColumn>? columns;
  Map<String, String>? cellStyle;
  int? colBandSize;
  int? rowBandSize;

  WmlTable()
      : super(type: DomType.table, children: []);
}

/// Table row element.
class WmlTableRow extends OpenXmlElement {
  bool? isHeader;
  int? gridBefore;
  int? gridAfter;

  WmlTableRow()
      : super(type: DomType.row, children: []);
}

/// Table cell element.
class WmlTableCell extends OpenXmlElement {
  String? verticalMerge; // 'restart' | 'continue'
  int? span;

  WmlTableCell()
      : super(type: DomType.cell, children: []);
}

/// Image element.
class IDomImage extends OpenXmlElement {
  String src;
  List<double>? srcRect;
  double? rotation;
  String? id;

  IDomImage(this.src, {this.srcRect, this.rotation, this.id})
      : super(type: DomType.image);
}

/// Table column definition.
class WmlTableColumn {
  String? width;

  WmlTableColumn({this.width});
}

/// Numbering definition for lists.
class IDomNumbering {
  String id;
  int level;
  int start;
  String? pStyleName;
  Map<String, String> pStyle;
  Map<String, String> rStyle;
  String? levelText;
  String suff;
  String? format;
  NumberingPicBullet? bullet;

  IDomNumbering({
    required this.id,
    required this.level,
    this.start = 1,
    this.pStyleName,
    Map<String, String>? pStyle,
    Map<String, String>? rStyle,
    this.levelText,
    this.suff = 'tab',
    this.format,
    this.bullet,
  })  : pStyle = pStyle ?? {},
        rStyle = rStyle ?? {};
}

/// Picture bullet for numbered lists.
class NumberingPicBullet {
  int id;
  String src;
  String? style;

  NumberingPicBullet({required this.id, required this.src, this.style});
}
