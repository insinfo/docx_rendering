/// Ported from docxjs src/document/document.ts
/// Document element interface.

import 'dom.dart';
import 'section.dart';

/// The root document element, containing the body and section properties.
class DocumentElement extends OpenXmlElement {
  SectionProperties? sectionProps;

  DocumentElement({this.sectionProps})
      : super(type: DomType.document, children: []);

  // Override props to return sectionProps for compatibility
  @override
  Map<String, dynamic>? get props => null;
}
