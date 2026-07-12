# PLANO TÉCNICO COMPLETO: EDITOR ESTILO TIPTAP.DEV EM DART PURO

Plano de engenharia para construir um editor interativo no navegador equivalente ao [tiptap.dev](https://tiptap.dev/) (cópia visual salva em `referencias/tiptap.dev/tiptap.dev/index.html`), com os seguintes requisitos **não-funcionais como cidadãos de primeira classe**:

| # | Requisito | Meta mensurável (documento de referência: os DOCX grandes em `resources/`) |
|---|-----------|------------------------------------------------------------------------------|
| R1 | Abrir DOCX grande de forma eficiente | Primeira página visível < 1,5 s; documento de 200+ páginas navegável sem travar a UI (nenhuma tarefa > 50 ms no main thread após o primeiro paint) |
| R2 | Exportar DOCX | Documento de 200 páginas exportado < 3 s, fiel (estilos, tabelas, imagens, headers/footers) |
| R3 | Aplicar deltas grandes vindos do Quill | Delta com 50k+ ops convertido e aplicado < 1 s, em uma única transação |
| R4 | Exportar PDF rápido | PDF **vetorial** (texto selecionável/pesquisável) de 200 páginas < 5 s, sem rasterização |
| R5 | Edição fluida | Digitação em documento de 200 páginas com latência de tecla < 16 ms |

Tudo em **Dart puro** (runtime só com `package:web ^1.1.1`), compatível com compilação JS e Wasm.

---

## 1. INVENTÁRIO DE ATIVOS REUTILIZÁVEIS (o que já existe e onde)

Levantamento feito em jul/2026 sobre `C:\MyDartProjects`:

### 1.1. Neste repositório (`docx_rendering`)
- **Porte ProseMirror** (`lib/src/prosemirror/`): `model`, `transform`, `state`, `commands`, `history`, `keymap`, `inputrules`, `test_builder` e uma **view funcional inicial** em `lib/src/prosemirror/view/`. A view já monta `EditorView`, `ViewDesc`, `MutationObserver`, seleção DOM↔state, decorações, clipboard e handlers de input. `dart analyze` e `dart analyze lib/src/prosemirror/view/` estão limpos.
- **Porte Tiptap** (`lib/src/tiptap/`): core inicial com `TiptapEditor`, `ExtensionManager`, `CommandManager` encadeável mínimo, extensões `Document/Text/Paragraph/Bold/Italic`, plugins padrão de `history`/`keymap` e demo web digitável.
- **Renderizador DOCX→DOM** (`lib/src/docx_rendering/`): porte do docx-preview, com `renderAsync`. Carrega tudo em memória e renderiza de uma vez — sem lazy/streaming (ver §4.1).
- **Paginação pós-render** (`lib/src/docx_rendering/renderer/pagination.dart`, 483 linhas): arquitetura Measure→Plan→Build (evita reflow), clona headers/footers, divide tabelas linha a linha. **Pendência conhecida:** não divide parágrafo longo único entre páginas (a solução está em `referencias/tiptap-pages/src/core.ts`, função `binarySearchTextBreak`).
- **Harness Puppeteer** (`test/docx_rendering/render_harness.dart`): compila a demo, serve, faz upload de cada DOCX de `resources/`, salva PNG+HTML — base pronta para benchmarks automatizados.
- **Referências-fonte** em `referencias/`: todos os repositórios ProseMirror oficiais (inclusive `prosemirror-history`, `-commands`, `-keymap`, `-dropcursor`), o monorepo `tiptap-main`, e **quatro extensões de paginação do Tiptap** (`tiptap-pages`, `tiptap-extension-pagination`, `tiptap-pagination`, `tiptap-pagination-breaks`).

### 1.2. Projetos vizinhos
- **`docx_dart`** — porte maduro do python-docx (v1.2.0, 13 suítes de teste). **Escreve DOCX de verdade**: `addHeading`, `addParagraph`, `addTable`, `addPicture`, seções, headers/footers, merge de células, campos (TOC/PAGE). **Funciona na web** (ZIP próprio in-memory em `lib/src/internal/archive/`, opera por bytes via `lib/src/platform/file_access_stub.dart`). → pipeline de exportação DOCX.
- **`dart_quill`** — Delta **completo** em `lib/src/dependencies/dart_quill_delta/core/`: `delta.dart` com `compose`, `transform`, `diff`, `invert`; `delta_iterator.dart` (`peekLength`, `next(length)`); `operation.dart`. → base canônica do pipeline Quill (não reimplementar).
- **`jsPDF`** — porte Dart puro completo do jsPDF (17 suítes): texto + `split_text_to_size.dart` (word wrap), **embedding/subset TTF** (`lib/src/libs/ttffont.dart` parseia head/cmap/hhea/hmtx/glyf...), imagens (PNG/JPEG/BMP), vetorial (`modules/context2d.dart`, `matrix.dart`), Flate próprio, saída `blob`/`save()` na web. → pipeline PDF.
- **`canvas-editor-port`** / **`canvas_text_editor`** — editores em canvas, **fora do escopo** (este projeto NÃO é editor em canvas — ver §2). Só interessam como referência de código pontual: `canvas-editor-port/lib/src/document/` tem `docx/writer.dart` e `pdf/pdf_writer.dart` (pipelines de arquivo, independentes de canvas) caso `docx_dart`/`jsPDF` apresentem lacunas.
- **`pdf.js` / `pdfium_dart`** — portes Dart de *leitura* de PDF. Só relevantes se quisermos preview do PDF gerado; fora do caminho crítico.
- **Evitar na web:** `dart_graphics` (FFI/.dll, só VM); `pdfbox_dart` e `itext` (puro Dart, mas orientados a VM/assinatura — `itext/lib/src/layout` fica como alternativa de última instância ao jsPDF).

---

## 2. ARQUITETURA GERAL

**Decisão fundamental: o editor é HTML DOM + `contenteditable`, exatamente como o tiptap.dev.** A superfície de edição é a `EditorView` do ProseMirror renderizando nós DOM reais (parágrafos, tabelas, imagens como elementos HTML), com o browser cuidando de layout de texto, seleção nativa, IME e acessibilidade. **Não há renderização em canvas em nenhuma camada do editor** — os projetos de editor-em-canvas do workspace estão fora do escopo. O único uso de "desenho" é na exportação PDF (§5.2), que emite operadores vetoriais de PDF (não é canvas do browser).

```mermaid
graph TD
    DOCX[Arquivo DOCX] -->|docx_rendering parseAsync| WD[WordDocument]
    WD -->|conversor direto §4.2| PM_DOC[Documento ProseMirror AST]
    PM_DOC -->|EditorView + ViewDesc diffing| VIEW[DOM paginado + virtualizado]
    VIEW -->|Input/IME/Clipboard| TRANS[Transações]
    TRANS -->|State.apply| PM_DOC

    PM_DOC -->|conversor direto §5.1| OUT_DOCX[docx_dart → .docx]
    PM_DOC -->|conversor vetorial §5.2 + geometria da paginação| OUT_PDF[jsPDF → .pdf]
    PM_DOC <-->|DeltaConverter §5.3| QUILL[Quill Delta JSON]
```

**Decisão de arquitetura (mudança em relação ao plano anterior):** os conversores de exportação (DOCX, PDF, Delta) fazem travessia **direta do AST ProseMirror**, sem passar por HTML intermediário via `DOMSerializer`. Motivos: (a) HTML perde informação (estilos de seção, numeração, larguras de tabela em twips); (b) serializar para DOM e re-parsear é O(n) extra com alocação pesada; (c) a travessia do AST é pura (roda fora do DOM, testável na VM). O `DOMSerializer` continua existindo apenas para o clipboard e para `getHTML()`.

---

## 3. LACUNA CRÍTICA #1: A VIEW REAL DO PROSEMIRROR

A view deixou de ser scaffold e agora é uma implementação funcional inicial. **Ela continua sendo o item que define R1 e R5**: no ProseMirror original, a classe `ViewDesc` mantém uma árvore paralela DOM↔documento e, a cada transação, redesenha **apenas os nós alterados** (diffing estrutural). O próximo trabalho aqui é endurecer a fidelidade do `domchange`/IME/clipboard e medir re-render localizado em documentos grandes.

### 3.1. Tarefas (portar de `referencias/prosemirror-view/src/`)
- [x] `viewdesc.dart` real: hierarquia `ViewDesc`/`NodeViewDesc`/`TextViewDesc`/`MarkViewDesc`, algoritmo `updateChildren` (reuso de nós DOM), mapeamento DOM↔posição.
- [x] `domobserver.dart` inicial real: `MutationObserver` + reconciliação de edições nativas do browser por região suja.
- [x] `input.dart` inicial real: keydown → keymap, composição IME (`compositionstart/end`), beforeinput e props de plugin.
- [x] `clipboard.dart`: copy/cut serializa via `DOMSerializer`; paste via `parseSlice`.
- [x] Seleção: sincronização bidirecional `Selection` DOM ↔ `TextSelection`/`NodeSelection`.
- [x] `decoration.dart`: `Decoration.widget/inline/node` + `DecorationSet` (necessário para cursor de drop, realce de busca e paginação por decorações).
- [ ] Portar `prosemirror-dropcursor` (referência já clonada).
- [ ] Endurecer `domchange.dart` para paridade completa com `prosemirror-view/src/domchange.ts`, incluindo casos de composição, joins/backspace e restauração precisa de seleção.
- [ ] Adicionar teste de `MutationObserver` provando re-render localizado por parágrafo.

**Aceite parcial já validado:** a demo `web/tiptap_demo.html` compila para JS e foi verificada em Chrome headless: digitação, `Ctrl+B`, `Ctrl+Z`/`Ctrl+Y`, `getTiptapHTML()` e `setEditable(false)` funcionam sem erros de console. **Aceite final pendente:** digitar no meio de um documento de 200 páginas altera apenas o subtree DOM do parágrafo editado (verificável com `MutationObserver` no teste), latência < 16 ms.

---

## 4. LACUNA CRÍTICA #2: DOCUMENTOS GRANDES (R1)

### 4.1. Abertura eficiente
O `WordDocument.load` atual é monolítico. Estratégia em três camadas, da mais barata para a mais cara — **implementar nessa ordem e medir antes de avançar** (pode ser que as duas primeiras bastem):

1. **Parse cooperativo:** o Dart compilado para JS não tem isolates; trabalho longo deve ceder o event loop. Inserir pontos de `await Future.delayed(Duration.zero)` a cada N parágrafos no parser e no conversor DOCX→PM, com callback de progresso (barra de carregamento na UI).
2. **`content-visibility: auto`** + `contain-intrinsic-size` nas `<section>` de página geradas pela paginação: o browser pula layout/paint das páginas fora da viewport. Ganho grande, custo de uma linha de CSS.
3. **Virtualização real (se necessário):** páginas fora de uma janela de ±10 viram placeholders `<div>` com altura fixa conhecida (a geometria já foi calculada na fase Plan da paginação); `IntersectionObserver` materializa/desmaterializa ao rolar. A árvore ProseMirror permanece completa em memória (ela é barata — estrutura persistente imutável); só o DOM é virtualizado, via `Decoration.node` marcando páginas ocultas.

### 4.2. Conversor DOCX → ProseMirror direto
- [ ] Criar `lib/src/tiptap/converters/docx_import.dart`: traversal do `WordDocument` (já parseado por `docx_rendering`) emitindo `PMNode`s direto, **sem materializar HTML no DOM**. O caminho atual (renderAsync → DOM → DOMParser.parse) fica como fallback de validação nos testes (comparar os dois resultados).
- [ ] Schema do editor com atributos suficientes para round-trip: estilo de parágrafo, alinhamento, indentação, spacing, larguras de coluna em twips, propriedades de seção (guardadas em `doc.attrs`).

### 4.3. Paginação incremental
Hoje `paginate()` reprocessa o documento inteiro. Para edição:
- [ ] Transformar a paginação em plugin ProseMirror: a cada transação, usar `tr.mapping` para identificar o intervalo sujo e **repaginar apenas da página afetada para a frente, parando na primeira página cujo corte não mudou** (as extensões em `referencias/tiptap-extension-pagination` e `tiptap-pages` fazem exatamente isso — portar a lógica, não reinventar).
- [ ] Resolver a pendência do parágrafo longo: portar `binarySearchTextBreak` de `referencias/tiptap-pages/src/core.ts` (busca binária com `Range.getBoundingClientRect` para achar o ponto de quebra dentro do parágrafo).
- [ ] Debounce: repaginar em `requestIdleCallback`/microtask após pausa de digitação (~150 ms), nunca sincronamente no keystroke.

---

## 5. PIPELINES DE CONVERSÃO

### 5.1. Exportação DOCX (R2) — via `docx_dart`
- [ ] Criar `lib/src/tiptap/converters/docx_export.dart`: traversal do `PMNode` → API do `docx_dart` (`Document()`, `addParagraph`, `addTable`, `addPicture` com bytes, `addHeading` por nível, headers/footers a partir de `doc.attrs`). Saída por bytes (web-safe).
- [ ] Teste de round-trip: DOCX de `resources/` → importar → exportar → reimportar → comparar ASTs (tolerância documentada para o que não é preservado).
- Mapa mínimo: `paragraph`→`addParagraph`+runs com bold/italic/underline/cor/fonte; `heading[level]`→`addHeading`; `table`→`addTable` com merges; `image`→`addPicture`; listas→numbering do docx_dart.

### 5.2. Exportação PDF (R4) — vetorial via porte `jsPDF`
**Decisão: 100% vetorial, sem canvas/rasterização** (o plano anterior estava contraditório nesse ponto). Texto selecionável, arquivo pequeno, geração rápida.

- [ ] Copiar o porte de `C:\MyDartProjects\jsPDF\` para dentro do projeto (ou depender por path) — ele é auto-contido.
- [ ] Criar `lib/src/tiptap/converters/pdf_export.dart`: traversal do `PMNode` emitindo `pdf.text()`, `pdf.rect()`/linhas para bordas de tabela, `pdf.addImage()` para imagens.
- [ ] **Reusar a geometria da paginação**: a fase Plan já calculou onde cada bloco quebra de página e as larguras/altura de linha. O exportador consome esse plano em vez de recalcular word-wrap do zero — é isso que garante (a) PDF idêntico ao que se vê na tela e (b) velocidade. Para texto, `split_text_to_size.dart` do jsPDF só como fallback quando não houver plano (export sem render prévio).
- [ ] Fontes: embutir/subsetar TTF via `ttffont.dart` (uma vez por documento, cache por família+peso); bold/italic mapeados para as variantes da família.
- [ ] Geração cooperativa: uma página por microtask (`await` a cada página) com callback de progresso — 200 páginas sem travar a UI.

### 5.3. Quill Delta (R3) — via core do `dart_quill`
- [ ] Trazer `delta.dart`, `delta_iterator.dart`, `operation.dart` de `dart_quill/lib/src/dependencies/dart_quill_delta/core/` (não reimplementar — já tem `compose`/`transform`/`diff` maduros).
- [ ] `lib/src/tiptap/converters/quill_delta.dart`:
  - **Delta→PM (documento inteiro):** um único passe com `DeltaIterator`; acumular runs de texto em buffers e construir cada parágrafo **uma vez** (nunca `Fragment.append` repetido — é O(n²)); atributo de bloco vem do `\n` que fecha a linha (convenção Quill). Resultado aplicado como **uma única transação** `replaceWith(0, doc.size, ...)`.
  - **Delta incremental (retain/insert/delete sobre documento existente):** manter um mapeamento posição-Quill→posição-PM durante o passe (posições Quill contam 1 por char e 1 por embed; PM conta tokens de abertura/fechamento de nó). Emitir os `ReplaceStep`s correspondentes em uma transação única — é isso que faz um delta de 50k ops ser aplicado sem reconstruir o documento.
  - **PM→Delta:** traversal linear com marcas → attrs inline e tipo de bloco → attrs no `\n`.
- [ ] Testes de propriedade: `toDelta(fromDelta(d)) == d.normalize()` para deltas gerados aleatoriamente; benchmark com delta de 50k ops.

---

## 6. TIPTAP CORE E EXTENSÕES (ergonomia)

- [x] Concluir acoplamento inicial de `prosemirror-commands` + `keymap` + `history` no `EditorView`.
- [x] `TiptapEditor`: `getHTML()`, `getJSON()`, `setEditable()`, `isActive(name, [attrs])` básico.
- [ ] `TiptapEditor`: eventos (`onUpdate`, `onSelectionUpdate`, `onFocus`, `onBlur`) via `Stream`.
- [x] `CommandManager` real mínimo (chaining: `editor.chain.focus().toggleBold().run()`).
- [ ] Extensões restantes para paridade com a demo do tiptap.dev: `Heading`, `Strike`, `Code`, `Link`, `TextColor`/`Highlight`, `BulletList`/`OrderedList`/`ListItem`, `TextAlign`, `Image`, `Table` (+ row/cell/header), `HardBreak`, `HorizontalRule`, `History`, `Dropcursor`.

---

## 7. INTERFACE (clone visual do tiptap.dev)

Referência visual: `referencias/tiptap.dev/tiptap.dev/index.html` (cópia Webflow salva — usar como guia de estética, não de código).

- Layout de folha A4 centralizada com sombra (`box-shadow: 0 10px 30px rgba(0,0,0,0.08)`), tema claro/escuro glassmorphism, fontes Inter/Outfit **embarcadas localmente** (woff2 já salvos na cópia do site — sem CDN, para funcionar offline e em Wasm).
- Toolbar: dropdown de estilo (Normal/H1/H2), zoom, tamanho de fonte, grupo inline (bold/italic/strike/code/link + color pickers), grupo de blocos (listas, alinhamento), ações de arquivo (abrir DOCX, salvar DOCX, exportar PDF, copiar Delta).
- Estado ativo dos botões via `isActive` no evento `onSelectionUpdate`.
- Indicador de progresso para abrir/exportar (integrado aos callbacks de progresso dos pipelines cooperativos).

---

## 8. FASES DE EXECUÇÃO (ordem por caminho crítico)

### Fase 1 — View real do ProseMirror (bloqueia tudo)
Itens de §3.1. **Status:** demo digitável com bold/undo/redo funcionando via teclado. **Pendente para fechar fase:** italic no smoke automatizado, teste de MutationObserver confirmando re-render localizado, e endurecimento de `domchange`/IME.

### Fase 2 — Importação DOCX + documentos grandes
Itens de §4.1 e §4.2. Aceite: DOCX grande de `resources/` abre com primeira página < 1,5 s (medido no harness Puppeteer com `performance.now()`), scroll fluido.

### Fase 3 — Paginação incremental + edição em documento grande
Itens de §4.3. Aceite: latência de tecla < 16 ms em documento de 200 páginas; parágrafo longo quebra entre páginas.

### Fase 4 — Conversores (podem andar em paralelo com a Fase 3)
§5.1 (DOCX out), §5.2 (PDF), §5.3 (Delta). Aceite: metas R2/R3/R4 medidas em benchmark; round-trips passam.

### Fase 5 — Tiptap API + extensões + UI
§6 e §7. Aceite: paridade funcional com a toolbar da demo do tiptap.dev; teste e2e no harness: abrir DOCX → editar → exportar DOCX/PDF/Delta e validar integridade.

### Fase 6 — Benchmark contínuo
- [ ] Estender `test/docx_rendering/render_harness.dart` com um modo benchmark: mede open-time, latência de digitação (injeção de teclas via CDP), tempo de export PDF/DOCX para cada arquivo de `resources/`; grava JSON histórico em `test/output/bench/`.
- [ ] Rodar a cada fase e comparar com as metas da tabela do topo — **nenhuma fase fecha sem os números**.

---

## 9. RISCOS E DECISÕES REGISTRADAS

| Risco | Mitigação |
|---|---|
| Sem isolates no Dart→JS: qualquer conversor síncrono trava a UI | Todos os pipelines são cooperativos (yield por chunk) desde o design, não como retrofit |
| IME/composição no contenteditable é a parte mais traiçoeira da view | Portar fielmente o `domobserver` do PM (código de referência em `referencias/prosemirror-view/src/domobserver.ts`); testar com IME real cedo |
| Fidelidade DOCX↔PM: PM não representa tudo do WordprocessingML | Atributos opacos preservados em `attrs` (round-trip "lossless o suficiente"); documentar o que se perde |
| Porte jsPDF pode ter lacunas de fonte (acentos/subset) | Teste cedo com os DOCX reais de `resources/` (português, tabelas, VML) |
| Virtualização (§4.1 item 3) é complexa | Só implementar se `content-visibility` não bastar — medir primeiro |
