import 'package:web/web.dart' as web;
import 'fragment.dart';
import 'node.dart';
import 'schema.dart';
import 'mark.dart';

/// A description of a DOM structure.
typedef DOMOutputSpec = dynamic;

class DOMSerializer {
  final Map<String, dynamic Function(PMNode)> nodes;
  final Map<String, dynamic Function(Mark, bool)> marks;

  DOMSerializer(this.nodes, this.marks);

  web.Node serializeFragment(Fragment fragment, {web.Document? document, web.Node? target}) {
    target ??= doc(document).createDocumentFragment();

    web.Node top = target;
    List<List<dynamic>> active = []; // Tuple of [Mark, web.Node]

    for (int i = 0; i < fragment.childCount; i++) {
      PMNode node = fragment.child(i);
      if (active.isNotEmpty || node.marks.isNotEmpty) {
        int keep = 0, rendered = 0;
        while (keep < active.length && rendered < node.marks.length) {
          Mark next = node.marks[rendered];
          if (!marks.containsKey(next.type.name)) {
            rendered++;
            continue;
          }
          if (!next.eq(active[keep][0]) || next.type.spec.spanning == false) break;
          keep++;
          rendered++;
        }
        while (keep < active.length) {
          top = active.removeLast()[1] as web.Node;
        }
        while (rendered < node.marks.length) {
          Mark add = node.marks[rendered++];
          dynamic markDOM = serializeMark(add, node.isInline, document);
          if (markDOM != null) {
            active.add([add, top]);
            top.appendChild(markDOM['dom'] as web.Node);
            top = (markDOM['contentDOM'] ?? markDOM['dom']) as web.Node;
          }
        }
      }
      top.appendChild(serializeNodeInner(node, document));
    }
    return target;
  }

  web.Node serializeNodeInner(PMNode node, web.Document? document) {
    if (node.isText) return doc(document).createTextNode(node.text!);
    
    Map<String, web.Node?> rendered = renderSpec(doc(document), nodes[node.type.name]!(node), null, node.attrs);
    web.Node dom = rendered['dom']!;
    web.Node? contentDOM = rendered['contentDOM'];
    
    if (contentDOM != null) {
      if (node.isLeaf) {
        throw RangeError("Content hole not allowed in a leaf node spec");
      }
      serializeFragment(node.content, document: document, target: contentDOM);
    }
    return dom;
  }

  web.Node serializeNode(PMNode node, {web.Document? document}) {
    web.Node dom = serializeNodeInner(node, document);
    for (int i = node.marks.length - 1; i >= 0; i--) {
      dynamic wrap = serializeMark(node.marks[i], node.isInline, document);
      if (wrap != null) {
        ((wrap['contentDOM'] ?? wrap['dom']) as web.Node).appendChild(dom);
        dom = wrap['dom'] as web.Node;
      }
    }
    return dom;
  }

  Map<String, web.Node?>? serializeMark(Mark mark, bool inline, web.Document? document) {
    var toDOM = marks[mark.type.name];
    if (toDOM != null) {
      return renderSpec(doc(document), toDOM(mark, inline), null, mark.attrs);
    }
    return null;
  }

  static Map<String, web.Node?> renderSpecStatic(web.Document document, DOMOutputSpec structure, [String? xmlNS]) {
    if (structure is String) {
      return {'dom': document.createTextNode(structure)};
    }
    return renderSpec(document, structure, xmlNS);
  }

  static DOMSerializer fromSchema(Schema schema) {
    schema.cached['domSerializer'] ??= DOMSerializer(nodesFromSchema(schema), marksFromSchema(schema));
    return schema.cached['domSerializer'] as DOMSerializer;
  }

  static Map<String, dynamic Function(PMNode)> nodesFromSchema(Schema schema) {
    Map<String, dynamic Function(PMNode)> result = {};
    for (String name in schema.nodes.keys) {
      var toDOM = schema.nodes[name]!.spec.toDOM;
      if (toDOM != null) result[name] = toDOM;
    }
    if (!result.containsKey('text')) {
      result['text'] = (PMNode node) => node.text;
    }
    return result;
  }

  static Map<String, dynamic Function(Mark, bool)> marksFromSchema(Schema schema) {
    Map<String, dynamic Function(Mark, bool)> result = {};
    for (String name in schema.marks.keys) {
      var toDOM = schema.marks[name]!.spec.toDOM;
      if (toDOM != null) result[name] = toDOM;
    }
    return result;
  }
}

web.Document doc(web.Document? document) {
  return document ?? web.window.document;
}

Map<String, web.Node?> renderSpec(web.Document document, DOMOutputSpec structure, [String? xmlNS, Map<String, dynamic>? blockArraysIn]) {
  if (structure is String) {
    return {'dom': document.createTextNode(structure)};
  }
  
  if (structure is Map) {
    if (structure.containsKey('dom')) {
      return {'dom': structure['dom'] as web.Node, 'contentDOM': structure['contentDOM'] as web.Node?};
    }
  }

  if (structure is! List) {
    // If it's not a String, Map, or List, it must be a DOM node.
    return {'dom': structure as web.Node};
  }

  List<dynamic> struct = structure;
  dynamic tagNameArg = struct[0];
  if (tagNameArg is! String) {
    throw RangeError("Invalid array passed to renderSpec");
  }

  String tagName = tagNameArg;
  int space = tagName.indexOf(" ");
  if (space > 0) {
    xmlNS = tagName.substring(0, space);
    tagName = tagName.substring(space + 1);
  }

  web.Node? contentDOM;
  web.Element dom = xmlNS != null ? document.createElementNS(xmlNS, tagName) : document.createElement(tagName);
  
  int start = 1;
  dynamic attrs = struct.length > 1 ? struct[1] : null;
  
  if (attrs is Map<String, dynamic> && attrs['nodeType'] == null && !(attrs is List)) {
    start = 2;
    for (String name in attrs.keys) {
      if (attrs[name] != null) {
        int space = name.indexOf(" ");
        if (space > 0) {
          dom.setAttributeNS(name.substring(0, space), name.substring(space + 1), attrs[name].toString());
        } else if (name == "style" && dom is web.HTMLElement) {
          // Setting style is restricted in some contexts but allowed like this:
          dom.style.cssText = attrs[name].toString();
        } else {
          dom.setAttribute(name, attrs[name].toString());
        }
      }
    }
  }

  for (int i = start; i < struct.length; i++) {
    dynamic child = struct[i];
    if (child == 0) {
      if (i < struct.length - 1 || i > start) {
        throw RangeError("Content hole must be the only child of its parent node");
      }
      return {'dom': dom, 'contentDOM': dom};
    } else if (child is String) {
      dom.appendChild(document.createTextNode(child));
    } else {
      Map<String, web.Node?> innerStruct = renderSpec(document, child, xmlNS, blockArraysIn);
      web.Node inner = innerStruct['dom']!;
      web.Node? innerContent = innerStruct['contentDOM'];
      dom.appendChild(inner);
      if (innerContent != null) {
        if (contentDOM != null) throw RangeError("Multiple content holes");
        contentDOM = innerContent;
      }
    }
  }
  return {'dom': dom, 'contentDOM': contentDOM};
}
