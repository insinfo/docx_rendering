import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Framework-independent access to Microsoft's Fluent UI System Icons font.
///
/// The regular WOFF2 font is vendored in `lib/assets/fonts`, so editor chrome
/// works offline and when embedded in Dart web or AngularDart applications.
/// Codepoints come from the official `FluentSystemIcons-Regular.json` map.
abstract final class TiptapIcons {
  static const _codepoints = <String, int>{
    'open': 62511, // folder_open_24_regular
    'download': 61777, // arrow_download_24_regular
    'sun': 63650, // weather_sunny_24_regular
    'moon': 63614, // weather_moon_24_regular
    'minus': 60369, // subtract_24_regular
    'plus': 61706, // add_24_regular
    'bold': 63397, // text_bold_24_regular
    'italic': 63477, // text_italic_24_regular
    'underline': 63499, // text_underline_24_regular
    'strike': 60768, // text_strikethrough_24_regular
    'code': 62192, // code_24_regular
    'link': 62693, // link_24_regular
    'image': 62601, // image_24_regular
    'list-bullet': 60634, // text_bullet_list_ltr_24_regular
    'list-number': 63482, // text_number_list_ltr_24_regular
    'align-left': 63392, // text_align_left_24_regular
    'align-center': 63386, // text_align_center_24_regular
    'align-right': 63394, // text_align_right_24_regular
    'table': 63326, // table_24_regular
    'horizontal-rule': 62688, // line_horizontal_1_20_regular
    'undo': 61850, // arrow_undo_24_regular
    'redo': 61807, // arrow_redo_24_regular
    'view': 58867, // eye_24_regular
    'edit': 62430, // edit_24_regular
    'save': 63104, // save_24_regular
    'menu': 62817, // navigation_24_regular
    'page-margins': 62374, // document_page_top_center_24_regular
    'orientation': 59552, // orientation_24_regular
    'page-size': 59923, // resize_24_regular
  };

  static String markup(String name, {int size = 18}) {
    final codepoint = _codepoints[name];
    if (codepoint == null) return '';
    final glyph = String.fromCharCode(codepoint);
    return '<span class="tiptap-icon tiptap-fluent-icon" '
        'style="font-size:${size}px" aria-hidden="true">$glyph</span>';
  }

  /// Replaces every `[data-tiptap-icon]` placeholder under [root].
  static void hydrate(web.Element root) {
    final nodes = root.querySelectorAll('[data-tiptap-icon]');
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes.item(index);
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
