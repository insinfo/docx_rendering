import '../../prosemirror/model/index.dart';
import 'extension.dart';

class ExtensionManager {
  final List<AnyExtension> extensions;

  ExtensionManager(this.extensions);

  Schema createSchema() {
    final nodes = <String, NodeSpec>{};
    final marks = <String, MarkSpec>{};
    for (final extension in extensions) {
      if (extension is NodeExtension) {
        nodes[extension.name] = extension.config();
      } else if (extension is MarkExtension) {
        marks[extension.name] = extension.config();
      }
    }
    return Schema(SchemaSpec(nodes: nodes, marks: marks));
  }

  List<dynamic> createPlugins() => const [];
}
