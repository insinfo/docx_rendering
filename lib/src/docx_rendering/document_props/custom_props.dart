/// Ported from docxjs src/document-props/custom-props.ts

import '../parser/xml_parser.dart';

/// A custom document property.
class CustomProperty {
  String? formatId;
  String? name;
  String? type;
  String? value;

  CustomProperty({this.formatId, this.name, this.type, this.value});
}

/// Parses the custom properties element.
List<CustomProperty> parseCustomProps(dynamic root, XmlParser xml) {
  return xml.elements(root, 'property').map((e) {
    final firstChild = e.firstChild;
    return CustomProperty(
      formatId: xml.attr(e, 'fmtid'),
      name: xml.attr(e, 'name'),
      type: firstChild?.nodeName,
      value: firstChild?.textContent,
    );
  }).toList();
}
