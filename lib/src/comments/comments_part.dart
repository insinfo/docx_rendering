/// Ported from docxjs src/comments/comments-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../document_parser.dart';
import '../utils.dart';
import 'elements.dart';

/// Part containing document comments.
class CommentsPart extends Part {
  final DocumentParser _documentParser;

  List<WmlComment> comments = [];
  Map<String, WmlComment> commentMap = {};

  CommentsPart(OpenXmlPackage pkg, String path, this._documentParser)
      : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    comments = _documentParser.parseComments(root);
    commentMap = keyBy(comments, (c) => c.id ?? '');
  }
}
