/// Quill Delta ↔ ProseMirror converter (§5.3 of the plan).
///
/// Pure AST work — no DOM involved — so everything here runs on the VM
/// as well as compiled to JS/Wasm.
///
/// Quill's document model is a flat sequence of characters where `\n`
/// terminates a line and carries the line's block attributes (`header`,
/// `align`, `list`). ProseMirror is a tree. The mapping implemented here:
///
/// - line without block attrs        ↔ `paragraph`
/// - `header: n`                     ↔ `heading[level: n]`
/// - `align: x`                      ↔ `textAlign` attribute
/// - `list: bullet|ordered` (runs of consecutive lines)
///                                   ↔ `bulletList`/`orderedList` > `listItem`
/// - embed `{image: src}`            ↔ `image` node
/// - embed `{divider: true}`         ↔ `horizontalRule`
/// - inline attrs `bold`, `italic`, `underline`, `strike`, `code`,
///   `link`, `color`, `background`, `font`, `size` ↔ marks
///
/// Known lossy cases (documented per plan §9): tables and `hardBreak`
/// have no Quill representation; nested lists flatten one level.
library;

import '../../prosemirror/model/index.dart' as model;
import '../../prosemirror/state/index.dart';
import '../../quill_delta/delta.dart';

class QuillDeltaConverter {
  final model.Schema schema;

  QuillDeltaConverter(this.schema);

  // =====================================================================
  // Delta → ProseMirror (documento inteiro, um único passe)
  // =====================================================================

  /// Converts a document Delta (insert-only) to a ProseMirror document.
  ///
  /// Single pass; inline content is accumulated in plain lists and each
  /// block node is constructed exactly once (no repeated
  /// `Fragment.append`, which would be O(n²)).
  model.PMNode fromDelta(Delta delta) {
    final blocks = <model.PMNode>[];
    var inline = <model.PMNode>[];

    // Grouping of consecutive list lines into a single list node.
    String? listKind;
    var listItems = <model.PMNode>[];

    void flushList() {
      if (listItems.isEmpty) return;
      final listName = listKind == 'ordered' ? 'orderedList' : 'bulletList';
      final listType = schema.nodes[listName];
      if (listType != null) {
        blocks.add(schema.node(listName, null, listItems));
      } else {
        // Schema without lists: unwrap the paragraphs.
        for (final item in listItems) {
          blocks.addAll(item.children);
        }
      }
      listItems = [];
      listKind = null;
    }

    void endLine(Map<String, dynamic>? attrs) {
      final block = _buildBlock(inline, attrs);
      inline = [];
      final list = attrs?['list'];
      if ((list == 'bullet' || list == 'ordered') &&
          schema.nodes.containsKey('listItem') &&
          block.type.name == 'paragraph') {
        if (listKind != null && listKind != list) flushList();
        listKind = list as String;
        listItems.add(schema.node('listItem', null, [block]));
      } else {
        flushList();
        blocks.add(block);
      }
    }

    // Um embed de bloco em Quill é uma "linha" própria terminada por \n;
    // esse \n não deve gerar um parágrafo vazio extra.
    var pendingBlockEmbed = false;

    for (final op in delta.operations) {
      if (!op.isInsert) {
        throw ArgumentError(
            'fromDelta espera um delta de documento (apenas inserts)');
      }
      final data = op.data;
      if (data is String) {
        final marks = _marksFromAttributes(op.attributes);
        var start = 0;
        while (true) {
          final newline = data.indexOf('\n', start);
          if (newline == -1) {
            if (start < data.length) {
              inline.add(schema.text(data.substring(start), marks));
              pendingBlockEmbed = false;
            }
            break;
          }
          if (newline > start) {
            inline.add(schema.text(data.substring(start, newline), marks));
            pendingBlockEmbed = false;
          }
          if (inline.isEmpty && pendingBlockEmbed) {
            pendingBlockEmbed = false;
          } else {
            endLine(op.attributes);
          }
          start = newline + 1;
        }
      } else if (data is Map) {
        final embed = _embedToNode(data, op.attributes);
        if (embed != null) {
          if (embed.isInline) {
            inline.add(embed);
            pendingBlockEmbed = false;
          } else {
            // Block embed: fecha a linha corrente, emite o bloco.
            if (inline.isNotEmpty) endLine(null);
            flushList();
            blocks.add(embed);
            pendingBlockEmbed = true;
          }
        }
      }
    }
    if (inline.isNotEmpty) endLine(null);
    flushList();

    if (blocks.isEmpty) {
      blocks.add(schema.node('paragraph', null, []));
    }
    return schema.node(schema.topNodeType.name, null, blocks);
  }

