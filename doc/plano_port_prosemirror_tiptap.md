# ESPECIFICAÇÃO TÉCNICA E ARQUITETURAL COMPLETA: PORTABILIDADE PROSEMIRROR & TIPTAP PARA DART

Este é o documento definitivo e exaustivo para a reescrita do ecossistema ProseMirror e Tiptap em Dart puro. Este documento detalha as assinaturas de classes, a arquitetura de módulos, os padrões de conversão de TypeScript para Dart e a implementação passo a passo.

---

## 1. DIRETRIZES DE ENGENHARIA E CONVERSÃO DE TIPOS

A migração de um ecossistema TypeScript complexo para Dart exige adaptações estritas.

### 1.1. Abolição do `dart:html` e Adoção do `package:web`
Devido à deprecação do `dart:html` e sua incompatibilidade com WebAssembly (Wasm), **todo o acesso ao DOM será feito exclusivamente via `package:web`**.
Isso significa que as APIs JavaScript serão tipadas através de `JSInterop`.

**Comparação de Código:**
```dart
// ERRADO (Antigo dart:html):
import 'dart:html' as html;
html.Element div = html.document.createElement('div');
div.onClick.listen((html.MouseEvent e) { ... });

// CORRETO (Novo package:web):
import 'package:web/web.dart' as web;
import 'dart:js_interop';

web.HTMLDivElement div = web.document.createElement('div'.toJS) as web.HTMLDivElement;
div.addEventListener('click', ((web.MouseEvent e) {
  // Lógica de evento
}).toJS);
```

### 1.2. Mapeamento de Tipos Avançados do TypeScript

**1. Union Types (`A | B`):**
O TypeScript permite coisas como `let content: Fragment | Node | Node[]`. No Dart, usaremos construtores de fábrica e `sealed classes` ou sobrecarga de métodos.
```dart
// TypeScript
static from(nodes?: Fragment | Node | Node[] | null): Fragment;

// Dart (Polimorfismo e Type Checking)
static Fragment from(dynamic nodes) {
  if (nodes == null) return Fragment.empty;
  if (nodes is Fragment) return nodes;
  if (nodes is PMNode) return Fragment([nodes]);
  if (nodes is List<PMNode>) return Fragment(nodes);
  throw ArgumentError('Invalid type for Fragment.from');
}
```

**2. Option Objects e Props:**
```dart
// TypeScript
interface EditorProps {
  editable?: (state: EditorState) => boolean;
  transformPasted?: (slice: Slice) => Slice;
}

// Dart
class EditorProps {
  final bool Function(EditorState)? editable;
  final Slice Function(Slice)? transformPasted;

  const EditorProps({this.editable, this.transformPasted});
}
```

**3. Records para Tuplas:**
TypeScript: `[number, number]` 
Dart: `(int, int)` (novo recurso do Dart 3).

---

## 2. ARQUITETURA DETALHADA: `prosemirror-model`

O módulo base que representa o documento como uma árvore imutável (AST). 

### 2.1. `fragment.dart`
O `Fragment` representa a lista de filhos de um nó. Ele é imutável.
**Estrutura da Classe:**
```dart
class Fragment {
  final List<PMNode> content;
  int get size => _size; // Soma do tamanho de todos os nós filhos

  const Fragment(this.content, [this._size]);

  static const Fragment empty = Fragment([]);

  void append(Fragment other) { ... }
  Fragment cut(int from, [int? to]) { ... }
  Fragment replaceChild(int index, PMNode node) { ... }
  void forEach(void Function(PMNode node, int offset, int index) f) { ... }
  
  // Construtor principal usado internamente
  static Fragment from(dynamic nodes) { ... }
}
```

### 2.2. `node.dart` (ProseMirror Node)
Para evitar conflito com `web.Node`, usaremos `PMNode` ou `Node`.
**Estrutura da Classe:**
```dart
class PMNode {
  final NodeType type;
  final Map<String, dynamic> attrs;
  final Fragment content;
  final List<Mark> marks;
  
  int get nodeSize => isLeaf ? 1 : content.size + 2;
  bool get isLeaf => type.isLeaf;
  bool get isInline => type.isInline;
  bool get isBlock => type.isBlock;

  const PMNode(this.type, this.attrs, this.content, this.marks);

  PMNode child(int index) => content.content[index];
  PMNode childAfter(int pos) { ... }
  PMNode childBefore(int pos) { ... }
  
  PMNode copy([Fragment? newContent]) { ... }
  Slice slice(int from, [int? to]) { ... }
  PMNode replace(int from, int to, Slice slice) { ... }
  
  ResolvedPos resolve(int pos) { ... }
}
```

