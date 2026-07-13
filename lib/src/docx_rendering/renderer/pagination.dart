/// Post-render pagination pass (approximate dynamic pagination).
///
/// docx-preview (and this port) only break pages on *explicit* breaks
/// (`w:br type="page"`, section changes, `lastRenderedPageBreak`). A document
/// without them therefore renders as a single very tall page, unlike Word which
/// paginates dynamically by measuring layout.
///
/// This pass runs **after** the HTML is in the live DOM, measures it, then
/// redistributes each overflowing page's top-level content across real
/// page-sized `<section>`s — cloning the header/footer onto every page. Tables
/// taller than the space left on a page are split row-by-row and continue on
/// the next page, repeating any `w:tblHeader` rows. It is the same core idea
/// used by the Tiptap pagination extensions in `referencias/` (measure the
/// laid-out geometry, then cut a page on overflow), adapted to a static
/// renderer.
///
/// **Three phases**, deliberately separated because any DOM mutation reflows the
/// page and invalidates every not-yet-taken measurement:
///   1. *Measure* — read all block/row geometry (no mutation).
///   2. *Plan* — pure arithmetic over the captured numbers → page buckets.
///   3. *Build* — mutate the DOM once: create the page sections.
///
/// Long paragraphs are split at a measured line boundary by binary-searching
/// character offsets with `Range.getBoundingClientRect`, then preserving the
/// nested span structure with `Range.extractContents` during the build phase.
library;

import 'package:web/web.dart' as web;

/// Paginates every `section.<className>` found inside [root].
///
/// Safe to call unconditionally: sections that already fit on one page are left
/// untouched, and any measurement error is swallowed so pagination can never
/// break the base rendering.
void paginate(web.Element root, {String className = 'docx'}) {
  final sections = root.querySelectorAll('section.$className');
  // Snapshot first: we mutate the DOM (replace sections) while iterating.
  final list = <web.HTMLElement>[];
  for (var i = 0; i < sections.length; i++) {
    final n = sections.item(i);
    if (n != null) list.add(n as web.HTMLElement);
  }
  for (final section in list) {
    try {
      _paginateSection(section);
    } catch (_) {
      // Never let pagination break rendering.
    }
  }

  // After all sections are split, number every page globally so PAGE/NUMPAGES
  // fields show the real page N of M instead of Word's stale cached value.
  try {
    _numberPages(root, className);
  } catch (_) {}
}

/// Rewrites the text of every PAGE / NUMPAGES field result (marked with
/// `data-docx-field`) to the real page index and total page count.
void _numberPages(web.Element root, String className) {
  final sections = root.querySelectorAll('section.$className');
  final total = sections.length;
  if (total == 0) return;

  for (var i = 0; i < total; i++) {
    final sec = sections.item(i);
    if (sec == null) continue;
    _setFieldText(sec as web.Element, 'PAGE', '${i + 1}');
    _setFieldText(sec, 'NUMPAGES', '$total');
  }
}

void _setFieldText(web.Element section, String field, String value) {
  final els = section.querySelectorAll('[data-docx-field="$field"]');
  for (var j = 0; j < els.length; j++) {
    final el = els.item(j);
    if (el != null) el.textContent = value;
  }
}

