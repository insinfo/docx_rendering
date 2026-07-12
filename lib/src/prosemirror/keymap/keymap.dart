import 'package:web/web.dart' as web;
import '../state/index.dart';
import '../view/index.dart';
import '../commands/commands.dart' show PlatformHelper;

// Base key codes mapping
const Map<int, String> baseKeyCodes = {
  8: "Backspace",
  9: "Tab",
  13: "Enter",
  19: "Pause",
  27: "Escape",
  32: " ",
  33: "PageUp",
  34: "PageDown",
  35: "End",
  36: "Home",
  37: "ArrowLeft",
  38: "ArrowUp",
  39: "ArrowRight",
  40: "ArrowDown",
  44: "PrintScreen",
  45: "Insert",
  46: "Delete",
  112: "F1",
  113: "F2",
  114: "F3",
  115: "F4",
  116: "F5",
  117: "F6",
  118: "F7",
  119: "F8",
  120: "F9",
  121: "F10",
  122: "F11",
  123: "F12",
  144: "NumLock",
  145: "ScrollLock",
};

String? getBaseName(int keyCode) {
  if (baseKeyCodes.containsKey(keyCode)) return baseKeyCodes[keyCode];
  if (keyCode >= 65 && keyCode <= 90) {
    return String.fromCharCode(keyCode).toLowerCase();
  }
  if (keyCode >= 48 && keyCode <= 57) {
    return String.fromCharCode(keyCode);
  }
  return null;
}

String normalizeKeyName(String name) {
  final parts = name.split(RegExp(r'-(?!$)'));
  String result = parts.last;
  if (result == "Space") result = " ";
  bool alt = false;
  bool ctrl = false;
  bool shift = false;
  bool meta = false;
  
  final isMac = PlatformHelper.isMac;

  for (int i = 0; i < parts.length - 1; i++) {
    final mod = parts[i];
    if (RegExp(r'^(cmd|meta|m)$', caseSensitive: false).hasMatch(mod)) {
      meta = true;
    } else if (RegExp(r'^a(lt)?$', caseSensitive: false).hasMatch(mod)) {
      alt = true;
    } else if (RegExp(r'^(c|ctrl|control)$', caseSensitive: false).hasMatch(mod)) {
      ctrl = true;
    } else if (RegExp(r'^s(hift)?$', caseSensitive: false).hasMatch(mod)) {
      shift = true;
    } else if (mod.toLowerCase() == 'mod') {
      if (isMac) {
        meta = true;
      } else {
        ctrl = true;
      }
    } else {
      throw ArgumentError("Unrecognized modifier name: $mod");
    }
  }
  if (alt) result = "Alt-$result";
  if (ctrl) result = "Ctrl-$result";
  if (meta) result = "Meta-$result";
  if (shift) result = "Shift-$result";
  return result;
}

Map<String, Command> normalize(Map<String, Command> map) {
  final Map<String, Command> copy = {};
  for (final prop in map.keys) {
    final norm = normalizeKeyName(prop);
    if (copy.containsKey(norm)) {
      throw ArgumentError("Multiple bindings for key $norm in a single keymap");
    }
    copy[norm] = map[prop]!;
  }
  return copy;
}

String modifiers(String name, web.KeyboardEvent event, [bool shift = true]) {
  if (event.altKey) name = "Alt-$name";
  if (event.ctrlKey) name = "Ctrl-$name";
  if (event.metaKey) name = "Meta-$name";
  if (shift && event.shiftKey) name = "Shift-$name";
  return name;
}

Plugin keymap(Map<String, Command> bindings) {
  return Plugin(PluginSpec(
    props: {
      "handleKeyDown": keydownHandler(bindings),
    },
  ));
}


bool Function(EditorView view, dynamic event) keydownHandler(Map<String, Command> bindings) {
  final map = normalize(bindings);
  final isWindows = web.window.navigator.platform.contains('Win');

  return (EditorView view, dynamic event) {
    if (event is! web.KeyboardEvent) return false;
    final name = event.key;
    final direct = map[modifiers(name, event)];
    if (direct != null && direct(view.state, view.dispatch, view)) return true;
    
    // A character key
    if (name.length == 1 && name != " ") {
      if (event.shiftKey) {
        final noShift = map[modifiers(name, event, false)];
        if (noShift != null && noShift(view.state, view.dispatch, view)) return true;
      }
      final baseName = getBaseName(event.keyCode);
      if ((event.altKey || event.metaKey || event.ctrlKey) &&
          !(isWindows && event.ctrlKey && event.altKey) &&
          baseName != null && baseName != name) {
        final fromCode = map[modifiers(baseName, event)];
        if (fromCode != null && fromCode(view.state, view.dispatch, view)) return true;
      }
    }
    return false;
  };
}
