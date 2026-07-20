import 'dart:async';

import 'package:docx_rendering/docx_rendering.dart';
import 'package:docx_rendering/src/docx_rendering/common/part.dart';
import 'package:docx_rendering/src/docx_rendering/document/dom.dart';
import 'package:docx_rendering/src/docx_rendering/document/paragraph.dart';
import 'package:docx_rendering/src/docx_rendering/document/section.dart';
import 'package:docx_rendering/src/docx_rendering/document/style.dart';
import 'package:docx_rendering/src/docx_rendering/document/run.dart';
import 'package:docx_rendering/src/docx_rendering/header_footer/parts.dart';
import 'package:docx_rendering/src/docx_rendering/numbering/numbering.dart';
import 'package:docx_rendering/src/docx_rendering/vml/vml.dart';

import '../../prosemirror/model/index.dart' as model;

/// Converts the parsed Word model straight to a ProseMirror document.
///
/// Word formatting is a cascade (document defaults -> basedOn styles ->
/// paragraph style -> direct formatting). The HTML renderer gets that cascade
/// from CSS classes; this importer must flatten it explicitly because it never
/// materializes intermediate HTML.
class DocxImporter {
  final WordDocument docx;
  final model.Schema schema;
  late final _DocxStyleResolver _styles;

  final Map<String, String> _resolvedImages = {};
  final Map<String, int> _listCounters = {};
  Map<String, dynamic>? _headers;
  Map<String, dynamic>? _footers;
  Part? _currentPart;

  DocxImporter(this.docx, this.schema) {
    _styles = _DocxStyleResolver(docx.stylesPart?.styles ?? const []);
    _currentPart = docx.documentPart;
  }

  /// Synchronous import used by existing callers.
  ///
  /// Relationship-backed images remain as relationship ids. Call
  /// [importDocumentAsync] when media and header/footer payloads are needed.
  model.PMNode importDocument() {
    final body = docx.documentPart?.body;
    if (body == null || body.children == null) {
      return schema.node('doc', _attrsFor('doc', _documentAttrs(body)), [
        schema.node('paragraph', null, []),
      ]);
    }

    _currentPart = docx.documentPart;
    _listCounters.clear();
    final children = _visitBlocks(body.children!);
    if (children.isEmpty) {
      children.add(schema.node('paragraph', null, []));
    }
    return schema.node(
      'doc',
      _attrsFor('doc', _documentAttrs(body)),
      children,
    );
  }

  /// Resolves relationship-backed media and preserves editable header/footer
  /// content as opaque PM JSON in the document attributes.
  ///
  /// The pagination view can materialize and repeat those payloads without
  /// putting headers and footers in the editable body.
  Future<model.PMNode> importDocumentAsync() async {
    final body = docx.documentPart?.body;
    if (body != null) {
      await _resolveImages(body.children ?? const [], docx.documentPart);
      _headers = await _headerFooterPayload(body.sectionProps?.headerRefs);
      _footers = await _headerFooterPayload(body.sectionProps?.footerRefs);
    }
    return importDocument();
  }

  Map<String, dynamic> _documentAttrs(dynamic body) {
    final SectionProperties? section = body?.sectionProps;
    final page = section?.pageSize;
    final margins = section?.pageMargins;
    return {
      'pageWidth': page?.width,
      'pageHeight': page?.height,
      'pageOrientation': page?.orientation,
      'titlePage': section?.titlePage,
      'evenAndOddHeaders':
          docx.settingsPart?.settings?.evenAndOddHeaders == true,
      'pageMarginTop': margins?.top,
      'pageMarginRight': margins?.right,
      'pageMarginBottom': margins?.bottom,
      'pageMarginLeft': margins?.left,
      'pageMarginHeader': margins?.header,
      'pageMarginFooter': margins?.footer,
      'pageMarginGutter': margins?.gutter,
      'defaultTabStop': docx.settingsPart?.settings?.defaultTabStop,
      'sourcePageCount': docx.extendedPropsPart?.props?.pages,
      'headers': _headers,
      'footers': _footers,
    };
  }

  Future<Map<String, dynamic>?> _headerFooterPayload(
      List<FooterHeaderReference>? refs) async {
    if (refs == null || refs.isEmpty || docx.documentPart == null) return null;
    final result = <String, dynamic>{};
    for (final ref in refs) {
      final part = docx.findPartByRelId(ref.id ?? '', docx.documentPart);
      if (part is! BaseHeaderFooterPart || part.rootElement == null) continue;
      final elements = part.rootElement!.children ?? const <OpenXmlElement>[];
      await _resolveImages(elements, part);
      final oldPart = _currentPart;
      final savedCounters = Map<String, int>.from(_listCounters);
      _currentPart = part;
      _listCounters.clear();
      final nodes = _visitBlocks(elements);
      _listCounters
        ..clear()
        ..addAll(savedCounters);
      _currentPart = oldPart;
      result[ref.type ?? 'default'] =
          nodes.map((node) => node.toJSON()).toList();
    }
    return result.isEmpty ? null : result;
  }

  Future<void> _resolveImages(List<OpenXmlElement> elements, Part? part) async {
    for (final element in elements) {
      if (element is IDomImage && element.src.isNotEmpty && part != null) {
        final key = _imageKey(part, element.src);
        if (!_resolvedImages.containsKey(key)) {
          final data = await docx.loadDocumentImage(element.src, part);
          if (data != null) _resolvedImages[key] = data;
        }
      }
      if (element.children?.isNotEmpty == true) {
        await _resolveImages(element.children!, part);
      }
    }
  }

