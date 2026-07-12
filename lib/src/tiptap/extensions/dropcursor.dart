import '../../prosemirror/dropcursor/index.dart';
import '../../prosemirror/state/index.dart';
import '../core/extension.dart';

class DropcursorExtension extends Extension {
  final DropCursorOptions options;

  const DropcursorExtension([this.options = const DropCursorOptions()])
      : super('dropcursor');

  @override
  List<Plugin> addPlugins() => [dropCursor(options)];
}
