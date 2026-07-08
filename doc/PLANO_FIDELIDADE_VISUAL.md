# PLANO — Fidelidade Visual da Renderização DOCX

> **Escopo:** `docx_rendering` (porte Dart puro do docx-preview/docxjs).
> **Meta:** aproximar a renderização HTML do que o Microsoft Word exibe, usando
> como documentos-alvo os arquivos em `resources/` (ETP e TR — modelos de
> governo do Município de Rio das Ostras).
> **Ferramenta de teste:** Puppeteer (`^3.19.0`) dirigindo Chrome headless.
> **Atualizado:** 2026-07-08.

---

## 1. Objetivo

Elevar a **fidelidade visual** (o quão perto o HTML renderizado fica do PDF/Word
original) sem quebrar a arquitetura existente (Dart puro + `package:web`, saída
HTML/CSS no browser). O trabalho é orientado por evidência: cada mudança é
validada com screenshots automatizados antes/depois via o *harness* Puppeteer.

Não-objetivos (por ora): editar/salvar DOCX, paginação dinâmica pixel-perfect
(o docx-preview é estático por design), suporte fora do browser.

---

## 2. Metodologia de teste (harness Puppeteer)

O harness `test/render_harness.dart` é a espinha dorsal do trabalho de fidelidade.
Ele torna a renderização **reproduzível e headless**:

1. Compila `example/web/main.dart` → `example/web/main.dart.js` (`dart compile js`).
2. Sobe um servidor estático (shelf) em `127.0.0.1:8080` servindo `example/web`.
3. Para cada `.docx` em `resources/` (ignora arquivos de lock `~$…`):
   - abre a página, faz upload do arquivo, dispara `change`;
   - espera o sinal de console `Render complete!` (timeout 30 s);
   - neutraliza o CSS do `#container` do exemplo para que o screenshot reflita a
     saída real da lib (o "wrapper" de páginas do docx-preview);
   - salva em `test/output/`:
     - `<nome>.png` — screenshot de página inteira (regressão visual completa);
     - `<nome>__top.png` — recorte legível do topo (1200×1500) para inspeção;
     - `<nome>.html` — HTML renderizado (inspeção estrutural/CSS);
     - `<nome>.log` — logs de console (depuração).

### Como rodar

```bash
# renderiza todos os resources/*.docx (compila antes)
dart run test/render_harness.dart

# pula a compilação (itera rápido em mudanças só de Dart-lib já compiladas)
dart run test/render_harness.dart --no-compile

# um arquivo específico
dart run test/render_harness.dart resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx
```

> **Ciclo de iteração:** editar lib → `dart run test/render_harness.dart`
> (recompila) → abrir `test/output/*__top.png` → comparar com o Word.
> Estatísticas impressas por documento: nº de páginas, parágrafos, tabelas e
> imagens carregadas — servem como *smoke test* numérico.

Além das estatísticas, o harness imprime **métricas de fonte/entrelinha** (para
diagnosticar altura de conteúdo) e verifica os campos `PAGE`/`NUMPAGES`. Com
`FIND="texto" dart run test/render_harness.dart …` ele recorta a região ao redor
do primeiro elemento que contém o texto — útil para comparar uma tabela/rodapé
específico contra a página correspondente do PDF de referência.

### Próximos incrementos do harness (ver Fase 5)

- ✅ Baseline "verdade" a partir do PDF exportado do Word (per-página em
  `resources/<doc>/…-NN.png`, commitado) — já usado para validar F8/F5/F9.
- ✅ Recorte por região via `FIND=` (cabeçalho, rodapé, tabela específica).
- Diff de imagem pixel-a-pixel `test/output` × `resources/<doc>/*.png` para
  detectar regressão automaticamente.

---

## 3. Diagnóstico da linha de base

Renderização atual dos dois documentos-alvo (baseline capturado em
`test/output/`). **A base já é boa** — corpo de texto, títulos e tabelas saem
com alta fidelidade. Os problemas concentram-se em objetos flutuantes (VML) e
paginação.

