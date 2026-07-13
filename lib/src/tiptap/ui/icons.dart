import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Lightweight, framework-independent SVG icons for editor chrome.
///
/// Icons are embedded as a small subset instead of shipping an entire icon
/// font. This avoids font routing and flash-of-unstyled-content issues when
/// the editor is embedded in AngularDart or served with `dart compile js`.
abstract final class TiptapIcons {
  static const _paths = <String, String>{
    'open':
        '<path d="M4 15.5V6.8A1.8 1.8 0 0 1 5.8 5h3l1.5 1.7H18a2 2 0 0 1 2 2v6.8"/><path d="M12 19V10m0 0-3 3m3-3 3 3"/>',
    'download': '<path d="M12 3v11m0 0-4-4m4 4 4-4"/><path d="M5 16v3h14v-3"/>',
    'sun':
        '<circle cx="12" cy="12" r="3.5"/><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    'moon': '<path d="M20 15.2A8 8 0 0 1 8.8 4 8.3 8.3 0 1 0 20 15.2Z"/>',
    'minus': '<path d="M5 12h14"/>',
    'plus': '<path d="M12 5v14M5 12h14"/>',
    'bold': '<path d="M8 4h5a4 4 0 0 1 0 8H8zm0 8h6a4 4 0 0 1 0 8H8z"/>',
    'italic': '<path d="M14 4h4M6 20h4M14 4 10 20"/>',
    'underline': '<path d="M7 4v7a5 5 0 0 0 10 0V4M5 21h14"/>',
    'strike':
        '<path d="M17 6.5A5 5 0 0 0 12.5 4C9.8 4 8 5.4 8 7.4c0 1 .4 1.8 1.2 2.6M6 12h12m-3.1 2c.7.6 1.1 1.3 1.1 2.2 0 2.2-1.8 3.8-4.6 3.8A6 6 0 0 1 6 17"/>',
    'code': '<path d="m8 8-4 4 4 4m8-8 4 4-4 4M14 5l-4 14"/>',
    'link':
        '<path d="M10 13a4 4 0 0 0 5.7 0l2.1-2.1a4 4 0 0 0-5.7-5.7L11 6.3"/><path d="M14 11a4 4 0 0 0-5.7 0l-2.1 2.1a4 4 0 0 0 5.7 5.7l1.1-1.1"/>',
    'image':
        '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m4 17 5-5 4 4 2-2 5 4"/>',
    'list-bullet':
        '<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r=".7" fill="currentColor" stroke="none"/><circle cx="4.5" cy="12" r=".7" fill="currentColor" stroke="none"/><circle cx="4.5" cy="18" r=".7" fill="currentColor" stroke="none"/>',
    'list-number':
        '<path d="M10 6h10M10 12h10M10 18h10M4 5h1v3M4 11.5c.4-.5 2-.5 2 .5 0 .8-2 1.3-2 2h2M4 17h1.2a1 1 0 0 1 0 2H4m1.2 0a1 1 0 0 1 0 2H4"/>',
    'align-left': '<path d="M4 6h16M4 10h11M4 14h16M4 18h9"/>',
    'align-center': '<path d="M4 6h16M7 10h10M4 14h16M8 18h8"/>',
    'align-right': '<path d="M4 6h16M9 10h11M4 14h16M11 18h9"/>',
    'table':
        '<rect x="3" y="4" width="18" height="16" rx="1"/><path d="M3 9h18M9 4v16m6-16v16"/>',
    'horizontal-rule': '<path d="M4 12h16"/>',
    'undo': '<path d="M9 7 4 12l5 5"/><path d="M5 12h8a6 6 0 0 1 6 6"/>',
    'redo': '<path d="m15 7 5 5-5 5"/><path d="M19 12h-8a6 6 0 0 0-6 6"/>',
  };

  static String markup(String name, {int size = 18}) {
    final body = _paths[name];
    if (body == null) return '';
    return '<svg class="tiptap-icon" width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">$body</svg>';
  }

  /// Replaces every `[data-tiptap-icon]` placeholder under [root].
  static void hydrate(web.Element root) {
    final nodes = root.querySelectorAll('[data-tiptap-icon]');
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes.item(i);
      if (node is! web.HTMLElement) continue;
      final name = node.getAttribute('data-tiptap-icon');
      if (name != null) set(node, name);
    }
  }

  static void set(web.HTMLElement element, String name, {int size = 18}) {
    element.innerHTML = markup(name, size: size).toJS;
    element.setAttribute('data-tiptap-icon', name);
  }
}
