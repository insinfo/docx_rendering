import '../../prosemirror/model/index.dart';
import '../core/extension.dart';

class TextExtension extends NodeExtension {
  const TextExtension() : super('text');

  @override
  NodeSpec config() => NodeSpec(
        group: 'inline',
        inline: true,
      );
}
