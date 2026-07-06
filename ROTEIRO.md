# ROTEIRO — Porte docxjs → docx_rendering (Dart puro)

> **Origem:** `referencias/docxjs-master/src/` (TypeScript, 48 arquivos, ~5 642 linhas)
> **Destino:** `lib/src/` (Dart puro, zero dependências externas além de `package:web`)
> **Princípio:** Dart puro — sem dependências de pub no runtime (apenas `dart:core`, `dart:convert`, `dart:typed_data`, `package:web`).

---

## Mapa de pastas: TS → Dart

| TS (docxjs `src/`)                  | Dart (`lib/src/`)                       | Obs                                        |
|--------------------------------------|-----------------------------------------|--------------------------------------------|
| `parser/xml-parser.ts`               | `parser/xml_parser.dart`                | Usa browser DOMParser via `package:web`    |
| `utils.ts`                           | `utils.dart`                            | Funções utilitárias puras                  |
| `length.ts`                          | `length.dart`                           | Classe Length (CSS units)                  |
| `html.ts`                            | `html.dart`                             | Virtual-DOM helper `h()` via `package:web` |
| `javascript.ts`                      | `javascript.dart`                       | Tab-stop compute via DOM medidas           |
| `common/open-xml-package.ts`         | `common/open_xml_package.dart`          | Vendorar ZIP (inflate) inline              |
| `common/part.ts`                     | `common/part.dart`                      |                                            |
| `common/relationship.ts`             | `common/relationship.dart`              |                                            |
| `common/content-types.ts`            | `common/content_types.dart`             |                                            |
| `document/dom.ts`                    | `document/dom.dart`                     | Enums + interfaces → classes Dart          |
| `document/common.ts`                 | `document/common.dart`                  | ns, Length typedef, conversões             |
| `document/document.ts`               | `document/document.dart`                |                                            |
| `document/document-part.ts`          | `document/document_part.dart`           |                                            |
| `document/paragraph.ts`             | `document/paragraph.dart`               |                                            |
| `document/run.ts`                    | `document/run.dart`                     |                                            |
| `document/section.ts`               | `document/section.dart`                 |                                            |
| `document/border.ts`                | `document/border.dart`                  |                                            |
| `document/style.ts`                 | `document/style.dart`                   |                                            |
| `document/bookmarks.ts`             | `document/bookmarks.dart`               |                                            |
| `document/fields.ts`                | `document/fields.dart`                  |                                            |
| `document/line-spacing.ts`          | `document/line_spacing.dart`            |                                            |
| `numbering/numbering.ts`            | `numbering/numbering.dart`              |                                            |
| `numbering/numbering-part.ts`       | `numbering/numbering_part.dart`         |                                            |
| `styles/styles-part.ts`             | `styles/styles_part.dart`               |                                            |
| `theme/theme.ts`                    | `theme/theme.dart`                      |                                            |
| `theme/theme-part.ts`               | `theme/theme_part.dart`                 |                                            |
| `notes/elements.ts`                 | `notes/elements.dart`                   |                                            |
| `notes/parts.ts`                    | `notes/parts.dart`                      |                                            |
| `comments/elements.ts`              | `comments/elements.dart`                |                                            |
| `comments/comments-part.ts`         | `comments/comments_part.dart`           |                                            |
| `comments/comments-extended-part.ts`| `comments/comments_extended_part.dart`  |                                            |
| `header-footer/elements.ts`         | `header_footer/elements.dart`           |                                            |
| `header-footer/parts.ts`            | `header_footer/parts.dart`              |                                            |
| `font-table/fonts.ts`               | `font_table/fonts.dart`                 |                                            |
| `font-table/font-table.ts`          | `font_table/font_table.dart`            |                                            |
| `settings/settings.ts`              | `settings/settings.dart`                |                                            |
| `settings/settings-part.ts`         | `settings/settings_part.dart`           |                                            |
| `document-props/core-props.ts`      | `document_props/core_props.dart`        |                                            |
| `document-props/core-props-part.ts` | `document_props/core_props_part.dart`   |                                            |
| `document-props/extended-props.ts`  | `document_props/extended_props.dart`    |                                            |
| `document-props/extended-props-part.ts`| `document_props/extended_props_part.dart`|                                          |
| `document-props/custom-props.ts`    | `document_props/custom_props.dart`      |                                            |
| `document-props/custom-props-part.ts`| `document_props/custom_props_part.dart` |                                            |
| `vml/vml.ts`                        | `vml/vml.dart`                          |                                            |
| `document-parser.ts`                | `document_parser.dart`                  | 1735 linhas — maior arquivo               |
| `html-renderer.ts`                  | `html_renderer.dart`                    | 1469 linhas — segundo maior               |
| `word-document.ts`                  | `word_document.dart`                    |                                            |
| `docx-preview.ts`                   | `docx_preview.dart`                     | API pública                                |

**Total estimado: ~48 arquivos Dart**

---

## Estratégia de dependências

