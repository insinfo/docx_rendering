/// Ported from docxjs src/document/fields.ts
/// Field model types.

import 'dom.dart';

/// Instruction text element (field code text).
class WmlInstructionText extends OpenXmlElement {
  String text;

  WmlInstructionText({required this.text})
      : super(type: DomType.instruction);
}

/// Field char element (begin/end/separate markers).
class WmlFieldChar extends OpenXmlElement {
  String charType; // 'begin' | 'end' | 'separate'
  bool? lock;

  WmlFieldChar({required this.charType, this.lock})
      : super(type: DomType.complexField);
}

/// Simple field element.
class WmlFieldSimple extends OpenXmlElement {
  String? instruction;
  bool? lock;
  bool? dirty;

  WmlFieldSimple({this.instruction, this.lock, this.dirty})
      : super(type: DomType.simpleField, children: []);
}
