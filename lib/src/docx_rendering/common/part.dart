/// Ported from docxjs src/common/part.ts
/// Base class for all OPC parts.

import 'package:web/web.dart' as web;

import '../parser/xml_parser.dart';
import 'open_xml_package.dart';
import 'relationship.dart';

/// Base class for a part within an OpenXML package.
class Part {
  final OpenXmlPackage package_;
  final String path;

  web.Document? xmlDocument_;

  List<Relationship>? rels;

  Part(this.package_, this.path);

  /// Loads this part: resolves relationships and parses XML content.
  Future<void> load() async {
    rels = await package_.loadRelationships(path);

    final xmlText = await package_.loadString(path);
    if (xmlText == null) return;

    final xmlDoc = package_.parseXmlDocument(xmlText);

    if (package_.options.keepOrigin) {
      xmlDocument_ = xmlDoc;
    }

    final root = xmlDoc.documentElement;
    if (root != null) {
      await parseXml(root);
    }
  }

  /// Saves this part back to the package.
  void save() {
    if (xmlDocument_ != null) {
      package_.update(path, serializeXmlString(xmlDocument_!));
    }
  }

  /// Parses the XML content of this part.
  Future<void> parseXml(web.Element root) async {}
}
