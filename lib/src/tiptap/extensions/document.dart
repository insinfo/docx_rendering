import '../../prosemirror/model/index.dart';
import '../core/extension.dart';

class DocumentExtension extends NodeExtension {
  const DocumentExtension() : super('doc');

  @override
  NodeSpec config() => NodeSpec(
        content: 'block+',
      );
}