  /// Applies [delta] as a whole-document replacement in a single
  /// transaction (path used for R3's "50k ops < 1s" requirement).
  Transaction applyDeltaAsDocument(EditorState state, Delta delta) {
    final doc = fromDelta(delta);
    final tr = state.tr;
    tr.replaceWith(0, state.doc.content.size, doc.content);
    return tr;
  }

  // =====================================================================
  // Delta incremental (retain/insert/delete) sobre documento existente
  // =====================================================================

  /// Applies an incremental Delta (retain/insert/delete) to [state]'s
  /// document, emitting all steps into a single transaction.
  ///
  /// Quill positions count 1 per character and 1 per embed; a line's
  /// `\n` is the block boundary. The cursor below walks the *original*
  /// document once (deltas address original positions in order) and
  /// original positions are remapped through `tr.mapping` as steps pile
  /// up — this is what keeps the whole thing O(doc + ops).
  Transaction applyDelta(EditorState state, Delta delta) {
    final tr = state.tr;
    final cursor = _QuillCursor(state.doc);

    for (final op in delta.operations) {
      if (op.isRetain) {
        final length = op.length!;
        final fromPm = cursor.pmPos;
        final crossed = <_Textblock>[];
        cursor.advance(length, crossedBlocks: crossed);
        final attrs = op.attributes;
        if (attrs != null) {
          _applyRetainAttributes(tr, attrs, fromPm, cursor.pmPos, crossed);
        }
      } else if (op.isDelete) {
        final fromPm = cursor.pmPos;
        cursor.advance(op.length!);
        final from = tr.mapping.map(fromPm);
        final to = tr.mapping.map(cursor.pmPos);
        if (to > from) tr.delete(from, to);
      } else if (op.isInsert) {
        final data = op.data;
        var at = tr.mapping.map(cursor.pmPos);
        if (data is String) {
          final marks = _marksFromAttributes(op.attributes);
          var start = 0;
          while (true) {
            final newline = data.indexOf('\n', start);
            final segment = newline == -1
                ? data.substring(start)
                : data.substring(start, newline);
            if (segment.isNotEmpty) {
              tr.insert(at, schema.text(segment, marks));
              at += segment.length;
            }
            if (newline == -1) break;
            tr.split(at);
            at += 2;
            start = newline + 1;
          }
        } else if (data is Map) {
          final embed = _embedToNode(data, op.attributes);
          if (embed != null) tr.insert(at, embed);
        }
      }
    }
    return tr;
  }

  void _applyRetainAttributes(Transaction tr, Map<String, dynamic> attrs,
      int fromPm, int toPm, List<_Textblock> crossedBlocks) {
    final from = tr.mapping.map(fromPm);
    final to = tr.mapping.map(toPm);
    // Inline marks: value != null adds, value == null removes.
    for (final entry in attrs.entries) {
      if (_blockAttributeKeys.contains(entry.key)) continue;
      final markType = _markTypeFor(entry.key);
      if (markType == null) continue;
      if (to <= from) continue;
      if (entry.value == null) {
        tr.removeMark(from, to, markType);
      } else {
        final mark = _markFromAttribute(entry.key, entry.value);
        if (mark != null) tr.addMark(from, to, mark);
      }
    }
    // Block attributes carried by retained `\n`s.
    if (attrs.keys.any(_blockAttributeKeys.contains)) {
      for (final block in crossedBlocks) {
        _applyBlockAttributes(tr, block, attrs);
      }
    }
  }

  void _applyBlockAttributes(
      Transaction tr, _Textblock block, Map<String, dynamic> attrs) {
    final contentStart = tr.mapping.map(block.start);
    final nodePos = contentStart - 1;
    final node = tr.doc.nodeAt(nodePos);
    if (node == null || !node.isTextblock) return;

    if (attrs.containsKey('header')) {
      final level = attrs['header'];
      final heading = schema.nodes['heading'];
      final paragraph = schema.nodes['paragraph'];
      if (level is int && heading != null) {
        tr.setBlockType(contentStart, contentStart, heading,
            _allowedAttrs(heading, {
              'level': level,
              'textAlign': node.attrs['textAlign'],
            }));
      } else if (level == null && paragraph != null) {
        tr.setBlockType(contentStart, contentStart, paragraph,
            _allowedAttrs(paragraph, {
              'textAlign': node.attrs['textAlign'],
            }));
      }
    }
    if (attrs.containsKey('align') && node.attrs.containsKey('textAlign')) {
      tr.setNodeAttribute(tr.mapping.map(block.start) - 1, 'textAlign',
          attrs['align']);
    }
  }

  // =====================================================================
  // ProseMirror → Delta (travessia linear)
  // =====================================================================

  /// Converts a ProseMirror document to a document Delta.
  Delta toDelta(model.PMNode doc) {
    final delta = Delta();
    for (final child in doc.children) {
      _blockToDelta(child, delta, null);
    }
    return delta;
  }