### 2.3. `mark.dart`
Representa estilos aplicados ao texto (negrito, itálico, link).
**Estrutura da Classe:**
```dart
class Mark {
  final MarkType type;
  final Map<String, dynamic> attrs;

  const Mark(this.type, this.attrs);

  List<Mark> addToSet(List<Mark> set) { ... }
  List<Mark> removeFromSet(List<Mark> set) { ... }
  bool isInSet(List<Mark> set) { ... }
  
  static bool sameSet(List<Mark> a, List<Mark> b) { ... }
}
```

### 2.4. `schema.dart`
Valida o que pode existir na árvore.
```dart
class Schema {
  final Map<String, NodeType> nodes;
  final Map<String, MarkType> marks;
  final PMNode cachedTopNodeType;

  Schema(SchemaSpec spec) { ... }
  
  PMNode text(String text, [List<Mark>? marks]) { ... }
  PMNode node(String type, [Map<String, dynamic>? attrs, dynamic content, List<Mark>? marks]) { ... }
}

class NodeType {
  final String name;
  final Schema schema;
  final NodeSpec spec;
  
  bool get isBlock => ...
  bool get isText => ...
  
  PMNode createAndFill([Map<String, dynamic>? attrs, dynamic content, List<Mark>? marks]) { ... }
  bool validContent(Fragment content) { ... }
}
```

### 2.5. `resolvedpos.dart`
Dada uma posição inteira no documento (ex: 15), resolve para uma estrutura indicando todos os nós pais e índices.
```dart
class ResolvedPos {
  final int pos;
  final PMNode doc;
  final List<PMNode> path;
  
  int get depth => path.length / 3 - 1;
  PMNode get parent => node(depth);
  PMNode node(int depth) { ... }
  int index(int depth) { ... }
  PMNode? get nodeAfter { ... }
  PMNode? get nodeBefore { ... }
}
```

### 2.6. `to_dom.dart` e `from_dom.dart`
A conexão com `package:web`.
```dart
// Utiliza web.Node para parseamento
class DOMParser {
  final Schema schema;
  final List<ParseRule> rules;

  DOMParser(this.schema, this.rules);

  PMNode parse(web.Node dom, [ParseOptions? options]) { ... }
  Slice parseSlice(web.Node dom, [ParseOptions? options]) { ... }
}

class DOMSerializer {
  final Map<String, dynamic> nodes;
  final Map<String, dynamic> marks;

  web.DocumentFragment serializeFragment(Fragment fragment, [Map<String, dynamic>? options]) { ... }
  web.Node serializeNode(PMNode node, [Map<String, dynamic>? options]) { ... }
}
```

---

## 3. ARQUITETURA DETALHADA: `prosemirror-transform`

Trata da mutabilidade. Os documentos PM não podem ser editados diretamente. Uma `Transform` registra passos (`Steps`).

### 3.1. `step.dart`
```dart
abstract class Step {
  StepMap getMap();
  StepResult apply(PMNode doc);
  Step invert(PMNode doc);
  Step? merge(Step other) { return null; }
  Map<String, dynamic> toJSON();
  static Step fromJSON(Schema schema, Map<String, dynamic> json) { ... }
}

class StepResult {
  final PMNode? doc;
  final String? failed;
  
  StepResult.ok(this.doc) : failed = null;
  StepResult.fail(this.failed) : doc = null;
}
```

### 3.2. Passos Concretos (Subclasses de Step)
*   **`ReplaceStep`:** Substitui um intervalo por um `Slice` de documento.
*   **`ReplaceAroundStep`:** Substitui o contorno de um bloco mantendo o conteúdo interno.
*   **`AddMarkStep`:** Adiciona um `Mark` a um intervalo numérico.
*   **`RemoveMarkStep`:** Remove um `Mark` de um intervalo numérico.

### 3.3. `map.dart` (Mapeamento de Posições)
Se eu deleto os caracteres da posição 2 a 5, o caractere 6 agora é 3. `Mapping` computa isso.
```dart
class StepMap {
  final List<int> ranges;
  int map(int pos, [int assoc = 1]) { ... }
  void forEach(void Function(int oldStart, int oldEnd, int newStart, int newEnd) f) { ... }
}

class Mapping {
  final List<StepMap> maps;
  int map(int pos, [int assoc = 1]) { ... }
  int mapResult(int pos, [int assoc = 1]) { ... }
}
```

