import 'package:test/test.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';
import 'package:docx_rendering/src/prosemirror/model/index.dart';

class ParagraphExtension extends NodeExtension {
  const ParagraphExtension() : super('paragraph');

  @override
  NodeSpec config() => NodeSpec(content: 'inline*', group: 'block');
}

class DocExtension extends NodeExtension {
  const DocExtension() : super('doc');

  @override
  NodeSpec config() => NodeSpec(content: 'block+');
}

class TextExtension extends NodeExtension {
  const TextExtension() : super('text');

  @override
  NodeSpec config() => NodeSpec(inline: true, group: 'inline');
}

class EmExtension extends MarkExtension {
  const EmExtension() : super('em');

  @override
  MarkSpec config() => MarkSpec();
}

void main() {
  test('creates a schema from extensions', () {
    final manager = ExtensionManager(const [
      DocExtension(),
      ParagraphExtension(),
      TextExtension(),
      EmExtension(),
    ]);

    final schema = manager.createSchema();
    expect(schema.nodes.containsKey('paragraph'), isTrue);
    expect(schema.nodes.containsKey('text'), isTrue);
    expect(schema.marks.containsKey('em'), isTrue);
  });
}
