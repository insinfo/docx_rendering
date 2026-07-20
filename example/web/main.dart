import 'package:docx_rendering/tiptap.dart';
import 'package:web/web.dart' as web;

void main() {
  TiptapDocxEditorComponent.mount(
    web.document.getElementById('app') as web.HTMLElement,
    options: const TiptapDocxEditorOptions(
      shell: TiptapEditorShellOptions(
        initialMode: TiptapEditorMode.word,
        locale: 'Português (Brasil)',
        width: '100%',
        height: 'min(840px, calc(100vh - 40px))',
        maxWidth: '1200px',
        margin: '0 auto',
        showTitleBar: true,
        showStatusBar: true,
        enableDocumentStatistics: false,
        hostStyles: {
          'min-height': '100vh',
          'padding': '20px',
          'box-sizing': 'border-box',
          'background': '#e9eef2',
        },
      ),
      exposeDebugApi: true,
    ),
  );
}