### 3.4. `transform.dart`
O agregador de passos.
```dart
class Transform {
  PMNode doc;
  final List<Step> steps;
  final List<PMNode> docs;
  final Mapping mapping;

  Transform(this.doc);

  Transform step(Step step) { ... }
  Transform replace(int from, int to, [Slice? slice]) { ... }
  Transform replaceWith(int from, int to, PMNode node) { ... }
  Transform insert(int pos, PMNode node) { ... }
  Transform addMark(int from, int to, Mark mark) { ... }
}
```

---

## 4. ARQUITETURA DETALHADA: `prosemirror-state`

Mantém o estado global (documento, seleção, plugins) para injetar na View.

### 4.1. `state.dart`
```dart
class EditorState {
  final PMNode doc;
  final Selection selection;
  final List<Mark>? storedMarks;
  final List<Plugin> plugins;
  
  // Estado isolado dos plugins
  final Map<PluginKey, dynamic> pluginState; 

  Transaction get tr => Transaction(this);

  EditorState apply(Transaction tr) { ... }
  EditorState applyTransaction(Transaction tr) { ... }
  
  static EditorState create(EditorStateConfig config) { ... }
}
```

### 4.2. `transaction.dart`
```dart
class Transaction extends Transform {
  final int time;
  final Map<String, dynamic> meta;
  Selection? selection;
  
  Transaction(EditorState state) : super(state.doc);

  Transaction setSelection(Selection selection) { ... }
  Transaction setMeta(dynamic key, dynamic value) { ... }
  dynamic getMeta(dynamic key) { ... }
  Transaction setTime(int time) { ... }
}
```

### 4.3. `selection.dart`
```dart
abstract class Selection {
  final int from;
  final int to;
  final ResolvedPos $from;
  final ResolvedPos $to;

  Selection(this.$from, this.$to);
  
  bool get empty => from == to;
  Selection map(PMNode doc, Mapping mapping);
}

class TextSelection extends Selection { ... }
class NodeSelection extends Selection { ... }
```

### 4.4. `plugin.dart`
Sistema de modularidade vital.
```dart
class Plugin<T> {
  final PluginSpec<T> spec;
  final PluginKey key;

  Plugin(this.spec) : key = spec.key ?? PluginKey();
  
  T getState(EditorState state) => state.pluginState[key];
}

class PluginSpec<T> {
  final PluginKey? key;
  final StateField<T>? state;
  final EditorProps? props;
  final void Function(EditorView)? view;
  final List<Transaction> Function(Transaction, EditorState, EditorState)? appendTransaction;
  final bool Function(Transaction, EditorState)? filterTransaction;

  PluginSpec({ ... });
}
```

---

## 5. ARQUITETURA DETALHADA: `prosemirror-view`

A camada de interface gráfica via DOM com `package:web`. É onde a maior parte da lógica específica de Dart/JS se concentra.

### 5.1. `index.dart` (EditorView)
```dart
class EditorView {
  final web.Element dom; // O container principal gerado no DOM
  EditorState state;
  final EditorProps props; // Plugins + configurações iniciais
  
  // Referência interna à representação virtual do DOM do ProseMirror
  ViewDesc? docView; 
  
  EditorView(web.Element place, DirectEditorProps props) {
    // Inicialização e montagem no place
    dom = web.document.createElement('div'.toJS) as web.HTMLDivElement;
    dom.setAttribute('contenteditable'.toJS, 'true'.toJS);
    dom.classList.add('ProseMirror'.toJS);
    
    // Binding de eventos do teclado e mouse via package:web
  }

  void updateState(EditorState newState) { ... }
  void update(DirectEditorProps newProps) { ... }
  void destroy() { ... }
  
  // Mecanismo de dispatch para enviar ações ao estado
  void dispatch(Transaction tr) { ... }
}
```

### 5.2. `domobserver.dart`
Lê alterações feitas pelo navegador (como correções ortográficas e IME) e sincroniza com o state.
```dart
class DOMObserver {
  final EditorView view;
  late final web.MutationObserver observer;
  
  DOMObserver(this.view) {
    observer = web.MutationObserver(((JSArray<web.MutationRecord> mutations, web.MutationObserver obs) {
      handleMutations(mutations);
    }).toJS);
  }
  
  void start() {
    observer.observe(view.dom, web.MutationObserverInit(
      childList: true,
      characterData: true,
      characterDataOldValue: true,
      subtree: true,
    ));
  }
  
  void flush() { ... }
  void handleMutations(JSArray<web.MutationRecord> mutations) { ... }
}
```

