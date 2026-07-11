/// Ported from docxjs src/common/open-xml-package.ts
/// OpenXML package (ZIP container) abstraction.

import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../parser/xml_parser.dart';
import '../utils.dart';
import '../zip/zip_archive.dart';
import 'content_types.dart';
import 'relationship.dart';

/// Options for loading OpenXML packages.
class OpenXmlPackageOptions {
  final bool trimXmlDeclaration;
  final bool keepOrigin;

  const OpenXmlPackageOptions({
    this.trimXmlDeclaration = true,
    this.keepOrigin = false,
  });
}

/// An OpenXML package backed by a ZIP archive.
class OpenXmlPackage {
  final XmlParser xmlParser = XmlParser();
  final ZipArchive _zip;
  final OpenXmlPackageOptions options;

  OpenXmlPackage(this._zip, this.options);

  /// Checks if a path exists in the package.
  bool has(String path) {
    final p = _normalizePath(path);
    return _zip.contains(p) || _zip.contains(p.replaceAll('/', r'\'));
  }

  /// Updates a file in the package.
  void update(String path, String content) {
    _zip.setFile(path, utf8.encode(content));
  }

  /// Loads an OpenXML package from raw ZIP bytes.
  static Future<OpenXmlPackage> load(
      Uint8List input, OpenXmlPackageOptions options) async {
    final zip = ZipArchive.decodeBytes(input);
    return OpenXmlPackage(zip, options);
  }

  /// Saves the package as ZIP bytes.
  Uint8List save() {
    return _zip.encode();
  }

  /// Loads a file as a UTF-8 string, or null if not found.
  Future<String?> loadString(String path) async {
    final p = _normalizePath(path);
    return _zip.readString(p) ?? _zip.readString(p.replaceAll('/', r'\'));
  }

  /// Loads a file as raw bytes, or null if not found.
  Future<Uint8List?> loadBytes(String path) async {
    final p = _normalizePath(path);
    return _zip.readBytes(p) ?? _zip.readBytes(p.replaceAll('/', r'\'));
  }

  /// Loads relationships for a given part path, or the root relationships.
  Future<List<Relationship>?> loadRelationships([String? path]) async {
    String relsPath = '_rels/.rels';

    if (path != null) {
      final (f, fn) = splitPath(path);
      relsPath = '${f}_rels/$fn.rels';
    }

    final txt = await loadString(relsPath);
    if (txt == null) return null;

    final doc = parseXmlDocument(txt);
    final root = doc.documentElement;
    return root != null ? parseRelationships(root, xmlParser) : null;
  }

  /// Loads content types from [Content_Types].xml.
  Future<List<ContentType>> loadContentTypes() async {
    final txt = await loadString('[Content_Types].xml');
    if (txt == null) return [];

    final doc = parseXmlDocument(txt);
    final root = doc.documentElement;
    return root != null ? parseContentTypes(root, xmlParser) : [];
  }

  /// Parses an XML string into a DOM Document.
  web.Document parseXmlDocument(String txt) {
    return parseXmlString(txt, options.trimXmlDeclaration);
  }
}

String _normalizePath(String path) {
  return path.startsWith('/') ? path.substring(1) : path;
}