  void _blockToDelta(
      model.PMNode node, Delta delta, Map<String, dynamic>? listAttrs) {
    switch (node.type.name) {
      case 'paragraph':
        _inlineToDelta(node, delta);
        delta.insert('\n', _lineAttributes(node, listAttrs));
        break;
      case 'heading':
        _inlineToDelta(node, delta);
        final attrs = _lineAttributes(node, listAttrs) ?? {};
        attrs['header'] = node.attrs['level'];
        delta.insert('\n', attrs);
        break;
      case 'bulletList':
        for (final item in node.children) {
          _listItemToDelta(item, delta, {'list': 'bullet'});
        }
        break;
      case 'orderedList':
        for (final item in node.children) {
          _listItemToDelta(item, delta, {'list': 'ordered'});
        }
        break;
      case 'horizontalRule':
        delta.insert({'divider': true});
        delta.insert('\n');
        break;
      case 'image':
        delta.insert({'image': node.attrs['src']});
        delta.insert('\n');
        break;
      case 'table':
        // Quill não tem tabelas: emite o texto das células linha a linha.
        for (final row in node.children) {
          for (final cell in row.children) {
            for (final block in cell.children) {
              _blockToDelta(block, delta, null);
            }
          }
        }
        break;
      default:
        if (node.isTextblock) {
          _inlineToDelta(node, delta);
          delta.insert('\n', _lineAttributes(node, listAttrs));
        } else {
          for (final child in node.children) {
            _blockToDelta(child, delta, listAttrs);
          }
        }
    }
  }

  void _listItemToDelta(
      model.PMNode item, Delta delta, Map<String, dynamic> listAttrs) {
    for (final block in item.children) {
      _blockToDelta(block, delta, listAttrs);
    }
  }

  void _inlineToDelta(model.PMNode block, Delta delta) {
    for (final child in block.children) {
      if (child.isText) {
        delta.insert(child.text!, _attributesFromMarks(child.marks));
      } else if (child.type.name == 'image') {
        delta.insert(
            {'image': child.attrs['src']}, _attributesFromMarks(child.marks));
      }
      // hardBreak: sem representação em Quill — perda documentada.
    }
  }

  Map<String, dynamic>? _lineAttributes(
      model.PMNode node, Map<String, dynamic>? listAttrs) {
    final attrs = <String, dynamic>{};
    if (listAttrs != null) attrs.addAll(listAttrs);
    final align = node.attrs['textAlign'];
    if (align != null) attrs['align'] = align;
    return attrs.isEmpty ? null : attrs;
  }

  // =====================================================================
  // Marcas ↔ atributos inline
  // =====================================================================

  static const _blockAttributeKeys = {'header', 'align', 'list'};

  model.MarkType? _markTypeFor(String attributeKey) {
    switch (attributeKey) {
      case 'bold':
        return schema.marks['bold'];
      case 'italic':
        return schema.marks['italic'];
      case 'underline':
        return schema.marks['underline'];
      case 'strike':
        return schema.marks['strike'];
      case 'code':
        return schema.marks['code'];
      case 'link':
        return schema.marks['link'];
      case 'background':
        return schema.marks['highlight'];
      case 'color':
      case 'font':
      case 'size':
        return schema.marks['textStyle'];
    }
    return null;
  }

  model.Mark? _markFromAttribute(String key, dynamic value) {
    switch (key) {
      case 'bold':
      case 'italic':
      case 'underline':
      case 'strike':
      case 'code':
        return schema.marks[key]?.create();
      case 'link':
        return schema.marks['link']?.create({'href': value});
      case 'background':
        return schema.marks['highlight']?.create({'color': value});
      case 'color':
        return schema.marks['textStyle']?.create({'color': value});
      case 'font':
        return schema.marks['textStyle']?.create({'fontFamily': value});
      case 'size':
        return schema.marks['textStyle']?.create({'fontSize': value});
    }
    return null;
  }

  /// Builds the mark list for a run, in a stable order so equal inputs
  /// produce identical (mergeable) text nodes.
  List<model.Mark> _marksFromAttributes(Map<String, dynamic>? attrs) {
    if (attrs == null || attrs.isEmpty) return const [];
    final marks = <model.Mark>[];

    void add(String markName, [Map<String, dynamic>? markAttrs]) {
      final type = schema.marks[markName];
      if (type != null) marks.add(type.create(markAttrs));
    }

    if (attrs['link'] != null) add('link', {'href': attrs['link']});
    if (attrs['bold'] == true) add('bold');
    if (attrs['italic'] == true) add('italic');
    if (attrs['underline'] == true) add('underline');
    if (attrs['strike'] == true) add('strike');
    if (attrs['code'] == true) add('code');
    final textStyle = <String, dynamic>{
      if (attrs['color'] != null) 'color': attrs['color'],
      if (attrs['font'] != null) 'fontFamily': attrs['font'],
      if (attrs['size'] != null) 'fontSize': attrs['size'],
    };
    if (textStyle.isNotEmpty) add('textStyle', textStyle);
    if (attrs['background'] != null) {
      add('highlight', {'color': attrs['background']});
    }
    return marks;
  }