| Aspecto | Estado | Evidência / observação |
|---|---|---|
| Texto justificado (Arial) | ✅ Fiel | Alinhamento, quebra e espaçamento batem com o Word |
| Títulos numerados (1., 2., 3., 4.) | ✅ Fiel | Negrito, tamanho e numeração corretos |
| Listas com marcadores | ✅ Fiel | Bullets e recuo próximos do original |
| Tabelas multi-página (TR) | ✅ Fiel | Bordas, `colspan` (SUBTOTAL), merge vertical, larguras de coluna, quebra de célula e negrito corretos |
| Imagens (brasão, logos) | ✅ Carregam | `images loaded = 2/2` (ETP), `5/5` (TR); base64 embutido OK |
| Fontes / cores de tema | ✅ OK | Variáveis `--docx-*-color`, mapeamento de fontes de estilo aplicados |
| **Caixa VML "Continuação de Processo"** | ✅ Corrigido (F1+F2+F15) | Reposicionada (F1), **com borda** (F2) e **inset interno vertical** (F15) — texto não encosta na borda, igual ao Word |
| **Composição do cabeçalho (objetos flutuantes)** | ✅ Corrigido (F1) | Caixa VML reposicionada; layout horizontal fiel nos dois docs |
| **Paginação dinâmica** | ✅ v3 (F3+F10+F11) | Cabeçalho/rodapé por página; **tabelas** quebradas linha-a-linha (repetindo `w:tblHeader`); **parágrafos longos** quebrados no limite da linha (sem cortar palavra). ETP: 1 → 19; TR: 3 → 158 |
| **Número de página (`PAGE`/`NUMPAGES`)** | ✅ Corrigido (F12) | Antes "Página 2 \| 15" repetido (cache do Word); agora "Página 1 \| 19", "Página 2 \| 19"… recalculado por página |
| Borda de textbox / autoshapes VML | ✅ Corrigido (F2) | Texto-boxes VML *stroked* por padrão ganham borda CSS na `<svg>` |
| Contagem de páginas vs Word | ✅ Confirmado (F8) | **ETP: 19 páginas = PDF de referência 19 páginas (bate exato!)**. O "15" era cache obsoleto. TR: 158 vs PDF 140 (~13% de resíduo, ligado a tabelas). PDFs/PNGs de referência em `resources/<doc>/` |
| Rodapé (logos GOVTIC/DIGITAL) | ✅ OK | 3 logos + endereço + número de página renderizam e repetem por página |
| **Títulos pretos saindo vermelhos** | ✅ Corrigido (F13) | Estilo de parágrafo com override preto (`w:color auto`) era sobreposto pelo vermelho do estilo de caractere *linked*; corrigida a ordem (main vence) |
| **Linhas internas de tabela ausentes** | ✅ Corrigido (F14) | `tblBorders` (inclui `insideH`/`insideV`) agora vai para o `cellStyle` → toda célula recebe borda → grade completa (não só a caixa externa) |

### Causa-raiz dos defeitos principais

**(D1) Caixa VML mal posicionada** — `lib/src/renderer/html_renderer_vml.dart:14-16`:
o `cssStyleText` bruto do VML é jogado direto no atributo `style` do `<svg>`.
Esse texto contém `position:absolute; margin-left:79.3pt; …;
mso-position-horizontal:right; mso-position-horizontal-relative:margin; …`.
O browser **ignora todas as propriedades `mso-*`**, então a caixa não vai para a
margem direita — fica no canto superior esquerdo (deslocada por `margin-left`),
sobrepondo o brasão/endereço. Faltam também um bloco-contêiner posicionado
(`position: relative`) para ancorar o `right:0` na área de conteúdo e a borda.

**(D2) Paginação estática** — `_renderSections` em
`html_renderer_core.dart` só quebra página em quebras explícitas
(`w:br type="page"`), seções, ou `lastRenderedPageBreak` — e este último está
desligado por padrão (`ignoreLastRenderedPageBreak = true`,
`html_renderer.dart:97`). O Word pagina dinamicamente por medição de layout, o
que o docx-preview não faz por design. Como cabeçalho/rodapé são renderizados
por página, um documento de 1 página só mostra 1 cabeçalho.

---

## 4. Backlog priorizado

Ordenado por (impacto visual ÷ risco/esforço). Cada item: **problema → causa →
abordagem → risco**.

### TIER 1 — Alto impacto, escopo isolado