  List<model.PMNode> _visitBlocks(List<OpenXmlElement> elements) {
    final result = <model.PMNode>[];
    var index = 0;
    while (index < elements.length) {
      final element = elements[index];
      if (element is WmlParagraph) {
        final numbering = _numberingFor(element);
        if (numbering != null && _canBuildLists) {
          final group = <WmlParagraph>[];
          var cursor = index;
          while (cursor < elements.length && elements[cursor] is WmlParagraph) {
            final paragraph = elements[cursor] as WmlParagraph;
            final candidate = _numberingFor(paragraph);
            if (candidate == null || !candidate.sameSequence(numbering)) break;
            group.add(paragraph);
            cursor++;
          }
          result.add(_visitList(group, numbering));
          index = cursor;
          continue;
        }
      }

      final visited = _visitElement(element);
      final blockImages =
          element is WmlParagraph && schema.nodes['image']?.isBlock == true
              ? _blockImages(element)
              : const <model.PMNode>[];
      final blockShapes = element is WmlParagraph
          ? _blockVmlShapes(element)
          : const <model.PMNode>[];
      final mediaOnlyAnchor = _currentPart is BaseHeaderFooterPart &&
          element is WmlParagraph &&
          visited is model.PMNode &&
          visited.childCount == 0 &&
          (blockImages.isNotEmpty || blockShapes.isNotEmpty);
      if (visited is model.PMNode) {
        // A Word paragraph that only anchors a drawing is a positioning
        // container, not a visible empty paragraph. Keeping it would add an
        // extra line before every header/footer image and shift the media by
        // roughly one em on every page.
        if (!mediaOnlyAnchor) result.add(visited);
      } else if (visited is List<model.PMNode>) {
        result.addAll(visited.where((node) => node.isBlock));
      }
      if (element is WmlParagraph) {
        result.addAll(blockImages);
        result.addAll(blockShapes);
      }
      index++;
    }
    return result;
  }

  List<model.PMNode> _blockImages(OpenXmlElement root) {
    final result = <model.PMNode>[];
    final paragraphStyle = root is WmlParagraph
        ? _styles.paragraph(root)
        : const <String, String>{};
    void visit(OpenXmlElement element) {
      if (element is IDomImage) {
        final image = _visitImage(
          element,
          blockStyle: paragraphStyle,
          alignment: paragraphStyle['text-align'] ?? 'left',
        );
        if (image != null) result.add(image);
      }
      for (final child in element.children ?? const <OpenXmlElement>[]) {
        visit(child);
      }
    }

    visit(root);
    return result;
  }

  List<model.PMNode> _blockVmlShapes(OpenXmlElement root) {
    final result = <model.PMNode>[];
    void visit(OpenXmlElement element) {
      if (element is VmlElement && element.borderCss != null) {
        final converted = _visitVmlElement(element);
        if (converted is model.PMNode && converted.isBlock) {
          result.add(converted);
          return;
        }
      }
      for (final child in element.children ?? const <OpenXmlElement>[]) {
        visit(child);
      }
    }

    visit(root);
    return result;
  }

  bool get _canBuildLists =>
      schema.nodes.containsKey('listItem') &&
      schema.nodes.containsKey('bulletList') &&
      schema.nodes.containsKey('orderedList');

  model.PMNode _visitList(
      List<WmlParagraph> paragraphs, _NumberingInfo numbering) {
    final ordered = numbering.format != 'bullet';
    final listName = ordered ? 'orderedList' : 'bulletList';
    final counterKey = '${numbering.id}:${numbering.level}';
    final start = _listCounters[counterKey] ?? numbering.start;
    final items = <model.PMNode>[];
    for (final paragraph in paragraphs) {
      final itemNumbering = _numberingFor(paragraph) ?? numbering;
      final counter = _nextListCounter(itemNumbering);
      final label = itemNumbering.format == 'none'
          ? null
          : _resolveNumberingLabel(itemNumbering, counter);
      final paragraphNode = _visitParagraph(
        paragraph,
        numbering: itemNumbering,
        forceParagraph: true,
      );
      items.add(schema.node(
        'listItem',
        _attrsFor('listItem', {
          'numberingLabel': label,
          'numberingLevel': label == null ? null : itemNumbering.level,
        }),
        [paragraphNode],
      ));
    }
    final attrs = ordered ? _attrsFor(listName, {'start': start}) : null;
    return schema.node(listName, attrs, items);
  }

  /// Returns the counter value for the item being emitted and advances the
  /// Word numbering sequence. Counters store the *next* value, matching the
  /// existing continuation behaviour across intervening non-list blocks.
  int _nextListCounter(_NumberingInfo numbering) {
    final prefix = '${numbering.id}:';
    final deeperKeys = _listCounters.keys.where((key) {
      if (!key.startsWith(prefix)) return false;
      final level = int.tryParse(key.substring(prefix.length));
      return level != null && level > numbering.level;
    }).toList(growable: false);
    for (final key in deeperKeys) {
      _listCounters.remove(key);
    }

    final key = '$prefix${numbering.level}';
    final value = _listCounters[key] ?? numbering.start;
    _listCounters[key] = value + 1;
    return value;
  }

