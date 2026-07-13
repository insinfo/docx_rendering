/// jsPDF XMP Metadata module — Dart port.
///
/// Adds XMP metadata to the PDF document as a `/Metadata` stream
/// in the root catalog.
///
/// Ported from modules/xmp_metadata.js of jsPDF.

/// Holds the XMP metadata configuration for a document.
class XmpMetadataConfig {
  /// The metadata string (XML or raw value).
  final String metadata;

  /// Namespace URI used when wrapping in RDF.
  final String namespaceUri;

  /// When true, [metadata] is treated as complete raw XMP XML.
  final bool rawXml;

  /// PDF object number assigned when the metadata stream is written.
  int objectNumber = 0;

  XmpMetadataConfig({
    required this.metadata,
    this.namespaceUri = 'http://jspdf.default.namespaceuri/',
    this.rawXml = false,
  });
}

/// Escapes XML special characters.
String escapeXml(String str) {
  return str
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Builds the XMP content string from [config].
String buildXmpContent(XmpMetadataConfig config) {
  // Convert to UTF-8 escaping (equivalent to JS unescape(encodeURIComponent))
  final utf8Metadata = _toUtf8BinaryString(config.metadata);

  if (config.rawXml) {
    return utf8Metadata;
  }

  const xmpmetaBeginning = '<x:xmpmeta xmlns:x="adobe:ns:meta/">';
  final rdfBeginning =
      '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
      '<rdf:Description rdf:about="" xmlns:jspdf="${config.namespaceUri}">'
      '<jspdf:metadata>';
  const rdfEnding = '</jspdf:metadata></rdf:Description></rdf:RDF>';
  const xmpmetaEnding = '</x:xmpmeta>';

  return xmpmetaBeginning +
      rdfBeginning +
      escapeXml(utf8Metadata) +
      rdfEnding +
      xmpmetaEnding;
}

/// Converts a Dart string to a UTF-8 binary string (one byte per char).
///
/// Equivalent to `unescape(encodeURIComponent(str))` in JavaScript.
String _toUtf8BinaryString(String str) {
  final bytes = <int>[];
  for (final rune in str.runes) {
    if (rune < 0x80) {
      bytes.add(rune);
    } else if (rune < 0x800) {
      bytes.add(0xC0 | (rune >> 6));
      bytes.add(0x80 | (rune & 0x3F));
    } else if (rune < 0x10000) {
      bytes.add(0xE0 | (rune >> 12));
      bytes.add(0x80 | ((rune >> 6) & 0x3F));
      bytes.add(0x80 | (rune & 0x3F));
    } else {
      bytes.add(0xF0 | (rune >> 18));
      bytes.add(0x80 | ((rune >> 12) & 0x3F));
      bytes.add(0x80 | ((rune >> 6) & 0x3F));
      bytes.add(0x80 | (rune & 0x3F));
    }
  }
  return String.fromCharCodes(bytes);
}
