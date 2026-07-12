// Port of prosemirror-view/src/browser.ts (IE support dropped).
import 'package:web/web.dart' as web;

final String _agent = web.window.navigator.userAgent;
final String _vendor = web.window.navigator.vendor;
final String _platform = web.window.navigator.platform;

final bool gecko =
    RegExp(r'gecko\/(\d+)', caseSensitive: false).hasMatch(_agent);
final int geckoVersion = () {
  final m = RegExp(r'Firefox\/(\d+)').firstMatch(_agent);
  return m != null ? int.parse(m.group(1)!) : 0;
}();

final RegExpMatch? _chromeMatch = RegExp(r'Chrome\/(\d+)').firstMatch(_agent);
final bool chrome = _chromeMatch != null;
final int chromeVersion = () {
  final match = _chromeMatch;
  return match != null ? int.parse(match.group(1) ?? '0') : 0;
}();

final bool safari = _vendor.contains('Apple Computer');
// True for both iOS and iPadOS for convenience.
final bool ios = safari &&
    (RegExp(r'Mobile\/\w+').hasMatch(_agent) ||
        web.window.navigator.maxTouchPoints > 2);
final bool mac = ios || _platform.contains('Mac');
final bool windows = _platform.contains('Win');
final bool android = RegExp(r'Android \d').hasMatch(_agent);
final bool webkit = RegExp(r'\bAppleWebKit\/(\d+)').hasMatch(_agent);
final int webkitVersion = () {
  final m = RegExp(r'\bAppleWebKit\/(\d+)').firstMatch(_agent);
  return m != null ? int.parse(m.group(1)!) : 0;
}();
