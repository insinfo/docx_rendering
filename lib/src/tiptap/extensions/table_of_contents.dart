import 'package:web/web.dart' as web;

import '../../prosemirror/model/from_dom.dart';
import '../../prosemirror/model/index.dart';
import '../../prosemirror/state/index.dart';
import '../core/extension.dart';

/// Container node for a generated table of contents.
///
/// The block holds regular paragraphs (one per heading, plus the title), so
/// pagination, export and editing treat it as ordinary content; the wrapper
/// only marks the region so "Atualizar Sumário" can find and regenerate it.
class TableOfContentsExtension extends NodeExtension {
  const TableOfContentsExtension() : super('tableOfContents');

  @override
  NodeSpec config() => NodeSpec(
        content: 'paragraph+',
        group: 'block',
        defining: true,
        attrs: {
          'maxLevel': AttributeSpec(defaultValue: 3, hasDefault: true),
        },
        parseDOM: [
          TagParseRule(
            tag: 'div[data-docx-toc]',
            getAttrs: (web.HTMLElement dom) => {
              'maxLevel':
                  int.tryParse(dom.getAttribute('data-docx-toc') ?? '') ?? 3,
            },
          ),
        ],
        toDOM: (node) => [
          'div',
          {
            'data-docx-toc': '${node.attrs['maxLevel']}',
            'class': 'tiptap-toc',
          },
          0
        ],
      );
}

/// One collected heading.
class TocEntry {
  final String title;
  final int level;
  final int pos;
  final int? page;

  const TocEntry(this.title, this.level, this.pos, this.page);
}

/// Collects the outline (headings up to [maxLevel]) of [doc], skipping
/// headings inside existing TOC blocks (they only contain paragraphs, so the
/// walk is naturally safe) and empty titles.
List<TocEntry> collectOutline(
  PMNode doc,
  int maxLevel,
  int? Function(int pos)? pageOf,
) {
  final entries = <TocEntry>[];
  doc.descendants((node, pos, parent, index) {
    if (node.type.name != 'heading') return true;
    final level = node.attrs['level'] is int ? node.attrs['level'] as int : 1;
    if (level > maxLevel) return false;
    final title = node.textContent.trim();
    if (title.isEmpty) return false;
    entries.add(TocEntry(title, level, pos, pageOf?.call(pos)));
    return false;
  });
  return entries;
}

/// Builds a `tableOfContents` node for [state]'s document.
///
/// [pageOf] resolves a document position to its rendered page number (null
/// when pagination has not settled); [contentWidth] positions the right tab
/// stop that carries the dotted leader, in CSS px.
PMNode buildTableOfContents(
  EditorState state, {
  int? Function(int pos)? pageOf,
  int maxLevel = 3,
  double contentWidth = 644,
}) {
  final schema = state.schema;
  final paragraph = schema.nodes['paragraph']!;
  final toc = schema.nodes['tableOfContents']!;
  final bold = schema.marks['bold'];

  final children = <PMNode>[
    paragraph.create({
      'lineHeight': null,
    },
        Fragment.from(schema.text(
            'Sumário', bold != null ? [bold.create()] : null))),
  ];
  final entries = collectOutline(state.doc, maxLevel, pageOf);
  for (final entry in entries) {
    final attrs = <String, dynamic>{
      'tabStops': [
        {
          'position': contentWidth,
          'type': 'right',
          'leader': 'dot',
        }
      ],
    };
    if (entry.level > 1) {
      attrs['marginLeft'] = '${(entry.level - 1) * 22}px';
    }
    final text = entry.page != null
        ? '${entry.title}\t${entry.page}'
        : entry.title;
    children.add(paragraph.create(attrs, Fragment.from(schema.text(text))));
  }
  if (entries.isEmpty) {
    children.add(paragraph.create(
        null,
        Fragment.from(schema.text(
            'Nenhum título encontrado. Aplique estilos de título ao documento.'))));
  }
  return toc.create({'maxLevel': maxLevel}, Fragment.fromArray(children));
}

/// Inserts a table of contents at the selection.
Command insertTableOfContentsCommand({
  int? Function(int pos)? pageOf,
  int maxLevel = 3,
  double contentWidth = 644,
}) {
  return (state, [dispatch, view]) {
    if (state.schema.nodes['tableOfContents'] == null) return false;
    if (dispatch == null) return true;
    final node = buildTableOfContents(
      state,
      pageOf: pageOf,
      maxLevel: maxLevel,
      contentWidth: contentWidth,
    );
    final tr = state.tr;
    tr.replaceRangeWith(state.selection.from, state.selection.to, node);
    dispatch(tr.scrollIntoView());
    return true;
  };
}

/// Regenerates the content of every `tableOfContents` block in the document.
/// Returns false when the document has none.
Command updateTableOfContentsCommand({
  int? Function(int pos)? pageOf,
  double contentWidth = 644,
}) {
  return (state, [dispatch, view]) {
    final targets = <(int, PMNode)>[];
    state.doc.descendants((node, pos, parent, index) {
      if (node.type.name == 'tableOfContents') {
        targets.add((pos, node));
        return false;
      }
      return true;
    });
    if (targets.isEmpty) return false;
    if (dispatch == null) return true;
    final tr = state.tr;
    for (final (pos, node) in targets.reversed) {
      final maxLevel =
          node.attrs['maxLevel'] is int ? node.attrs['maxLevel'] as int : 3;
      final fresh = buildTableOfContents(
        state,
        pageOf: pageOf,
        maxLevel: maxLevel,
        contentWidth: contentWidth,
      );
      tr.replaceRangeWith(pos, pos + node.nodeSize, fresh);
    }
    dispatch(tr);
    return true;
  };
}
