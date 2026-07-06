/// Ported from docxjs src/document/style.ts
/// Style model types.

import 'paragraph.dart';
import 'run.dart';

/// A document style definition.
class IDomStyle {
  String? id;
  String? name;
  String? cssName;
  List<String>? aliases;
  String? target;
  String? basedOn;
  bool? isDefault;
  List<IDomSubStyle> styles;
  String? linked;
  String? next;

  ParagraphProperties? paragraphProps;
  RunProperties? runProps;

  IDomStyle({
    this.id,
    this.name,
    this.cssName,
    this.aliases,
    this.target,
    this.basedOn,
    this.isDefault,
    List<IDomSubStyle>? styles,
    this.linked,
    this.next,
    this.paragraphProps,
    this.runProps,
  }) : styles = styles ?? [];
}

/// A sub-style within a style definition.
class IDomSubStyle {
  String? target;
  String? mod;
  Map<String, String> values;

  IDomSubStyle({this.target, this.mod, Map<String, String>? values})
      : values = values ?? {};
}
