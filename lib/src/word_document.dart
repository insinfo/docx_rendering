/// Ported from docxjs src/word-document.ts

import 'dart:typed_data';
import 'dart:convert';

import 'document_parser.dart';
import 'common/relationship.dart';
import 'common/part.dart';
import 'font_table/font_table.dart';
import 'common/open_xml_package.dart';
import 'document/document_part.dart';
import 'utils.dart';
import 'numbering/numbering_part.dart';
import 'styles/styles_part.dart';
import 'header_footer/parts.dart';
import 'document_props/extended_props_part.dart';
import 'document_props/core_props_part.dart';
import 'theme/theme_part.dart';
import 'notes/parts.dart';
import 'settings/settings_part.dart';
import 'document_props/custom_props_part.dart';
import 'comments/comments_part.dart';
import 'comments/comments_extended_part.dart';
import 'common/content_types.dart';

final _topLevelRels = [
  Relationship(
      type: RelationshipTypes.officeDocument, target: 'word/document.xml', id: ''),
  Relationship(
      type: RelationshipTypes.extendedProperties, target: 'docProps/app.xml', id: ''),
  Relationship(
      type: RelationshipTypes.coreProperties, target: 'docProps/core.xml', id: ''),
  Relationship(
      type: RelationshipTypes.customProperties, target: 'docProps/custom.xml', id: ''),
];

/// Represents a loaded Word document.
class WordDocument {
  late OpenXmlPackage _package;
  late DocumentParser _parser;
  Map<String, dynamic> _options = {};

  List<Relationship> rels = [];
  List<Part> parts = [];
  Map<String, Part> partsMap = {};
  List<ContentType> contentTypes = [];

  DocumentPart? documentPart;
  FontTablePart? fontTablePart;
  NumberingPart? numberingPart;
  StylesPart? stylesPart;
  FootnotesPart? footnotesPart;
  EndnotesPart? endnotesPart;
  ThemePart? themePart;
  CorePropsPart? corePropsPart;
  ExtendedPropsPart? extendedPropsPart;
  SettingsPart? settingsPart;
  CommentsPart? commentsPart;
  CommentsExtendedPart? commentsExtendedPart;

  /// Loads a document from a byte array.
  static Future<WordDocument> load(Uint8List data, DocumentParser parser,
      [Map<String, dynamic>? options]) async {
    final d = WordDocument();

    d._options = options ?? {};
    d._parser = parser;
    d._package = await OpenXmlPackage.load(data, OpenXmlPackageOptions(
      trimXmlDeclaration: options?['trimXmlDeclaration'] ?? true,
      keepOrigin: options?['keepOrigin'] ?? false,
    ));
    d.rels = await d._package.loadRelationships() ?? [];
    d.contentTypes = await d._package.loadContentTypes();

    for (final rel in _topLevelRels) {
      final r = d.rels.cast<Relationship?>().firstWhere(
            (x) => x?.type == rel.type,
            orElse: () => null,
          ) ??
          rel;
      await d.loadRelationshipPart(r.target, r.type);
    }

    return d;
  }

  Future<Part?> loadRelationshipPart(String path, String type) async {
    if (partsMap.containsKey(path)) {
      return partsMap[path];
    }

    if (!(_package.has(path))) {
      return null;
    }

    Part? part;

    switch (type) {
      case RelationshipTypes.officeDocument:
        part = documentPart = DocumentPart(_package, path, _parser);
        break;
      case RelationshipTypes.fontTable:
        part = fontTablePart = FontTablePart(_package, path);
        break;
      case RelationshipTypes.numbering:
        part = numberingPart = NumberingPart(_package, path, _parser);
        break;
      case RelationshipTypes.styles:
        part = stylesPart = StylesPart(_package, path, _parser);
        break;
      case RelationshipTypes.theme:
        part = themePart = ThemePart(_package, path);
        break;
      case RelationshipTypes.footnotes:
        part = footnotesPart = FootnotesPart(_package, path, _parser);
        break;
      case RelationshipTypes.endnotes:
        part = endnotesPart = EndnotesPart(_package, path, _parser);
        break;
      case RelationshipTypes.footer:
        part = FooterPart(_package, path, _parser);
        break;
      case RelationshipTypes.header:
        part = HeaderPart(_package, path, _parser);
        break;
      case RelationshipTypes.coreProperties:
        part = corePropsPart = CorePropsPart(_package, path);
        break;
      case RelationshipTypes.extendedProperties:
        part = extendedPropsPart = ExtendedPropsPart(_package, path);
        break;
      case RelationshipTypes.customProperties:
        part = CustomPropsPart(_package, path);
        break;
      case RelationshipTypes.settings:
        part = settingsPart = SettingsPart(_package, path);
        break;
      case RelationshipTypes.comments:
        part = commentsPart = CommentsPart(_package, path, _parser);
        break;
      case RelationshipTypes.commentsExtended:
        part = commentsExtendedPart = CommentsExtendedPart(_package, path);
        break;
    }

    if (part == null) return null;

    partsMap[path] = part;
    parts.add(part);

    part.load();

    if (part.rels?.isNotEmpty == true) {
      final folder = splitPath(part.path).$1;
      final partRels = part.rels ?? [];
      for (final rel in partRels) {
        await loadRelationshipPart(resolvePath(rel.target, folder), rel.type);
            }
    }

    return part;
  }

