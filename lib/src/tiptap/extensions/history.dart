import '../../prosemirror/history/history.dart' as pm_history;
import '../../prosemirror/keymap/keymap.dart';
import '../../prosemirror/state/index.dart';

import '../core/extension.dart';

/// Undo/redo support. When present, `TiptapEditor` skips its built-in
/// default history plugin so the plugin is not registered twice.
class HistoryExtension extends Extension {
  final int depth;
  final int newGroupDelay;

  const HistoryExtension({this.depth = 100, this.newGroupDelay = 500})
      : super('history');

  @override
  List<Plugin> addPlugins() => [
        pm_history.history(
            pm_history.HistoryOptions(depth: depth, newGroupDelay: newGroupDelay)),
        keymap({
          'Mod-z': pm_history.undo,
          'Shift-Mod-z': pm_history.redo,
          'Mod-y': pm_history.redo,
        }),
      ];
}
