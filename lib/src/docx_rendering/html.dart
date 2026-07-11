/// Ported from docxjs src/html.ts

import 'package:web/web.dart' as web;

import 'utils.dart';

/// XML/HTML namespaces.
class HtmlNs {
  static const html = 'http://www.w3.org/1999/xhtml';
  static const svg = 'http://www.w3.org/2000/svg';
  static const mathML = 'http://www.w3.org/1998/Math/MathML';
}

/// A simplified Virtual DOM element representation.
class HElement {
  String? ns;
  String tagName;
  String? className;
  dynamic style; // String | Map<String, String>
  List<dynamic>? children; // List of HElement | web.Node | String
  Map<String, dynamic>? props;

  HElement({
    this.ns,
    required this.tagName,
    this.className,
    this.style,
    this.children,
    this.props,
  });
}

/// Creates a physical browser DOM Node from a Virtual DOM element.
web.Node h(dynamic elem) {
  if (elem is String) return web.document.createTextNode(elem);
  if (elem is web.Node) return elem;

  if (elem is Map) {
    final ns = elem['ns'] as String?;
    final tagName = elem['tagName'] as String?;
    if (tagName == null) throw ArgumentError('tagName must be provided');

    if (tagName == '#fragment') {
      final frag = web.document.createDocumentFragment();
      final children = elem['children'];
      if (children is List) {
        for (final child in children) {
          frag.appendChild(h(child));
        }
      }
      return frag;
    }
    if (tagName == '#comment') {
      final children = elem['children'] as List?;
      final text = (children != null && children.isNotEmpty)
          ? children[0].toString()
          : '';
      return web.document.createComment(text);
    }

    final web.Element result = ns != null
        ? web.document.createElementNS(ns, tagName)
        : web.document.createElement(tagName);

    final className = elem['className'] as String?;
    if (className != null && className.isNotEmpty) {
      result.setAttribute('class', className);
    }

    final style = elem['style'];
    if (style != null) {
      if (style is String) {
        result.setAttribute('style', style);
      } else if (style is Map) {
        final stringMap = style.map((k, v) => MapEntry(k.toString(), v.toString()));
        final styleStr = formatCssRules(stringMap);
        result.setAttribute('style', styleStr);
      }
    }

    final knownKeys = {'ns', 'tagName', 'className', 'style', 'children', 'props'};
    for (final entry in elem.entries) {
      final key = entry.key.toString();
      if (!knownKeys.contains(key) && entry.value != null) {
        result.setAttribute(key, entry.value.toString());
      }
    }

    final props = elem['props'];
    if (props is Map) {
      for (final entry in props.entries) {
        if (entry.value != null) {
          result.setAttribute(entry.key.toString(), entry.value.toString());
        }
      }
    }

    final children = elem['children'];
    if (children != null) {
      if (children is List) {
        for (final child in children) {
          result.appendChild(h(child));
        }
      }
    }

    return result;
  }

  if (elem is HElement) {
    if (elem.tagName == '#fragment') {
      final frag = web.document.createDocumentFragment();
      if (elem.children != null) {
        for (final child in elem.children!) {
          frag.appendChild(h(child));
        }
      }
      return frag;
    }
    if (elem.tagName == '#comment') {
      final text =
          (elem.children != null && elem.children!.isNotEmpty)
              ? elem.children![0].toString()
              : '';
      return web.document.createComment(text);
    }

    final web.Element result = elem.ns != null
        ? web.document.createElementNS(elem.ns!, elem.tagName)
        : web.document.createElement(elem.tagName);

    if (elem.className != null && elem.className!.isNotEmpty) {
      result.setAttribute('class', elem.className!);
    }

    if (elem.style != null) {
      if (elem.style is String) {
        result.setAttribute('style', elem.style as String);
      } else if (elem.style is Map) {
        final stringMap = (elem.style as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
        final styleStr = formatCssRules(stringMap);
        result.setAttribute('style', styleStr);
      }
    }

    if (elem.props != null) {
      for (final entry in elem.props!.entries) {
        if (entry.value != null) {
          result.setAttribute(entry.key, entry.value.toString());
        }
      }
    }

    if (elem.children != null) {
      for (final child in elem.children!) {
        result.appendChild(h(child));
      }
    }

    return result;
  }

  throw ArgumentError('Unsupported element type in h()');
}

/// Joins multiple class names, filtering out nulls/falsy values.
String cx(List<String?> classNames) {
  return classNames.where((c) => c != null && c.isNotEmpty).join(' ');
}
