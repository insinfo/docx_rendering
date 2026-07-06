/// Ported from docxjs src/parser/xml-parser.ts
/// XML parsing utilities using the browser's DOMParser via package:web.

import 'package:web/web.dart' as web;

import '../document/common.dart';
import 'dart:js_interop';

/// Parses an XML string into a browser DOM Document.
web.Document parseXmlString(String xmlString,
    [bool trimXmlDeclaration = false]) {
  if (trimXmlDeclaration) {
    xmlString = xmlString.replaceAll(RegExp(r'<[?].*?[?]>'), '');
  }

  xmlString = _removeUtf8Bom(xmlString);

  final parser = web.DOMParser();
  final result = parser.parseFromString(xmlString.toJS, 'application/xml');

  final errorElem = result.getElementsByTagName('parsererror');
  if (errorElem.length > 0) {
    final errorText = errorElem.item(0)?.textContent;
    if (errorText != null && errorText.isNotEmpty) {
      throw FormatException('XML parse error: $errorText');
    }
  }

  return result;
}

String _removeUtf8Bom(String data) {
  if (data.isNotEmpty && data.codeUnitAt(0) == 0xFEFF) {
    return data.substring(1);
  }
  return data;
}

/// Serializes a DOM Node back to an XML string.
String serializeXmlString(web.Node elem) {
  final serializer = web.XMLSerializer();
  return serializer.serializeToString(elem);
}

/// Helper class for navigating and extracting data from XML elements.
/// Wraps the browser DOM API for convenient attribute/element access.
class XmlParser {
  /// Returns all child elements, optionally filtered by localName.
  List<web.Element> elements(web.Element elem, [String? localName]) {
    final result = <web.Element>[];
    final children = elem.childNodes;
    for (var i = 0; i < children.length; i++) {
      final c = children.item(i)!;
      if (c.nodeType == web.Node.ELEMENT_NODE) {
        final el = c as web.Element;
        if (localName == null || el.localName == localName) {
          result.add(el);
        }
      }
    }
    return result;
  }

  /// Returns the first child element with the given localName, or null.
  web.Element? element(web.Element elem, String localName) {
    final children = elem.childNodes;
    for (var i = 0; i < children.length; i++) {
      final c = children.item(i)!;
      if (c.nodeType == web.Node.ELEMENT_NODE &&
          (c as web.Element).localName == localName) {
        return c;
      }
    }
    return null;
  }

  /// Returns the attribute value of a child element.
  String? elementAttr(
      web.Element elem, String localName, String attrLocalName) {
    final el = element(elem, localName);
    return el != null ? attr(el, attrLocalName) : null;
  }

  /// Returns all attributes of an element.
  List<web.Attr> attrs(web.Element elem) {
    final result = <web.Attr>[];
    final attributes = elem.attributes;
    for (var i = 0; i < attributes.length; i++) {
      result.add(attributes.item(i)!);
    }
    return result;
  }

  /// Returns the value of an attribute by localName, or null.
  String? attr(web.Element elem, String localName) {
    final attributes = elem.attributes;
    for (var i = 0; i < attributes.length; i++) {
      final a = attributes.item(i)!;
      if (a.localName == localName) {
        return a.value;
      }
    }
    return null;
  }

  /// Returns an integer attribute value, or [defaultValue].
  int? intAttr(web.Element node, String attrName, [int? defaultValue]) {
    final val = attr(node, attrName);
    return val != null ? int.tryParse(val) ?? defaultValue : defaultValue;
  }

  /// Returns a hex integer attribute value, or [defaultValue].
  int? hexAttr(web.Element node, String attrName, [int? defaultValue]) {
    final val = attr(node, attrName);
    return val != null
        ? int.tryParse(val, radix: 16) ?? defaultValue
        : defaultValue;
  }

  /// Returns a float attribute value, or [defaultValue].
  double? floatAttr(web.Element node, String attrName,
      [double? defaultValue]) {
    final val = attr(node, attrName);
    return val != null
        ? double.tryParse(val) ?? defaultValue
        : defaultValue;
  }

  /// Returns a boolean attribute value, using OOXML conventions.
  bool? boolAttr(web.Element node, String attrName,
      [bool? defaultValue]) {
    return convertBoolean(attr(node, attrName), defaultValue ?? false);
  }

  /// Returns a CSS length attribute value, converted using [usage].
  CssLength? lengthAttr(web.Element node, String attrName,
      [LengthUsageType usage = LengthUsage.dxa]) {
    return convertLength(attr(node, attrName), usage);
  }

  /// Returns the localName of an element.
  String? localName(web.Element elem) => elem.localName;

  /// Returns the namespaceURI of an element.
  String? namespaceURI(web.Element elem) => elem.namespaceURI;

  /// Returns the text content of an element.
  String? textContent(web.Element elem) => elem.textContent;

  /// Returns a color attribute value.
  String? colorAttr(web.Element node, String attrName, [String? defaultValue]) {
    final val = attr(node, attrName);
    if (val == null) return defaultValue;
    if (val.toLowerCase() == 'auto') return 'auto';
    if (val.length == 6) return '#$val';
    return val;
  }

  /// Returns the parent element.
  web.Element? parent(web.Element elem) {
    final p = elem.parentElement;
    return p;
  }
}

/// Global singleton XML parser instance.
final globalXmlParser = XmlParser();
