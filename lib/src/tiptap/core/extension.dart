import '../../prosemirror/model/index.dart';

abstract class AnyExtension {
  const AnyExtension();
}

abstract class Extension extends AnyExtension {
  final String name;
  const Extension(this.name);
}

abstract class NodeExtension extends Extension {
  const NodeExtension(super.name);

  NodeSpec config();
}

abstract class MarkExtension extends Extension {
  const MarkExtension(super.name);

  MarkSpec config();
}
