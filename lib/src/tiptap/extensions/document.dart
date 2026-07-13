import '../../prosemirror/model/index.dart';
import '../core/extension.dart';

class DocumentExtension extends NodeExtension {
  const DocumentExtension() : super('doc');

  @override
  NodeSpec config() => NodeSpec(
        content: 'block+',
        attrs: {
          'pageWidth': AttributeSpec(defaultValue: null, hasDefault: true),
          'pageHeight': AttributeSpec(defaultValue: null, hasDefault: true),
          'pageOrientation':
              AttributeSpec(defaultValue: null, hasDefault: true),
          'titlePage': AttributeSpec(defaultValue: null, hasDefault: true),
          'evenAndOddHeaders':
              AttributeSpec(defaultValue: false, hasDefault: true),
          'pageMarginTop': AttributeSpec(defaultValue: null, hasDefault: true),
          'pageMarginRight':
              AttributeSpec(defaultValue: null, hasDefault: true),
          'pageMarginBottom':
              AttributeSpec(defaultValue: null, hasDefault: true),
          'pageMarginLeft': AttributeSpec(defaultValue: null, hasDefault: true),
          'pageMarginHeader':
              AttributeSpec(defaultValue: null, hasDefault: true),
          'pageMarginFooter':
              AttributeSpec(defaultValue: null, hasDefault: true),
          'pageMarginGutter':
              AttributeSpec(defaultValue: null, hasDefault: true),
          // Advisory page count cached by Word in docProps/app.xml. The
          // paginator uses it only to bootstrap documents whose oversized
          // table rows cannot participate in the float chain; it is released
          // as soon as the editable body changes.
          'sourcePageCount':
              AttributeSpec(defaultValue: null, hasDefault: true),
          // Header/footer payloads are populated by importDocumentAsync. They
          // remain opaque JSON until the pagination view materializes them.
          'headers': AttributeSpec(defaultValue: null, hasDefault: true),
          'footers': AttributeSpec(defaultValue: null, hasDefault: true),
        },
      );
}
