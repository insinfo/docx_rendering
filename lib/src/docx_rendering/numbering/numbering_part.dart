/// Ported from docxjs src/numbering/numbering-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../document/dom.dart';
import '../document_parser.dart';
import 'numbering.dart';

/// Part representing the numbering definitions.
class NumberingPart extends Part implements NumberingPartProperties {
  final DocumentParser _documentParser;

  @override
  List<Numbering> numberings = [];
  @override
  List<AbstractNumbering> abstractNumberings = [];
  @override
  List<NumberingBulletPicture> bulletPictures = [];

  List<IDomNumbering> domNumberings = [];

  NumberingPart(OpenXmlPackage pkg, String path, this._documentParser)
      : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    final parsed = parseNumberingPart(root, package_.xmlParser);
    numberings = parsed.numberings;
    abstractNumberings = parsed.abstractNumberings;
    bulletPictures = parsed.bulletPictures;
    domNumberings = _documentParser.parseNumberingFile(root);
  }
}