  /// Resolves Word's level text (for example `%1.%2.`) to the literal label
  /// shown beside this item. Keeping that resolved value on the list item is
  /// important because the importer currently emits each run of equal levels
  /// as an independent ProseMirror list; native CSS counters would therefore
  /// lose the parent level when the sequence changes depth.
  String? _resolveNumberingLabel(_NumberingInfo numbering, int currentValue) {
    final template = numbering.levelText;
    if (template == null || template.isEmpty) return null;

    var resolved = template.replaceAllMapped(RegExp(r'%([1-9])'), (match) {
      final referencedLevel = int.parse(match.group(1)!) - 1;
      final definition = _numberingDefinition(numbering.id, referencedLevel);
      final value = referencedLevel == numbering.level
          ? currentValue
          : _previousListCounter(
              numbering.id,
              referencedLevel,
              definition?.start ?? 1,
            );
      return _formatListCounter(value, definition?.format ?? 'decimal');
    });
    if (numbering.format == 'bullet') {
      // Symbol/Wingdings commonly stores the standard round bullet in the
      // private-use area. Normalize the portable glyph so both the browser
      // marker and the base-font PDF path can render it.
      resolved = resolved
          .replaceAll('\uf0b7', '\u2022')
          .replaceAll('\uf0a7', '\u25aa');
    }
    return resolved.isEmpty ? null : resolved;
  }

  int _previousListCounter(String id, int level, int start) {
    final next = _listCounters['$id:$level'];
    return next == null ? start : next - 1;
  }

  _ResolvedNumberingDefinition? _numberingDefinition(String id, int level) {
    // `domNumberings` historically maps abstract numbering ids to a single
    // concrete numId. Word commonly creates many concrete sequences from the
    // same abstract definition (each with its own restart overrides), so all
    // but the last numId would otherwise lose levelText and render as a flat
    // decimal list. Prefer the structured numbering model, which also retains
    // per-numId startOverride values.
    final part = docx.numberingPart;
    if (part != null) {
      Numbering? concrete;
      for (final candidate in part.numberings) {
        if (candidate.id == id) {
          concrete = candidate;
          break;
        }
      }
      if (concrete?.abstractId != null) {
        AbstractNumbering? abstract;
        for (final candidate in part.abstractNumberings) {
          if (candidate.id == concrete!.abstractId) {
            abstract = candidate;
            break;
          }
        }
        if (abstract != null) {
          NumberingLevelOverride? override;
          for (final candidate in concrete!.overrides) {
            if (candidate.level == level) {
              override = candidate;
              break;
            }
          }
          NumberingLevel? levelDefinition = override?.numberingLevel;
          levelDefinition ??= abstract.levels
              .where((candidate) => candidate.level == level)
              .firstOrNull;
          if (levelDefinition != null) {
            return _ResolvedNumberingDefinition(
              start: override?.start ??
                  int.tryParse(levelDefinition.start ?? '') ??
                  1,
              format: levelDefinition.format,
              levelText: levelDefinition.text,
            );
          }
        }
      }
    }

    final definitions = part?.domNumberings ?? const <IDomNumbering>[];
    for (final definition in definitions) {
      if (definition.id == id && definition.level == level) {
        return _ResolvedNumberingDefinition(
          start: definition.start,
          format: definition.format,
          levelText: definition.levelText,
        );
      }
    }
    return null;
  }

  static String _formatListCounter(int value, String format) {
    switch (format) {
      case 'decimalZero':
        return value.toString().padLeft(2, '0');
      case 'lowerLetter':
        return _alphabeticCounter(value, upperCase: false);
      case 'upperLetter':
        return _alphabeticCounter(value, upperCase: true);
      case 'lowerRoman':
        return _romanCounter(value).toLowerCase();
      case 'upperRoman':
        return _romanCounter(value);
      case 'none':
        return '';
      default:
        // Word exposes many locale-specific formats. Decimal is the safest
        // lossless fallback when this pure-Dart importer has no formatter for
        // the requested locale.
        return value.toString();
    }
  }

