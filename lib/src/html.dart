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

  if (elem is HElement) {
    if (elem.tagName == '#fragment') {
      return web.document.createDocumentFragment();
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
      } else if (elem.style is Map<String, String>) {
        final styleStr = formatCssRules(elem.style as Map<String, String>);
        result.setAttribute('style', styleStr);
      }
    }

    if (elem.props != null) {
      // In Dart, setting arbitrary properties on Element is restricted.
      // We set them as attributes instead for generic props.
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
