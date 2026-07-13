import '../../prosemirror/keymap/keymap.dart';
import '../../prosemirror/state/index.dart';

import '../core/commands.dart';
import '../core/extension.dart';

/// Adds text-alignment keyboard shortcuts. The `textAlign` attribute
/// itself lives on the `paragraph` and `heading` node specs.
class TextAlignExtension extends Extension {
  final List<String> types;
  final List<String> alignments;

  const TextAlignExtension({
    this.types = const ['paragraph', 'heading'],
    this.alignments = const ['left', 'center', 'right', 'justify'],
  }) : super('textAlign');

  @override
  List<Plugin> addPlugins() => [
        keymap({
          if (alignments.contains('left'))
            'Mod-Shift-l': setTextAlignCommand(types, 'left'),
          if (alignments.contains('center'))
            'Mod-Shift-e': setTextAlignCommand(types, 'center'),
          if (alignments.contains('right'))
            'Mod-Shift-r': setTextAlignCommand(types, 'right'),
          if (alignments.contains('justify'))
            'Mod-Shift-j': setTextAlignCommand(types, 'justify'),
        }),
      ];
}