  Future<String?> loadDocumentImage(String id, [Part? part]) async {
    final path = getPathById(part ?? documentPart!, id);
    if (path == null) return null;
    final bytes = await _package.loadBytes(path);
    return blobToURL(bytes, path);
  }

  Future<String?> loadNumberingImage(String id) async {
    if (numberingPart == null) return null;
    final path = getPathById(numberingPart!, id);
    if (path == null) return null;
    final bytes = await _package.loadBytes(path);
    return blobToURL(bytes, path);
  }

  Future<String?> loadFont(String id, String key) async {
    if (fontTablePart == null) return null;
    final path = getPathById(fontTablePart!, id);
    if (path == null) return null;
    final x = await _package.loadBytes(path);
    if (x == null) return null;
    return blobToURL(deobfuscate(x, key), path);
  }

  Future<String?> loadAltChunk(String id, [Part? part]) async {
    final path = getPathById(part ?? documentPart!, id);
    if (path == null) return null;
    return await _package.loadString(path);
  }

  String? blobToURL(Uint8List? blob, [String? path]) {
    if (blob == null) return null;

    String mimeType = 'application/octet-stream';
    if (path != null) {
      final ct = contentTypes.cast<ContentType?>().firstWhere(
            (x) => x?.partName == path || (x?.extension_ != null && path.endsWith('.${x!.extension_!}')),
            orElse: () => null,
          );
      if (ct != null && ct.contentType != null) {
        mimeType = ct.contentType!;
      }
    }

    if (_options['useBase64URL'] == true) {
      final base64 = base64Encode(blob);
      return 'data:$mimeType;base64,$base64';
    }

    // fallback to data URI if ObjectURL is not available in pure dart without blob
    // for standard web app use web.URL.createObjectURL(web.Blob(...))
    final base64 = base64Encode(blob);
    return 'data:$mimeType;base64,$base64';
  }

  Part? findPartByRelId(String id, [Part? basePart]) {
    final relList = basePart?.rels ?? rels;
    final rel = relList.cast<Relationship?>().firstWhere((r) => r?.id == id, orElse: () => null);
    if (rel == null) return null;
    final folder = basePart != null ? splitPath(basePart.path).$1 : '';
    return partsMap[resolvePath(rel.target, folder)];
  }

  String? getPathById(Part part, String id) {
    final rel = (part.rels ?? []).cast<Relationship?>().firstWhere((x) => x?.id == id, orElse: () => null);
    if (rel == null) return null;
    final folder = splitPath(part.path).$1;
    return resolvePath(rel.target, folder);
  }
}

/// Deobfuscates font data.
Uint8List deobfuscate(Uint8List data, String guidKey) {
  final len = 16;
  final trimmed = guidKey.replaceAll(RegExp(r'[{}-]'), '');
  final numbers = List<int>.filled(len, 0);

  for (var i = 0; i < len; i++) {
    numbers[len - i - 1] = int.parse(trimmed.substring(i * 2, i * 2 + 2), radix: 16);
  }

  final out = Uint8List.fromList(data);
  for (var i = 0; i < 32; i++) {
    out[i] = out[i] ^ numbers[i % len];
  }

  return out;
}