### 5.3. `input.dart` (Event Listeners)
Controle massivo de teclado.
```dart
void editHandlers(EditorView view) {
  view.dom.addEventListener('keydown', ((web.KeyboardEvent e) {
    if (view.someProp('handleKeyDown', (f) => f(view, e))) {
      e.preventDefault();
      return;
    }
    // Lógica fallback de digitação
  }).toJS);
  
  view.dom.addEventListener('paste', ((web.ClipboardEvent e) {
    // Parsing do web.ClipboardEvent para PMNode Slice e inserção via Transaction
  }).toJS);
}
```

---

## 6. ARQUITETURA DETALHADA: `tiptap-core` & EXTENSÕES

O Tiptap é um wrapper idiomático em cima do ProseMirror que esconde a complexidade de Schemas e Plugins sob uma API limpa orientada a objetos ("Extensions").

### 6.1. O Motor Principal: `Editor.dart`
```dart
class TiptapEditor {
  late final EditorState state;
  late final EditorView view;
  late final ExtensionManager extensionManager;
  final StreamController<EditorEvents> _eventEmitter = StreamController.broadcast();

  TiptapEditor(EditorOptions options) {
    extensionManager = ExtensionManager(options.extensions);
    
    // Criação do Schema a partir das extensões
    final schema = extensionManager.createSchema();
    
    // Criação do State
    state = EditorState.create(EditorStateConfig(
      doc: createDocument(options.content, schema),
      schema: schema,
      plugins: extensionManager.createPlugins(),
    ));
    
    // Montagem na View
    view = EditorView(options.element, DirectEditorProps(
      state: state,
      dispatchTransaction: (tr) {
        state = state.apply(tr);
        view.updateState(state);
        _eventEmitter.add(EditorEvents.update);
      }
    ));
  }

  // Chaining API
  CommandManager get chain => CommandManager(this);
  bool get isActive => ...
  void destroy() { ... }
}
```

### 6.2. `ExtensionManager.dart`
Pega uma lista de classes `Node`, `Mark` e `Extension` e as funde.
```dart
class ExtensionManager {
  final List<AnyExtension> extensions;
  
  ExtensionManager(this.extensions);

  Schema createSchema() {
    final nodes = <String, NodeSpec>{};
    final marks = <String, MarkSpec>{};
    
    for (final ext in extensions) {
      if (ext is NodeExtension) {
        nodes[ext.name] = ext.config();
      } else if (ext is MarkExtension) {
        marks[ext.name] = ext.config();
      }
    }
    
    return Schema(SchemaSpec(nodes: nodes, marks: marks));
  }
  
  List<Plugin> createPlugins() { ... }
}
```

### 6.3. Classes Abstratas do Tiptap (`Node`, `Mark`, `Extension`)
Como os usuários finais criarão blocos:
```dart
abstract class NodeExtension extends AnyExtension {
  final String name;
  
  NodeExtension(this.name);

  NodeSpec config();
  List<InputRule> inputRules() => [];
  Map<String, dynamic> addKeyboardShortcuts() => {};
  NodeView? addNodeView() => null;
}
```

### 6.4. Extensões Concretas (Fase 6)
**`Document` (O Nó Raiz):**
```dart
class Document extends NodeExtension {
  Document() : super('doc');

  @override
  NodeSpec config() => NodeSpec(
    content: 'block+',
  );
}
```

**`Paragraph` (O Parágrafo):**
```dart
class Paragraph extends NodeExtension {
  Paragraph() : super('paragraph');

  @override
  NodeSpec config() => NodeSpec(
    content: 'inline*',
    group: 'block',
    parseDOM: [ParseRule(tag: 'p')],
    toDOM: (node) => ['p', 0], // Mapeamento DOM (0 significa "conteúdo aqui")
  );
}
```

**`Bold` (A Marcação de Negrito):**
```dart
class Bold extends MarkExtension {
  Bold() : super('bold');

  @override
  MarkSpec config() => MarkSpec(
    parseDOM: [ParseRule(tag: 'strong'), ParseRule(tag: 'b')],
    toDOM: (mark, inline) => ['strong', 0],
  );
}
```

---

## 7. CRONOGRAMA DE EXECUÇÃO EM TAREFAS ATÔMICAS

Para evitar o colapso cognitivo e erros de compilação em cascata, a codificação seguirá um checklist restrito:

### Etapa A: Fundações (Módulo Model)
- [x] Criar `lib/src/prosemirror/model/dom.dart` (Interfaces).
- [x] Criar `lib/src/prosemirror/model/fragment.dart` (Árvore Plana).
- [x] Criar `lib/src/prosemirror/model/mark.dart` (Formatação).
- [x] Criar `lib/src/prosemirror/model/node.dart` (O AST Node principal).
- [x] Criar `lib/src/prosemirror/model/resolvedpos.dart`.
- [x] Criar `lib/src/prosemirror/model/schema.dart`.
- [x] Implementar Serializador `to_dom.dart`.
- [x] Implementar Parser `from_dom.dart`.

