import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';

abstract class AnyExtension {
  const AnyExtension();
}

abstract class Extension extends AnyExtension {
  final String name;
  const Extension(this.name);

  List<Plugin> addPlugins() => const [];
}

abstract class NodeExtension extends Extension {
  const NodeExtension(super.name);

  NodeSpec config();
}

abstract class MarkExtension extends Extension {
  const MarkExtension(super.name);

  MarkSpec config();
}
