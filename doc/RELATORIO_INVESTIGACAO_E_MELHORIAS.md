# Relatório de Investigação e Plano de Melhorias — Editor/Visualizador DOCX (contenteditable, sem canvas)

> **Data:** 2026-07-19
> **Fontes investigadas:**
> 1. `resources/word.example.zip` + `resources/word.example/` — captura completa ("Save page as") do **Word for the web** (word.cloud.microsoft / word-edit.officeapps.live.com), 461 arquivos, ~93 MB descompactados, incluindo os bundles JS/CSS reais do editor.
> 2. `C:\MyDartProjects\docx_rendering` — o nosso projeto (viewer docx-preview portado + editor ProseMirror/Tiptap portado, Dart puro com `package:web` apenas).
> 3. `D:\EuroOfficeNative\DocumentServer` — fork do OnlyOffice DocumentServer com **sdkjs completo não-minificado** (referência de algoritmos).
> 4. `resources/*.docx` — documentos-alvo de fidelidade (ETP 19 págs., TR 140 págs.) + PNGs de gabarito por página + capturas de tela do Word 365.
>
> **Objetivo:** implementar no nosso editor contenteditable (sem canvas) as melhorias para: (a) colar/abrir ~200 páginas vindas do Word sem travar; (b) editar sem bugs/travamentos mantendo estilo e formatação originais; (c) réguas e recursos de edição fiéis ao Word; (d) estilos customizados de título; (e) sumário automático; (f) margens e tamanho de página configuráveis (A4, Letter, Ofício…); (g) importação de Quill Delta incluindo quill-better-table, tamanho de fonte, listas, cor de fundo, entrelinha etc.

---

## Índice