**F13. Títulos pretos renderizados em vermelho** — ✅ **implementado** (validado
contra o PDF: "Memória de Cálculo" agora preto).
- **Causa:** um estilo de parágrafo (ex.: `Nvel1-SemNum0`) que sobrescreve a cor
  para preto (`<w:color w:val="auto"/>`, herdando de um base vermelho) tem um
  **estilo de caractere *linked*** que ficou vermelho. O renderer emitia as
  regras CSS do estilo *linked* **depois** das do estilo principal → como CSS é
  "último vence" na mesma especificidade, o vermelho ganhava.
- **Abordagem:** em `_renderStyles`, emitir as regras do estilo *linked*
  **antes** das do principal (`[...linkedStyle.styles, ...subStyles]`), para o
  estilo principal vencer o conflito (como no Word).
- **Risco:** Baixo — estritamente mais correto (principal vence, linked preenche
  lacunas). ETP/TR sem regressão.

**F14. Linhas internas de tabela ausentes** — ✅ **implementado** (validado
contra o PDF pág. 6).
- **Causa:** um `tblBorders` no nível da tabela (comum quando as células não têm
  `tcBorders` próprios) era aplicado ao **elemento `<table>`** (só caixa
  externa). O `table.cellStyle`, que o docxjs usa para levar a borda a **cada
  célula**, nunca era populado (o 3º parâmetro de `parseDefaultProperties` fora
  portado como `List` e ignorado).
- **Abordagem:** 3º parâmetro vira `childStyle` (Map); `tblBorders` roteia para
  `childStyle ?? style`; `_parseTable` passa `cellStyle`; `_parseBorderProperties`
  passa a entender `insideH`/`insideV` (→ topo/baixo e esq./dir. das células).
  `_processTable` já copia o `cellStyle` para células sem borda própria → grade
  completa via `border-collapse`.
- **Nota:** o arquivo TR é uma cópia *Recuperação Automática*; alguns atributos
  podem ter sido perdidos na recuperação, mas as tabelas com `tblBorders` agora
  batem com o PDF.
- **Risco:** Baixo — células com `tcBorders` próprios têm precedência (cópia só
  preenche o que falta); GRUPO/requisitos sem regressão.

**F15. Inset interno da caixa VML (padding)** — ✅ **implementado**.
- **Problema:** o texto encostava na borda da caixa; o Word tem uma margem
  interna (inset padrão ~0.05in/0.1in).
- **Abordagem:** `padding` **vertical** na `<svg>` — fica entre a borda e o
  *viewport* do `<foreignObject>` (que mantém a altura autoral), então insere o
  texto no topo/base **sem cortar** a última linha; a caixa só cresce um pouco
  para baixo. O padding **horizontal foi omitido de propósito**: a caixa é
  ancorada à direita e nosso texto renderiza um pouco mais largo que o do Word —
  crescer a largura invadiria o cabeçalho, e encolher o *viewport* quebraria uma
  linha e cortaria a última. Vertical-only é o inset seguro que nunca perde
  conteúdo. (Refinamento futuro: inset horizontal fiel exigiria casar a métrica
  de fonte — ver F8b.)
- **Risco:** Baixo — sem corte, sem sobreposição, validado nos dois docs.

**F1. Posicionamento da caixa VML (textbox flutuante)** — *defeito nº 1, aparece
nos dois documentos.*
- **Causa:** D1 acima.
- **Abordagem:**
  1. Adicionar `_translateVmlStyle(String raw)` que faz o *parse* do style VML
     em um `Map<String,String>`, **remove ruído** (`mso-*`, `v-*`,
     `*-percent`) e **traduz** as dicas de posição:
     - `mso-position-horizontal:right` → `right:0` (remove `left`/`margin-left`);
       `left`/`inside` → `left:0`; `center` → `left:0;right:0;margin:auto`.
     - `mso-position-vertical:top` → `top:0`; `bottom` → `bottom:0`;
       `center` → centraliza; caso contrário mantém `margin-top` como offset.
  2. Passar o Map (em vez do string bruto) no `_renderVmlElement`.
  3. Ancoragem: adicionar ao CSS default
     `section.docx header, section.docx footer { position: relative; }` para que
     o `right:0` da `<svg>` absoluta se meça pela **caixa de conteúdo** (entre
     margens) do cabeçalho/rodapé, alinhando à margem direita (como no Word).