  static String _alphabeticCounter(int value, {required bool upperCase}) {
    if (value <= 0) return value.toString();
    var remaining = value;
    final result = StringBuffer();
    while (remaining > 0) {
      remaining--;
      result.writeCharCode((upperCase ? 65 : 97) + (remaining % 26));
      remaining ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  static String _romanCounter(int value) {
    if (value <= 0 || value >= 4000) return value.toString();
    const values = <int>[1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = <String>[
      'M',
      'CM',
      'D',
      'CD',
      'C',
      'XC',
      'L',
      'XL',
      'X',
      'IX',
      'V',
      'IV',
      'I',
    ];
    var remaining = value;
    final result = StringBuffer();
    for (var index = 0; index < values.length; index++) {
      while (remaining >= values[index]) {
        result.write(symbols[index]);
        remaining -= values[index];
      }
    }
    return result.toString();
  }

  dynamic _visitElement(OpenXmlElement elem) {
    switch (elem.type) {
      case DomType.paragraph:
        return _visitParagraph(elem as WmlParagraph);
      case DomType.table:
        return _visitTable(elem as WmlTable);
      case DomType.run:
        return _visitRun(elem as WmlRun, const {});
      case DomType.text:
      case DomType.deletedText:
        return _visitText(elem as WmlText);
      case DomType.image:
        return _visitImage(elem as IDomImage);
      case DomType.lineBreak:
        return _visitBreak(elem as WmlBreak);
      case DomType.noBreakHyphen:
        return schema.text('\u2011');
      case DomType.tab:
        return schema.text('\t');
      case DomType.symbol:
        final symbol = elem as WmlSymbol;
        return schema.text(String.fromCharCode(symbol.char));
      case DomType.inserted:
      case DomType.deleted:
      case DomType.hyperlink:
      case DomType.smartTag:
      case DomType.drawing:
      case DomType.vmlPicture:
      case DomType.ruby:
        return _visitContainer(elem);
      case DomType.vmlElement:
        return _visitVmlElement(elem as VmlElement);
      default:
        return null;
    }
  }

  List<model.PMNode> _visitContainer(OpenXmlElement elem) {
    final result = <model.PMNode>[];
    for (final child in elem.children ?? const <OpenXmlElement>[]) {
      final visited = _visitElement(child);
      if (visited is model.PMNode) {
        result.add(visited);
      } else if (visited is List<model.PMNode>) {
        result.addAll(visited);
      }
    }
    return result;
  }

  dynamic _visitVmlElement(VmlElement element) {
    final textBox = _findVmlTextBox(element);
    final canCreateBox = element.borderCss != null &&
        textBox != null &&
        schema.nodes.containsKey('table') &&
        schema.nodes.containsKey('tableRow') &&
        schema.nodes.containsKey('tableCell');
    if (!canCreateBox) return _visitContainer(element);

    final blocks = _visitContainer(textBox)
        .where((node) => node.isBlock)
        .toList(growable: true);
    if (blocks.isEmpty) {
      blocks.add(schema.node('paragraph', null, []));
    }
    final style = _vmlStyle(element.cssStyleText);
    final textBoxFontFamily = _firstTextStyleAttribute(blocks, 'fontFamily');
    final textBoxFontSize = _firstTextStyleAttribute(blocks, 'fontSize');
    final textBoxLineHeight = _firstBlockAttribute(blocks, 'lineHeight');
    final horizontal = style['mso-position-horizontal'];
    final horizontalRelative =
        style['mso-position-horizontal-relative']?.toLowerCase();
    final rightAligned = horizontal == 'right' || horizontal == 'outside';
    final leftAligned = horizontal == 'left' || horizontal == 'inside';
    final margins = docx.documentPart?.body?.sectionProps?.pageMargins;
    final alignToMargins = horizontalRelative == 'margin';
    return schema.node(
      'table',
      _attrsFor('table', {
        'width': style['width'],
        'height': style['height'],
        // Inline text-style marks size the glyphs, but an HTML paragraph also
        // contributes an inherited line-box strut. Give the fixed-size Word
        // textbox the same base font so the table does not expand to the
        // editor's 16px/1.45 defaults around otherwise 10pt runs.
        'fontFamily': textBoxFontFamily,
        'fontSize': textBoxFontSize,
        'lineHeight': textBoxLineHeight ?? 'normal',
        'textBox': true,
        'marginLeft': rightAligned ? 'auto' : style['margin-left'],
        'position': 'absolute',
        'right': rightAligned
            ? (alignToMargins ? margins?.right ?? '0' : '0')
            : null,
        'left':
            leftAligned ? (alignToMargins ? margins?.left ?? '0' : '0') : null,
        'top': _vmlTop(style, margins),
        'zIndex': style['z-index'],
      }),
      [
        schema.node('tableRow', null, [
          schema.node(
            'tableCell',
            _attrsFor('tableCell', {
              'borderTop': element.borderCss,
              'borderRight': element.borderCss,
              'borderBottom': element.borderCss,
              'borderLeft': element.borderCss,
            }),
            blocks,
          ),
        ]),
      ],
    );
  }

  String? _firstTextStyleAttribute(
    List<model.PMNode> blocks,
    String attribute,
  ) {
    String? result;
    for (final block in blocks) {
      block.descendants((node, position, parent, index) {
        for (final mark in node.marks) {
          if (mark.type.name != 'textStyle') continue;
          final value = mark.attrs[attribute];
          if (value != null && '$value'.isNotEmpty) {
            result = '$value';
            return false;
          }
        }
        return result == null;
      });
      if (result != null) break;
    }
    return result;
  }

  String? _firstBlockAttribute(
    List<model.PMNode> blocks,
    String attribute,
  ) {
    for (final block in blocks) {
      final value = block.attrs[attribute];
      if (value != null && '$value'.isNotEmpty) return '$value';
    }
    return null;
  }

  VmlElement? _findVmlTextBox(VmlElement element) {
    if (element.tagName == 'foreignObject') return element;
    for (final child in element.children ?? const <OpenXmlElement>[]) {
      if (child is VmlElement) {
        final found = _findVmlTextBox(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  Map<String, String> _vmlStyle(String? raw) {
    final result = <String, String>{};
    for (final declaration in (raw ?? '').split(';')) {
      final separator = declaration.indexOf(':');
      if (separator < 0) continue;
      final name = declaration.substring(0, separator).trim().toLowerCase();
      final value = declaration.substring(separator + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) result[name] = value;
    }
    return result;
  }

  model.PMNode _visitParagraph(
    WmlParagraph elem, {
    _NumberingInfo? numbering,
    bool forceParagraph = false,
  }) {
    final paragraphStyle = _styles.paragraph(elem);
    final inlineBase = _styles.inlineForParagraph(elem);
    final children = <model.PMNode>[];
    for (final child in elem.children ?? const <OpenXmlElement>[]) {
      dynamic visited;
      if (child is WmlRun) {
        visited = _visitRun(child, inlineBase);
      } else {
        visited = _visitElement(child);
      }
      if (visited is model.PMNode) {
        if (visited.isInline) children.add(visited);
      } else if (visited is List<model.PMNode>) {
        children.addAll(visited.where((node) => node.isInline));
      }
    }

    numbering ??= _numberingFor(elem);
    final isPageRegion = _currentPart is BaseHeaderFooterPart;
    final inlineText = children.map((node) => node.textContent).join();
    String? firstInlineStyle(String attribute) {
      for (final child in children) {
        for (final mark in child.marks) {
          if (mark.type.name != 'textStyle') continue;
          final value = mark.attrs[attribute];
          if (value != null && '$value'.isNotEmpty) return '$value';
        }
      }
      return null;
    }

    final inferredRegionAlignment =
        isPageRegion && inlineText.startsWith('\t\t')
            ? 'right'
            : isPageRegion && inlineText.startsWith('\t')
                ? 'center'
                : null;
    final attrs = <String, dynamic>{
      'styleName': elem.styleName,
      'textAlign': paragraphStyle['text-align'] ?? inferredRegionAlignment,
      // The editor theme supplies a readable default paragraph gap and a
      // 16px/1.45 line box. In Word, absent paragraph spacing is zero and the
      // run/paragraph font defines the line box. Persist those defaults in the
      // imported node so UI theme CSS cannot stretch tables and pagination.
      'marginTop': paragraphStyle['margin-top'] ?? '0',
      'marginRight': paragraphStyle['margin-right'],
      'marginBottom': paragraphStyle['margin-bottom'] ?? '0',
      'marginLeft': paragraphStyle['margin-left'],
      'textIndent': paragraphStyle['text-indent'],
      'tabStops': elem.tabs
          ?.where((tab) => tab.position != null && tab.style != 'clear')
          .map((tab) => {
                'position': tab.position,
                'type': tab.style ?? 'left',
                'leader': tab.leader ?? 'none',
              })
          .toList(),
      'lineHeight': paragraphStyle['line-height'] ?? 'normal',
      'fontFamily': firstInlineStyle('fontFamily') ?? inlineBase['font-family'],
      'fontSize': firstInlineStyle('fontSize') ?? inlineBase['font-size'],
      'keepLines': _styles.keepLines(elem),
      'keepNext': _styles.keepNext(elem),
      'pageBreakBefore': _styles.pageBreakBefore(elem),
      'numberingId': numbering?.id,
      'numberingLevel': numbering?.level,
      'numberingFormat': numbering?.format,
      'numberingText': numbering?.levelText,
    };

    final headingLevel = forceParagraph ? null : _styles.headingLevel(elem);
    if (headingLevel != null && schema.nodes.containsKey('heading')) {
      return schema.node(
        'heading',
        _attrsFor('heading', {'level': headingLevel, ...attrs}),
        children.isEmpty ? null : children,
      );
    }
    return schema.node(
      'paragraph',
      _attrsFor('paragraph', attrs),
      children.isEmpty ? null : children,
    );
  }

  List<model.PMNode> _visitRun(
      WmlRun elem, Map<String, String> inheritedStyle) {
    final children = <model.PMNode>[];
    for (final child in elem.children ?? const <OpenXmlElement>[]) {
      final visited = _visitElement(child);
      if (visited is model.PMNode) {
        children.add(visited);
      } else if (visited is List<model.PMNode>) {
        children.addAll(visited);
      }
    }

    if (_currentPart is BaseHeaderFooterPart && elem.fieldType != null) {
      children
        ..clear()
        ..add(schema.text(
          elem.fieldType == 'NUMPAGES' ? '{{DOCX_NUMPAGES}}' : '{{DOCX_PAGE}}',
        ));
    }

    final style = _styles.run(elem, inheritedStyle);
    final marks = <model.Mark>[];
    void mark(String name, [Map<String, dynamic>? attrs]) {
      if (schema.marks.containsKey(name)) marks.add(schema.mark(name, attrs));
    }

    final weight = style['font-weight'];
    if (weight == 'bold' || (int.tryParse(weight ?? '') ?? 0) >= 600) {
      mark('bold');
    }
    if (style['font-style'] == 'italic') mark('italic');
    final decoration = style['text-decoration'] ?? '';
    if (decoration.contains('underline')) mark('underline');
    if (decoration.contains('line-through')) mark('strike');

    final textStyle = <String, dynamic>{
      'color': style['color'],
      'backgroundColor': style['background-color'],
      'fontFamily': style['font-family'],
      'fontSize': style['font-size'],
      'letterSpacing': style['letter-spacing'],
    }..removeWhere((_, value) => value == null || value == '');
    if (textStyle.isNotEmpty) mark('textStyle', textStyle);

    for (var index = 0; index < children.length; index++) {
      final child = children[index];
      if (child.isText) children[index] = child.mark(marks);
    }
    return children;
  }

  model.PMNode? _visitText(WmlText elem) {
    if (elem.text.isEmpty) return null;
    return schema.text(elem.text);
  }

  model.PMNode? _visitBreak(WmlBreak elem) {
    if (elem.breakType == 'textWrapping' &&
        schema.nodes.containsKey('hardBreak')) {
      return schema.node('hardBreak');
    }
    return null;
  }

  model.PMNode? _visitImage(
    IDomImage elem, {
    Map<String, String>? blockStyle,
    String? alignment,
  }) {
    if (!schema.nodes.containsKey('image')) return null;
    final part = _currentPart;
    final src = part == null
        ? elem.src
        : (_resolvedImages[_imageKey(part, elem.src)] ?? elem.src);
    return schema.node(
        'image',
        _attrsFor('image', {
          'src': src,
          'width': elem.cssStyle?['width'],
          'height': elem.cssStyle?['height'],
          'alignment': alignment,
          // Block images are extracted from their Word anchor paragraph. Move
          // the paragraph geometry onto the image so that removing the empty
          // anchor does not lose indents or spacing.
          'marginTop': blockStyle?['margin-top'] ?? '0',
          'marginRight': blockStyle?['margin-right'],
          'marginBottom': blockStyle?['margin-bottom'] ?? '0',
          'marginLeft': blockStyle?['margin-left'],
        }));
  }

  model.PMNode? _visitTable(WmlTable elem) {
    if (!schema.nodes.containsKey('table')) return null;
    final columnWidths = (elem.columns ?? const <WmlTableColumn>[])
        .map((column) => _cssLengthToPixels(column.width))
        .whereType<int>()
        // A valid Word tblGrid can contain a sub-pixel compatibility track
        // (the TR fixture has 6 twips = .4 CSS px). Dropping it invalidates
        // the complete grid and makes CSS invent equal columns; keep a one-px
        // sentinel so gridSpan still sums the intended tracks.
        .map((width) => width.clamp(1, 1 << 30))
        .toList();
    final rowSpans = <WmlTableCell, int>{};
    final continuations = <WmlTableCell>{};
    _resolveVerticalMerges(elem, rowSpans, continuations);
    final rows = <model.PMNode>[];
    for (final child in elem.children ?? const <OpenXmlElement>[]) {
      if (child is WmlTableRow) {
        final row = _visitTableRow(
          child,
          elem,
          columnWidths,
          rowSpans,
          continuations,
        );
        if (row != null) rows.add(row);
      }
    }
    if (rows.isEmpty) return null;
    return schema.node(
        'table',
        _attrsFor('table', {
          'styleName': elem.styleName,
          'width': elem.cssStyle?['width'],
          'columnWidths': columnWidths.length == (elem.columns?.length ?? 0)
              ? columnWidths
              : null,
          'marginLeft': elem.cssStyle?['margin-left'],
          'alignment': elem.cssStyle?['text-align'],
          'borderCollapse': elem.cssStyle?['border-collapse'],
          'borderSpacing': elem.cssStyle?['border-spacing'],
        }),
        rows);
  }

  model.PMNode? _visitTableRow(
    WmlTableRow elem,
    WmlTable table,
    List<int> columnWidths,
    Map<WmlTableCell, int> rowSpans,
    Set<WmlTableCell> continuations,
  ) {
    if (!schema.nodes.containsKey('tableRow')) return null;
    final cells = <model.PMNode>[];
    var column = 0;
    for (final child in elem.children ?? const <OpenXmlElement>[]) {
      if (child is WmlTableCell) {
        final cell = continuations.contains(child)
            ? null
            : _visitTableCell(
                child,
                elem.isHeader == true,
                table,
                column,
                rowspan: rowSpans[child] ?? 1,
              );
        if (cell != null) cells.add(cell);
        column += child.span ?? 1;
      }
    }
    if (cells.isEmpty) return null;
    return schema.node(
      'tableRow',
      _attrsFor('tableRow', {
        'columnWidths': columnWidths.isEmpty ? null : columnWidths,
        'isHeader': elem.isHeader == true,
        'tableWidth': table.cssStyle?['width'],
        'tableAlignment': table.cssStyle?['text-align'],
        'height': elem.height,
        'heightRule': elem.heightRule,
      }),
      cells,
    );
  }

  model.PMNode? _visitTableCell(
    WmlTableCell elem,
    bool header,
    WmlTable table,
    int column, {
    required int rowspan,
  }) {
    var cellName = header && schema.nodes.containsKey('tableHeader')
        ? 'tableHeader'
        : 'tableCell';
    if (!schema.nodes.containsKey(cellName)) return null;

    final children = _visitBlocks(elem.children ?? const <OpenXmlElement>[]);
    if (children.isEmpty || children.every((node) => node.isInline)) {
      children
        ..clear()
        ..add(schema.node('paragraph', null, []));
    }

    final colspan = elem.span ?? 1;
    final widths = <int>[];
    for (var offset = 0; offset < colspan; offset++) {
      final index = column + offset;
      if (index >= (table.columns?.length ?? 0)) break;
      final width = _cssLengthToPixels(table.columns![index].width);
      // Keep this in sync with the table/row grid. Word can emit a valid
      // sub-pixel compatibility track (for example 6 twips = .4 CSS px),
      // which rounds to zero. A zero in colwidth makes the cell disagree
      // with the one-pixel sentinel used by grid-template-columns and can
      // later invalidate resize/round-trip geometry.
      if (width != null) widths.add(width.clamp(1, 1 << 30));
    }
    final directWidth = _positiveCssLength(elem.cssStyle?['width']);
    final tableCellStyle = table.cellStyle ?? const <String, String>{};
    return schema.node(
        cellName,
        _attrsFor(cellName, {
          'colspan': colspan,
          'rowspan': rowspan,
          'colwidth': widths.length == colspan ? widths : null,
          'columnIndex': column,
          // Word commonly writes tcW=0/auto even though tblGrid contains the
          // authoritative width. A literal width:0pt collapses the CSS grid.
          'width': directWidth,
          'backgroundColor': elem.cssStyle?['background-color'] ??
              tableCellStyle['background-color'],
          'borderTop':
              elem.cssStyle?['border-top'] ?? tableCellStyle['border-top'],
          'borderRight':
              elem.cssStyle?['border-right'] ?? tableCellStyle['border-right'],
          'borderBottom': elem.cssStyle?['border-bottom'] ??
              tableCellStyle['border-bottom'],
          'borderLeft':
              elem.cssStyle?['border-left'] ?? tableCellStyle['border-left'],
          'paddingTop':
              elem.cssStyle?['padding-top'] ?? tableCellStyle['padding-top'],
          'paddingRight': elem.cssStyle?['padding-right'] ??
              tableCellStyle['padding-right'],
          'paddingBottom': elem.cssStyle?['padding-bottom'] ??
              tableCellStyle['padding-bottom'],
          'paddingLeft':
              elem.cssStyle?['padding-left'] ?? tableCellStyle['padding-left'],
        }),
        children);
  }

  void _resolveVerticalMerges(
    WmlTable table,
    Map<WmlTableCell, int> rowSpans,
    Set<WmlTableCell> continuations,
  ) {
    final active = <int, WmlTableCell>{};
    for (final row
        in table.children?.whereType<WmlTableRow>() ?? const <WmlTableRow>[]) {
      var column = 0;
      final extended = <WmlTableCell>{};
      for (final cell in row.children?.whereType<WmlTableCell>() ??
          const <WmlTableCell>[]) {
        final span = cell.span ?? 1;
        if (cell.verticalMerge == 'restart') {
          rowSpans[cell] = 1;
          for (var offset = 0; offset < span; offset++) {
            active[column + offset] = cell;
          }
        } else if (cell.verticalMerge == 'continue') {
          final origin = active[column];
          if (origin != null) {
            continuations.add(cell);
            if (extended.add(origin)) {
              rowSpans[origin] = (rowSpans[origin] ?? 1) + 1;
            }
          }
        } else {
          for (var offset = 0; offset < span; offset++) {
            active.remove(column + offset);
          }
        }
        column += span;
      }
    }
  }

  _NumberingInfo? _numberingFor(WmlParagraph paragraph) {
    final reference = _styles.numbering(paragraph);
    if (reference?.id == null || reference!.id == '0') return null;
    final level = reference.level ?? 0;
    final definition = _numberingDefinition(reference.id!, level);
    return _NumberingInfo(
      id: reference.id!,
      level: level,
      format: definition?.format ?? 'decimal',
      levelText: definition?.levelText,
      start: definition?.start ?? 1,
    );
  }

  Map<String, dynamic>? _attrsFor(
      String nodeName, Map<String, dynamic> values) {
    final type = schema.nodes[nodeName];
    if (type == null || type.attrs.isEmpty) return null;
    final result = <String, dynamic>{};
    for (final name in type.attrs.keys) {
      final value = values[name];
      if (value != null) result[name] = value;
    }
    return result;
  }

  static int? _cssLengthToPixels(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(-?[0-9.]+)(pt|px)?$').firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    return (match.group(2) == 'pt' ? number * 96 / 72 : number).round();
  }

  static String? _positiveCssLength(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(-?[0-9.]+)([a-z%]*)$', caseSensitive: false)
        .firstMatch(value.trim());
    final number = double.tryParse(match?.group(1) ?? '');
    return number != null && number > 0 ? value : null;
  }

  String? _vmlTop(Map<String, String> style, PageMargins? margins) {
    final top = style['margin-top'];
    if (_currentPart is! HeaderPart) return top;
    final relative = style['mso-position-vertical-relative']?.toLowerCase();
    if (relative != 'text' && relative != 'paragraph') return top;
    return _addCssLengths(margins?.header, top);
  }

  static String? _addCssLengths(String? base, String? offset) {
    if (base == null || base.trim().isEmpty) return offset;
    if (offset == null || offset.trim().isEmpty) return base;
    final pattern = RegExp(
      r'^(-?[0-9.]+)([a-z%]+)$',
      caseSensitive: false,
    );
    final baseMatch = pattern.firstMatch(base.trim());
    final offsetMatch = pattern.firstMatch(offset.trim());
    if (baseMatch != null &&
        offsetMatch != null &&
        baseMatch.group(2)!.toLowerCase() ==
            offsetMatch.group(2)!.toLowerCase()) {
      final sum = double.parse(baseMatch.group(1)!) +
          double.parse(offsetMatch.group(1)!);
      final number = sum
          .toStringAsFixed(4)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
      return '$number${baseMatch.group(2)}';
    }
    final trimmedOffset = offset.trim();
    return trimmedOffset.startsWith('-')
        ? 'calc(${base.trim()} - ${trimmedOffset.substring(1)})'
        : 'calc(${base.trim()} + $trimmedOffset)';
  }

  static String _imageKey(Part part, String id) => '${part.path}::$id';
}

class _DocxStyleResolver {
  final Map<String, IDomStyle> _byId;
  final List<IDomStyle> _styles;

  _DocxStyleResolver(List<IDomStyle> styles)
      : _styles = styles,
        _byId = {
          for (final style in styles)
            if (style.id != null) style.id!: style,
        };

  Map<String, String> paragraph(WmlParagraph paragraph) {
    final result = _defaults('p');
    _merge(result, _styleValues(paragraph.styleName, 'p'));
    _merge(result, paragraph.cssStyle);
    return result;
  }

  Map<String, String> inlineForParagraph(WmlParagraph paragraph) {
    final result = _defaults('span');
    _merge(result, _styleValues(paragraph.styleName, 'span'));
    final direct = paragraph.cssStyle;
    if (direct != null) {
      for (final key in _inlineProperties) {
        final value = direct[key];
        if (value != null) result[key] = value;
      }
    }
    return result;
  }

  Map<String, String> run(WmlRun run, Map<String, String> inherited) {
    final result = Map<String, String>.from(inherited);
    if (run.styleName != null) {
      _merge(result, _styleValues(run.styleName, 'span'));
    }
    _merge(result, run.cssStyle);
    return result;
  }

  ParagraphNumbering? numbering(WmlParagraph paragraph) =>
      paragraph.numbering ?? _metadata(paragraph).numbering;

  bool? keepLines(WmlParagraph paragraph) =>
      paragraph.keepLines ?? _metadata(paragraph).keepLines;

  bool? keepNext(WmlParagraph paragraph) =>
      paragraph.keepNext ?? _metadata(paragraph).keepNext;

  bool? pageBreakBefore(WmlParagraph paragraph) =>
      paragraph.pageBreakBefore ?? _metadata(paragraph).pageBreakBefore;

  int? headingLevel(WmlParagraph paragraph) {
    final outline = paragraph.outlineLevel ?? _metadata(paragraph).outlineLevel;
    if (outline != null) return (outline + 1).clamp(1, 6);
    final id = paragraph.styleName;
    if (id == null) return null;
    final style = _byId[id];
    final candidates = [id, style?.name, ...?style?.aliases];
    for (final candidate in candidates.whereType<String>()) {
      final match =
          RegExp(r'(?:heading|t[ií]tulo|ttulo)\s*([1-6])', caseSensitive: false)
              .firstMatch(candidate);
      if (match != null) return int.parse(match.group(1)!);
    }
    return null;
  }

  _ParagraphMetadata _metadata(WmlParagraph paragraph) {
    final result = _ParagraphMetadata();
    for (final style in _styleChain(paragraph.styleName)) {
      final props = style.paragraphProps;
      if (props == null) continue;
      if (props.numbering != null) result.numbering = props.numbering;
      if (props.keepLines != null) result.keepLines = props.keepLines;
      if (props.keepNext != null) result.keepNext = props.keepNext;
      if (props.pageBreakBefore != null) {
        result.pageBreakBefore = props.pageBreakBefore;
      }
      if (props.outlineLevel != null) result.outlineLevel = props.outlineLevel;
    }
    return result;
  }

  Map<String, String> _defaults(String target) {
    final result = <String, String>{};
    final docDefaults = _byId['default'];
    if (docDefaults != null) _mergeSubStyles(result, docDefaults, target);
    for (final style in _styles) {
      if (style.isDefault == true && style.target == 'p') {
        for (final item in _styleChain(style.id)) {
          _mergeSubStyles(result, item, target);
        }
      }
    }
    return result;
  }

  Map<String, String> _styleValues(String? id, String target) {
    final result = <String, String>{};
    for (final style in _styleChain(id)) {
      if (target == 'span' && style.linked != null) {
        for (final linked in _styleChain(style.linked)) {
          _mergeSubStyles(result, linked, target);
        }
      }
      _mergeSubStyles(result, style, target);
    }
    return result;
  }

  List<IDomStyle> _styleChain(String? id) {
    final result = <IDomStyle>[];
    final seen = <String>{};
    void visit(String? current) {
      if (current == null || !seen.add(current)) return;
      final style = _byId[current];
      if (style == null) return;
      visit(style.basedOn);
      result.add(style);
    }

    visit(id);
    return result;
  }

  static void _mergeSubStyles(
      Map<String, String> output, IDomStyle style, String target) {
    for (final subStyle in style.styles) {
      if (subStyle.target == target) output.addAll(subStyle.values);
    }
  }

  static void _merge(Map<String, String> output, Map<String, String>? values) {
    if (values != null) output.addAll(values);
  }

  static const _inlineProperties = {
    'color',
    'background-color',
    'font-family',
    'font-size',
    'font-weight',
    'font-style',
    'font-variant',
    'text-transform',
    'text-decoration',
    'vertical-align',
    'letter-spacing',
    'display',
  };
}

class _ParagraphMetadata {
  ParagraphNumbering? numbering;
  bool? keepLines;
  bool? keepNext;
  bool? pageBreakBefore;
  int? outlineLevel;
}

class _NumberingInfo {
  final String id;
  final int level;
  final String format;
  final String? levelText;
  final int start;

  const _NumberingInfo({
    required this.id,
    required this.level,
    required this.format,
    required this.levelText,
    required this.start,
  });

  bool sameSequence(_NumberingInfo other) =>
      id == other.id && level == other.level && format == other.format;
}

class _ResolvedNumberingDefinition {
  final int start;
  final String? format;
  final String? levelText;

  const _ResolvedNumberingDefinition({
    required this.start,
    required this.format,
    required this.levelText,
  });
}