void _paginateSection(web.HTMLElement section) {
  // Classify the section's direct children.
  web.HTMLElement? header;
  web.HTMLElement? footer;
  final articles = <web.HTMLElement>[];
  final kids = section.children;
  for (var i = 0; i < kids.length; i++) {
    final el = kids.item(i);
    if (el == null) continue;
    switch (el.tagName.toLowerCase()) {
      case 'header':
        header = el as web.HTMLElement;
        break;
      case 'footer':
        footer = el as web.HTMLElement;
        break;
      case 'article':
        articles.add(el as web.HTMLElement);
        break;
    }
  }
  if (articles.isEmpty) return;

  // Page geometry from the section's own computed style. In docx-preview the
  // section's padding == the page margins, and the header/footer are pulled
  // into the margin area with negative margins (net ~0 flex consumption), so
  // the text area available to the article is simply (min-height - padding) —
  // the space between the top and bottom margins, matching Word.
  final cs = web.window.getComputedStyle(section);
  final sectionRect = section.getBoundingClientRect();
  final minH = _px(cs.getPropertyValue('min-height'));
  final padT = _px(cs.getPropertyValue('padding-top'));
  final padB = _px(cs.getPropertyValue('padding-bottom'));
  if (minH <= 0) return; // ignoreHeight / no fixed page height -> can't paginate
  final avail = minH - padT - padB;
  if (avail <= 0) return;

  // ---- Phase 1: measure (no DOM mutation) --------------------------------
  final measured = <_Block>[];
  for (final a in articles) {
    final ac = a.children;
    for (var i = 0; i < ac.length; i++) {
      final el = ac.item(i);
      if (el == null) continue;
      final node = el as web.HTMLElement;
      final rect = node.getBoundingClientRect();

      List<_Row> rows = const [];
      web.Element? colgroup;
      if (node.tagName.toLowerCase() == 'table') {
        final trs = _tableRows(node);
        if (trs.length > 1) {
          colgroup = node.querySelector(':scope > colgroup');
          rows = [
            for (final r in trs)
              () {
                final rr = r.getBoundingClientRect();
                return _Row(r, rr.top, rr.bottom,
                    r.hasAttribute('data-docx-header'));
              }()
          ];
        }
      }
      measured.add(_Block(node, rect.top, rect.bottom, rows, colgroup));
    }
  }
  if (measured.isEmpty) return;

  // ---- Phase 2: plan (pure arithmetic) -----------------------------------
  final pages = <List<_Placement>>[<_Placement>[]];
  double? pageStart; // viewport-top where the current page's content begins

  void newPage(double startY) {
    pages.add(<_Placement>[]);
    pageStart = startY;
  }

  for (final b in measured) {
    pageStart ??= b.top;

    // Fits wholly on the current page?
    if (b.bottom - pageStart! <= avail) {
      pages.last.add(_BlockPlacement(b.node));
      continue;
    }

    if (b.rows.length > 1) {
      // Split the table across pages.
      final headerRows = <web.Element>[
        for (final r in b.rows)
          if (r.isHeader) r.node,
      ];
      var segment = <web.Element>[];
      var firstPiece = true;

      void flush() {
        if (segment.isEmpty) return;
        pages.last.add(_TablePlacement(
            b.node, b.colgroup, headerRows, segment, firstPiece));
        segment = <web.Element>[];
        firstPiece = false;
      }

      for (final r in b.rows) {
        if (r.bottom - pageStart! > avail) {
          if (segment.isNotEmpty) {
            flush();
            newPage(r.top);
          } else if (pages.last.isNotEmpty) {
            newPage(r.top); // move the table start to a fresh page
          }
          // else: a single row taller than a page on an empty page -> overflow.
        }
        segment.add(r.node);
      }
      flush();
    } else {
      // Try to split a long paragraph across the page boundary (F11).
      final splits = b.node.tagName.toLowerCase() == 'p'
          ? _planParagraphSplit(b.node, pageStart!, avail)
          : null;

      if (splits != null && splits.isNotEmpty) {
        final ctrl = _SplitParagraph(b.node, [for (final s in splits) s.offset]);
        pages.last.add(_ParagraphPiecePlacement(ctrl, 0)); // head, current page
        for (var i = 0; i < splits.length; i++) {
          newPage(splits[i].yTop);
          pages.last.add(_ParagraphPiecePlacement(ctrl, i + 1));
        }
      } else {
        // Block-atomic: push to a fresh page unless it is already alone there.
        if (pages.last.isNotEmpty) {
          newPage(b.top);
        } else {
          pageStart = b.top;
        }
        pages.last.add(_BlockPlacement(b.node));
      }
    }
  }

  if (pages.length <= 1) return; // already fits on a single page

  // ---- Phase 3: build (single DOM mutation) ------------------------------
  final parent = section.parentNode;
  if (parent == null) return;
  final templateArticle = articles.first;
  final frag = web.document.createDocumentFragment();

  for (final placements in pages) {
    final newSection = section.cloneNode(false) as web.HTMLElement; // attrs+style
    // §4.1 (R1): páginas fora da viewport não pagam layout/paint. A geometria
    // conhecida da página vira o placeholder (contain-intrinsic-size), então
    // o scroll não "pula" quando as páginas materializam.
    newSection.style.setProperty('content-visibility', 'auto');
    newSection.style.setProperty('contain-intrinsic-size',
        '${sectionRect.width.round()}px ${sectionRect.height.round()}px');
    if (header != null) newSection.appendChild(header.cloneNode(true));
    final art = templateArticle.cloneNode(false) as web.HTMLElement;
    for (final p in placements) {
      art.appendChild(p.build());
    }
    newSection.appendChild(art);
    if (footer != null) newSection.appendChild(footer.cloneNode(true));
    frag.appendChild(newSection);
  }

  parent.replaceChild(frag, section);
}