- **Risco:** Baixo — afeta só o caminho VML, que hoje já sai errado.
- **Validação:** `__top.png` de ETP e TR — caixa no canto superior direito, sem
  sobrepor brasão/endereço, sem corte.
- **Status:** ✅ **implementado nesta iteração** (ver §7).

**F2. Borda/contorno de textboxes VML** — ✅ **implementado**.
- **Causa:** `<v:shape>` vira `<g>` (grupo SVG, que não pinta contorno); o
  textbox (`foreignObject`) ficava sem borda.
- **Abordagem adotada:** no parser (`vml.dart`), um `<v:shape>` que contém um
  `<v:textbox>` e **não** tem `stroked="f"` é *stroked* por padrão no VML →
  capturamos `borderCss` (`strokeweight` ou 0.75pt, `strokecolor` ou #000000).
  No renderer (`html_renderer_vml.dart`), aplicamos `border` via CSS na `<svg>`.
  Só a borda (sem padding/box-sizing): a altura autoral da caixa comporta as 4
  linhas exatas; padding encolheria a área e o `foreignObject` cortaria a última.
- **Resultado:** a caixa "Continuação de Processo" fica com a borda envolvendo
  as 4 linhas, idêntica ao Word.
- **Risco:** Baixo — restrito a text-boxes VML.

### TIER 2 — Estrutural

**F3. Paginação dinâmica por medição de DOM** — ✅ **implementado (v1)**.
- **Causa:** D2 acima (paginação estática do docx-preview).
- **Abordagem adotada:** em vez da paginação estática por `lastRenderedPageBreak`
  (imprecisa e dependente do cache do Word), foi implementado um **passo de
  pós-renderização** que mede o DOM já renderizado e redistribui o conteúdo em
  páginas A4 reais — a mesma técnica das extensões de paginação do Tiptap
  clonadas em `referencias/` (medir `getBoundingClientRect`, acumular, quebrar
  no overflow). Ver `lib/src/renderer/pagination.dart` e §7.
- **Resultado:** ETP 1 → **19 páginas** (= PDF de referência: **19** ✓);
  cabeçalho **e** rodapé repetem em cada página; conteúdo flui de página em página.
- **Risco:** Baixo — opt-in (chamada explícita a `paginate()`); qualquer erro de
  medição é engolido sem quebrar a renderização base.

**F4. Cabeçalho/rodapé por página** — ✅ coberto por F3 (clonados por página).
- Refinamento futuro: seleção `first`/`even`/`odd` por página real (hoje o mesmo
  header/footer é clonado em todas).

**F12. Número de página (`PAGE`/`NUMPAGES`)** — ✅ **implementado**.
- **Problema:** os campos `PAGE`/`NUMPAGES` mostravam o valor em cache do Word
  ("Página 2 | 15" repetido em todas as páginas), pois o resultado do campo é
  renderizado como texto e nunca recalculado.
- **Abordagem adotada:** o parser (`document_parser_runs.dart` →
  `_markFieldResults`) rastreia o estado do campo (begin/instrText/separate/end)
  e marca o *run resultado* de PAGE/NUMPAGES com `run.fieldType`; o renderer
  emite `data-docx-field="PAGE|NUMPAGES"`. No fim da paginação,
  `_numberPages` percorre **todas** as `section.docx` finais e reescreve o texto:
  PAGE = índice global (1..N), NUMPAGES = N.
- **Resultado:** "Página 1 | 19", "Página 2 | 19"… — número real por página
  (verificado: `PAGE=[1,2,3] NUMPAGES=[19,19]`).

**F10. Quebra de tabelas entre páginas** — ✅ **implementado**.
- **Problema:** a v1 era *block-atômica* — uma tabela maior que a página ficava
  numa única `<section>` alta (o TR saía com 57 páginas vs 140 do Word).
- **Abordagem adotada:** paginação em **três fases** (medir → planejar → mutar),
  necessária porque qualquer mutação no DOM refluia a página e invalidava as
  medições ainda não feitas. Tabelas que estouram a página são divididas
  linha-a-linha em "pedaços" (`<table>` clonada com `<colgroup>` + linhas
  `w:tblHeader` repetidas nas continuações). O renderer marca as linhas de
  cabeçalho com `data-docx-header` (`html_renderer_tables.dart`).
- **Resultado:** TR 3 → **159 páginas** (Word: 140); as 22 tabelas viram 139
  pedaços, quebrando limpo entre páginas, sem corte. Ver §7.
- **Risco:** Baixo (isolado no passo de paginação).

**F11. Quebra de parágrafos longos entre páginas** — ✅ **implementado**.
- **Abordagem adotada:** na fase de *planejamento*, um parágrafo que estoura a
  página tem o ponto de quebra achado por **busca binária no texto** com
  `Range.getBoundingClientRect` (só leitura — não muta), buscando o maior
  offset cujo fundo ainda cabe, e **recuando até um espaço/hífen** para não
  cortar palavra. A divisão real do DOM usa `Range.extractContents()` (que
  preserva os `<span>` aninhados) e ocorre só na fase de *construção*. Uma
  continuação de item de lista tem sua classe de numeração removida para não
  repetir o marcador.
- **Resultado:** os fins de página agora fecham no meio do parágrafo (como no
  Word), sem vãos; sem corte de palavra nem perda/duplicação de texto. A
  contagem de páginas quase não muda porque o resíduo vem da **altura de
  conteúdo** (métrica de fonte / parágrafos vazios com `min-height`), não do
  empacotamento — ver F8.
- **Risco:** controlado — isolado no passo de paginação, com `try/catch` por
  seção que faz fallback para "sem paginação" se algo falhar.

### TIER 3 — Polimento

- **F5. Rodapé** — ✅ **verificado, já fiel**. Comparação direta contra o PDF de
  referência (ETP pág. 1 e TR pág. 139): os logos (GOVTIC + Secretaria / RIO DAS
  OSTRAS DIGITAL / PREFEITURA RIO DAS OSTRAS), o endereço, a URL e o número de
  página aparecem alinhados como no Word, repetidos por página. Sem correção.
- **F6.** Precisão de recuo/espaçamento de listas (comparar `margin-left`/
  `text-indent` com o Word).
- **F7.** Tab stops (`w:tabs`) — a feature é `experimental` e hoje não computa
  posições reais (`_refreshTabStops` é no-op). Alinhamentos por tabulação em
  cabeçalhos podem depender disso.
- **F8. Altura de conteúdo / entrelinha vs Word** — ✅ **investigado e
  confirmado; sem correção necessária**. Medido no ETP (harness): 437 parágrafos
  de corpo em **Arial** (fonte correta) com **entrelinha 18,4px = 1,15 × 12pt**,
  exatamente o que o docx especifica; parágrafos vazios são só 6 (96px, irrelev.).
  **Prova definitiva:** o PDF de referência do ETP (`resources/<doc>/…-01..19.png`)
  tem **19 páginas** e rodapé "Página 1 | 19" — **igual ao nosso render**. O "15"
  era `NUMPAGES` em cache de uma versão antiga. Forçar 15 seria *sub-renderizar*.
- **F8b (tentado, REVERTIDO — contraproducente).** No ETP, nossa página 1
  empacota um pouco *mais* que o PDF (termina na seção 4; o PDF na 3). Hipótese:
  as linhas do Word (`auto` = N × entrelinha simples ≈ 1,15em) são mais altas
  que o `line-height:1,15` do CSS (= N × font-size). **Experimento:** multipliquei
  a entrelinha `auto` por 1,15 (→ 18,4px vira 21,15px). **Resultado medido:** o
  ETP foi de 19 → **21 páginas**, *divergindo* do PDF (19). Ou seja, o valor
  atual (1,15) já faz a **contagem bater exatamente com o PDF**; aumentá-lo
  quebra isso. A diferença de quebra na página 1 é **local**, não um erro global
  de entrelinha. **Mantido o valor atual** (comentário no código explica o porquê
  para ninguém "consertar" de novo). Fechar as quebras locais exigiria replicar o
  modelo de line-box do Word por-linha (muito complexo, alto risco) sem ganho de
  contagem — não vale a pena.
- **F9. Sombreamento de células (`w:shd`)** — ✅ **verificado, já fiel**. O
  parser aplica `w:shd fill` como `background-color` (via `parseDefaultProperties`
  no `tcPr`) e `colorAttr` prefixa `#`. No render do TR aparecem todas as cores:
  `#FFFFFF`×1308, `#FFFF00`×4, `#FF0000`×2, `#E8E8E8`, `#00B050`, e caixas de nota
  `#FFFFCC`/`#E1DFDD`. As tabelas de requisitos (linhas-cabeçalho "Diário de
  Obras" etc.) são brancas no Word também — nada faltando. Sem correção.

---

## 5. Métricas e critérios de aceite

- **Smoke numérico** (impresso pelo harness): páginas/parágrafos/tabelas/imagens
  não regridem entre execuções; `images loaded == images total`.
- **Inspeção visual:** `__top.png` de cada alvo revisado contra o screenshot do
  Word a cada mudança de Tier 1/2.
- **Sem regressão de análise:** `dart analyze` limpo (0 erros) após cada fix.
- **Meta Tier 1:** caixa "Continuação de Processo" no canto superior direito,
  com borda, sem sobreposição, nos dois documentos.
- **(Fase 4) Diff de pixels:** desvio < limiar acordado contra baseline aprovado.

---

## 6. Cronograma por fases

| Fase | Entrega | Itens |
|---|---|---|
| **0 — Harness** ✅ | Renderização headless reproduzível + baseline capturado | `test/render_harness.dart`, `test/output/*` |
| **1 — VML** | Objetos flutuantes fiéis | F1 ✅, F2 |
| **2 — Paginação** ✅ (v1) | Paginação dinâmica por medição + header/footer por página | F3 ✅, F4 ✅ |
| **3 — Paginação v2/v3** ✅ | Quebra de tabelas e parágrafos entre páginas | F10 ✅, F11 ✅ |
| **4 — Polimento** | Altura de conteúdo/fonte, rodapé, listas, tabs, sombreamento | F5–F9 |
| **5 — Regressão** | Diff de pixels automatizado + baseline do Word | incrementos do harness |

---

## 7. Estado da implementação (esta iteração)

- ✅ **Harness Puppeteer** (`test/render_harness.dart`) — compila, serve, dirige
  o Chrome, captura PNG de página inteira + recorte de topo + HTML + logs para
  cada `resources/*.docx`. Base de todo o trabalho de fidelidade.
- ✅ **Baseline capturado** para ETP e TR em `test/output/`.
- ✅ **F1 — Posicionamento da caixa VML** implementado e **verificado**.

### Detalhe do F1 (implementado)

**Arquivos alterados:**
- `lib/src/renderer/html_renderer_vml.dart` — nova função `_translateVmlStyle()`
  (parse do style VML → CSS, remove `mso-*`/`v-*`/`*-percent`, traduz
  `mso-position-horizontal/vertical` em `left/right/top/bottom`); usada em
  `_renderVmlElement` no lugar do string bruto.
- `lib/src/renderer/html_renderer_styles.dart` — regra
  `section.docx > header, section.docx > footer { position: relative; }` para
  ancorar o `right:0` da caixa na área de conteúdo (entre margens).

**Resultado (antes → depois):**
- **ETP:** a caixa deixou de sobrepor brasão/endereço e foi para o **canto
  superior direito**, alinhada à margem direita (igual ao Word).
- **TR:** a caixa deixou de ser **cortada** na borda direita e agora aparece
  inteira ("Continuação de Processo / Processo nº 44505/2025 / Folha / Rubrica").
- Sem regressão numérica (páginas/parágrafos/tabelas/imagens inalterados);
  `dart analyze lib` sem erros novos.

**Pendência remanescente:** a **borda** do retângulo da caixa ainda não é
desenhada (item **F2**) — é o único detalhe que falta para a caixa ficar
idêntica ao Word.

### Detalhe do F3 — Paginação dinâmica v1 (implementado)

**Arquivo novo:** `lib/src/renderer/pagination.dart` — função `paginate(root)`.

**Como funciona:**
1. Roda **após** o HTML estar no DOM vivo (chamada em `example/web/main.dart`
   logo após `renderAsync`, antes do sinal `Render complete!`).
2. Para cada `section.docx`, lê a geometria da própria seção via
   `getComputedStyle` (min-height = altura A4; padding = margens) e calcula a
   área de texto disponível = `min-height − padding` (o cabeçalho/rodapé ficam
   na margem via margens negativas, consumindo ~0 de espaço de fluxo).
3. Percorre os blocos de topo do `<article>` medindo **posições reais**
   (`getBoundingClientRect`) — usar posição, e não a soma de alturas, faz o
   colapso de margens entre blocos "sair de graça".
4. Quando um bloco ultrapassa a área disponível, fecha a página e abre outra.
5. Reconstrói N `<section>`s A4, **clonando header/footer** em cada e **movendo**
   os nós de bloco originais para novos `<article>`s (preserva todo o estilo).

**Calibração (medido no ETP):** `minH=1122.5px` (A4), `padT=padB=94.5px`
(margens ~2,5 cm) → `avail≈933px`. Resultado: **1 → 19 páginas** (a primeira
versão dava 29 por subtrair header/footer indevidamente e por somar alturas com
margens colapsadas em duplicidade; ambos corrigidos).

**Referências estudadas (clonadas em `referencias/`):**
`tiptap-extension-pagination` (hugs7), `tiptap-pages` (adalat-ai — motor de
medição em `src/core.ts`), `tiptap-pagination` (RomikMakavana),
`tiptap-pagination-breaks` (adityayaduvanshi). Todas medem `offsetHeight`/
`getBoundingClientRect` e quebram no overflow — a técnica aplicada aqui.

### Detalhe do F10 — Quebra de tabelas entre páginas (implementado)

Evolução da paginação para **três fases** em `lib/src/renderer/pagination.dart`,
porque mover linhas no meio da medição refluía a página e corrompia as medidas
seguintes (bug observado: TR parava em 57–60 páginas):
1. **Medir** — captura `getBoundingClientRect` de todos os blocos e, para
   tabelas, de todas as linhas (`<tr>`), sem mutar o DOM.
2. **Planejar** — aritmética pura sobre os números capturados, produzindo os
   "baldes" de página; tabelas que estouram viram vários pedaços.
3. **Construir** — uma única passagem que muta o DOM: cria as `<section>`s,
   move os nós originais e, para continuações de tabela, clona a casca
   `<table>` + `<colgroup>` + linhas `data-docx-header`.

O renderer passou a marcar linhas de cabeçalho de tabela
(`w:tblHeader` → `isHeader`) com o atributo `data-docx-header`
(`lib/src/renderer/html_renderer_tables.dart`) para que sejam repetidas no topo
de cada continuação.

**Resultado:** TR 3 → **159 páginas** (Word: 140); 22 tabelas → 139 pedaços,
quebrando limpo entre páginas, sem corte, com o conteúdo fluindo após a tabela e
cabeçalho/rodapé repetidos.

### Detalhe do F11 — Quebra de parágrafos entre páginas (implementado)

Mesma separação medir/planejar/construir do F10, agora para `<p>`:
- **Planejar (medição, sem mutar):** `_planParagraphSplit` coleta os nós de
  texto do parágrafo e faz **busca binária** pelo maior offset de caractere cujo
  `Range.getBoundingClientRect().bottom` ainda cabe na página; recua até o último
  espaço/hífen para não cortar palavra. Repete enquanto o restante estourar,
  produzindo N pontos de quebra (um parágrafo muito longo cruza várias páginas).
- **Construir (mutação única):** `_SplitParagraph` divide o `<p>` com
  `Range.extractContents()` (preserva `<span>`/formatação aninhada), gerando a
  cabeça (nó original encurtado) + caudas clonadas. Continuações de item de
  lista têm a classe `*-num-*` removida para não repetir marcador/número.

**Resultado:** os fins de página fecham no meio do parágrafo, como no Word
(verificado: "…contratação da solução" | "tecnológica, devendo assegurar…" —
quebra limpa na fronteira de palavra). Contagem de páginas quase não muda: o
resíduo (ETP 19 vs 15, TR 158 vs 140) vem da **altura de conteúdo** (métrica de
fonte, parágrafos vazios com `min-height`), não do empacotamento (F8).

**Nota:** Campos `PAGE`/`NUMPAGES` não são recalculados (mostram o cache do
Word — ex.: "Página 2 | 15" repetido).

> Referências de código citadas: caminho:linha apontam para o commit atual e
> podem deslocar conforme o código evolui.
