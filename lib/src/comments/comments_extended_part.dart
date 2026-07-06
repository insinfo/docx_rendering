/// Ported from docxjs src/comments/comments-extended-part.ts

import 'package:web/web.dart' as web;

import '../common/open_xml_package.dart';
import '../common/part.dart';
import '../utils.dart';

/// Extended comment properties.
class CommentsExtended {
  String? paraId;
  String? paraIdParent;
  bool? done;

  CommentsExtended({this.paraId, this.paraIdParent, this.done});
}

/// Part containing extended comment properties.
class CommentsExtendedPart extends Part {
  List<CommentsExtended> comments = [];
  Map<String, CommentsExtended> commentMap = {};

  CommentsExtendedPart(OpenXmlPackage pkg, String path) : super(pkg, path);

  @override
  void parseXml(web.Element root) {
    final xml = package_.xmlParser;

    for (final el in xml.elements(root, 'commentEx')) {
      comments.add(CommentsExtended(
        paraId: xml.attr(el, 'paraId'),
        paraIdParent: xml.attr(el, 'paraIdParent'),
        done: xml.boolAttr(el, 'done'),
      ));
    }

    commentMap = keyBy(comments, (c) => c.paraId ?? '');
  }
}
