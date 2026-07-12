import 'package:test/test.dart';
import 'package:docx_rendering/src/tiptap/core/index.dart';

void main() {
  test('creates a schema with concrete Tiptap extensions', () {
    final manager = ExtensionManager(const [
      DocumentExtension(),
      TextExtension(),
      ParagraphExtension(),
      BoldExtension(),
      ItalicExtension(),
    ]);

    final schema = manager.createSchema();

    // Verify nodes are registered correctly
    expect(schema.nodes.containsKey('doc'), isTrue);
    expect(schema.nodes.containsKey('text'), isTrue);
    expect(schema.nodes.containsKey('paragraph'), isTrue);

    // Verify marks are registered correctly
    expect(schema.marks.containsKey('bold'), isTrue);
    expect(schema.marks.containsKey('italic'), isTrue);

    // Verify content constraints and structure
    final docType = schema.nodes['doc']!;
    expect(docType.spec.content, equals('block+'));

    final paragraphType = schema.nodes['paragraph']!;
    expect(paragraphType.spec.content, equals('inline*'));
    expect(paragraphType.spec.group, equals('block'));

    final textType = schema.nodes['text']!;
    expect(textType.spec.group, equals('inline'));
    expect(textType.spec.inline, isTrue);

    // Verify parseDOM rules exist
    expect(paragraphType.spec.parseDOM, isNotNull);
    expect(paragraphType.spec.parseDOM!.length, equals(1));

    final boldType = schema.marks['bold']!;
    expect(boldType.spec.parseDOM, isNotNull);
    expect(boldType.spec.parseDOM!.length, equals(3));

    final italicType = schema.marks['italic']!;
    expect(italicType.spec.parseDOM, isNotNull);
    expect(italicType.spec.parseDOM!.length, equals(3));
  });
}
