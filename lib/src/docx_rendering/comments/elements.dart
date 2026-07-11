/// Ported from docxjs src/comments/elements.ts
/// Comment elements.

import '../document/dom.dart';

/// A comment element.
class WmlComment extends OpenXmlElementBase {
  String? id;
  String? author;
  String? initials;
  String? date;

  WmlComment({this.id, this.author, this.initials, this.date})
      : super(type: DomType.comment);
}

/// A reference to a comment.
class WmlCommentReference extends OpenXmlElementBase {
  String? id;

  WmlCommentReference({this.id})
      : super(type: DomType.commentReference);
}

/// Start marker for a comment range.
class WmlCommentRangeStart extends OpenXmlElementBase {
  String? id;

  WmlCommentRangeStart({this.id})
      : super(type: DomType.commentRangeStart);
}

/// End marker for a comment range.
class WmlCommentRangeEnd extends OpenXmlElementBase {
  String? id;

  WmlCommentRangeEnd({this.id})
      : super(type: DomType.commentRangeEnd);
}