/// Direct `<tr>` rows of a table, in order (tolerating an optional `<tbody>`).
List<web.Element> _tableRows(web.Element table) {
  final rows = table.querySelectorAll(':scope > tr, :scope > tbody > tr');
  final list = <web.Element>[];
  for (var i = 0; i < rows.length; i++) {
    final n = rows.item(i);
    if (n != null) list.add(n as web.Element);
  }
  return list;
}

double _px(String value) {
  var v = value.trim();
  if (v.endsWith('px')) v = v.substring(0, v.length - 2);
  return double.tryParse(v) ?? 0.0;
}

/// A measured top-level block and (if it is a splittable table) its rows.
class _Row {
  final web.Element node;
  final double top;
  final double bottom;
  final bool isHeader;
  _Row(this.node, this.top, this.bottom, this.isHeader);
}

class _Block {
  final web.HTMLElement node;
  final double top;
  final double bottom;
  final List<_Row> rows; // empty unless a table with >1 row
  final web.Element? colgroup;
  _Block(this.node, this.top, this.bottom, this.rows, this.colgroup);
}

/// A planned unit of content for one page. `build()` produces the DOM node
/// (moving original nodes; cloning shells/headers for table continuations).
abstract class _Placement {
  web.Node build();
}

class _BlockPlacement extends _Placement {
  final web.Node node;
  _BlockPlacement(this.node);
  @override
  web.Node build() => node; // moved when appended
}

class _TablePlacement extends _Placement {
  final web.Element table;
  final web.Element? colgroup;
  final List<web.Element> headerRows;
  final List<web.Element> rows;
  final bool firstPiece;
  _TablePlacement(
      this.table, this.colgroup, this.headerRows, this.rows, this.firstPiece);

  @override
  web.Node build() {
    final piece = table.cloneNode(false) as web.HTMLElement; // shallow shell
    if (colgroup != null) piece.appendChild(colgroup!.cloneNode(true));
    if (!firstPiece) {
      for (final h in headerRows) {
        piece.appendChild(h.cloneNode(true)); // repeat header on continuation
      }
    }
    for (final r in rows) {
      piece.appendChild(r); // moves the original row node
    }
    return piece;
  }
}

// ---- Paragraph splitting (F11) -----------------------------------------
//
// A paragraph taller than the space left on the page is split at a line
// boundary. The split point is found by binary-searching the text for the
// deepest character offset whose bottom still fits (measured with a Range —
// read-only, so it stays in the "measure" phase), then snapped back to a
// whitespace so words aren't cut. The actual DOM split (Range.extractContents,
// which preserves nested <span> structure) happens later, in the build phase.

class _SplitPoint {
  final int offset; // global char offset where the tail begins
  final double yTop; // viewport-y where the tail begins (original layout)
  _SplitPoint(this.offset, this.yTop);
}

class _TextRun {
  final web.Text node;
  final int start; // global char offset of this run's first char
  final int length;
  _TextRun(this.node, this.start, this.length);
}

class _Loc {
  final web.Node node;
  final int offset;
  _Loc(this.node, this.offset);
}

/// Plans where to break paragraph [p] so each fragment fills a page. Returns
/// null when it can't be usefully split (caller then moves it whole to the next
/// page). Pure measurement — does NOT mutate the DOM.
List<_SplitPoint>? _planParagraphSplit(
    web.HTMLElement p, double pageStartY, double avail) {
  final runs = <_TextRun>[];
  final sb = StringBuffer();
  _collectTextRuns(p, runs, sb);
  final text = sb.toString();
  final n = text.length;
  if (n < 8 || runs.isEmpty) return null; // too short to bother splitting

  final range = web.document.createRange();
  final points = <_SplitPoint>[];
  var lastOffset = 0;
  var curBottom = pageStartY + avail;
  var guard = 0;

  while (guard++ < 2000) {
    if (p.getBoundingClientRect().bottom <= curBottom) break; // remainder fits
    final o = _findSplitOffset(p, runs, text, n, lastOffset, curBottom, range);
    if (o == null || o <= lastOffset) break;
    final yTop = _rangeBottom(p, runs, o, range);
    points.add(_SplitPoint(o, yTop));
    lastOffset = o;
    curBottom = yTop + avail;
  }

  return points.isEmpty ? null : points;
}