### ZIP (inflate/deflate)
- Vendorar o `ZipArchive` + `Inflate` do projeto `ce_zip` (`canvas-editor-port/packages/ce_zip/`)
  em `lib/src/zip/` (≈ 11 arquivos, ~1 900 linhas).
- Zero dependências externas.

### XML
- O docxjs original usa `DOMParser` nativo do browser.
- No Dart web, usar `DomParser()` do `package:web` (mesmo approach).
- `XmlParser` helper portado 1:1 de `xml-parser.ts`.

### HTML DOM
- O docxjs usa `document.createElement` / `document.createElementNS`.
- No Dart web, usar `document.createElement()` / `document.createElementNS()` via `package:web`.
- A função `h()` de `html.ts` será portada diretamente.

---

## Fases do Porte (checklist)

### Fase 0 — Infraestrutura (pré-requisito)
- [ ] 0.1 Vendorar ZIP em `lib/src/zip/` (copiar de `ce_zip`)
- [ ] 0.2 Criar `lib/src/parser/xml_parser.dart` (portar `xml-parser.ts` usando `package:web` DomParser)

### Fase 1 — Utilitários & tipos base
- [ ] 1.1 `lib/src/utils.dart` — portar `utils.ts`
- [ ] 1.2 `lib/src/length.dart` — portar `length.ts`
- [ ] 1.3 `lib/src/html.dart` — portar `html.ts` (h(), cx(), ns enum)
- [ ] 1.4 `lib/src/javascript.dart` — portar `javascript.ts` (tab-stop)

### Fase 2 — Common (pacote OPC)
- [ ] 2.1 `lib/src/common/relationship.dart` — portar `relationship.ts`
- [ ] 2.2 `lib/src/common/content_types.dart` — portar `content-types.ts`
- [ ] 2.3 `lib/src/common/part.dart` — portar `part.ts`
- [ ] 2.4 `lib/src/common/open_xml_package.dart` — portar `open-xml-package.ts` (usar ZIP vendorado)

### Fase 3 — Modelos de documento
- [ ] 3.1 `lib/src/document/dom.dart` — portar `dom.ts` (DomType enum + interfaces)
- [ ] 3.2 `lib/src/document/common.dart` — portar `common.ts` (ns, LengthUsage, conversões)
- [ ] 3.3 `lib/src/document/border.dart` — portar `border.ts`
- [ ] 3.4 `lib/src/document/line_spacing.dart` — portar `line-spacing.ts`
- [ ] 3.5 `lib/src/document/run.dart` — portar `run.ts`
- [ ] 3.6 `lib/src/document/section.dart` — portar `section.ts`
- [ ] 3.7 `lib/src/document/paragraph.dart` — portar `paragraph.ts`
- [ ] 3.8 `lib/src/document/bookmarks.dart` — portar `bookmarks.ts`
- [ ] 3.9 `lib/src/document/fields.dart` — portar `fields.ts`
- [ ] 3.10 `lib/src/document/style.dart` — portar `style.ts`
- [ ] 3.11 `lib/src/document/document.dart` — portar `document.ts`
- [ ] 3.12 `lib/src/document/document_part.dart` — portar `document-part.ts`

### Fase 4 — Parts especializados
- [ ] 4.1 `lib/src/numbering/numbering.dart` — portar `numbering.ts`
- [ ] 4.2 `lib/src/numbering/numbering_part.dart` — portar `numbering-part.ts`
- [ ] 4.3 `lib/src/styles/styles_part.dart` — portar `styles-part.ts`
- [ ] 4.4 `lib/src/theme/theme.dart` — portar `theme.ts`
- [ ] 4.5 `lib/src/theme/theme_part.dart` — portar `theme-part.ts`
- [ ] 4.6 `lib/src/notes/elements.dart` — portar `notes/elements.ts`
- [ ] 4.7 `lib/src/notes/parts.dart` — portar `notes/parts.ts`
- [ ] 4.8 `lib/src/comments/elements.dart` — portar `comments/elements.ts`
- [ ] 4.9 `lib/src/comments/comments_part.dart` — portar `comments/comments-part.ts`
- [ ] 4.10 `lib/src/comments/comments_extended_part.dart` — portar `comments/comments-extended-part.ts`
- [ ] 4.11 `lib/src/header_footer/elements.dart` — portar `header-footer/elements.ts`
- [ ] 4.12 `lib/src/header_footer/parts.dart` — portar `header-footer/parts.ts`
- [ ] 4.13 `lib/src/font_table/fonts.dart` — portar `font-table/fonts.ts`
- [ ] 4.14 `lib/src/font_table/font_table.dart` — portar `font-table/font-table.ts`
- [ ] 4.15 `lib/src/settings/settings.dart` — portar `settings/settings.ts`
- [ ] 4.16 `lib/src/settings/settings_part.dart` — portar `settings/settings-part.ts`
- [ ] 4.17 `lib/src/document_props/core_props.dart` — portar `document-props/core-props.ts`
- [ ] 4.18 `lib/src/document_props/core_props_part.dart` — portar `document-props/core-props-part.ts`
- [ ] 4.19 `lib/src/document_props/extended_props.dart` — portar `document-props/extended-props.ts`
- [ ] 4.20 `lib/src/document_props/extended_props_part.dart` — portar `document-props/extended-props-part.ts`
- [ ] 4.21 `lib/src/document_props/custom_props.dart` — portar `document-props/custom-props.ts`
- [ ] 4.22 `lib/src/document_props/custom_props_part.dart` — portar `document-props/custom-props-part.ts`
- [ ] 4.23 `lib/src/vml/vml.dart` — portar `vml/vml.ts`

