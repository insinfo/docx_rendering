/// Ported from docxjs src/docx-preview.ts

import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'word_document.dart';
import 'document_parser.dart';
import 'html_renderer.dart';
import 'html.dart';

/// Options for rendering.
class Options {
  bool inWrapper;
  bool hideWrapperOnPrint;
  bool ignoreWidth;
  bool ignoreHeight;
  bool ignoreFonts;
  bool breakPages;
  bool debug;
  bool experimental;
  String className;
  bool trimXmlDeclaration;
  bool renderHeaders;
  bool renderFooters;
  bool renderFootnotes;
  bool renderEndnotes;
  bool ignoreLastRenderedPageBreak;
  bool useBase64URL;
  bool renderChanges;
  bool renderComments;
  bool renderAltChunks;
  Function hFunc;

  Options({
    this.inWrapper = true,
    this.hideWrapperOnPrint = false,
    this.ignoreWidth = false,
    this.ignoreHeight = false,
    this.ignoreFonts = false,
    this.breakPages = true,
    this.debug = false,
    this.experimental = false,
    this.className = 'docx',
    this.trimXmlDeclaration = true,
    this.renderHeaders = true,
    this.renderFooters = true,
    this.renderFootnotes = true,
    this.renderEndnotes = true,
    this.ignoreLastRenderedPageBreak = true,
    this.useBase64URL = false,
    this.renderChanges = false,
    this.renderComments = false,
    this.renderAltChunks = true,
    this.hFunc = h,
  });

  Map<String, dynamic> toMap() {
    return {
      'inWrapper': inWrapper,
      'hideWrapperOnPrint': hideWrapperOnPrint,
      'ignoreWidth': ignoreWidth,
      'ignoreHeight': ignoreHeight,
      'ignoreFonts': ignoreFonts,
      'breakPages': breakPages,
      'debug': debug,
      'experimental': experimental,
      'className': className,
      'trimXmlDeclaration': trimXmlDeclaration,
      'renderHeaders': renderHeaders,
      'renderFooters': renderFooters,
      'renderFootnotes': renderFootnotes,
      'renderEndnotes': renderEndnotes,
      'ignoreLastRenderedPageBreak': ignoreLastRenderedPageBreak,
      'useBase64URL': useBase64URL,
      'renderChanges': renderChanges,
      'renderComments': renderComments,
      'renderAltChunks': renderAltChunks,
      'hFunc': hFunc,
    };
  }
}

/// Parses the DOCX file asynchronously.
Future<WordDocument> parseAsync(Uint8List data, [Options? userOptions]) async {
  final ops = userOptions ?? Options();
  return WordDocument.load(
      data,
      DocumentParser(DocumentParserOptions(
        ignoreWidth: ops.ignoreWidth,
        debug: ops.debug,
      )),
      ops.toMap());
}

/// Renders the parsed document.
Future<List<web.Node>> renderDocument(WordDocument document,
    [Options? userOptions]) async {
  final ops = userOptions ?? Options();
  final renderer = HtmlRenderer();
  return await renderer.render(document, ops.toMap());
}

/// Parses and renders the DOCX file.
Future<WordDocument> renderAsync(Uint8List data, web.HTMLElement bodyContainer,
    [web.HTMLElement? styleContainer, Options? userOptions]) async {
  final doc = await parseAsync(data, userOptions);
  final nodes = await renderDocument(doc, userOptions);

  styleContainer ??= bodyContainer;
  styleContainer.innerHTML = ''.toJS;
  bodyContainer.innerHTML = ''.toJS;

  for (final n in nodes) {
    if (n.nodeName.toUpperCase() == 'STYLE') {
      styleContainer.appendChild(n);
    } else {
      bodyContainer.appendChild(n);
    }
  }

  return doc;
}