int? _findSplitOffset(web.HTMLElement p, List<_TextRun> runs, String text,
    int n, int lo, double curBottom, web.Range range) {
  var low = lo + 1, high = n, best = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final bottom = _rangeBottom(p, runs, mid, range);
    if (bottom <= curBottom) {
      best = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  if (best <= lo || best >= n) return null;
  // Snap back to a whitespace/hyphen boundary so words aren't split.
  var s = best;
  while (s > lo + 1 && !_isBreak(text.codeUnitAt(s - 1))) {
    s--;
    if (best - s > 200) return best; // give up snapping; accept the raw split
  }
  return s > lo ? s : best;
}

bool _isBreak(int cu) =>
    cu == 0x20 || cu == 0x09 || cu == 0x0A || cu == 0x2D; // space tab nl hyphen

double _rangeBottom(
    web.HTMLElement p, List<_TextRun> runs, int offset, web.Range range) {
  final loc = _locate(runs, offset);
  range.setStart(p, 0);
  range.setEnd(loc.node, loc.offset);
  return range.getBoundingClientRect().bottom;
}

_Loc _locate(List<_TextRun> runs, int globalOffset) {
  for (final r in runs) {
    if (globalOffset < r.start + r.length) {
      final local = (globalOffset - r.start).clamp(0, r.length);
      return _Loc(r.node, local);
    }
  }
  final last = runs.last;
  return _Loc(last.node, last.length);
}

void _collectTextRuns(web.Node node, List<_TextRun> out, StringBuffer sb) {
  for (var c = node.firstChild; c != null; c = c.nextSibling) {
    if (c.nodeType == 3) {
      final data = (c as web.CharacterData).data;
      out.add(_TextRun(c as web.Text, sb.length, data.length));
      sb.write(data);
    } else if (c.nodeType == 1) {
      _collectTextRuns(c, out, sb);
    }
  }
}

/// Lazily splits a paragraph into a head (the original node) + tail clones at
/// the planned offsets. Computed on first `piece()` access, i.e. in the build
/// phase, so no measurement is invalidated.
class _SplitParagraph {
  final web.HTMLElement p;
  final List<int> offsets; // ascending
  List<web.Node>? _pieces;
  _SplitParagraph(this.p, this.offsets);

  web.Node piece(int i) => (_pieces ??= _compute())[i];

  List<web.Node> _compute() {
    final tails = <web.Node>[];
    // Extract descending so earlier offsets stay valid as the tail is removed.
    for (var j = offsets.length - 1; j >= 0; j--) {
      tails.insert(0, _extractFrom(p, offsets[j]));
    }
    return [p, ...tails];
  }
}

web.Node _extractFrom(web.HTMLElement p, int globalOffset) {
  final runs = <_TextRun>[];
  final sb = StringBuffer();
  _collectTextRuns(p, runs, sb);
  final loc = _locate(runs, globalOffset);
  final range = web.document.createRange();
  range.setStart(loc.node, loc.offset);
  range.setEnd(p, p.childNodes.length);
  final frag = range.extractContents();
  final tail = p.cloneNode(false) as web.HTMLElement;
  tail.appendChild(frag);
  // A continuation of a list item must not repeat its bullet/number.
  final cls = tail.getAttribute('class');
  if (cls != null && cls.contains('-num-')) {
    tail.setAttribute(
        'class',
        cls
            .split(RegExp(r'\s+'))
            .where((c) => !c.contains('-num-'))
            .join(' '));
  }
  return tail;
}

class _ParagraphPiecePlacement extends _Placement {
  final _SplitParagraph ctrl;
  final int index;
  _ParagraphPiecePlacement(this.ctrl, this.index);
  @override
  web.Node build() => ctrl.piece(index);
}