  Map<String, dynamic>? _attributesFromMarks(List<model.Mark> marks) {
    if (marks.isEmpty) return null;
    final attrs = <String, dynamic>{};
    for (final mark in marks) {
      switch (mark.type.name) {
        case 'bold':
        case 'italic':
        case 'underline':
        case 'strike':
        case 'code':
          attrs[mark.type.name] = true;
          break;
        case 'link':
          attrs['link'] = mark.attrs['href'];
          break;
        case 'highlight':
          attrs['background'] = mark.attrs['color'];
          break;
        case 'textStyle':
          if (mark.attrs['color'] != null) attrs['color'] = mark.attrs['color'];
          if (mark.attrs['fontFamily'] != null) {
            attrs['font'] = mark.attrs['fontFamily'];
          }
          if (mark.attrs['fontSize'] != null) {
            attrs['size'] = mark.attrs['fontSize'];
          }
          if (mark.attrs['backgroundColor'] != null) {
            attrs['background'] = mark.attrs['backgroundColor'];
          }
          break;
      }
    }
    return attrs.isEmpty ? null : attrs;
  }

  // =====================================================================
  // Blocos e embeds
  // =====================================================================

  model.PMNode _buildBlock(
      List<model.PMNode> inline, Map<String, dynamic>? attrs) {
    final header = attrs?['header'];
    final align = attrs?['align'];
    if (header is int && schema.nodes.containsKey('heading')) {
      final heading = schema.nodes['heading']!;
      return schema.node(
          'heading',
          _allowedAttrs(heading, {'level': header, 'textAlign': align}),
          inline.isEmpty ? null : inline);
    }
    final paragraph = schema.nodes['paragraph']!;
    return schema.node(
        'paragraph',
        _allowedAttrs(paragraph, {'textAlign': align}),
        inline.isEmpty ? null : inline);
  }

  /// Filters an attribute map down to the keys the node type supports
  /// (schemas without `textAlign`, for example, must not receive it).
  Map<String, dynamic>? _allowedAttrs(
      model.NodeType type, Map<String, dynamic> attrs) {
    final allowed = <String, dynamic>{};
    for (final entry in attrs.entries) {
      if (type.attrs.containsKey(entry.key)) allowed[entry.key] = entry.value;
    }
    return allowed.isEmpty ? null : allowed;
  }

  model.PMNode? _embedToNode(Map data, Map<String, dynamic>? attributes) {
    if (data.containsKey('image')) {
      final image = schema.nodes['image'];
      if (image == null) return null;
      return image.create({'src': data['image']});
    }
    if (data.containsKey('divider')) {
      return schema.nodes['horizontalRule']?.create();
    }
    return null;
  }
}

// =======================================================================
// Cursor Quill → ProseMirror sobre o documento original
// =======================================================================

class _Textblock {
  /// Position of the first content token inside the textblock.
  final int start;
  final int size;

  _Textblock(this.start, this.size);
}

class _QuillCursor {
  final List<_Textblock> _blocks = [];
  int _blockIndex = 0;
  int _offset = 0;

  _QuillCursor(model.PMNode doc) {
    doc.nodesBetween(0, doc.content.size, (node, pos, parent, index) {
      if (node.isTextblock) {
        _blocks.add(_Textblock(pos + 1, node.content.size));
        return false;
      }
      return true;
    });
  }

  /// ProseMirror position equivalent to the current Quill position.
  int get pmPos {
    if (_blocks.isEmpty) return 0;
    if (_blockIndex >= _blocks.length) {
      final last = _blocks.last;
      return last.start + last.size;
    }
    return _blocks[_blockIndex].start + _offset;
  }

  /// Advances [quillLength] characters. Each block boundary (`\n`)
  /// counts as one character. Blocks whose `\n` is consumed are added
  /// to [crossedBlocks] (used for block-attribute retains).
  void advance(int quillLength, {List<_Textblock>? crossedBlocks}) {
    var remaining = quillLength;
    while (remaining > 0 && _blockIndex < _blocks.length) {
      final block = _blocks[_blockIndex];
      final left = block.size - _offset;
      if (remaining <= left) {
        _offset += remaining;
        remaining = 0;
      } else {
        remaining -= left + 1; // +1 consome o \n da linha
        crossedBlocks?.add(block);
        _blockIndex++;
        _offset = 0;
      }
    }
  }
}
