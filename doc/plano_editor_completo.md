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
- **Paginação pós-render** (`lib/src/docx_rendering/renderer/pagination.dart`, 483 linhas): arquitetura Measure→Plan→Build (evita reflow), clona headers/footers, divide tabelas linha a linha e já divide parágrafos longos por busca binária com `Range.getBoundingClientRect`.
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

    PM_DOC -->|conversor direto §5.1| OUT_DOCX[OOXML próprio → .docx]
    PM_DOC -->|conversor vetorial §5.2 + geometria da paginação| OUT_PDF[jsPDF → .pdf]
    PM_DOC <-->|DeltaConverter §5.3| QUILL[Quill Delta JSON]
```

**Decisão de arquitetura (mudança em relação ao plano anterior):** DOCX e Delta fazem travessia **direta do AST ProseMirror**, sem HTML intermediário. O PDF também possui esse caminho puro-Dart como fallback headless, mas, quando há uma `EditorView`, consome um plano geométrico capturado diretamente do DOM já paginado. Essa exceção é intencional: só o browser conhece as quebras finais de line boxes, a geometria dos floats e as cópias de headers/footers. O `DOMSerializer` continua restrito ao clipboard, a `getHTML()` e à materialização dos payloads editáveis de cabeçalho/rodapé.

---

## 3. LACUNA CRÍTICA #1: A VIEW REAL DO PROSEMIRROR

A view deixou de ser scaffold e agora é uma implementação funcional inicial. **Ela continua sendo o item que define R1 e R5**: no ProseMirror original, a classe `ViewDesc` mantém uma árvore paralela DOM↔documento e, a cada transação, redesenha **apenas os nós alterados** (diffing estrutural). O próximo trabalho aqui é endurecer a fidelidade do `domchange`/IME/clipboard e medir re-render localizado em documentos grandes.

### 3.1. Tarefas (portar de `referencias/prosemirror-view/src/`)
- [x] `viewdesc.dart` real: hierarquia `ViewDesc`/`NodeViewDesc`/`TextViewDesc`/`MarkViewDesc`, algoritmo `updateChildren` (reuso de nós DOM), mapeamento DOM↔posição.
- [x] `domobserver.dart` inicial real: `MutationObserver` + reconciliação de edições nativas do browser por região suja.
- [x] Sincronização de seleção nativa antes de comandos externos: registros `selectionchange` sem mutação agora geram transação de seleção; a toolbar força o flush no `pointerdown` antes que botões/selects movam o foco. Validado no Chrome com seleção DOM real aplicando bold, fonte, cor e alinhamento.
- [x] `input.dart` inicial real: keydown → keymap, composição IME (`compositionstart/end`), beforeinput e props de plugin.
- [x] `clipboard.dart`: copy/cut serializa via `DOMSerializer`; paste via `parseSlice`. O parser agora testa `nodeType`/`nodeName` antes de acessar propriedades de `Element`, porque `package:web` pode aceitar `Comment` (`<!--StartFragment-->`) e `DocumentFragment` nos checks JS interop; isso eliminou o `Null is not a subtype of String` observado ao colar no AngularDart.
- [x] Seleção: sincronização bidirecional `Selection` DOM ↔ `TextSelection`/`NodeSelection`.
- [x] `decoration.dart`: `Decoration.widget/inline/node` + `DecorationSet` (necessário para cursor de drop, realce de busca e paginação por decorações).
- [x] Portar `prosemirror-dropcursor` (plugin visual via `PluginSpec.view`, `DropCursorView` e extensão Tiptap `DropcursorExtension`).
- [ ] Endurecer `domchange.dart` para paridade completa com `prosemirror-view/src/domchange.ts`, incluindo casos de composição, joins/backspace e restauração precisa de seleção.
- [ ] Adicionar teste de `MutationObserver` provando re-render localizado por parágrafo.

**Aceite parcial já validado:** a demo `web/tiptap_demo.html` compila para JS e foi verificada em Chrome headless: digitação, `Ctrl+B`, `Ctrl+Z`/`Ctrl+Y`, `getTiptapHTML()` e `setEditable(false)` funcionam sem erros de console. O dropcursor foi validado por smoke de `dragover`, criando overlay `.prosemirror-dropcursor-*`. **Aceite final pendente:** digitar no meio de um documento de 200 páginas altera apenas o subtree DOM do parágrafo editado (verificável com `MutationObserver` no teste), latência < 16 ms.

---

## 4. LACUNA CRÍTICA #2: DOCUMENTOS GRANDES (R1)

### 4.1. Abertura eficiente
O `WordDocument.load` atual é monolítico. Estratégia em três camadas, da mais barata para a mais cara — **implementar nessa ordem e medir antes de avançar** (pode ser que as duas primeiras bastem):

1. **[x] Parse cooperativo:** o Dart compilado para JS não tem isolates; trabalho longo deve ceder o event loop. **Feito:** `_parseBodyElementsAsync` cede o event loop a cada `chunkSize` elementos (default 50) e reporta progresso; exposto em `Options.onParseProgress`/`Options.parseChunkSize` → `parseAsync`.
2. **[x] `content-visibility: auto`** + `contain-intrinsic-size` nas `<section>` de página geradas pela paginação: o browser pula layout/paint das páginas fora da viewport. **Feito** na fase Build de `pagination.dart` (placeholder com a geometria real da página); validado no harness Puppeteer (screenshot do meio do documento renderiza integralmente).
3. **Virtualização real (se necessário):** páginas fora de uma janela de ±10 viram placeholders `<div>` com altura fixa conhecida (a geometria já foi calculada na fase Plan da paginação); `IntersectionObserver` materializa/desmaterializa ao rolar. A árvore ProseMirror permanece completa em memória (ela é barata — estrutura persistente imutável); só o DOM é virtualizado, via `Decoration.node` marcando páginas ocultas.

### 4.2. Conversor DOCX → ProseMirror direto
- [x] Criar `lib/src/tiptap/converters/docx_import.dart`: traversal do `WordDocument` emitindo `PMNode`s direto, **sem materializar HTML no DOM**. O importador agora resolve a cascata `docDefaults → basedOn/linked → estilo → formatação direta`, converte fonte/tamanho/cor/alinhamento/spacing/indentação/line-height, restaura `numPr` como listas, preserva tabelas e resolve imagens de body/header/footer no caminho assíncrono. Validado pelo round-trip e pelo DOCX real `PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx` no harness Puppeteer.
- [x] Schema do editor com atributos suficientes para o round-trip principal: estilos de bloco, margens, indentação, line-height, keep/page-break, largura/bordas de tabela, geometria da seção e payloads de headers/footers em `doc.attrs`. `TiptapEditor.setDocument()` substitui conteúdo **e attrs** numa única transação, evitando perder esses metadados na abertura.
- [x] Preservar o VML relevante do documento de referência: textboxes com borda/posição (a caixa “Continuação de Processo”) são convertidos em tabela posicionada; imagens dos headers/footers são data-URI e materializadas pelo paginador.
- [x] Preservar a grade de tabelas: `w:tblGrid` vira tracks CSS, `tcW=0/auto` não colapsa a célula, `gridSpan` mantém `columnIndex`/`colspan` e `vMerge` vira `rowspan` sem duplicar as continuações. No modo paginado, `min-width` genérico de célula é neutralizado para não sobrepor tracks estreitos. Tracks residuais subpixel não invalidam mais a grade inteira: a tabela problemática do TR conserva `[683, 44, 8766, 6]` twips como `[46, 3, 584, 1]` px em vez de cair no fallback percentual que espalhava as colunas.
- [x] Preservar `w:trHeight`: o modelo/schema distinguem `atLeast` de `exact`; 1.485 das 1.642 linhas do TR têm altura explícita e 1.367 usam 290 twips (14,5 pt). O CSS aplica `min-height`/`height` como o módulo de tabela da referência minificada, incluindo clipping somente para `exact`.
- [x] Resolver numeração Word por `abstractNum`/`numId`, níveis e `startOverride`: formatos decimal, zero-padded, letras e romanos materializam rótulos hierárquicos como `1.2.` no DOM e no plano PDF. Símbolos Wingdings/Symbol usados como bullets são normalizados para glifos Unicode portáveis.
- [x] Preservar tracking de run (`w:spacing`) como `letter-spacing` no schema/DOM; a captura PDF emite `Tc` por run e o restaura para zero, evitando contaminar o texto seguinte.

### 4.3. Paginação incremental
A cópia minificada local revelou que o Tiptap Pages comercial usa uma solução diferente das extensões públicas: um único `Decoration.widget(0)` com uma cadeia de floats e sentinela (`referencias/tiptap.dev/template.tiptap.dev/_next/static/chunks/03j5g3xmqmuwh.js`, módulo 584282). O conteúdo normal flui entre header/footer/gap e o próprio browser quebra line boxes dentro de parágrafos/listas.
- [x] Portar a cadeia de floats/sentinela em `PaginationExtension`: A4 a 96 dpi, geometria DOCX dinâmica, `minHeight` no último footer, normalização de zoom, `ResizeObserver`/`MutationObserver`, debounce+rAF e estabilização contra oscilação A/B.
- [x] Parágrafo longo quebra entre páginas sem partir o AST nem medir cada bloco. Teste Chrome usa **um único parágrafo** e confirma o salto entre line boxes, crescimento e redução posterior para uma página.
- [x] Materializar e repetir headers/footers `first/even/default`, incluindo imagens e VML preservado. Tabelas em pages-mode usam `display: contents`/grid para o float avançar entre linhas.
- [x] Respeitar `w:titlePg` e `w:evenAndOddHeaders` também no editor de regiões. Se o documento contém um payload `even` dormente, mas `evenAndOddHeaders=false`, editar a página 2 atualiza `default` — a mesma variante realmente mostrada — em vez de salvar uma alteração invisível em `even`.
- [x] Interpretar campos Word `PAGE`/`NUMPAGES` preservados nos headers/footers: o paginador substitui os sentinelas por página atual/total depois que o número de folhas estabiliza, sem reutilizar o valor textual cacheado pelo Word.
- [x] Estabilizar documentos com uma linha/tabela maior que a área útil: o importador lê `Pages` de `docProps/app.xml`, mas o número salvo pelo Word só é usado como fallback quando o DOM comprova um bloco não-fluente. Edição do corpo volta imediatamente à medição viva. O TR de recuperação automática deixa de crescer 580→828→1076 páginas e estabiliza nas 140 páginas registradas pelo arquivo.
- [x] Tornar zoom estritamente visual: a escala é lida do ancestral exato, contagens não mudam por arredondamento de line boxes e a trava é invalidada na troca de documento. O fluxo ETP permanece em 18 páginas antes/depois do zoom a 60% e um Delta importado em seguida força uma nova medição, sem herdar a trava do DOCX anterior.
- [x] Retirar a régua vertical do contexto de floats. A versão anterior usava `float:left`; como os breakers usam `clear:both`, cada folha era deslocada pela altura inteira da régua. A régua agora é sticky, tem altura de layout zero e desenha a escala por pseudo-elemento.
- [x] Fixar a régua à borda esquerda visual da folha em todos os zooms/scrolls, sem participar do fluxo do documento nem deslocar os breakers.
- [x] Regressão estrutural do TR real: depois de restaurar `w:trHeight`, a paginação estabiliza em 142 páginas, com 142 headers, 142 footers e caixa VML repetida; o PDF contém as mesmas 142 páginas, reutiliza três XObjects de imagem e os desenha 285 vezes. Headers, footers, caixas, marcadores e tabelas permanecem dentro do MediaBox. O recorte/preto observado em alguns renderizadores é artefato de visualização, não perda de operadores no PDF.
- [ ] Fragmentar linhas de tabela entre páginas quando `w:cantSplit` não está presente. O Word divide células sincronizadamente (o PDF de referência continua a linha/item 196 da página 79 na 80), enquanto `tr { display:grid }` torna a linha atômica na cadeia de floats. O trace mede ~4.367 px de espaço desperdiçado em 102 páginas (~5,1 áreas úteis); isso explica o desvio atual de +2 páginas. As antigas 140 páginas eram uma compensação acidental entre linhas 2,33 px baixas demais e esse desperdício, portanto não se deve remover `trHeight` para forçar a contagem.
- [ ] Fechar a última diferença de métricas do DOCX ETP: o Word gravou 19 páginas e o layout atual do Chrome estabiliza em 18. Ajustar a equivalência de métricas de fonte/spacing e avaliar `w:lastRenderedPageBreak` sem tornar quebras cacheadas uma fonte permanente de verdade após edição. O desvio caiu de cinco páginas para uma, mas ainda não é paridade visual integral.
- [ ] Medir latência de tecla e custo de reflow com 200 páginas; virtualização real continua condicionada aos números.

---

## 5. PIPELINES DE CONVERSÃO

### 5.1. Exportação DOCX (R2) — gerador OOXML próprio (decisão revisada)
**Decisão (jul/2026): NÃO usar `docx_dart` como dependência** — restrição confirmada pelo usuário de que o runtime só pode depender de `package:web`. Em vez disso, `docx_export.dart` gera WordprocessingML diretamente (strings) e empacota com o `ZipArchive` próprio do repositório (`lib/src/docx_rendering/zip/`), que já tem deflate/encode. O `docx_dart` permanece apenas como referência de código.
- [x] Criar `lib/src/tiptap/converters/docx_export.dart` (`DocxExporter`): traversal do `PMNode` emitindo `document.xml`, `styles.xml` (Normal, Heading 1..9, ListParagraph), `numbering.xml` (bullet/decimal), `[Content_Types].xml`, rels e `word/media/*`. Pipeline cooperativo (yield a cada `chunkSize` blocos + callback de progresso). Saída por bytes (web-safe, roda também na VM).
- [x] Teste de round-trip: exportar → reimportar com `parseAsync`+`DocxImporter` → comparar (browser, `test/tiptap/converters/test_docx_roundtrip_browser.dart`); validação estrutural do pacote na VM (`test_docx_export.dart`, 8 testes). **R2 medido:** 6000 parágrafos (~200 páginas) exportados < 3 s na VM.
- Mapa implementado: `paragraph`→`<w:p>`+runs com bold/italic/underline/strike/cor/fonte/tamanho/highlight; `heading[level]`→`pStyle Heading{n}`; `table`→`<w:tbl>` com bordas e `gridSpan` (colspan); `image` data-URI→`<w:drawing>`+media+rel; listas→`numPr`+numbering. Perdas documentadas: link vira texto, `horizontalRule` vira parágrafo vazio, rowspan não emitido, imagem por URL http ignorada. Os payloads editados de header/footer/VML persistem no estado e no PDF DOM-driven, mas o exportador DOCX ainda não reemite as parts/relationships dessas regiões.

### 5.2. Exportação PDF (R4) — vetorial via porte `jsPDF`
**Decisão: 100% vetorial, sem canvas/rasterização** (o plano anterior estava contraditório nesse ponto). Texto selecionável, arquivo pequeno, geração rápida.

- [x] Copiar o porte de `C:\MyDartProjects\jsPDF\` para dentro do projeto o que for necessário. **Feito:** fechamento de 36 arquivos vendorizado em `lib/src/jspdf/`; sem dependências externas e com backend condicional VM/JS/Wasm. Módulos alheios ao pipeline (HTML, annotations, outline etc.) ficaram de fora. O segundo inflater zlib do porte foi removido: PNG/PDF e ZIP/DOCX agora compartilham `docx_rendering/zip/codecs/zlib/zlib_codec.dart`, que acrescenta o envelope RFC 1950 ao Deflate/Inflate existente.
- [x] Criar `lib/src/tiptap/converters/pdf_export.dart`: traversal do `PMNode` emitindo `pdf.text()`, `pdf.rect()`/linhas e `pdf.addImage()` PNG/JPEG. Inclui headings, marcas bold/italic/cor/fonte/tamanho, alinhamento, listas (inclusive `start`), `hardBreak`, tabelas, HR e imagens data-URI.
- [x] **Reusar a geometria da paginação**: `capturePaginatedPdfLayout()` captura a superfície contínua por floats e a converte em folhas físicas, incluindo linhas de texto, células, HR, imagens, caixas VML e cópias de headers/footers. O resultado é um `PdfLayoutPlan` consumido diretamente pelo exportador, sem recalcular word-wrap; imagens repetidas compartilham um alias/XObject. `capturePdfLayout()` continua atendendo páginas `<section>` do renderizador DOCX e, sem DOM/plano, permanece o fallback puro-Dart com métricas jsPDF.
- [x] Corrigir captura sob zoom CSS: `getBoundingClientRect()` inclui zoom, mas `getComputedStyle().fontSize` não. A captura separa `visualScaleY`, mantendo 16 px = 12 pt em zoom 60%, 100% e 150%; o harness gera e inspeciona o PDF real em 60% para impedir regressão de texto sobreposto.
- [x] Capturar marcadores de lista que existem como pseudo-elementos CSS (`data-docx-numbering-label`) em itens PDF reais. O PDF do TR preserva rótulos hierárquicos (`1.`, `1.1.`, `1.2.`...) e bullets, em vez de exportar apenas o texto dos parágrafos.
- [x] Fontes: TTFs fornecidas como `PdfFontAsset` são registradas uma vez por documento e subsetadas via `ttffont.dart`/Identity-H; família+peso/estilo são selecionados por run. As 14 fontes base usam WinAnsi/CP1252. Smoke com Roboto confirmou `/Type0`, `/ToUnicode`, `/Identity-H` e `/FontFile2`; a ordem extraída por `pdftotext` ficou correta após ajustar o fator das métricas vendorizadas.
- [x] Geração cooperativa: layout cede o event loop por chunk e render cede uma vez por página, com callback de progresso. Benchmark em `test_pdf_export.dart`: ~200 páginas vetoriais em < 5 s (R4); no Chrome, 2,863 s. Inclui testes de PNG com alpha/SMask, xref, tabelas, listas e plano explícito; JS e Wasm compilam.
- [x] Metadado PDF: `/CreationDate` usa o sinal de fuso da convenção PDF (`-03'00'` em São Paulo), coberto para offsets negativos, positivos com meia hora e UTC.

### 5.3. Quill Delta (R3) — via core do `dart_quill`
- [x] Trazer `delta.dart`, `delta_iterator.dart`, `operation.dart` de `dart_quill/lib/src/dependencies/dart_quill_delta/core/` (não reimplementar — já tem `compose`/`transform`/`diff` maduros). **Feito:** vendorizado em `lib/src/quill_delta/` (+ `diff_match_patch`), com `package:collection` substituído por `equality.dart` local para manter o runtime só com `package:web`. Exposto em `lib/quill_delta.dart`.
- [x] `lib/src/tiptap/converters/quill_delta.dart` (`QuillDeltaConverter`):
  - **Delta→PM (documento inteiro):** um único passe com `DeltaIterator`; acumular runs de texto em buffers e construir cada parágrafo **uma vez** (nunca `Fragment.append` repetido — é O(n²)); atributo de bloco vem do `\n` que fecha a linha (convenção Quill). Resultado aplicado como **uma única transação** `replaceWith(0, doc.size, ...)`.
  - **Delta incremental (retain/insert/delete sobre documento existente):** manter um mapeamento posição-Quill→posição-PM durante o passe (posições Quill contam 1 por char e 1 por embed; PM conta tokens de abertura/fechamento de nó). Emitir os `ReplaceStep`s correspondentes em uma transação única — é isso que faz um delta de 50k ops ser aplicado sem reconstruir o documento.
  - **PM→Delta:** traversal linear com marcas → attrs inline e tipo de bloco → attrs no `\n`.
- [x] Testes de propriedade: `toDelta(fromDelta(d)) == d` para deltas gerados aleatoriamente (50 seeds); benchmark com delta de 50k+ ops aplicado em uma transação < 1s na VM (`test/tiptap/converters/test_quill_delta.dart`). **Perdas documentadas:** tabelas e `hardBreak` não têm representação Quill; listas aninhadas achatam um nível; o caminho incremental cobre docs "flat" (parágrafos/headings) — split dentro de `listItem` cria parágrafo no mesmo item.
- [x] Importação de arquivo Quill Delta JSON nas demos Dart Web e AngularDart (`[{ops}]` ou `{ "ops": [...] }`), aplicada via `setDocument()` em uma transação. O smoke web importa 120 parágrafos e valida oito páginas; o equivalente AngularDart estabiliza em seis com a geometria do componente.

---

## 6. TIPTAP CORE E EXTENSÕES (ergonomia)

- [x] Concluir acoplamento inicial de `prosemirror-commands` + `keymap` + `history` no `EditorView`.
- [x] `TiptapEditor`: `getHTML()`, `getJSON()`, `setEditable()`, `isActive(name, [attrs])` básico.
- [x] `TiptapEditor`: eventos (`onUpdate`, `onSelectionUpdate`, `onFocus`, `onBlur`) via `Stream` (broadcast; `dispatchTransaction` centralizado funciona também headless).
- [x] `CommandManager` real mínimo (chaining: `editor.chain.focus().toggleBold().run()`).
- [x] Toolbar reutilizável no pacote: `TiptapToolbarController` recebe `TiptapEditor` + elemento raiz, usa somente seletores `data-tiptap-*` limitados à raiz, preserva a seleção nativa e solta listeners/streams em `destroy()`. Isso permite múltiplas instâncias e uso tanto em Dart Web puro quanto em AngularDart, sem IDs globais. `setColor`/`setFontFamily`/`setFontSize` mesclam os atributos de `textStyle` por run em vez de apagar estilos existentes.
- [x] Extensões restantes para paridade com a demo do tiptap.dev: `Heading`, `Strike`, `Code`, `Underline`, `Link`, `TextStyle` (color/font/size/background), `Highlight`, `BulletList`/`OrderedList`/`ListItem`, `TextAlign` (atributo em paragraph/heading + atalhos), `Image`, `Table` (+ row/cell/header com colspan/rowspan/colwidth), `HardBreak`, `HorizontalRule`, `History` (dedupe com o plugin default do editor). Comandos de lista portados do `prosemirror-schema-list` em `lib/src/prosemirror/schema_list/` (`wrapInList`, `splitListItem`, `liftListItem`, `sinkListItem`, com testes em `test/prosemirror/schema_list/`); `CommandManager` cobre todas (toggle de marcas, heading, listas, align, link/color, hardBreak/hr/image/insertTable). Keymap default: Mod-U/Mod-Shift-X/Mod-E, Enter/Tab/Shift-Tab em listas, Shift-Enter para hardBreak. Validado em Chrome (`test/tiptap/core/test_editor_browser.dart`).

---

## 7. INTERFACE (clone visual do tiptap.dev)

Referência visual: `referencias/tiptap.dev/tiptap.dev/index.html` (cópia Webflow salva — usar como guia de estética, não de código).

- [x] Layout de folha A4 centralizada (794 × 1123 px), sombra, viewport rolável, shell glassmorphism responsivo e temas claro/escuro, reproduzindo as proporções do editor DOCX da referência.
- [x] Toolbar: dropdown de estilo (Normal/H1/H2/H3), zoom, família/tamanho de fonte, bold/italic/underline/strike/code/link, cores, imagem, listas, alinhamento, tabela, HR, undo/redo e ações de arquivo (abrir DOCX, **abrir Delta JSON**, exportar DOCX/PDF, copiar Delta).
- [x] Estado ativo dos botões via `isActive` no evento `onSelectionUpdate`, preservando a seleção ao pressionar botões da toolbar.
- [x] Indicador de progresso para abrir/exportar integrado aos callbacks dos pipelines cooperativos, contagem de palavras/caracteres e notificações de sucesso/erro.
- [x] Assets portáteis: `lib/assets/tiptap_editor.css` contém apenas o CSS estrutural prefixado por `.tiptap-ui`; `TiptapIcons` injeta um subconjunto SVG local, sem CDN e sem carregar os ~713 KB do pacote completo Tabler. A pilha de fonte usa system UI por padrão; Inter pode ser adicionada pelo aplicativo como tema opcional.
- [x] Edição Word-like de regiões: duplo clique em um header/footer abre a cópia da região, mostra divisor tracejado e label `Cabeçalho`/`Rodapé`, protege campos PAGE/NUMPAGES e persiste o payload em `doc.attrs`. Imagens e caixas VML recebem oito alças de tamanho, uma alça de movimento e ações esquerda/centro/direita. **Limitação registrada:** a implementação atual edita a cópia DOM e a reconverte ao schema; uma segunda `EditorView` exclusiva da região e um nó `textBox` dedicado continuam sendo o caminho de longo prazo para paridade integral com o produto comercial.
- [x] Harness real `test/tiptap/render_demo_harness.dart`: compila Dart→JS, serve com Shelf e abre Chrome com Puppeteer. Além da toolbar/tema/seleção, gera PDF em zoom 60%, abre o DOCX real (508+ parágrafos, 3 tabelas, headers/footers/VML), importa Delta longo e valida paginação crescer/encolher; grava PNG/PDF/JSON/log sem erros de página.
- [x] `example2/` convertido em exemplo AngularDart 8 real: componente `TiptapDocxEditorComponent` com IDs por instância, `package:web`, lifecycle `ngAfterViewInit`/`ngOnDestroy`, toolbar declarativa, importação DOCX e exportação DOCX/PDF/Delta. O build Angular/Webdev e o smoke Puppeteer (`render_angular_example_harness.dart`) validam seleção nativa, undo, tema e modo somente leitura.

---

## 8. FASES DE EXECUÇÃO (ordem por caminho crítico)

### Fase 1 — View real do ProseMirror (bloqueia tudo)
Itens de §3.1. **Status:** demo digitável com bold/undo/redo funcionando via teclado; dropcursor visual validado em smoke. **Pendente para fechar fase:** italic no smoke automatizado, teste de MutationObserver confirmando re-render localizado, e endurecimento de `domchange`/IME.

### Fase 2 — Importação DOCX + documentos grandes
Itens de §4.1 e §4.2. Aceite: DOCX grande de `resources/` abre com primeira página < 1,5 s (medido no harness Puppeteer com `performance.now()`), scroll fluido.

### Fase 3 — Paginação incremental + edição em documento grande
**Status:** arquitetura Pages por floats, parágrafo longo, geometria DOCX e headers/footers implementados e cobertos no Chrome. **Pendente para fechar:** medir latência de tecla < 16 ms em documento de 200 páginas.

### Fase 4 — Conversores (podem andar em paralelo com a Fase 3)
§5.1 (DOCX out), §5.2 (PDF), §5.3 (Delta). Aceite: metas R2/R3/R4 medidas em benchmark; round-trips passam.

### Fase 5 — Tiptap API + extensões + UI
§6 e §7. **Status:** API, extensões, shell visual, toolbar portátil e fluxo Puppeteer com DOCX real/PDF/Delta estão implementados. **Pendente para fechar:** benchmark contínuo e round-trip visual automatizado dos artefatos exportados.

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
