# Editor Tiptap/DOCX em AngularDart

Exemplo de um componente AngularDart que consome somente a API pública de
`package:docx_rendering`.

O `TiptapDocxEditorComponent`:

- cria `TiptapEditor` e `TiptapToolbarController` em `ngAfterViewInit`;
- gera identificadores exclusivos, permitindo várias instâncias na página;
- usa `package:web` diretamente, sem conversões frágeis de `dart:html`;
- cancela streams e destrói toolbar/editor em `ngOnDestroy`;
- abre DOCX e exporta DOCX, PDF vetorial e Quill Delta;
- carrega o CSS do pacote globalmente para alcançar os nós criados pelo
  ProseMirror em runtime.

## Executar

```powershell
cd example2
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run webdev serve web:8081 --auto=refresh -- --delete-conflicting-outputs
```

Abra `http://127.0.0.1:8081`.

O CSS estrutural vem de
`packages/docx_rendering/assets/tiptap_editor.css`; o arquivo CSS do componente
contém apenas o chrome específico deste exemplo AngularDart.