### Etapa B: Motor de Transição (Módulo Transform)
- [x] `lib/src/prosemirror/transform/step.dart` (Abstrações e global registry)
- [x] `lib/src/prosemirror/transform/map.dart` (`StepMap`, `Mapping`)
- [x] Subclasses de Step (`replace_step.dart`, `mark_step.dart`, `attr_step.dart`)
- [x] `lib/src/prosemirror/transform/replace.dart` (Motor e Fitter)
- [x] `lib/src/prosemirror/transform/structure.dart` (Operadores de árvore: lift, wrap, join)
- [x] `lib/src/prosemirror/transform/mark.dart` (Helper methods de marcação)
- [x] Portar testes vitais do `prosemirror-transform`:
  - [x] `test-mapping.ts` -> `test_mapping.dart`
  - [x] `test-replace_step.ts` -> `test_replace_step.dart`
  - [x] `test-step.ts` -> `test_step.dart`
  - [x] `test-structure.ts` -> `test_structure.dart`
  - [x] `test-trans.ts` -> `test_trans.dart`
- [x] `lib/src/prosemirror/transform/transform.dart` (Classe principal `Transform`)
- [x] **Status:** 100% Concluído. Zero erros de compilação!

### Etapa C: Qualidade e Testes (prosemirror-test-builder)
- [x] Criar `lib/src/prosemirror/test_builder/` (DSL `doc`, `p`, `blockquote`).
- [x] Portar Testes do Model (Prioritário)
  - [x] `test-resolve.ts` -> `test_resolve.dart`
  - [x] `test-node.ts` -> `test_node.dart`
  - [x] `test-slice.ts` -> `test_slice.dart`
  - [x] `test-mark.ts` -> `test_mark.dart`
  - [x] `test-content.ts` -> `test_content.dart`
  - [x] `test-replace.ts` -> `test_replace.dart`
  - [x] `test-diff.ts` -> `test_diff.dart`
  - [x] `test_state.dart` foi portada e validada com `dart test`.
- [x] Suítes `model`, `transform` e `state` validadas com `dart test`.
- [x] `dart analyze lib/src/prosemirror test/prosemirror` está limpo.

### Etapa D: O Cérebro (Módulo State)
- [x] Criar `lib/src/prosemirror/state/selection.dart`.
- [x] Criar `lib/src/prosemirror/state/transaction.dart`.
- [x] Criar `lib/src/prosemirror/state/plugin.dart`.
- [x] Criar `lib/src/prosemirror/state/state.dart`.
- [x] Validar a suíte `test/prosemirror/state/test_state.dart`.

### Etapa E: A Interface Gráfica (Módulo View)
- [x] Criar `lib/src/prosemirror/view/dom.dart` (Básicos `package:web`).
- [x] Criar `lib/src/prosemirror/view/viewdesc.dart`.
- [x] Criar `lib/src/prosemirror/view/domobserver.dart`.
- [x] Criar `lib/src/prosemirror/view/input.dart` (Event listeners).
- [x] Criar `lib/src/prosemirror/view/index.dart` (`EditorView`).
- [x] Scaffold inicial validado com `dart analyze lib/src/prosemirror lib/src/tiptap test/prosemirror test/tiptap`.

### Etapa F: A Ergonomia (Tiptap Core & Extensions)
- [x] Criar `lib/src/tiptap/core/extension_manager.dart`.
- [x] Criar `lib/src/tiptap/core/command_manager.dart`.
- [x] Criar extensões base abstratas (`Extension`, `Node`, `Mark`).
- [x] Criar `lib/src/tiptap/core/editor.dart`.
- [ ] Construir extensões concretas: `Document`, `Text`, `Paragraph`, `Bold`, `Italic`.
- [x] Portar e validar o teste `test/tiptap/core/test_extension_manager.dart`.
- [x] `dart analyze lib/src/tiptap/core test/tiptap` está limpo.
- [x] `dart test test/tiptap/core/test_extension_manager.dart` passou.

---

## 8. CONCLUSÃO

Este guia fornece a modelagem exata e detalhada para todas as centenas de classes fundamentais que serão construídas. Cada módulo será codificado seguindo estritamente as assinaturas Dart providenciadas neste documento para garantir a paridade com a API do Tiptap/ProseMirror original, permitindo renderização imediata de um editor Web em projetos Dart sem depender do ecossistema NPM.