### Fase 5 — Mega-parsers
- [ ] 5.1 `lib/src/document_parser.dart` — portar `document-parser.ts` (1735 linhas)
- [ ] 5.2 `lib/src/html_renderer.dart` — portar `html-renderer.ts` (1469 linhas)

### Fase 6 — API pública & orquestração
- [ ] 6.1 `lib/src/word_document.dart` — portar `word-document.ts`
- [ ] 6.2 `lib/src/docx_preview.dart` — portar `docx-preview.ts`
- [ ] 6.3 Atualizar `lib/docx_rendering.dart` (barrel exports)

### Fase 7 — Verificação
- [ ] 7.1 `dart analyze` limpo (zero errors)
- [ ] 7.2 Compilar para JS (`dart compile js` ou `build_runner`)
- [ ] 7.3 Teste de fumaça: renderizar um .docx de exemplo no browser

---

## Padrões de conversão TS → Dart

| TypeScript                           | Dart                                     |
|--------------------------------------|------------------------------------------|
| `interface Foo { ... }`              | `class Foo { ... }` (plain class)        |
| `Record<string, string>`            | `Map<String, String>`                    |
| `any`                                | `dynamic` ou tipo explícito              |
| `string \| null`                     | `String?`                                |
| `for (let x of arr)`                | `for (final x in arr)`                   |
| `array.map(fn)`                     | `arr.map(fn).toList()`                   |
| `array.find(fn)`                    | `arr.firstWhereOrNull(fn)` (inline ext)  |
| `array.filter(fn)`                  | `arr.where(fn).toList()`                 |
| `array.reduce(fn, init)`            | `arr.fold(init, fn)`                     |
| `Promise<T>`                        | `Future<T>`                              |
| `async/await`                       | `async/await` (idêntico)                 |
| `export class`                      | top-level class (sem export keyword)     |
| `export enum Foo { A="a" }`         | `enum Foo { A("a"); const Foo(this.v); final String v; }` |
| `?.` optional chaining               | `?.` (idêntico)                          |
| `??` nullish coalescing              | `??` (idêntico)                          |
| `DOMParser().parseFromString()`      | `DomParser().parseFromString()` via `package:web` |
| `document.createElement()`          | `document.createElement()` via `package:web` |
| `JSZip.loadAsync(blob)`              | `ZipArchive.decode(bytes)` vendorado     |
| `elem.localName`                    | `elem.localName` via `package:web`       |
| `elem.namespaceURI`                 | `elem.namespaceURI` via `package:web`    |
| `Node.ELEMENT_NODE`                 | `Node.ELEMENT_NODE` (1)                  |

---

## Referências do Usuário

| Projeto local                                   | Utilidade                        |
|--------------------------------------------------|----------------------------------|
| `c:\MyDartProjects\docx_dart`                    | Modelo OPC, XML parser, ZIP      |
| `c:\MyDartProjects\canvas-editor-port\packages\ce_zip`  | ZIP inflate/deflate vendorável |
| `c:\MyDartProjects\canvas-editor-port\packages\ce_xml`  | XML DOM/SAX (referência)       |
| `c:\MyDartProjects\canvas-editor-port\packages\ce_opc`  | OPC package (referência)       |
| `c:\MyDartProjects\canvas-editor-port\packages\ce_docx` | DOCX reader (referência)       |

---

## Notas

1. **`package:web`** é a única dependência pub (já está no pubspec.yaml).
   Ela expõe `DomParser`, `Element`, `Document`, `Node`, `HTMLElement` etc.
   para interop direto com o browser DOM — mesmo approach do docxjs original.

2. **ZIP**: Em vez de `JSZip`, vendoramos o `ZipArchive` Dart puro do `ce_zip`.
   No `OpenXmlPackage.load()` recebemos `Uint8List` (bytes do .docx) em vez de `Blob`.

3. **Sem `jsdom`/`xml`**: O XML parsing usa `DomParser` do browser (via `package:web`),
   portanto esta lib funciona **apenas na web** (mesmo escopo do docxjs original).

4. Os dois maiores arquivos (`document-parser.ts` = 1735 linhas, `html-renderer.ts` = 1469 linhas)
   serão portados por último, quando toda a infraestrutura já estiver compilando.
