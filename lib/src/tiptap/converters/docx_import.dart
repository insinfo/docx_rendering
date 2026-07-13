import 'package:docx_rendering/docx_rendering.dart';
import 'package:docx_rendering/src/docx_rendering/document/dom.dart';
import 'package:docx_rendering/src/docx_rendering/document/paragraph.dart';
import 'package:docx_rendering/src/docx_rendering/document/run.dart';

import '../../prosemirror/model/index.dart' as model;

class DocxImporter {
  final WordDocument docx;
  final model.Schema schema;

  DocxImporter(this.docx, this.schema);

  model.PMNode importDocument() {
    final body = docx.documentPart?.body;
    if (body == null || body.children == null) {
      return schema.node('doc', null, []);
    }

    final children = <model.PMNode>[];
    for (final child in body.children!) {
      final pmNode = _visitElement(child);
      if (pmNode != null) {
        if (pmNode is List<model.PMNode>) {
          children.addAll(pmNode);
        } else if (pmNode is model.PMNode) {
          children.add(pmNode);
        }
      }
    }
    
    // Fallback if empty doc
    if (children.isEmpty) {
      children.add(schema.node('paragraph', null, []));
    }

    return schema.node('doc', null, children);
  }

  dynamic _visitElement(OpenXmlElement elem) {
    switch (elem.type) {
      case DomType.paragraph:
        return _visitParagraph(elem as WmlParagraph);
      case DomType.table:
        return _visitTable(elem as WmlTable);
      case DomType.run:
        return _visitRun(elem as WmlRun);
      case DomType.text:
        return _visitText(elem as WmlText);
      case DomType.image:
        return _visitImage(elem as IDomImage);
      // NOTE: missing case sdt which is a DomType but wait, is it mapped?
      // Yes, sdt is mapped to inserted or just wrapper. Wait, sdt is not in DomType!
      // In dom.dart, sdt doesn't exist, but we have inserted, deleted, hyperlink, smartTag.
      case DomType.inserted:
      case DomType.deleted:
      case DomType.hyperlink:
      case DomType.smartTag:
        // Pass-through elements that wrap content
        if (elem.children == null) return null;
        final res = <model.PMNode>[];
        for (final child in elem.children!) {
          final r = _visitElement(child);
          if (r is model.PMNode) {
            res.add(r);
          } else if (r is List<model.PMNode>) {
            res.addAll(r);
          }
        }
        return res;
      default:
        // Ignore unmapped elements
        return null;
    }
  }

  model.PMNode? _visitParagraph(WmlParagraph elem) {
    final children = <model.PMNode>[];
    if (elem.children != null) {
      for (final child in elem.children!) {
        final pmNode = _visitElement(child);
        if (pmNode != null) {
          if (pmNode is List<model.PMNode>) {
            children.addAll(pmNode);
          } else if (pmNode is model.PMNode) {
            children.add(pmNode);
          }
        }
      }
    }

    // Convert styles to attributes. O parser guarda o `w:jc` em
    // cssStyle['text-align'] (o campo textAlignment é o alinhamento
    // vertical do OOXML, outra coisa).
    final attrs = <String, dynamic>{};
    final textAlign = elem.cssStyle?['text-align'];
    if (textAlign != null) {
      attrs['textAlign'] = textAlign;
    }
    // Extract heading level if applicable
    if (elem.styleName != null && elem.styleName!.startsWith('Heading')) {
      final level = int.tryParse(elem.styleName!.substring(7));
      if (level != null && schema.nodes.containsKey('heading')) {
        return schema.node('heading', {'level': level, ...attrs}, children.isEmpty ? null : children);
      }
    }

    return schema.node('paragraph', attrs, children.isEmpty ? null : children);
  }

  dynamic _visitRun(WmlRun elem) {
    final children = <model.PMNode>[];
    if (elem.children != null) {
      for (final child in elem.children!) {
        final pmNode = _visitElement(child);
        if (pmNode != null) {
          if (pmNode is List<model.PMNode>) {
            children.addAll(pmNode);
          } else if (pmNode is model.PMNode) {
            children.add(pmNode);
          }
        }
      }
    }

    // Apply marks
    final marks = <model.Mark>[];
    
    // Common formatting check (bold, italic, underline, color)
    if (elem.cssStyle != null) {
      if (elem.cssStyle!['font-weight'] == 'bold' && schema.marks.containsKey('bold')) {
        marks.add(schema.mark('bold'));
      }
      if (elem.cssStyle!['font-style'] == 'italic' && schema.marks.containsKey('italic')) {
        marks.add(schema.mark('italic'));
      }
      if (elem.cssStyle!['text-decoration'] == 'underline' && schema.marks.containsKey('underline')) {
        marks.add(schema.mark('underline'));
      }
      if (elem.cssStyle!['text-decoration'] == 'line-through' && schema.marks.containsKey('strike')) {
        marks.add(schema.mark('strike'));
      }
      if (elem.color != null && schema.marks.containsKey('textStyle')) {
         marks.add(schema.mark('textStyle', {'color': elem.color}));
      }
    }

    // Since runs wrap text, we apply the marks to the text nodes
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      if (child.isText) {
        children[i] = child.mark(marks);
      }
    }

    return children;
  }

  model.PMNode? _visitText(WmlText elem) {
    if (elem.text.isEmpty) return null;
    return schema.text(elem.text);
  }

  model.PMNode? _visitImage(IDomImage elem) {
    if (!schema.nodes.containsKey('image')) return null;
    return schema.node('image', {'src': elem.src});
  }

  model.PMNode? _visitTable(WmlTable elem) {
    if (!schema.nodes.containsKey('table')) return null;

    final rows = <model.PMNode>[];
    if (elem.children != null) {
      for (final child in elem.children!) {
        if (child.type == DomType.row) {
          final row = _visitTableRow(child as WmlTableRow);
          if (row != null) rows.add(row);
        }
      }
    }

    if (rows.isEmpty) return null;
    return schema.node('table', null, rows);
  }

  model.PMNode? _visitTableRow(WmlTableRow elem) {
    if (!schema.nodes.containsKey('tableRow')) return null;

    final cells = <model.PMNode>[];
    if (elem.children != null) {
      for (final child in elem.children!) {
        if (child.type == DomType.cell) {
          final cell = _visitTableCell(child as WmlTableCell);
          if (cell != null) cells.add(cell);
        }
      }
    }

    if (cells.isEmpty) return null;
    return schema.node('tableRow', null, cells);
  }

  model.PMNode? _visitTableCell(WmlTableCell elem) {
    if (!schema.nodes.containsKey('tableCell')) return null;

    final children = <model.PMNode>[];
    if (elem.children != null) {
      for (final child in elem.children!) {
        final pmNode = _visitElement(child);
        if (pmNode != null) {
          if (pmNode is List<model.PMNode>) {
            children.addAll(pmNode);
          } else if (pmNode is model.PMNode) {
            children.add(pmNode);
          }
        }
      }
    }

    // Cells must have at least one block element
    if (children.isEmpty || children.every((n) => n.isInline)) {
      children.clear();
      children.add(schema.node('paragraph', null, []));
    }

    return schema.node('tableCell', null, children);
  }
}