1. [Sumário executivo](#1-sumário-executivo)
2. [Engenharia reversa do Word for the web (word.example)](#2-engenharia-reversa-do-word-for-the-web)
3. [Estado atual do nosso projeto (gap analysis)](#3-estado-atual-do-nosso-projeto)
4. [Algoritmos de referência do OnlyOffice/DocumentServer](#4-algoritmos-de-referência-do-onlyofficedocumentserver)
5. [Inventário OOXML dos documentos-alvo](#5-inventário-ooxml-dos-documentos-alvo)
6. [Plano de melhorias — fases, tarefas e critérios de aceite](#6-plano-de-melhorias)
7. [Tabelas de referência rápida (unidades, tamanhos de página, arquivos)](#7-tabelas-de-referência-rápida)

---

## 1. Sumário executivo

**A descoberta central da investigação:** o Word for the web é exatamente o modelo que buscamos — **DOM + contenteditable nativo, sem canvas para o texto** — mas com uma nuance arquitetural decisiva: o layout (quebra de linha, paginação) **não é delegado ao CSS do navegador**. Uma engine própria ("Box4" + `linelayout-core.wasm`, 42 MB) mede o texto, decide as quebras e **emite/atualiza o DOM**, que o navegador apenas pinta. O DOM é a camada de apresentação; a verdade do layout está na engine.

Para o nosso caso (Dart + contenteditable), a estratégia recomendada é **híbrida**:
- Continuar delegando a **quebra de linha** ao navegador (via CSS fiel: mesmas fontes, `font-variant-ligatures:none`, entrelinha em `line-height` calculado, tabs materializados como spans com largura), aceitando pequenas diferenças de quebra em relação ao Word desktop;
- Mas assumir o controle da **paginação, régua, tabs, marcadores de lista, numeração, TOC e virtualização** com um modelo lógico próprio (como o Word Online e o OnlyOffice fazem), medindo o DOM de forma incremental.

**As 8 frentes de melhoria, em ordem de prioridade** (detalhes na §6):

| # | Frente | Estado atual | Meta |
|---|---|---|---|
| P1 | Paste/abertura de 200 páginas sem travar | Paste síncrono (risco real de travar); parse cooperativo só na abertura de DOCX | Paste cooperativo fatiado + render incremental |
| P2 | Virtualização de páginas | Inexistente (só `content-visibility:auto`) | Janela de páginas com placeholders (modelo Word Online) |
| P3 | Régua horizontal fiel (margens, indents, tabs) | Margens, quatro recuos e tab stops interativos; modo de tabela pendente | Régua 20px interativa (modelo Word/OnlyOffice) |
| P4 | Tamanho de página/margens configuráveis + UI | Geometria dinâmica e margens pela régua; falta diálogo de presets/custom | Page setup completo (A4/Letter/Ofício/custom) |
| P5 | Sumário automático (TOC) | Inexistente | Campo TOC gerado/atualizável com PAGEREF |
| P6 | Estilos customizados de título (galeria + round-trip) | Headings genéricos h1–h6; nome do estilo se perde | Registro de estilos nomeados com herança basedOn |
| P7 | Quill Delta completo (better-table, indent, line-height) | Delta básico OK; better-table ausente | Conversor completo |
| P8 | Fidelidade fina + benchmark contínuo | Tabs no-op, linhas de tabela atômicas, sem números de latência | F6/F7 fechados + harness de benchmark |

---

## 2. Engenharia reversa do Word for the web

### 2.1 Natureza da captura e mapa de arquivos

A captura é o editor real em execução. O DOM do documento **não** está salvo estaticamente (é construído em runtime pelo JS), mas os bundles e CSS estão íntegros e legíveis por grep. Arquivos-chave (todos sob `resources/word.example/`):

| Arquivo | Tamanho | Papel |
|---|---|---|
| `res.public.onecdn.static.microsoft/officeonline/hashed/e50ccb0b0b409312/linelayout-core.wasm` | 41,8 MB | Engine WASM de layout de linha (medição/quebra de texto) |
| `…/hashed/351afb16d868c806/wordeditords.js` | 4,96 MB | Bundle principal (constrói o DOM do documento, virtualização, paginação client-side) |
| `…/hashed/c009898cfeffbf81/wordeditords.box4.dll1.js` | 2,88 MB | Engine "Box4": réguas, floating objects, caret manager, page style |
| `…/hashed/3e772878482735f7/wordeditords.box4.dll2.js` | 824 KB | Box4 (RulerContainer, RulerPropertyBoundary, RulerContextMenu) |
| `…/hashed/c6b39345c05b1266/wordeditords.common.js` | 2,79 MB | Comum |
| `…/hashed/9d03c998e5bfacdd/wordeditor_version4.min.css` | 412 KB | **CSS principal** (páginas, réguas, seleção, containers) |
| `…/hashed/23c9cac59260bd16/editsurface.min.css` | 39 KB | CSS da superfície de edição |
| `word-edit.officeapps.live.com/we/wordeditorframe.aspx` | 748 KB | Shell/chrome do app (IDs de layout) |

> Nota: `wise.public.cdn.office.net/wise/owl/*.js` estão vazios na captura (`No Content`) — o bundle "owl" novo não foi salvo; toda a evidência vem do bundle clássico `wordeditords.*`, que é o que está em produção na página capturada.

### 2.2 Estrutura DOM da superfície do documento

Classes confirmadas como strings literais em `wordeditords.js`: `OutlineElement`, `NormalTextRun`, `TextRun`, `EOP`, `TabRun`, `LineBreakBlob`, `ListMarkerWrappingSpan`, além dos prefixos por-instância `SCXW…`/`BCX…` (escopo de CSS por documento; evita colisão ao copiar/colar).

Árvore reconstruída:

```
div.WACViewPanel                      ← scroll container (overflow:auto; height:100%)
 └ div.WACViewPanelContainer          ← position:absolute; inset:0
    ├ div.WACHorizontalRulerContainer ← régua horizontal (canvas, 20px)
    ├ div.WACVerticalRulerContainer   ← régua vertical (canvas, 20px)
    └ .PagesContainer                 ← CSS GRID (grid-row:2; BeforePageContent em grid-row:1)
       └ div.Page                     ← UMA por página; dimensões INLINE em px
          └ .PageContentContainer / .PageContentOrigin   ← position:absolute; z-index:3
             └ [EditingSurfaceBody]   ← contenteditable=true; aria-multiline
                └ div.OutlineElement  ← 1 bloco/parágrafo (position:relative; clear:both)
                   └ p.Paragraph      ← word-wrap:break-word; .Ltr/.Rtl
                      ├ span.ListMarker + span.ListMarkerWrappingSpan   ← bullet/número
                      ├ span.TextRun > span.NormalTextRun               ← texto real
                      ├ span.TabRun > span.TabChar                      ← tab (largura inline px)
                      ├ span.LineBreakBlob                              ← quebra manual
                      └ span.EOP                                        ← fim de parágrafo
```

CSS literal (copiado dos arquivos):

```css
/* wordeditor_version4.min.css */
.Page{background-color:window;background-color:var(--clrDocSurfaceBg,window);
      border:1px solid #ababab;border-radius:4px;margin-bottom:19px;
      margin-left:auto;margin-right:auto;position:relative}
div.OutlineElement,div.ParagraphTrackItem{clear:both;cursor:text;overflow:visible;position:relative}
div.OutlineElement.Ltr{direction:ltr}
div.OutlineElement.Rtl{direction:rtl}
li.OutlineElement{clear:both;cursor:text;overflow:visible;position:relative}
.ListMarker{display:inline-block;height:1px;visibility:visible}
.PagesContainer{grid-column:1;grid-row:2;position:relative}
.BottomlessViewContainer.PagesContainer{display:grid;justify-content:center;overflow:clip;position:absolute}
.ReflowViewContainer.PagesContainer{display:grid;justify-content:flex-start;overflow:visible;position:absolute}

/* editsurface.min.css */
.Paragraph{word-wrap:break-word}
.EditingSurfaceBody{background-color:transparent;border:none;outline:none}
.EditingSurfaceBody,.EditingSurfaceBody *{-webkit-user-select:text;-moz-user-select:text;-ms-user-select:text}
span.TextRun{font-variant-ligatures:none!important}
.TabRun{display:inline-block;font-family:Calibri,sans-serif;font-size:11pt;position:relative;
        text-indent:0;white-space:nowrap}
span.TabChar{display:inline-block;user-select:text}
```

**Pontos-chave:**
- **Página** = `div.Page` com borda `#ababab`, radius 4px, centralizada com `margin:auto`, gap de **19px** entre páginas, dimensões **inline em px** setadas por JS (`style.width/height`).
- **Margens** = offsets/padding inline da área de conteúdo (`.PageContentOrigin` absoluto) dentro da página.
- **Ligaduras desligadas** (`font-variant-ligatures:none!important`) em todos os runs — pré-requisito para mapeamento 1:1 caractere↔glifo (hit-testing e caret precisos).
- **font-size/font-family/line-height são aplicados inline por run/parágrafo** pela engine; o CSS global só define estrutura.
- **Tabs não são `\t`**: são `span.TabRun > span.TabChar` inline-block com **largura em px calculada** (distância até a próxima tab stop).
- **Listas não usam `::marker`**: o marcador é `span.ListMarker` controlado manualmente (posicionamento e hit-testing exatos).
- **Tabelas são `<table>/<td>/<th>` reais**, com `div.TableCellContent` na célula; seleção via classes `.TableRowSelected`, `.TableCellSelected`.
- **Quebra de página manual** tem indicador visual próprio (`.PageBreakBlob`/`.PageBreakBorderSpan`/`.PageBreakTextSpan`).

### 2.3 Unidades e dimensões

- Interno em **twips** (1440/polegada; a constante `1440` aparece 20× no bundle).
- Conversão para px: **15 twips por pixel CSS** (1440 ÷ 96 dpi).
- Dimensões default confirmadas no bundle: **816×1056 px** (Letter 8,5"×11") e **794×1123 / 793×1122 px** (A4 210×297 mm).

### 2.4 Réguas

- Containers de **20px** com fundo `#141414` (`--clrRulerBackgroundColor`); conteúdo (ticks, marcadores) desenhado em **canvas** (`rulerCanvasProps` no box4.dll1.js).

```css
.WACHorizontalRulerContainer{background-color:#141414;background-color:var(--clrRulerBackgroundColor,#141414);
                             height:20px;position:relative;top:0;width:100%;z-index:2}
.WACVerticalRulerContainer{background-color:#141414;height:100%;position:absolute;width:20px}
.ShowWACHorizontalRulerContainer{display:block}
```

- O objeto de desenho contém: `scale`, `margins[]` (esquerda/direita), `indents[]` (first-line, hanging, right), `precision`. Marcadores de margem/indent/tab são posições em `scale`/`precision` pintadas no canvas.
- Classes relacionadas em box4.dll2: `RulerContainer`, `RulerPropertyBoundary`, `RulerContextMenu`, `RulerDivider`, `RulerSettingInfo`.

### 2.5 Zoom

- **`transform: scale(fator)`** aplicado a um container único (código literal: `static setScale(m,u){ f.setTransform(m, "scale(" + u + ")"); … }`). Não usa a propriedade `zoom`. As réguas recebem o mesmo fator via `rulerCanvasProps.scale`.

### 2.6 Virtualização (confirmada)

- `ViewportActivePageRangeAdjustmentCalculatorVirtualizationWindow`, `"VirtualizationWindow"`, objeto `{IndexRenderWindowFirst, IndexRenderWindowLast, …}` e `WordEditor.ClientPagination` em `wordeditords.js`.
- Páginas fora da janela viram **placeholders com a altura correta** (scroll estável) e são re-hidratadas ao entrar no viewport. A decisão de janela é da engine (calculador de range ativo), não de `IntersectionObserver`.

### 2.7 Caret e seleção

- **Caret nativo do contenteditable** (não há div piscante para o texto). Mas a posição lógica (setas, hit-testing, mapa char↔px) é gerida por um **`Box4.CaretPositionManager`** próprio que ajusta a Selection nativa.
- Seleção pintada com classes próprias, não o highlight nativo:

```css
.EOP.Selected,.TextRun .Selected,.TabRun.Selected,.LineBreakBlob.Selected{
   border-color:#c6c6c6!important;border-color:var(--clrSelection,#c6c6c6)!important}
.…Selected.SelectionPipeBegin{border-left:1px solid #fff!important;margin-left:-1px}
.…Selected.SelectionPipeEnd{border-right:1px solid #fff!important;margin-right:-1px}
```

- Erros ortográficos: **CSS Custom Highlight API** (`span.NormalTextRun::highlight(SpellingError){text-decoration-style:wavy;…}`) com fallback SVG (`.SpellingErrorV2`).

### 2.8 Objetos flutuantes (imagens com wrapping)

- Container absoluto (`FloatingObjectsContainer*`) + overlays em **canvas e html** (`FloatingObjectOverlaysCanvasElement`/`…HtmlElement`) para handles/seleção.
- O contorno do texto é materializado com **quebras inseridas** (`textWrappingBreaks`) — não `float` CSS puro. Tipos: `TextWrappingSquare[Left|Right]`, `TextWrappingInLineWithText`.

### 2.9 Headers/Footers

```css
.HeaderFooterControl{bottom:0;left:0;position:absolute;right:0;top:0;z-index:1}
.HeaderFooterPane.Displayed{height:100px}
.HeaderFooterPane.Header{top:0}
.HeaderFooterPane.Footer{bottom:0}
```
Painel absoluto sobreposto por página, com overlay de foco.

### 2.10 Clipboard (formato do Word ao copiar)

Atributos confirmados no bundle: `data-contrast`, `data-ccp-props` (props de parágrafo compactadas), `data-ccp-parastyle` (nome do estilo de parágrafo), `paraid`/`paraeid` (IDs estáveis de parágrafo), `xml:lang`, `data-celllook`, `headers`. Wrappers `SCXW…`/`BCX…` no HTML copiado. **Nosso paste deve reconhecer esses atributos** para round-trip fiel de conteúdo copiado do Word Online (além do formato `mso-*` do Word desktop — ver §4.8).

### 2.11 Fontes

- UI: `Segoe UI Web` com `src:local("Segoe UI")` + woff. Documento: depende de **fontes locais** (`local(...)`); default **Calibri**. Os woff em `_DataURI` são só ícones de UI.
- Implicação: a engine não confia em métricas do browser para fontes ausentes — usa métricas próprias. No nosso caso (layout do browser), precisamos de **fallbacks métricos consistentes** (ex.: Arial→Liberation Sans/Arimo, Ecofont→sans genérica) e idealmente embutir as fontes críticas dos documentos-alvo.

---

## 3. Estado atual do nosso projeto

### 3.1 Arquitetura (dois subsistemas + conversores)

1. **Viewer** `lib/src/docx_rendering/` — porte do docx-preview: `.docx` → OOXML → DOM de uma vez; paginação como pós-processo que mede o DOM (`renderer/pagination.dart`, 3 fases Measure→Plan→Build). Demo: `example/web/main.dart`.
2. **Editor** `lib/src/prosemirror/` + `lib/src/tiptap/` — porte substancial e testado do ProseMirror (model/transform/state/view com contenteditable real) + Tiptap (25 extensões, `PaginationExtension` por float-chain, `PageRegionEditor` com régua vertical, toolbar declarativa). Demo principal: `web/tiptap_demo.dart`.
3. **Conversores** `lib/src/tiptap/converters/`: `docx_import.dart`, `docx_export.dart`, `pdf_export.dart` (+ jsPDF portado), `quill_delta.dart`.

Fluxo do produto: `.docx → parseAsync → WordDocument → DocxImporter → PMNode → TiptapEditor → EditorView (contenteditable) → PaginationExtension`.

**Problema estrutural:** viewer e editor têm **dois motores de paginação independentes** (contagem de páginas pode divergir entre "visualizar" e "editar"; manutenção duplicada).

### 3.2 Gap analysis por objetivo

| Objetivo | Estado | Evidência / lacuna |
|---|---|---|
| Colar/abrir 200 págs sem travar | **Parcial / arriscado** | Parse cooperativo existe (`parser/document_parser_core.dart:99`, chunk 50). MAS: `renderDocument` monta todo o DOM síncrono (`docx_preview.dart:108`); `paginate()` mede o doc inteiro num passe (reflow global); **paste via `view/clipboard.dart` → `parseSlice` é 100% síncrono** — colar 200 páginas roda numa única transação sem yield. Latência de tecla nunca medida (R5 aberto). |
| Virtualização | **Ausente** | Só `content-visibility:auto`. Sem janela de páginas/placeholders (plano §4.1 item 3 aberto). |
| Réguas fiéis | **Parcial (recuos e margens interativos)** | `WordRulers` cria régua horizontal alinhada à folha e régua vertical somente na página do caret, sincronizadas com zoom e ocultas em modo leitura. First-line, hanging, left, right e as quatro margens já têm drag com persistência e exportação DOCX. Ainda faltam tab stops e modo tabela. |
| Estilos customizados de título | **Parcial** | `DocxImporter._styles.headingLevel` (`docx_import.dart:693`) mapeia estilo→heading numérico; o **nome do estilo se perde** (sem galeria de estilos, sem round-trip fiel de `Nivel01`, `Nvel1-SemNum` etc.). |
| Sumário automático (TOC) | **Ausente** | Nenhuma geração/atualização de TOC no viewer nem no editor. Campos TOC só exibem o resultado pré-materializado no XML. |
| Página/margens configuráveis | **Parcial avançado** | Leitura de qualquer `pgSz`/`pgMar` alimenta paginação e PDF; as quatro margens podem ser alteradas pelas réguas e o DOCX exporta o `sectPr` real. Ainda não há diálogo de presets/orientação/custom; `PaginationOptions` mantém A4 apenas como fallback quando o documento não define geometria. |
| Quill Delta + better-table | **Parcial** | `quill_delta.dart:413-438` suporta bold/italic/underline/strike/code/link/color/font/size/background/header/align/list. **Faltam:** `quill-better-table` (nenhuma referência no código), `indent` de lista, `line-height`/spacing vindos do Delta; listas aninhadas achatam um nível. |
| Tamanho de fonte / cor de fundo | **OK** | `size`→fontSize, `background`→highlight; `w:shd`→background no viewer. |
| Entrelinha | **Parcial** | Lida do DOCX (`document/line_spacing.dart`, `block_style.dart`); não vem do Delta; sem controle na toolbar. |
| Export DOCX fiel | **Parcial** | `DocxExporter` não reemite parts/rels de header/footer/VML editados; perdas documentadas (link→texto, rowspan não emitido, imagem por URL ignorada). |
| Benchmark | **Ausente** | Fase 6 do plano (open-time/latência/export) não implementada; harness só faz PNG/estrutural, sem diff de pixels. |

### 3.3 Gargalos de performance identificados no código

1. Render do viewer não incremental (`docx_preview.dart:108-113`).
2. Reflow síncrono global na paginação (viewer e, em menor grau, editor).
3. Sem virtualização — todo o DOM materializado.
4. Imagens duplicadas em base64 (`word_document.dart:204`) — usar `URL.createObjectURL`.
5. ZIP/inflate síncronos (`open_xml_package.dart:48`).
6. **Paste síncrono** (`view/clipboard.dart`) — o maior risco para o requisito "colar 200 páginas".
7. Dois motores de paginação divergentes.
8. `tr{display:grid}` torna linhas de tabela atômicas → não fragmenta linha entre páginas (custa ~2 páginas no TR).

---

## 4. Algoritmos de referência do OnlyOffice/DocumentServer

O sdkjs está **completo e não-minificado** em `D:\EuroOfficeNative\DocumentServer\sdkjs\word\`. O OnlyOffice é canvas puro, então o mais reaproveitável para nós é o **modelo lógico** e a **estratégia de invalidação incremental**; a pipeline geométrica serve de referência onde precisarmos de paginação fiel (TOC com nº de página, réguas).

> Unidades: o sdkjs trabalha internamente em **mm** (`g_dKoef_pt_to_mm = 25.4/72` etc., `Editor/Styles.js:54-58`); twips↔mm só na borda de I/O. Nós podemos padronizar em twips (como o Word Online) ou mm — o importante é UMA unidade interna única.

### 4.1 Recálculo incremental em 3 níveis (`Editor/Document.js`)

Estado global: `CDocumentRecalcInfo` (`Document.js:314-461`) — flutuante corrente, controle de viúvas/órfãs, `KeepNextParagraph`, seção corrente, flags de pausa/reinício.

Do mais barato ao mais caro (`Document.js:2872-2879`):

1. **Fast Run Range** (`private_RecalculateFastRunRange:3253`): se todas as mudanças pertencem a **um único run** e são "simples" → recalcula só as linhas afetadas do parágrafo e repinta só a página. Caminho da digitação.
2. **Fast Whole Paragraph** (`private_RecalculateFastParagraph:3317` → `Recalculate_FastWholeParagraph`): mudanças confinadas a parágrafos inteiros. Aceito só se o parágrafo cabe em 1–2 páginas, o **`EndInfo`** (estado de campos/comentários abertos no fim do bloco) não mudou, os `Bounds` de cada página são idênticos e não mudou page/column-break na última linha. Se qualquer invariante quebra → nível 3.
3. **Completo fatiado**: menor índice alterado via histórico (`ChangeIndex`), recuo por `KeepNext`/seções, e recálculo página a página com **orçamento de tempo (~2 páginas por tick de `setTimeout`)**, interrompível/reiniciável se chegar nova edição (`:3094-3113`).

**Conceito a replicar:** cada bloco guarda um **`EndInfo`/estado-de-saída**; a comparação do EndInfo decide se a mudança "vazou" para os blocos seguintes. É isso que torna o incremental confiável.

Pseudocódigo adaptado ao nosso editor (browser faz a quebra de linha; nós fazemos a paginação):

```
onTransaction(tr):
  blocks = blocksTouchedBy(tr)
  if singleBlock(blocks) and heightUnchanged(block):   // fast path: repinta nada
      return
  if all(b.newHeight measured async via ResizeObserver):
      firstDirtyPage = pageOf(min(blocks))
      repaginateFrom(firstDirtyPage) with time budget (rAF slices, ~2 páginas/frame)
      // parar quando o "EndInfo" da página (offset do 1º bloco da página seguinte) não muda
```

### 4.2 Réguas (`Drawing/Rulers.js`, 3.734 linhas)

`CHorRuler` (`:186`) mantém em mm: `m_dMarginLeft/Right`, `m_dIndentLeft/Right/LeftFirst` (hanging = `IndentLeftFirst < IndentLeft`), `m_arrTabs[]`, `m_dDefaultTab = 12.5mm`, tipo do objeto sob o cursor (`PARAGRAPH|HEADER|FOOTER|TABLE|COLUMNS` — a mesma régua desenha marcadores de tabela e colunas).

- Conversão: `koef = g_dKoef_mm_to_pix * zoom * devicePixelRatio`; todo marcador é `x_px = koef * x_mm`; arrasto faz o inverso com clamps entre margens que impõem as relações first-line/hanging (`Rulers.js:932-1200`).
- A régua é **alimentada pelo documento**: ao mover o cursor, `DrawingDocument.Set_RulerState_Paragraph(margins…)` (`DrawingDocument.js:5880`) passa o pPr compilado; a régua compara com o último estado e só repinta se mudou (`CHorRulerRepaintChecker`).

### 4.3 Estilos e herança (`Editor/Styles.js`)

`CStyles.Get_Pr` (`:8019`) / `Internal_Get_Pr` (`:8174`) — ordem de merge (onde `undefined` não sobrescreve):

```
1. docDefaults (Default.TextPr/ParaPr)
2. cadeia basedOn (recursiva, com guarda de ciclo)
3. propriedades do nível de numeração vinculado (numPr→lvl.ParaPr/TextPr)
4. propriedades do próprio estilo
5. (tabelas) condicionais firstRow/lastCol/band1/band2…
6. formatação direta do parágrafo/run por cima
```

**Toggle properties** (bold, italic, caps, smallCaps, strike, vanish, emboss, imprint): compõem por **XOR** ao longo da cadeia, não por override. Estilos de título carregam `ParaPr.OutlineLvl` (0–8) — é o que o TOC e o outline leem.

### 4.4 TOC e campos complexos (`Editor/Paragraph/ComplexField*.js`)

Parser de instrução (`CFieldInstructionParser`, `ComplexFieldInstruction.js:1368+`): PAGE, PAGEREF, TOC, REF, NOTEREF, NUMPAGES, HYPERLINK, SEQ, STYLEREF, DATE… Switches do TOC (`private_ReadTOC:1674`): `\o "1-3"` (range de outline), `\h` (hyperlinks), `\t "Estilo;Nível"` (estilos custom), `\n` (sem nº de página), `\p` (separador), `\u`, `\z`.

Algoritmo de atualização (`private_UpdateTOC:919`):

```
1. remove bookmarks _Toc antigos
2. nTabPos = largura útil da coluna da seção corrente (posição do tab direito)
3. arrOutline = GetOutlineParagraphs(range \o + estilos \t)   // varre o doc
4. para cada parágrafo-alvo:
     bm = AddBookmarkForTOC()                     // bookmark _Toc único no título
     linha = clone do texto (sem breaks/campos/bookmarks)
     linha.style = "TOC N" (N = outlineLvl+1)
     linha += tab direito com leader de pontos
     linha += campo aninhado PAGEREF <bm> \h      // resolvido pós-paginação
     se \h: envolve em hyperlink interno para bm
5. substitui o conteúdo entre begin/separate/end do campo TOC
```

### 4.5 sectPr (`Editor/sections/`)

`SectionPageSize` (W=210, H=297 default), `SectionPageMargins` (L=30, T=20, R=15, B=20, Header=12.5, Footer=12.5 mm), `CSectionPr` com `Type` (NextPage/Continuous/EvenPage/OddPage), colunas, refs de header/footer.

```
contentWidth  = W - marginLeft - marginRight - gutter(lateral)
contentHeight = H - marginTop  - marginBottom - gutter(topo)
```

sectPr vive no **último parágrafo** da seção (e o final no body). `Continuous` não força página nova; header/footer escolhidos por `(isFirst && titlePg, isEven && evenAndOddHeaders, default)`.

### 4.6 Numbering (`Editor/Numbering/` + `Document.js:28491`)

`CNumberingLvl`: `Format`, `Start`, `Restart`, `Suff`, `PStyle`, `ParaPr`, `TextPr`, `LvlText[]` = tokens (`Str(".")` | `Num(lvlIndex)` para `%N`). Rótulo: percorre tokens formatando contadores (`IntToNumberFormat` decimal/roman/letter).

Motor de contadores (`CDocumentNumberingInfoEngine.private_UpdateCounter`, `Document.js:28658`):

```
para cada parágrafo da mesma lista até o alvo:
  lvl = p.numPr.ilvl
  se primeiro: counter = starts
  senão se lvl < prev: para l>lvl: se restart[l] → counter[l]=start[l]
  senão se lvl > prev: para l entre prev+1..lvl-1: counter[l]++
  counter[lvl]++
  se startOverride: counter[lvl]=startOverride
  prev = lvl
```

Resultado cacheado; invalidado só quando a numeração muda.

### 4.7 Tabelas (`Editor/Table/TableRecalculate.js`, `Editor/Table.js`)

- `private_RecalculateGrid` (`:244`): layout `Fixed` usa a grade declarada (`tblGrid`); `AutoFit` mede min/max de conteúdo por coluna e distribui a folga; `getLayoutScaleCoefficient()` reescala se não cabe. Larguras `auto|pct|dxa` para tabela e célula.
- `gridSpan` avança N colunas; `vMerge`: `Restart` inicia, `Continue` é pulada no grid e coberta pela célula de cima (`GetVMergeCount`, `Table.js:15517`).
- **Bordas conflitantes**: `Internal_CompareBorders2/3` (`Table.js:16085/16105`) — a borda "vencedora" na aresta compartilhada é escolhida por (espessura desc, prioridade de estilo, cor) e desenhada uma vez.

### 4.8 Paste de HTML do Word (`sdkjs/common/wordcopypaste.js`, 14.548 linhas)

`PasteProcessor` (`:2743`) → `_pasteFromHtml` (`:6650`) → `_Prepeare_recursive` (normaliza, remove comentários mso) → `_findMsoHeadStyle` (`:10246`, mapeia classes `MsoNormal`, `MsoHeading1`… do `<style>` do head) → `_Execute` (`:12074`, percorre e constrói o modelo: `_set_pPr:8787`, `_read_rPr:9482`, `_parseCss:9649`, tabelas `_ExecuteTable*:10501+`).

**Listas do Word desktop** (o ponto mais delicado do paste): Word não emite `<ul>/<ol>` — usa parágrafos `MsoListParagraph` com span `style="mso-list:Ignore"` contendo o marcador visível:
- `_getMsoListIgnore:9705` acha o span; `_getMsoListSymbol:9682` extrai o marcador; `_getTypeMsoListSymbol:9726` infere formato (roman/letter/decimal/bullet) e valor inicial; `_tryGenerateNumberingFromMsoStyle:9823` **reconstrói** um abstractNum/num e religa os parágrafos.
- Seções coladas: `_applyMsoSections:13620`. Modos de colar especial (manter origem/mesclar/só texto): `_specialPaste*:3335-3634`.

---

## 5. Inventário OOXML dos documentos-alvo

> Correção de premissas: `resources/01/` + `01.zip` são uma captura do **Google Docs** (ignorar). As pastas `PGCTIC1_-_ETP_-_…/` e `PGCTIC1_-_TR_-_…/` contêm **PNGs de gabarito por página** (ETP: 19; TR: 140) — ground truth visual. O OOXML real está dentro dos `.docx`. As 3 capturas de tela mostram o ETP no Word 365 (abas Página Inicial/Inserir/Layout, menu Margens com "Margens Personalizadas"; galeria de estilos exibindo **Conteúdo, Nível 01, Nível 1-Se…, Nível 2, Nível 2-…, Nível 3, Nível 3-R, Nível 4, Nível 4-R, Nível 5**; status "Página 1 de 19, 5875 palavras").

### 5.1 Seção (ambos: UMA seção única, A4)

- `pgSz w=11906 h=16838` → **A4 210×297 mm**.
- ETP: `pgMar top=1418 right=1134 bottom=1418 left=1134 header=426 footer=454 gutter=0` (≈2,5 cm vert., 2,0 cm horiz.).
- TR: idem com `header=567 footer=230`.
- `cols space=720` (1 coluna), `docGrid linePitch=326`.
- **Sem `titlePg` e sem `evenAndOddHeaders`** → apesar de existirem refs `first`/`even`, **só o header/footer `default` é usado em todas as páginas**. (Ponto de fidelidade crítico — usar `first`/`even` seria bug.)
- Footer default contém os campos ` PAGE ` e ` NUMPAGES \* ARABIC ` → "Página X | N" (confirmado no gabarito: "P á g i n a 70 | 140").

### 5.2 Estilos

- docDefaults: rFonts Times New Roman (+MS Mincho eastAsia), lang pt-BR; `pPrDefault: autoSpaceDN=0`; **sem sz default**.
- ETP: **158 estilos** (72 pará + 72 char + 11 num + 3 tabela); TR: **181**.
- `Normal`: fonte **Ecofont_Spranq_eco_Sans** 12pt (fallback sans obrigatório), `suppressAutoHyphens`.
- Corpo dominante: **`Textosimples`** (420/524 parágrafos no ETP): Arial 10pt (`sz=20`), justificado (`jc=both`), entrelinha `line=276 lineRule=auto` (≈1,15), spacing 120/120. TR: `Textonormal` (348 usos): idem + `ind left=788 hanging=431`.
- **Títulos**: `Ttulo1..6` (heading 1..6, keepNext/keepLines, cores 365F91/243F60, Calibri) **sem numeração própria**; a numeração vem dos **estilos customizados** `Nivel01` (basedOn Ttulo1, `numPr numId=11`, Arial 10pt, jc both, autoRedefine), `Nvel1-SemNum` (numId=0, cor FF0000), família `Nivel2/Nvel2-Red/Nivel3/Nvel3-R/Nivel4/Nvel4-R/Nivel5` (variantes "-R"/"-Red" = itálico vermelho FF0000). **Este é o caso real de "estilos customizados de título" que o editor precisa preservar por nome.**
- Estilos de caractere: `Hyperlink`, `HiperlinkVisitado`, `Forte`, `nfase`, e estilos importados de web (`normaltextrun`, `eop`, `spellingerror` — evidência de round-trip com Word Online!).

### 5.3 Numbering

- ETP: 40 nums → 40 abstractNums; TR: 40 nums → 13 abstractNums.
- **Numeração dos títulos**: `numId=11` (ETP→abstract 27, TR→abstract 10), `multiLevelType=multilevel`, decimal em 9 níveis, `lvlText` = `%1.` / `%1.%2.` / … / `…%9.`, indents left 360→4320 com hanging 360→1440, ilvl0 com `pStyle=Nivel01`.
- Outros formatos: `%1)`, `(%4)`, `8.%1` (prefixo fixo), bullets `numFmt=bullet` com glifos **Symbol/Wingdings/Courier "o"** (mapear glifos!).

### 5.4 Campos/links/bookmarks

- **Nenhum TOC field** nos corpos (se houver índice, é texto estático) — o TOC automático será recurso novo nosso.
- Campos só nos rodapés (PAGE/NUMPAGES via fldChar).
- TR: hyperlinks externos (planalto.gov.br) e internos (`w:anchor="art5"`); bookmarks `_Hlk…`, `_Ref…`.

### 5.5 Tabelas

| Métrica | ETP | TR |
|---|---|---|
| Tabelas | 3 | **22** |
| Linhas | 18 | **1.642** |
| Células | 82 | **3.650** |
| gridSpan | 1 | **1.670** |
| vMerge | 4 | 14 |
| tblHeader (header repetido) | 0 | **2** |
| tblLayout fixed | 0 | 4 |

- Larguras: os **três tipos** aparecem (`auto`, `pct` — dominante no TR com 3.223 tcW pct —, `dxa`).
- A grande tabela de requisitos do TR (2 colunas, header repetido) se estende por dezenas de páginas → **quebra linha-a-linha com repetição de cabeçalho é obrigatória**, e fragmentação de linha alta também (linhas atômicas custam ~2 páginas hoje).

### 5.6 Parágrafos/runs (propriedades a suportar)

`spacing before/after/line lineRule=auto|exact`, `jc both/center/left/right`, `ind left/right/firstLine/hanging`, `keepNext/keepLines`, `suppressAutoHyphens`, `contextualSpacing`, tabs customizados (`pos=1701`, até negativos `-389`), `shd` fill, rFonts distintos por script, `sz/szCs` em half-points, `color` hex/auto, `highlight yellow`, `b/i`, `lang pt-BR`. `settings.xml`: `defaultTabStop=708`, `autoHyphenation` (neutralizado por `suppressAutoHyphens` nos estilos), `compatibilityMode=15`.

### 5.7 Dimensionamento de performance (o TR é o stress test)

| Métrica | ETP | TR |
|---|---|---|
| Páginas | 19 | **140** |
| Palavras | 6.860 | **81.407** |
| `document.xml` | 258 KB | **4,45 MB (uma linha única)** |
| Parágrafos reais (`<w:p>`) | 524 | **4.414** |
| Runs | ~902 | **~6.035** |

---

## 6. Plano de melhorias

Cada fase tem tarefas concretas com referências aos algoritmos (§2/§4) e critérios de aceite mensuráveis. Ordem pensada para desbloquear o requisito nº 1 (200 páginas sem travar) primeiro, porque virtualização e paginação incremental mudam a base sobre a qual régua/TOC/pagesetup se apoiam.

### FASE 1 — Motor de performance: paste cooperativo + paginação incremental + virtualização

**1.1 Paste cooperativo (o gargalo nº 1).**
- Interceptar paste grande em `lib/src/prosemirror/view/clipboard.dart`: se o HTML colado exceder um limiar (ex.: > 100 KB ou > 200 blocos), desviar do caminho síncrono.
- Pipeline fatiado: (a) parsear o HTML em um `DocumentFragment` fora da árvore; (b) converter para PMNodes em chunks de ~50 blocos com yield (`await Future.delayed(Duration.zero)` / `scheduler.postTask`), reaproveitando o padrão do `_parseBodyElementsAsync` (`parser/document_parser_core.dart:99`); (c) aplicar como UMA transação no final (histórico/undo atômico) ou em transações agrupadas com `addToHistory` combinado; (d) overlay de progresso ("Colando… X%").
- Reconhecer os dois dialetos de HTML do Word no paste (nosso conversor deve cobrir ambos):
  - **Word desktop**: classes `MsoNormal/MsoListParagraph`, `<style>` no head, listas via `mso-list:Ignore` → portar a lógica do `PasteProcessor` (§4.8: `_getMsoListSymbol`, `_tryGenerateNumberingFromMsoStyle`).
  - **Word Online**: wrappers `SCXW…/BCX…`, `data-ccp-props`, `data-ccp-parastyle`, `paraid` (§2.10) — `data-ccp-parastyle` dá o **nome do estilo original** de graça (usar na Fase 4!).
- **Aceite:** colar HTML equivalente a 200 páginas (gerar fixture a partir do TR) sem nenhuma tarefa > 50 ms (medido com Long Tasks API); UI responsiva durante o paste; undo restaura em 1 passo.

**1.2 Paginação incremental com "EndInfo" (modelo OnlyOffice §4.1).**
- Na `PaginationExtension` (`lib/src/tiptap/extensions/pagination.dart`): manter por página o "estado de saída" (offset do primeiro bloco da página seguinte + altura acumulada). Ao editar, repaginar a partir da primeira página suja e **parar assim que o EndInfo de uma página coincidir com o anterior** (a edição não vazou).
- Fatiar o trabalho por orçamento de tempo (~2 páginas por rAF, como o `FullRecalc` fatia por `setTimeout`), interrompível se chegar nova edição.
- Fast path de digitação: se o bloco editado não mudou de altura (ResizeObserver), não repaginar nada.
- **Aceite:** digitação no meio do TR (140 págs) com latência de tecla p95 < 16 ms; repaginação completa nunca bloqueia > 50 ms por fatia.

**1.3 Virtualização por janela de páginas (modelo Word Online §2.6).**
- Janela `[IndexRenderWindowFirst..Last]` = páginas visíveis ± 2. Páginas fora viram **placeholders com a altura exata** (scrollbar estável); re-hidratar ao entrar na janela (scroll listener + geometria já conhecida da paginação — sem depender de IntersectionObserver, como o Word).
- Cuidado com contenteditable: a superfície editável precisa conter a página com o cursor; manter a página do caret e vizinhas sempre materializadas.
- **Aceite:** TR aberto com DOM ≤ ~7 páginas materializadas; memória e tempo de abertura medidos no benchmark (1.6).

**1.4 Abertura mais rápida do viewer.**
- Render incremental no viewer (`docx_preview.dart:108`): montar DOM em chunks com yield (mesmo padrão do parse).
- Trocar imagens base64 por `URL.createObjectURL` (`word_document.dart:204`).
- Avaliar `DecompressionStream('deflate-raw')` do browser como fast-path do inflate (fallback ao inflate Dart vendorado; **sem nova dependência de pubspec** — é API web).
- **Aceite:** abrir o TR < 1,5 s até primeira página visível (R1).

**1.5 Unificar os dois motores de paginação.**
- Extrair a paginação para um módulo compartilhado (geometria de página + algoritmo de corte) usado pelo viewer (pós-render estático) e pelo editor (incremental). Fonte única de contagem de páginas.

**1.6 Benchmark contínuo (Fase 6 do plano antigo — pré-requisito de aceite de tudo).**
- Estender `test/tiptap/render_demo_harness.dart` com modo benchmark: open-time (ETP/TR), latência de tecla (p50/p95 via CDP `Input.dispatchKeyEvent` + Long Tasks), tempo de paste (fixture 200 págs), export DOCX/PDF. Gravar JSON em `test/output/bench/`.
- **Aceite:** números R1–R5 do `plano_editor_completo.md` medidos e registrados a cada fase.

### FASE 2 — Régua horizontal e vertical fiéis ao Word

> **Estado em 2026-07-19:** a fundação visual foi implementada em `lib/src/tiptap/ui/word_rulers.dart` e integrada ao ciclo de vida da paginação. Após comparar com as capturas do Word desktop, a régua horizontal foi removida do viewport rolável e passou a ser chrome fixo entre a ribbon e o viewport. A vertical foi corrigida novamente: ela fica na borda esquerda da área de trabalho, distante da folha centralizada, enquanto sua escala acompanha verticalmente apenas a página ativa. Ela é ocultada quando essa página sai do viewport. Os quatro recuos, as quatro margens e os tab stops já são interativos; o modo específico de tabela permanece pendente.

**2.1 Régua horizontal (canvas, modelo §2.4 + §4.2).**
- Container de **20px** sobre `.PagesContainer` (`.WACHorizontalRulerContainer` como referência visual; nosso tema pode usar claro/escuro), desenho em `<canvas>` com `devicePixelRatio`.
- Estado da régua = `{scale(zoom), pageWidth, marginLeft/Right, indentLeft/Right/FirstLine, tabs[], defaultTab, objectType}` — alimentado pelo cursor: ao mudar a seleção, ler o pPr **compilado** do parágrafo (indents/tabs) + sectPr (margens) e repintar só se mudou (padrão `Set_RulerState_Paragraph` + RepaintChecker, §4.2).
- Conversão única: `px = twips/15 * zoom` (§2.3). Régua desenha: números de cm/pol, ticks, zona escura fora das margens, triângulos de indent (first-line “casinha”, hanging, right) e marcas de tab (left/center/right/decimal).
- Interação de arrasto: margens (com clamp), indents (impor relação first-line/hanging como `Rulers.js:980-1200`), criar tab clicando na régua, arrastar/remover tabs; ao soltar → comando Tiptap que grava `ind`/`tabs` no attrs do parágrafo (block_style) e, para margens, no sectPr do doc.
- Modo tabela: quando o cursor está numa tabela, régua mostra os limites de coluna arrastáveis (§4.2, `CurrentObjectType=TABLE`).
- **2.2 Régua vertical**: promover a atual (decorativa) ao mesmo modelo: margens top/bottom arrastáveis, alturas de linha de tabela quando aplicável.
- **2.3 Tab stops funcionais (fecha F7)**: renderizar tab como `span.TabRun>span.TabChar` inline-block com **largura calculada** até a próxima tab stop (§2.2) — nunca `\t` cru. Implementar `defaultTabStop` (708 twips nos docs-alvo), tabs left/center/right/decimal com leader (pontos — necessário para o TOC).
- **Aceite:** réguas reproduzem visualmente as capturas do Word 365 (`resources/Captura*.png`); arrastar indent/margem/tab atualiza o documento e vice-versa; harness com screenshot comparando marcadores.

### FASE 3 — Page setup configurável (A4, Letter, Ofício…)

> **Estado em 2026-07-19:** modelo, presets, orientação, tamanhos padrão e
> diálogos de margens/tamanho personalizados estão implementados. A geometria
> atualiza `doc.attrs`, paginação, réguas e exportação. Permanecem como expansão
> desta fase as opções avançadas de header/footer/gutter e múltiplas seções.

- **3.1 Modelo:** remover o A4 hard-coded de `PaginationOptions` (`pagination.dart:34`); a fonte de verdade passa a ser o `sectPr` em `doc.attrs` (já populado pelo import). Presets:

| Preset | mm | twips (w×h) |
|---|---|---|
| A4 | 210×297 | 11906×16838 |
| Letter | 215,9×279,4 | 12240×15840 |
| Legal | 215,9×355,6 | 12240×20160 |
| **Ofício (BR 216×330)** | 216×330 | 12247×18709 |
| A3 | 297×420 | 16838×23811 |
| A5 | 148×210 | 8391×11906 |

- **3.2 UI:** diálogo "Configurar página" na toolbar/demo: preset + custom (largura/altura), orientação (retrato/paisagem = swap w/h), margens (top/bottom/left/right/header/footer/gutter) com presets Normal/Estreita/Larga como o Word. Comando `setPageSetup(attrs)` → atualiza `doc.attrs` → repaginação incremental (Fase 1.2) + régua (Fase 2) + export DOCX/PDF já propagam.
- **3.3 Regras de header/footer fiéis:** aplicar `titlePg`/`evenAndOddHeaders` corretamente — **sem essas flags, usar só o `default` em todas as páginas** (bug em potencial identificado na §5.1).
- **Aceite:** trocar A4→Ofício repagina o TR corretamente; export DOCX reabre no Word com o tamanho certo; PDF sai com a página certa.

### FASE 4 — Estilos customizados nomeados (galeria + round-trip)

- **4.1 Registro de estilos no editor:** hoje o import achata estilo→heading numérico (`docx_import.dart:693`). Criar um `StyleRegistry` no doc (attrs) com os estilos do DOCX (id, name, basedOn, next, link, outlineLvl, pPr/rPr compilados e crus) e gravar em cada parágrafo o `styleId` original (attr `pStyle`), mantendo o heading como derivado do `outlineLvl`.
- **4.2 Resolução de herança** (§4.3): docDefaults → basedOn (com guarda de ciclo) → numbering-do-estilo → próprio → formatação direta; toggles por XOR. Já temos boa parte no viewer (`document_parser_styles.dart`) — extrair para módulo compartilhado com o editor.
- **4.3 Galeria de estilos na toolbar:** dropdown mostrando os estilos de parágrafo (como a captura do Word 365: Conteúdo, Nível 01…Nível 5), aplicar estilo = comando que seta `pStyle` (+ numPr herdado do estilo, ex. `Nivel01`→numId 11 ilvl 0).
- **4.4 Round-trip:** `DocxExporter` reemite `styles.xml` original + modificações; parágrafo com `pStyle` exporta `<w:pStyle>` em vez de formatação direta explodida.
- **4.5 Paste:** aproveitar `data-ccp-parastyle` (Word Online) e classes `MsoXxx` (desktop) para religar parágrafos colados a estilos do registro (criando-os se não existirem).
- **Aceite:** importar o ETP, ver "Nivel 01"…"Nível 5" na galeria; aplicar "Nivel 01" numera `1.` automaticamente; exportar e reabrir no Word preserva nomes e numeração dos estilos.

### FASE 5 — Sumário automático (TOC)

Implementar o algoritmo do OnlyOffice (§4.4) adaptado:

- **5.1 Modelo:** nó `tocField` (bloco) com attrs `{instr: 'TOC \\o "1-3" \\h \\z \\u', dirty}`; parser de instrução portado de `CFieldInstructionParser` (só TOC/PAGEREF/PAGE/NUMPAGES/HYPERLINK inicialmente).
- **5.2 Coleta:** `getOutlineParagraphs()` — parágrafos com `outlineLvl` no range `\o` (do estilo compilado! — nos docs-alvo o outlineLvl vem de `Ttulo1` herdado por `Nivel01`) ou estilos listados em `\t`.
- **5.3 Geração:** para cada título → bookmark `_Toc<uid>`; linha com estilo `TOC N`; **tab direito com leader de pontos** na posição = largura útil da coluna (depende da Fase 2.3); campo PAGEREF resolvido **pós-paginação** (número da página onde o bookmark caiu — depende da Fase 1.2 expor `pageOfBlock()`); com `\h`, linha inteira vira hyperlink interno.
- **5.4 Atualização:** comando "Atualizar sumário" (regenera tudo) + atualização automática dos PAGEREFs quando a paginação estabiliza (debounced). PAGE/NUMPAGES dos rodapés entram no mesmo mecanismo de campos (hoje o viewer já reescreve; unificar).
- **5.5 UI:** botão "Inserir sumário" (níveis 1–3 default), clique no item navega para o título.
- **Aceite:** inserir TOC no ETP importado gera índice idêntico ao que o Word geraria (títulos `Nivel01/2/3`, pontilhado, nº de página correto); editar texto desloca páginas e o TOC atualiza.

### FASE 6 — Quill Delta completo (better-table, indent, entrelinha)

Em `lib/src/tiptap/converters/quill_delta.dart`:

- **6.1 quill-better-table:** suportar o formato de linha do better-table — ops com atributo `table-cell-line: {rowspan, colspan, row, cell}` (e o legado `table: <rowId>` do quill nativo): agrupar ops consecutivas por row/cell → construir `table/tableRow/tableCell` PMNodes com rowspan/colspan; caminho inverso PM→Delta emitindo `table-cell-line`. Cobrir também `table-col` (larguras de coluna).
- **6.2 `indent`:** `attributes.indent: n` → aninhamento real de lista (n níveis) ou `ind` de parágrafo quando fora de lista; inverso no export. Corrigir o achatamento atual de listas aninhadas.
- **6.3 Entrelinha/espaçamento:** mapear `line-height`/`lineheight` (atributo custom comum em quills configurados) → attr `lineHeight` do block_style; expor também controle na toolbar (1.0/1.15/1.5/2.0 + antes/depois).
- **6.4 Demais:** `size` nomeado (small/large/huge) além de px; `align: justify`; `background`/`color` em formato rgb() e hex; `header` 1–6.
- **Aceite:** suíte property-based estendida com fixtures better-table (round-trip Delta→PM→Delta sem perda); demo importa um Delta com tabela mesclada, indent 3 níveis, entrelinha 1,5.

### FASE 7 — Fidelidade fina de renderização

- **7.1 Fragmentar linhas de tabela altas entre páginas** quando não há `w:cantSplit` (remover a atomicidade do `tr{display:grid}`) — corrige as ~2 páginas de desvio no TR; manter repetição de `tblHeader` (já existe no viewer, levar ao editor).
- **7.2 Listas:** marcador como span controlado (`ListMarker`, §2.2) em vez de `::marker`/counters onde a precisão exigir; glifos Symbol/Wingdings/Courier mapeados (§5.3); indents/hanging por nível exatos (fecha F6).
- **7.3 Resolução de bordas de tabela** (§4.7): borda vencedora por (espessura, estilo, cor) — hoje bordas conflitantes podem duplicar.
- **7.4 Tipografia:** `font-variant-ligatures:none` na superfície (§2.2); fallbacks métricos para Ecofont_Spranq_eco_Sans/Arial/Calibri; hifenização: respeitar `suppressAutoHyphens`/`autoHyphenation` + `lang` (CSS `hyphens:auto` com `lang="pt-BR"`).
- **7.5 Zoom:** migrar de `zoom` CSS para `transform:scale()` no container único (§2.5) — consistente cross-browser e compartilhável com a régua (mesmo fator).
- **7.6 Diff de pixels automatizado:** comparar screenshots do harness contra os PNGs de gabarito (`PGCTIC1_-_*/-NNN.png`) com métrica de diferença por página; orçamento de divergência por página no CI.
- **Aceite:** TR pagina em 140±2 páginas; diff médio por página abaixo do orçamento definido; ETP = 19 páginas exatas.

### FASE 8 — Robustez de edição (bugs/travamentos)

- **8.1 Endurecer `domchange.dart`/IME** (pendência declarada do porte): composição, autocorreção, backspace em bordas de bloco, joins.
- **8.2 Export DOCX fiel:** reemitir parts/rels de header/footer/VML editados; emitir rowspan; links preservados (perdas hoje documentadas no plano §5.1).
- **8.3 Testes de estresse:** digitação contínua no TR, undo/redo profundo, paste repetido, seleção total + retype — todos no harness com asserts de latência.

### Dependências entre fases

```
F1 (perf/paginação incremental) ──► F2 (régua usa zoom/geom) ──► F5 (TOC usa tab leader + pageOf)
                                └──► F3 (page setup repagina)
F4 (estilos) ────────────────────────► F5 (TOC coleta por outlineLvl/estilo)
F6 (Delta) independente; F7/F8 contínuas, gated pelo benchmark F1.6
```

---

## 7. Tabelas de referência rápida

### 7.1 Unidades

| Unidade | Definição | Conversão |
|---|---|---|
| twip | 1/20 pt = 1/1440 pol | **px = twips / 15** (a 96 dpi, zoom 1) |
| half-point | `w:sz` (fonte) | pt = sz/2 |
| EMU | drawings | 914.400/pol; px = EMU/9525 |
| mm | interno OnlyOffice | px = mm × 96/25,4 × zoom × dpr |
| dxa/pct | larguras de tabela | dxa = twips; pct = valor/50 % (`w:pct` 5000 = 100%) |

### 7.2 Medidas do Word Online (para replicar)

| Item | Valor |
|---|---|
| Página Letter / A4 | 816×1056 px / 794×1123 px |
| Gap entre páginas | 19px (`margin-bottom`) |
| Borda da página | `1px solid #ababab`, radius 4px |
| Altura da régua | 20px, fundo `#141414` |
| Default tab (docs-alvo) | 708 twips ≈ 47 px |
| Tab default OnlyOffice | 12,5 mm |

### 7.3 Arquivos de referência para consulta durante a implementação

| Tema | Onde olhar |
|---|---|
| CSS de página/régua/seleção do Word | `resources/word.example/res.public.onecdn.static.microsoft/officeonline/hashed/9d03c998e5bfacdd/wordeditor_version4.min.css` |
| CSS da superfície de edição | `…/hashed/23c9cac59260bd16/editsurface.min.css` |
| DOM/virtualização/clipboard do Word | `…/hashed/351afb16d868c806/wordeditords.js` |
| Réguas/caret/floating do Word | `…/hashed/c009898cfeffbf81/wordeditords.box4.dll1.js` (+ dll2) |
| Recálculo incremental | `D:\EuroOfficeNative\DocumentServer\sdkjs\word\Editor\Document.js` (`private_Recalculate:2843`, fast paths `:3253/:3317`) |
| Quebra de linha/página | `…\Editor\Paragraph_Recalculate.js` (`private_RecalculateLine:994`) |
| Réguas OnlyOffice | `…\Drawing\Rulers.js` (`CHorRuler:186`), `Drawing\DrawingDocument.js` (`Set_RulerState_Paragraph:5880`) |
| Estilos/herança | `…\Editor\Styles.js` (`Get_Pr:8019`, `Internal_Get_Pr:8174`) |
| TOC/campos | `…\Editor\Paragraph\ComplexField.js` (`private_UpdateTOC:919`), `ComplexFieldInstruction.js` (`private_ReadTOC:1674`) |
| Numbering | `…\Editor\Numbering\Num.js` (`GetText:715`), `Editor\Document.js` (`private_UpdateCounter:28658`) |
| Tabelas | `…\Editor\Table\TableRecalculate.js` (`private_RecalculateGrid:244`), `Table.js` (`Internal_CompareBorders2:16085`) |
| Paste HTML do Word | `…\sdkjs\common\wordcopypaste.js` (`PasteProcessor:2743`, `_getMsoListSymbol:9682`, `_tryGenerateNumberingFromMsoStyle:9823`) |
| Nosso paste | `lib/src/prosemirror/view/clipboard.dart` |
| Nossa paginação (editor) | `lib/src/tiptap/extensions/pagination.dart` |
| Nossa paginação (viewer) | `lib/src/docx_rendering/renderer/pagination.dart` |
| Import DOCX→PM | `lib/src/tiptap/converters/docx_import.dart` |
| Conversor Delta | `lib/src/tiptap/converters/quill_delta.dart` |
| Docs-alvo + gabaritos | `resources/PGCTIC1_-_{ETP,TR}_-_*.docx` + pastas de PNGs + PDFs |

### 7.4 Restrições do projeto

- Em `dependencies`, `pubspec.yaml` só pode depender de `web: ^1.1.1` — qualquer código de produção novo é vendorado em `lib/src/`. Dependências exclusivamente de desenvolvimento/teste, como `puppeteer: ^3.19.0`, são permitidas.
- Sem canvas para o texto do documento (canvas permitido para régua/overlays, como o próprio Word faz).

## 8. Registro de implementação

### 8.1 Correção das réguas — concluída (fundação visual)

Arquivos alterados:

- `lib/src/tiptap/ui/word_rulers.dart`: controlador único das réguas horizontal e vertical.
- `lib/src/tiptap/extensions/page_region_editor.dart`: remove a régua antiga fixa no viewport e delega instalação, atualização e descarte ao `WordRulers`.
- `lib/assets/tiptap_editor.css` e `web/tiptap_demo.css`: escala, zonas de margem, ticks, números e quatro marcadores de recuo.
- `test/tiptap/ui/test_page_region_editor_browser.dart` e `test/tiptap/render_angular_example_harness.dart`: cobertura de alinhamento, altura da página, zoom, régua horizontal, marcadores e ocultação em modo leitura.

Comportamentos validados:

1. A régua vertical pertence ao chrome do editor e fica alinhada à borda esquerda do viewport, como no Word; ela não fica encostada à folha centralizada.
2. O início de sua escala vertical acompanha a página que contém o caret, inferida pelas cópias materializadas de header de cada página.
3. Sua altura vem de `--tiptap-page-height`; ela não usa mais a altura arbitrária do viewport.
4. A régua horizontal é chrome fixo fora do scroll, acompanha a borda renderizada da página e espelha o mesmo `zoom` da folha sem cobrir o conteúdo.
5. As réguas são escondidas quando `EditorView.editable == false`.
6. Os marcadores first-line, hanging, left e right acompanham o bloco que contém o caret.

Validação executada:

- `dart analyze`: sem problemas.
- `dart test -p chrome test/tiptap/ui/test_page_region_editor_browser.dart`: passou.
- Testes browser relacionados de paginação, toolbar e shell da demo: 8 testes passaram.
- `dart analyze` em `example2/`: sem problemas. Uma reconstrução limpa com `build_runner` ainda falha dentro do compilador `ngdart` com `InvalidType` sem localização de fonte; o erro não é reportado pelo analyzer e precisa de investigação isolada da compatibilidade AngularDart/toolchain.

### 8.2 Próxima entrega da régua

A correção acima resolve geometria, página ativa, zoom e modo leitura, mas ainda não torna a régua um editor completo. A próxima entrega deve adicionar, nesta ordem:

1. ~~pointer drag dos quatro marcadores de recuo com preview e commit atômico no parágrafo~~ — concluído;
2. ~~arrasto das margens esquerda/direita e superior/inferior com clamp e atualização de `sectPr`~~ — concluído;
3. criação, movimentação e remoção de tab stops, incluindo left/center/right/decimal e leaders;
4. limites de coluna quando o caret estiver em tabela;
5. screenshots de regressão contra as capturas do Word 365.

### 8.3 Modos de produto e interface Word — primeira etapa implementada

O `example/` agora expõe um botão real de modo de produto. “Somente visualização” chama `setEditable(false)`, torna o título somente leitura, remove as réguas e desabilita as ferramentas de edição; o retorno a “Edição” restaura esses estados. A apresentação dedicada ainda pode ser refinada para manter apenas navegação, zoom, pesquisa e download.

A toolbar linear foi reorganizada como ribbon com barra azul de título, linha de abas e painéis de 100 px para `Arquivo`, `Página Inicial`, `Inserir`, `Layout`, `Revisão`, `Exibir` e a guia contextual `Formato`. Os painéis reutilizam o contrato declarativo `data-tiptap-*`, portanto Inserir imagem/tabela/link/linha, formatação, zoom, abrir e exportar continuam acionando comandos reais. A Página Inicial também possui uma galeria visual de estilos básicos. Permanecem pendentes as mini-UIs específicas de texto/tabela/imagem e a galeria baseada nos estilos nomeados importados do DOCX.

### 8.4 Recuos interativos e round-trip DOCX — concluído

Os marcadores `first`, `hanging`, `left` e `right` agora aceitam pointer drag. Durante o movimento, `WordRulers` atualiza somente o DOM como preview; no `pointerup`, restaura o DOM controlado pelo editor e despacha uma única transação `setNodeMarkup`. No `pointercancel`, nenhuma mudança entra no documento.

Mapeamento persistido:

| Marcador | Atributos alterados |
|---|---|
| First-line | `textIndent` |
| Hanging | `marginLeft` + `textIndent`, preservando a posição absoluta da primeira linha |
| Left | `marginLeft`, movendo first-line e hanging juntos |
| Right | `marginRight` |

O exportador passou a converter comprimentos CSS (`px`, `pt`, `in`, `cm`, `mm`) para twips e emitir `<w:ind w:left="…" w:right="…" w:firstLine="…"/>` ou `w:hanging` para recuo francês.

Validação adicional:

- teste browser cobre os quatro gestos e os valores persistidos;
- teste unitário cobre conversão para twips, first-line e hanging;
- `dart analyze`: sem problemas;
- 9 testes do exportador e 6 testes browser relacionados passaram.

### 8.5 Margens interativas e `sectPr` dinâmico — concluído

As fronteiras das zonas cinzas das réguas agora possuem handles para `left`, `right`, `top` e `bottom`. O arrasto usa as dimensões lógicas da página, compensando o zoom pelo `getBoundingClientRect`, e mantém no mínimo 48 px de área útil para impedir margens cruzadas.

No `pointerup`, uma única `DocAttrStep` grava `pageMarginLeft`, `pageMarginRight`, `pageMarginTop` ou `pageMarginBottom`. Isso aciona o fluxo existente de mudança de geometria da `PaginationExtension`, que atualiza padding, headers/footers, contagem de páginas e ambas as réguas. `pointercancel` apenas restaura o desenho anterior.

O `DocxExporter` deixou de emitir A4/margens fixos e agora gera `w:sectPr` a partir de:

- `pageWidth` e `pageHeight`;
- `pageOrientation`;
- as quatro margens da página;
- distâncias de header/footer e gutter.

Validação adicional:

- teste browser arrasta e verifica as quatro margens no nó raiz;
- teste do exportador cobre tamanho, landscape e todas as unidades suportadas;
- 10 testes do exportador, 1 teste integrado de régua/header e 5 testes de paginação passaram;
- `dart analyze`: sem problemas.

### 8.6 Regressão visual encontrada no `example/` e correção arquitetural

As capturas reais de 2026-07-19 mostraram uma falha que os primeiros testes DOM não detectaram: a régua horizontal estava inserida como primeiro filho do `.document-viewport` com `position: sticky`. Depois do scroll, ela permanecia sobre o texto, atravessando visualmente a página. O teste também não verificava a ausência da régua vertical quando a página do caret deixava completamente o viewport.

Correção:

1. a régua horizontal agora é irmã imediatamente anterior ao viewport, dentro do chrome do editor;
2. ela não participa do scroll vertical e nunca cobre o documento;
3. sua posição horizontal usa a diferença real entre `pageScale.getBoundingClientRect().left` e o track, sendo recalculada em scroll, resize e zoom;
4. o zoom é aplicado apenas à régua interna, sem escalar o offset calculado do chrome;
5. a régua vertical mede interseção com o viewport e usa `display:none` quando a página ativa do caret não está visível.

Foi criado `test/tiptap/render_example_rulers_harness.dart` usando `puppeteer: ^3.19.0`. O harness compila e serve o `example/` real, importa um Delta multipágina, executa scroll e valida geometria renderizada.

Resultado medido:

| Métrica | Resultado |
|---|---:|
| Diferença horizontal régua↔folha | 0 px |
| Alinhamento régua vertical↔borda esquerda do workspace | 0 px |
| Alinhamento do topo da escala↔página ativa | 0 px |
| Track antes/depois do scroll | 178 px / 178 px |
| Sobreposição com viewport | nenhuma |
| Vertical fora da página do caret | oculta |
| Erros de página | 0 |

Artefatos: `test/output/example_rulers_after_scroll.png`, `test/output/example_word_ribbon.png` e `test/output/example_rulers_harness.json`.

### 8.7 Análise das capturas do Word e validação da ribbon

As capturas `resources/Captura de tela 2026-07-19 211742.png` e `resources/Captura de tela 2026-07-19 211713.png`, complementadas pelas capturas completas fornecidas durante a execução, corrigiram as seguintes premissas visuais:

1. a régua vertical tem cerca de 20 px e fica no extremo esquerdo do workspace, não ao lado da folha;
2. a régua horizontal é chrome independente sob a ribbon e reserva sua própria altura, sem sobrepor a página;
3. o chrome usa fundo próximo de `#E9EEF2`, divisórias `#D6D6D6` e ticks/texto próximos de `#616161`;
4. a ribbon possui três níveis mensuráveis: título de 48 px, abas de 30 px e comandos/galeria de 100 px;
5. o arrasto de tab stop do Word usa marcador próprio, guia vertical pontilhada e tooltip com o tipo, por exemplo “Esquerdo”.

Uma inspeção ampliada posterior encontrou ainda que a primeira versão havia
invertido os dois triângulos de recuo e representado o recuo direito como uma
base retangular. O desenho foi corrigido para o conjunto do Word (triângulo
superior para baixo, triângulo inferior para cima, base esquerda e triângulo
direito), e a escala passou de meios para quartos de centímetro, com ticks de
meio centímetro mais altos.

O harness Puppeteer foi ampliado para validar a interface real, não apenas DOM isolado. Resultado atual:

| Invariante | Resultado |
|---|---:|
| Barra de título | 48 px; `rgb(24, 90, 189)` |
| Linha de abas | 30 px |
| Painel da ribbon | 100 px |
| Painel Inserir alternável | passou |
| `contenteditable` em visualização | `false` |
| Réguas em visualização | ambas ocultas |
| Alinhamento horizontal/vertical | 0 px / 0 px |
| Erros JavaScript capturados | 0 |

### 8.8 Shell incorporável, componentes e correção de overflow — concluído

A demo anterior concentrava marcação e comportamento no `index.html` e no
`main.dart`. Essa estrutura não atendia ao produto: o editor precisa ser
montado dentro de uma aplicação Dart web ou AngularDart, possivelmente em um
contêiner menor que a janela, sem duplicar HTML/CSS e sem reconstruir o DOM a
cada mudança de modo.

A implementação foi movida para a biblioteca:

- `lib/src/tiptap/ui/component_framework.dart`: primitivas leves de componente,
  botão, select, dropdown, modal e ribbon, com listeners descartáveis e sem
  virtual DOM;
- `lib/src/tiptap/ui/editor_shell.dart`: gera dinamicamente título, abas,
  painéis, viewport, status, menus e inputs de arquivo;
- `lib/src/tiptap/ui/docx_editor_component.dart`: monta editor, importação DOCX,
  exportações, toolbar e modos como um único componente incorporável;
- `lib/assets/tiptap_word_shell.css`: todo o layout do shell passa a ser asset da
  biblioteca;
- `lib/assets/fonts/FluentSystemIcons-Regular.woff2`: fonte oficial Microsoft
  Fluent UI System Icons, acompanhada de sua licença MIT.

O `example/web/index.html` contém apenas o host e os assets, e
`example/web/main.dart` contém somente a configuração e a chamada
`TiptapDocxEditorComponent.mount`. A demo usa um host de 100% × 100vh com
padding externo de 20 px e shell limitado a 1200 px, comprovando que o editor
não depende de ocupar a janela inteira. Aplicações incorporadoras podem definir
qualquer outra largura/altura no host.

O bug de duas barras de rolagem foi removido substituindo alturas calculadas
contra `100vh` por uma coluna flex com `min-height:0`. Somente
`.document-viewport` rola. A régua vertical passou a ficar dentro de um track
recortado exatamente entre a régua horizontal e a status bar; ela não pode mais
invadir a ribbon ou o rodapé.

Também foi corrigida uma quebra funcional introduzida na migração: o shell não
criava o controle interno `#insert-image-button`, portanto a inicialização
abortava antes de registrar Abrir DOCX, exportação e alternância de modo. O
contrato voltou a ser completo, e uma ausência futura agora produz um
`StateError` com o id exato do controle ausente, em vez de um cast JS nulo.

### 8.9 Ribbon fiel à organização do Word — fundação corrigida

As novas capturas demonstraram uma distinção importante: existem três níveis
de chrome (título, abas e painel), mas **dentro do painel os comandos se
organizam em duas linhas**. O painel não possui rolagem horizontal. A primeira
versão ainda colocava comandos numa única faixa com `overflow-x:auto`, o que
produzia a scrollbar mostrada na captura de regressão.

A ribbon agora:

1. possui grupos com rótulo inferior e conteúdo interno de duas linhas;
2. usa `overflow-x:hidden/clip` e verifica que `scrollWidth <= clientWidth`;
3. recolhe grupos de menor prioridade por *container query*, considerando a
   largura do editor incorporado, não a largura da janela;
4. apresenta Página Inicial com Área de Transferência, Fonte, Parágrafo,
   Estilos e Editando;
5. apresenta Inserir com Páginas, Tabelas, Ilustrações, Links e Cabeçalho e
   Rodapé;
6. adiciona Design com Formatação do Documento e Plano de Fundo da Página;
7. apresenta Layout com Configurar Página, Parágrafo e Organizar.

Os comandos ainda não implementados aparecem como estrutura visual inerte até
receberem seus respectivos modelos/comandos; os comandos existentes mantêm os
seletores `data-tiptap-*` e continuam funcionais.

Validação Puppeteer (`puppeteer: ^3.19.0`):

| Invariante | Resultado |
|---|---:|
| Shell no viewport de 1600×1000 | 1200×960, margens de 20 px |
| Scroll externo (`html/body`) | inexistente |
| Ribbon | 100 px, duas linhas, conteúdo cabe no painel |
| Troca Word → compacto → Word | mesmo `.ProseMirror` |
| Mutações `childList` no frame durante troca | 0 |
| Track vertical fora de ribbon/status | passou |
| Página do caret fora do viewport | régua vertical oculta |
| Fonte Fluent carregada | passou |
| Erros JavaScript | 0 |

Validação final desta etapa:

- `dart analyze`: sem problemas;
- `dart run test/tiptap/render_example_rulers_harness.dart`: passou;
- `dart test -p chrome test/tiptap/ui/test_page_region_editor_browser.dart`:
  passou;
- `dart test test/tiptap/converters/test_docx_export.dart`: 10 testes passaram.

### 8.10 Shell contextual, opções de custo e camadas flutuantes

A barra de título foi simplificada para conter apenas marca e identidade do
documento. Abrir DOCX, abrir Delta, exportação, modo de exibição e aparência
foram transferidos para a guia Arquivo. Foram adicionadas opções incorporáveis
para ocultar a barra de título, ocultar a status bar e habilitar estatísticas do
documento. A contagem de palavras/caracteres fica desabilitada por padrão e,
nessa condição, o editor não percorre o documento para calculá-la.

A ribbon contextual agora acompanha a seleção real:

- imagens ativam **Formato da Imagem**, com alinhamento, tamanho e exclusão;
- tabelas ativam **Design da Tabela**, com alinhamento e exclusão;
- cabeçalhos e rodapés ativam **Cabeçalho e Rodapé**, usando os mesmos comandos
  funcionais do overlay de edição da página.

Dois defeitos de empilhamento foram corrigidos. O dropdown Exportar deixou de
ser filho do painel da ribbon, cujo `overflow:hidden` é necessário, e passou a
ser portado para a raiz posicionada da shell. Sua posição continua derivada do
botão, mas o painel pode atravessar a borda inferior da ribbon e desenhar sobre
o stage. O overlay de cabeçalho/rodapé passou a criar um contexto isolado e
usar uma camada de UI superior aos grandes `z-index` inline presentes em
objetos flutuantes importados do DOCX; assim a caixa de texto não encobre mais
os botões de alinhamento e conclusão.

O harness Puppeteer verifica que o menu Exportar:

1. é filho direto da shell;
2. abre abaixo do botão;
3. ultrapassa o limite da ribbon sem ser recortado;
4. vence o hit-test sobre o stage e recebe cliques.

O teste browser de regiões reproduz ainda uma caixa importada com
`z-index: 251659264` e exige que a toolbar contextual permaneça acima dela.

Validação desta correção:

- `dart analyze`: sem problemas;
- harness real com `puppeteer: ^3.19.0`: passou;
- teste browser de cabeçalho/rodapé e objetos flutuantes: passou;
- testes browser do núcleo, incluindo inserção de tabela: 8 passaram;
- testes do exportador DOCX: 10 passaram.

### 8.11 Configurar Página funcional — presets e personalizados

Os controles antes decorativos da guia **Layout** foram substituídos por menus
funcionais construídos pelo mini framework da biblioteca. A organização foi
conferida contra as capturas do Word e contra os presets/handlers de
`DocumentServer/web-apps/apps/documenteditor/main/app/view/Toolbar.js` e seu
controller.

Foram implementados:

- **Margens:** Normal, Estreita, Moderada, Larga e Margens Personalizadas;
- **Orientação:** Retrato e Paisagem, trocando largura/altura sem perder o
  tamanho de papel corrente;
- **Tamanho:** Carta, Legal, Ofício brasileiro, A4, A5, B5, envelopes,
  Tabloide, A3, ROC 16K, Super B/A3 e tamanho personalizado;
- indicação do preset corrente por `aria-checked`, sincronizada também após
  importação ou mudanças externas no documento;
- validação para impedir papel ou margens que deixem menos de 25,4 mm de área
  útil em cada eixo.

Assim como o menu Exportar, os menus de configuração de página são portados
para a raiz da shell. Eles não são recortados pelo `overflow:hidden` obrigatório
da ribbon. Os diálogos usam `position:absolute` dentro da instância do editor,
portanto não assumem tela cheia nem cobrem outras instâncias incorporadas na
aplicação hospedeira.

Cada aplicação gera uma única transação com `DocAttrStep`. O fluxo observado é:

```
menu/dialog → pageWidth/pageHeight/pageOrientation/pageMargin* em doc.attrs
            → PaginationExtension recalcula geometria
            → WordRulers redesenha escala e margens
            → DocxExporter emite w:pgSz/w:pgMar
```

O harness Puppeteer cobre abertura sem recorte, preset Estreita, margens
personalizadas, A5 em Paisagem, tamanho personalizado, estado acessível do
preset e restauração A4/Retrato para as demais verificações de régua.

### 8.12 Tab stops funcionais e round trip DOCX

A régua horizontal deixou de tratar tabulações como item pendente. O modelo já
preservava `tabStops` importados em cada parágrafo, mas faltavam três partes: a
interação da régua, a largura calculada no DOM e a serialização correta do
caractere de tabulação.

Foram implementados:

- seletor de tipo no canto esquerdo da régua, alternando Esquerdo,
  Centralizado, Direito e Decimal;
- clique na escala para criar uma parada, com encaixe em quartos de centímetro;
- arrasto para mover e arrasto para fora da faixa para remover;
- guia vertical pontilhada e tooltip com tipo/posição durante o arrasto;
- duplo clique no marcador para alternar o preenchimento entre nenhum, pontos,
  hífens, sublinhado e pontos médios; botão direito remove diretamente;
- marcadores com geometria distinta para esquerda, centro, direita e decimal;
- `TabRenderingExtension`, que envolve apenas os caracteres `\t` com
  decorations e mede suas lacunas após o layout, sem reconstruir o documento;
- alinhamento visual esquerdo, centralizado, direito e decimal, além dos
  leaders, preservando o caractere original para edição e clipboard;
- exportação do caractere `\t` como `<w:tab/>`, em vez de inserir um tab
  literal incorreto dentro de `<w:t>`; propriedades de run são preservadas nos
  segmentos antes/depois da tabulação.

A alteração de uma parada gera uma única transação `setNodeMarkup` no parágrafo
ativo. Fora de alterações do documento, o conjunto de decorations é apenas
mapeado pela transação; a medição visual é agrupada em
`requestAnimationFrame`. Isso mantém a interação da régua fora do caminho
quente de digitação normal.

Validação desta etapa:

- `dart analyze`: sem problemas;
- `dart test test/tiptap/converters/test_docx_export.dart`: 11 testes passaram,
  incluindo `w:tabs` e `<w:tab/>`;
- `dart test -p chrome test/tiptap/ui/test_page_region_editor_browser.dart`:
  passou criação, movimento, leader e largura renderizada;
- `dart run test/tiptap/render_example_rulers_harness.dart`: passou no editor
  real com `puppeteer: ^3.19.0`, inclusive hit visual da guia/tooltip e ausência
  de erros JavaScript.

O diálogo completo **Tabulação...** do Word, inicialmente deixado para uma
etapa posterior, foi concluído na seção 8.14 usando essa mesma base de dados e
os comandos da régua.


### 8.13 Motor de edição de tabelas completo, número de página e sumário automático

Esta entrega ataca o bloco "tabelas profissionais" (F7.1/F7.3 e a mini-UI
contextual) e antecipa partes da F5 (TOC):

**Motor de tabelas (porte do prosemirror-tables):**

- `lib/src/tiptap/extensions/table_map.dart`: `TableMap` com resolução de
  `colspan`/`rowspan`, `findCell`, `colCount`, `nextCell`, `rectBetween`,
  `cellsInRect`, `isRectClean` e `positionAt`, com cache por instância de nó.
- `lib/src/tiptap/extensions/table_commands.dart`: `addColumn`/`addRow`
  (antes/depois, atravessando spans por aumento de `colspan`/`rowspan`),
  `deleteColumn`/`deleteRow` (com encolhimento de spans e reancoragem de
  células que nascem na linha removida), `deleteTable`, `mergeCells`
  (retângulo âncora→cabeça da seleção nativa, com verificação de retângulo
  limpo), `splitCell`, `setCellAttrs`, `setCellBorders`
  (all/outer/inner/none/lado), `toggleHeaderRow`, `setRowHeight`,
  `setTableAttrs` e `setColumnWidths`. Todas as operações aplicam as edições
  em ordem decrescente de posição (sem depender de `Mapping.slice`) e
  terminam com `_refreshGridAttrs`, que recalcula `columnIndex` por célula e
  ajusta `columnWidths` de tabela/linhas — mantendo o contrato de grid usado
  pela paginação para tabelas importadas de DOCX. Após exclusões, a seleção
  é recolocada na célula vizinha (`_selectCellAt`), mantendo os comandos
  encadeáveis.
- `CommandManager` ganhou os métodos correspondentes (encadeáveis via
  `editor.chain`).
- `lib/src/tiptap/extensions/table_resizing.dart`: redimensionamento
  interativo. Hover a ≤5 px da borda direita/inferior de uma célula mostra
  cursor `col-resize`/`row-resize`; o arrasto faz preview apenas com estilos
  inline (grid tracks nas linhas paginadas; larguras de célula na primeira
  linha para tabelas com layout fixo) e o `pointerup` gera UMA transação:
  `columnWidths` na tabela e em todas as linhas (colunas) ou
  `height`/`heightRule: atLeast` na linha. As fronteiras de coluna são
  derivadas dos retângulos renderizados (funciona com colspan e zoom, que é
  compensado por `getBoundingClientRect/offsetWidth`).

**Ribbon:**

- Inserir → Tabelas virou o grid picker 8×10 do Word (hover com prévia
  "Tabela LxC", clique insere via `insertTable(rows, cols)`).
- A guia contextual "Design da Tabela" agora tem grupos funcionais: Linhas e
  Colunas (inserir acima/abaixo/esquerda/direita), Excluir (linha, coluna,
  tabela), Mesclar (mesclar células, dividir célula, linha de cabeçalho),
  Sombreamento e Bordas (cor de preenchimento com "Sem Sombreamento", cor da
  borda + Todas/Externas/Internas/Sem Borda) e alinhamento da tabela.
- Inserir → Ilustrações ganhou "Caixa de Texto" (tabela 1×1 com
  `textBox: true`, borda e paddings editáveis pelos mesmos comandos de
  célula).

**Cabeçalho/rodapé e número de página:**

- Inserir → Cabeçalho/Rodapé abre a região correspondente da página
  materializada (scroll + dblclick programático no `PageRegionEditor`).
- Inserir → Número de Página: menu com Fim/Início da página em
  esquerda/centro/direita; grava um parágrafo com os campos
  `{{DOCX_PAGE}}`/`{{DOCX_NUMPAGES}}` no payload `headers`/`footers` de
  `doc.attrs` (mesmo mecanismo do PageRegionEditor, uma única
  `setDocAttribute`), substituindo qualquer parágrafo de número de página
  anterior; "Remover Números de Página" limpa os campos de todos os
  payloads. A paginação já resolve os campos por página e o export DOCX
  preserva o rodapé.

**Sumário automático (fundação da F5):**

- `lib/src/tiptap/extensions/table_of_contents.dart`: nó `tableOfContents`
  (`div[data-docx-toc]`, conteúdo `paragraph+` — pagina, edita e exporta
  como parágrafos normais), `collectOutline` (headings 1..maxLevel),
  `buildTableOfContents` e comandos `insertTableOfContentsCommand`/
  `updateTableOfContentsCommand`.
- Cada entrada é um parágrafo com tab stop direito com leader de pontos na
  largura útil da coluna (renderizado pela `TabRenderingExtension` já
  existente) e número de página real, obtido dos headers materializados por
  página (`data-page-number`) via `domAtPos` + `compareDocumentPosition`.
- Botões Inserir → Sumário / Atualizar Sumário na ribbon; clique numa
  entrada navega até o título correspondente (mesma regra de coleta, com
  `maxLevel` do bloco).

**Validação:**

- `dart analyze`: sem problemas.
- `test/tiptap/core/test_table_commands.dart` (novo, VM): 22 testes de
  TableMap e comandos, incluindo spans, retângulo sujo, reancoragem de
  rowspan e manutenção de `columnIndex`/`columnWidths`.
- `test/tiptap/core/test_table_editing_browser.dart` (novo, Chrome): 5
  testes com a view real — estrutura no DOM, colspan/rowspan após
  mesclar/dividir, sombreamento/bordas inline, grid tracks e sumário.
- Suites existentes: exportador DOCX, Quill Delta, editor core browser e
  PageRegionEditor browser continuam passando.
- `render_example_rulers_harness.dart` atualizado para o grid picker e
  ampliado com inserção/exclusão de linha pela guia contextual, executado
  contra o example real com Puppeteer.

**Pendências conhecidas desta frente:** formas (SVG), galeria de estilos
nomeados (F4), TOC com estilos `TOC N` dedicados e atualização automática
debounced dos PAGEREFs.

### 8.14 Diálogo Tabulação completo e `settings.xml`

Foi implementado o diálogo **Tabulação...** observado nas capturas do Word. O
lançador fica no grupo Parágrafo da Página Inicial, usando o pequeno botão de
diálogo no canto do grupo, sem aumentar a largura da ribbon nem introduzir
rolagem horizontal.

O diálogo é um `TiptapModal` gerado integralmente por
`lib/src/tiptap/ui/editor_shell.dart` e permanece contido na instância
incorporada do editor. Ele oferece:

- posição da parada em centímetros e lista ordenada das paradas existentes;
- alinhamentos Esquerdo, Centralizado, Direito e Decimal;
- preenchimentos Nenhum, pontos, hífens, sublinhado e pontos médios;
- ações Definir, Limpar e Limpar tudo;
- configuração da tabulação padrão;
- Cancelar sem alterar o documento e OK aplicando a lista completa.

Enquanto o diálogo está aberto, as operações alteram apenas uma lista
temporária. O botão OK aplica `defaultTabStop` no nó documento e `tabStops` no
parágrafo alvo em uma única transação. Isso evita uma transação e uma
repaginação para cada clique em Definir/Limpar.

A tabulação padrão deixou de ser uma constante apenas visual:

1. `DocumentExtension` ganhou o atributo `defaultTabStop`;
2. `DocxImporter` lê `w:settings/w:defaultTabStop`;
3. `TabRenderingExtension` usa o valor do documento ao calcular tabs
   implícitas, mantendo 1,25 cm como fallback;
4. `DocxExporter` passou a criar `word/settings.xml`, seu content type e seu
   relacionamento, emitindo `w:defaultTabStop` em twips.

Validação:

- `dart analyze`: sem problemas;
- exportador DOCX: 11 testes passaram, incluindo `settings.xml` e conversão de
  1 cm para 567 twips;
- harness real com `puppeteer: ^3.19.0`: passou abertura, estado inicial,
  Limpar tudo, definição de duas paradas, alinhamento, leader, tabulação padrão,
  OK, Limpar individual e atualização dos marcadores da régua;
- captura inspecionada: `test/output/example_tab_dialog.png`;
- erros JavaScript capturados no browser: zero.

Na verificação acumulada desta entrega, os 399 testes compatíveis com VM
passaram. Os 11 casos de `test/docx_rendering/docx_test.dart` continuam sendo
snapshots integrais do HTML antigo do renderer e precisam ter seus baselines
atualizados: eles detectam corretamente diferenças intencionais como os novos
estilos e a estrutura de cabeçalho/rodapé, não exceções funcionais. As suítes
Chrome comportamentais e os harnesses Puppeteer permanecem como a validação
funcional da nova shell, régua, regiões de página, tabelas e tabulações.
