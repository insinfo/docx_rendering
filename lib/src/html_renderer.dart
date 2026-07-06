/// Ported from docxjs src/html-renderer.ts

import 'package:web/web.dart' as web;

import 'word_document.dart';
import 'document/dom.dart';
import 'docx_preview.dart';
import 'document/document.dart';
import 'document/paragraph.dart';
import 'utils.dart';

import 'font_table/font_table.dart';
import 'document/section.dart';
import 'document/run.dart';
import 'document/bookmarks.dart';
import 'document/style.dart';
import 'notes/elements.dart';
import 'dart:js_interop';
import 'theme/theme_part.dart';
import 'header_footer/parts.dart';
import 'common/part.dart';
import 'common/relationship.dart';
import 'html.dart';
import 'vml/vml.dart';

part 'renderer/html_renderer_core.dart';
part 'renderer/html_renderer_styles.dart';
part 'renderer/html_renderer_tables.dart';
part 'renderer/html_renderer_blocks.dart';
part 'renderer/html_renderer_math.dart';
part 'renderer/html_renderer_vml.dart';

class CellPos {
  int col;
  int row;
  CellPos(this.col, this.row);
}

class Section {
  SectionProperties sectProps;
  List<OpenXmlElement> elements;
  bool pageBreak;
  Section(this.sectProps, this.elements, this.pageBreak);
}

typedef CellVerticalMergeType = Map<int, web.HTMLTableCellElement>;

/// Renders a [WordDocument] into HTML elements.
class HtmlRenderer {
  String className = 'docx';
  String rootSelector = '';
  late WordDocument document;
  late Options options;
  Map<String, IDomStyle>? styleMap;
  Part? currentPart;

  List<CellVerticalMergeType> tableVerticalMerges = [];
  CellVerticalMergeType? currentVerticalMerge;
  List<CellPos> tableCellPositions = [];
  CellPos? currentCellPosition;

  Map<String, WmlFootnote> footnoteMap = {};
  Map<String, WmlFootnote> endnoteMap = {};
  List<String> currentFootnoteIds = [];
  List<String> currentEndnoteIds = [];
  List<String> usedHederFooterParts = [];

  String? defaultTabSize;
  List<dynamic> currentTabs = [];

  dynamic commentHighlight;
  Map<String, dynamic> commentMap = {};

  List<Future<dynamic>> tasks = [];
  List<Function> postRenderTasks = [];

  Function hFunc = h;

  Future<List<web.Node>> render(WordDocument document,
      [Map<String, dynamic>? optionsMap]) async {
    this.document = document;
    options = Options()
      ..inWrapper = optionsMap?['inWrapper'] ?? true
      ..hideWrapperOnPrint = optionsMap?['hideWrapperOnPrint'] ?? false
      ..ignoreWidth = optionsMap?['ignoreWidth'] ?? false
      ..ignoreHeight = optionsMap?['ignoreHeight'] ?? false
      ..ignoreFonts = optionsMap?['ignoreFonts'] ?? false
      ..breakPages = optionsMap?['breakPages'] ?? true
      ..debug = optionsMap?['debug'] ?? false
      ..experimental = optionsMap?['experimental'] ?? false
      ..className = optionsMap?['className'] ?? 'docx'
      ..trimXmlDeclaration = optionsMap?['trimXmlDeclaration'] ?? true
      ..renderHeaders = optionsMap?['renderHeaders'] ?? true
      ..renderFooters = optionsMap?['renderFooters'] ?? true
      ..renderFootnotes = optionsMap?['renderFootnotes'] ?? true
      ..renderEndnotes = optionsMap?['renderEndnotes'] ?? true
      ..ignoreLastRenderedPageBreak =
          optionsMap?['ignoreLastRenderedPageBreak'] ?? true
      ..useBase64URL = optionsMap?['useBase64URL'] ?? false
      ..renderChanges = optionsMap?['renderChanges'] ?? false
      ..renderComments = optionsMap?['renderComments'] ?? false
      ..renderAltChunks = optionsMap?['renderAltChunks'] ?? true
      ..hFunc = optionsMap?['hFunc'] ?? h;

    className = options.className;
    rootSelector = options.inWrapper ? '.$className-wrapper' : ':root';
    hFunc = options.hFunc;
    styleMap = null;
    tasks = [];

    // Note: window.Highlight not natively available in Dart 'web' package without interop.
    // Assuming simple fallback.

    final result = <web.Node>[];
    result.addAll(_renderDefaultStyle(this));

    if (document.themePart != null) {
      result.addAll(_renderTheme(this, document.themePart!));
    }

    if (document.stylesPart != null) {
      styleMap = _processStyles(this, document.stylesPart!.styles);
      result.addAll(_renderStyles(this, document.stylesPart!.styles));
    }

    if (document.numberingPart != null) {
      _processNumberings(this, document.numberingPart!.domNumberings);
      result.addAll(await _renderNumbering(this, document.numberingPart!.domNumberings));
    }

    if (document.footnotesPart != null) {
      footnoteMap = {for (var x in document.footnotesPart!.notes) x.id ?? '': x};
    }

    if (document.endnotesPart != null) {
      endnoteMap = {for (var x in document.endnotesPart!.notes) x.id ?? '': x as WmlFootnote};
    }

    if (document.settingsPart != null) {
      defaultTabSize = document.settingsPart!.settings?.defaultTabStop;
    }

    if (!options.ignoreFonts && document.fontTablePart != null) {
      result.addAll(await _renderFontTable(this, document.fontTablePart!));
    }

    final sectionElements = _renderSections(this, document.documentPart!.body!);

    if (options.inWrapper) {
      result.add(_renderWrapper(this, sectionElements));
    } else {
      result.addAll(sectionElements);
    }

    for (final t in postRenderTasks) {
      t();
    }

    await Future.wait(tasks);

    _refreshTabStops(this);

    return result;
  }
}
