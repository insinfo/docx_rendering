// Port of prosemirror-view/src/viewdesc.ts.
//
// View descriptions are data structures that describe the DOM that is used
// to represent the editor's content. They are used for:
//
// - Incremental redrawing when the document changes
// - Figuring out what part of the document a given DOM position corresponds to
// - Wiring in custom implementations of the editing interface for a given node
//
// They form a doubly-linked mutable tree, starting at `view.docView`.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' show max, min;

import 'package:web/web.dart' as web;

import '../model/index.dart';
import '../model/to_dom.dart' show renderSpec;
import '../state/index.dart' show TextSelection;
import 'browser.dart' as browser;
import 'decoration.dart';
import 'dom.dart';
import 'index.dart';

/// A ViewMutationRecord represents a DOM
/// [mutation](https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver)
/// or a selection change that happens within the view. When the change is a
/// selection change, the record will have a `type` property of `"selection"`
/// (which doesn't occur for native mutation records).
///
/// TS models this as `MutationRecord | {type: "selection", target: DOMNode}`;
/// in Dart it is a single class that either wraps a native
/// [web.MutationRecord] or represents a synthetic selection record.
class ViewMutationRecord {
  /// One of `"childList"`, `"characterData"`, `"attributes"` or `"selection"`.
  final String type;
  final web.Node target;
  final String? oldValue;
  final String? attributeName;
  final List<web.Node> addedNodes;
  final List<web.Node> removedNodes;
  final web.Node? previousSibling;
  final web.Node? nextSibling;

  ViewMutationRecord({
    required this.type,
    required this.target,
    this.oldValue,
    this.attributeName,
    this.addedNodes = const [],
    this.removedNodes = const [],
    this.previousSibling,
    this.nextSibling,
  });

  ViewMutationRecord.selection(this.target)
      : type = 'selection',
        oldValue = null,
        attributeName = null,
        addedNodes = const [],
        removedNodes = const [],
        previousSibling = null,
        nextSibling = null;

  factory ViewMutationRecord.fromMutation(web.MutationRecord m) {
    List<web.Node> toList(web.NodeList list) {
      final result = <web.Node>[];
      for (int i = 0; i < list.length; i++) {
        result.add(list.item(i)!);
      }
      return result;
    }

    return ViewMutationRecord(
      type: m.type,
      target: m.target,
      oldValue: m.oldValue,
      attributeName: m.attributeName,
      addedNodes: toList(m.addedNodes),
      removedNodes: toList(m.removedNodes),
      previousSibling: m.previousSibling,
      nextSibling: m.nextSibling,
    );
  }
}

/// By default, document nodes are rendered using the result of the
/// [`toDOM`](#model.NodeSpec.toDOM) method of their spec, and managed entirely
/// by the editor. For some use cases, such as embedded node-specific editing
/// interfaces, you want more control over the behavior of a node's in-editor
/// representation, and need to define a custom node view.
///
/// Objects returned as node views must conform to this interface. (In TS this
/// is an interface with optional methods; here it is an abstract class whose
/// optional members are nullable function-valued getters that default to
/// `null`.)
abstract class NodeView {
  /// The outer DOM node that represents the document node.
  ///
  /// TS types this as `HTMLElement`, but text node views must return a DOM
  /// text node, so `web.Node` is used here.
  web.Node get dom;

  /// The DOM node that should hold the node's content. Only meaningful if the
  /// node view also defines a `dom` property and if its node type is not a
  /// leaf node type. When this is present, ProseMirror will take care of
  /// rendering the node's children into it. When it is not present, the node
  /// view itself is responsible for rendering (or deciding not to render) its
  /// child nodes.
  web.HTMLElement? get contentDOM => null;

  /// When given, this will be called when the view is updating itself. It
  /// will be given a node, an array of active decorations around the node,
  /// and a decoration source for the node's content. It should return true if
  /// it was able to update to that node, and false otherwise.
  bool Function(PMNode node, List<Decoration> decorations,
      DecorationSource innerDecorations)? get update => null;

  /// By default, `update` will only be called when a node of the same node
  /// type appears in this view's position. When you set this to true, it will
  /// be called for any node, making it possible to have a node view that
  /// represents multiple types of nodes.
  bool get multiType => false;

  /// Can be used to override the way the node's selected status (as a node
  /// selection) is displayed.
  void Function()? get selectNode => null;

  /// When defining a `selectNode` method, you should also provide a
  /// `deselectNode` method to remove the effect again.
  void Function()? get deselectNode => null;

  /// This will be called to handle setting the selection inside the node. The
  /// `anchor` and `head` positions are relative to the start of the node.
  /// `root` is a `web.Document` or shadow root.
  void Function(int anchor, int head, dynamic root)? get setSelection => null;

  /// Can be used to prevent the editor view from trying to handle some or all
  /// DOM events that bubble up from the node view.
  bool Function(web.Event event)? get stopEvent => null;

  /// Called when a [ViewMutationRecord] happens within the view. Return false
  /// if the editor should re-read the selection or re-parse the range around
  /// the mutation, true if it can safely be ignored.
  bool Function(ViewMutationRecord mutation)? get ignoreMutation => null;

  /// Called when the node view is removed from the editor or the whole editor
  /// is destroyed.
  void Function()? get destroy => null;
}

/// By default, document marks are rendered using the result of the
/// [`toDOM`](#model.MarkSpec.toDOM) method of their spec, and managed entirely
/// by the editor. For some use cases, you want more control over the behavior
/// of a mark's in-editor representation, and need to define a custom mark
/// view.
///
/// Objects returned as mark views must conform to this interface.
abstract class MarkView {
  /// The outer DOM node that represents the document node.
  web.Node get dom;

  /// The DOM node that should hold the mark's content. When this is not
  /// present, the `dom` property is used as the content DOM.
  web.HTMLElement? get contentDOM => null;

  /// When given, this is called when the view is updating itself. It will be
  /// given a mark (of the same type as the current one). When it returns
  /// true, the existing DOM is kept and reused; when it returns false, the
  /// mark view is rebuilt.
  bool Function(Mark mark)? get update => null;

  /// Called when a [ViewMutationRecord] happens within the view.
  bool Function(ViewMutationRecord mutation)? get ignoreMutation => null;

  /// Called when the mark view is removed from the editor or the whole editor
  /// is destroyed.
  void Function()? get destroy => null;
}

/// Adapter used when a mark is rendered through `renderSpec` rather than a
/// custom mark view (the TS code stores the raw `{dom, contentDOM}` object).
class _RenderedMarkView implements MarkView {
  @override
  final web.Node dom;
  @override
  final web.HTMLElement? contentDOM;

  _RenderedMarkView(this.dom, this.contentDOM);

  @override
  bool Function(Mark mark)? get update => null;
  @override
  bool Function(ViewMutationRecord mutation)? get ignoreMutation => null;
  @override
  void Function()? get destroy => null;
}

/// The result of [ViewDesc.domFromPos] (TS `{node, offset, atom?}`).
class DOMPosition {
  final web.Node node;
  final int offset;
  final int? atom;

  DOMPosition(this.node, this.offset, [this.atom]);
}

/// The result of [ViewDesc.parseRange]
/// (TS `{node, from, to, fromOffset, toOffset}`).
class ParseRangeResult {
  final web.Node node;
  final int from;
  final int to;
  final int fromOffset;
  final int toOffset;

  ParseRangeResult(
      this.node, this.from, this.to, this.fromOffset, this.toOffset);
}

/// The parse rule produced by [ViewDesc.parseRule]. This mirrors the TS
/// `Omit<TagParseRule, "tag">` return type; a separate class is used because
/// the model's `TagParseRule` requires a `tag` and types `skip` as a bool,
/// while view descs need `skip` to optionally be a DOM node.
class ViewParseRule {
  String? node;
  String? mark;
  Map<String, dynamic>? attrs;
  bool? ignore;

  /// Either `true` or a `web.Node` to skip to.
  dynamic skip;
  web.HTMLElement? contentElement;
  Fragment Function(web.Node node, Schema schema)? getContent;

  /// Either a bool or the string `'full'`.
  dynamic preserveWhitespace;

  ViewParseRule({
    this.node,
    this.mark,
    this.attrs,
    this.ignore,
    this.skip,
    this.contentElement,
    this.getContent,
    this.preserveWhitespace,
  });
}

/// Composition info produced by [NodeViewDesc.localCompositionInfo]
/// (TS `{node: Text, pos: number, text: string}`).
class LocalComposition {
  final web.Text node;
  final int pos;
  final String text;

  LocalComposition(this.node, this.pos, this.text);
}

const int NOT_DIRTY = 0, CHILD_DIRTY = 1, CONTENT_DIRTY = 2, NODE_DIRTY = 3;

/// Superclass for the various kinds of descriptions. Defines their basic
/// structure and shared methods.
class ViewDesc {
  ViewDesc? parent;
  List<ViewDesc> children;
  web.Node dom;

  /// This is the node that holds the child views. It may be null for descs
  /// that don't have children.
  final web.HTMLElement? contentDOM;

  int dirty = NOT_DIRTY;

  ViewDesc(this.parent, this.children, this.dom, this.contentDOM) {
    // An expando property on the DOM node provides a link back to its
    // description.
    dom.pmViewDesc = this;
  }

  /// The document node represented by this desc, if any. (TS declares a
  /// `node: Node | null` property on the base class that is only actually
  /// present on [NodeViewDesc].)
  PMNode? get node => null;

  // Used to check whether a given description corresponds to a
  // widget/mark/node.
  bool matchesWidget(Decoration widget) => false;
  bool matchesMark(Mark mark) => false;
  bool matchesNode(PMNode node, List<Decoration> outerDeco,
          DecorationSource innerDeco) =>
      false;
  bool matchesHack(String nodeName) => false;

  /// When parsing in-editor content (in domchange), we allow descriptions to
  /// determine the parse rules that should be used to parse them.
  ViewParseRule? parseRule() => null;

  /// Used by the editor's event handler to ignore events that come from
  /// certain descs.
  bool stopEvent(web.Event event) => false;

  /// The size of the content represented by this desc.
  int get size {
    int size = 0;
    for (int i = 0; i < children.length; i++) {
      size += children[i].size;
    }
    return size;
  }

  /// For block nodes, this represents the space taken up by their start/end
  /// tokens.
  int get border => 0;

  void destroy() {
    parent = null;
    if (dom.pmViewDesc == this) dom.pmViewDesc = null;
    for (int i = 0; i < children.length; i++) {
      children[i].destroy();
    }
  }

  int posBeforeChild(ViewDesc child) {
    int pos = posAtStart;
    for (int i = 0;; i++) {
      final cur = children[i];
      if (cur == child) return pos;
      pos += cur.size;
    }
  }

  int get posBefore => parent!.posBeforeChild(this);

  int get posAtStart =>
      parent != null ? parent!.posBeforeChild(this) + border : 0;

  int get posAfter => posBefore + size;

  int get posAtEnd => posAtStart + size - 2 * border;

  int localPosFromDOM(web.Node dom, int offset, int bias) {
    // If the DOM position is in the content, use the child desc after it to
    // figure out a position.
    if (contentDOM != null &&
        contentDOM!.contains(dom.nodeType == 1 ? dom : dom.parentNode)) {
      if (bias < 0) {
        web.Node? domBefore;
        ViewDesc? desc;
        if (dom == contentDOM) {
          domBefore = offset > 0 ? dom.childNodes.item(offset - 1) : null;
        } else {
          var cur = dom;
          while (cur.parentNode != contentDOM) {
            cur = cur.parentNode!;
          }
          domBefore = cur.previousSibling;
        }
        while (domBefore != null) {
          desc = domBefore.pmViewDesc;
          if (desc != null && desc.parent == this) break;
          desc = null;
          domBefore = domBefore.previousSibling;
        }
        return domBefore != null
            ? posBeforeChild(desc!) + desc.size
            : posAtStart;
      } else {
        web.Node? domAfter;
        ViewDesc? desc;
        if (dom == contentDOM) {
          domAfter = dom.childNodes.item(offset);
        } else {
          var cur = dom;
          while (cur.parentNode != contentDOM) {
            cur = cur.parentNode!;
          }
          domAfter = cur.nextSibling;
        }
        while (domAfter != null) {
          desc = domAfter.pmViewDesc;
          if (desc != null && desc.parent == this) break;
          desc = null;
          domAfter = domAfter.nextSibling;
        }
        return domAfter != null ? posBeforeChild(desc!) : posAtEnd;
      }
    }
    // Otherwise, use various heuristics, falling back on the bias parameter,
    // to determine whether to return the position at the start or at the end
    // of this view desc.
    bool? atEnd;
    if (dom == this.dom && contentDOM != null) {
      atEnd = offset > domIndex(contentDOM!);
    } else if (contentDOM != null &&
        contentDOM != this.dom &&
        this.dom.contains(contentDOM)) {
      atEnd = (dom.compareDocumentPosition(contentDOM!) & 2) != 0;
    } else if (this.dom.firstChild != null) {
      if (offset == 0) {
        for (web.Node search = dom;; search = search.parentNode!) {
          if (search == this.dom) {
            atEnd = false;
            break;
          }
          if (search.previousSibling != null) break;
        }
      }
      if (atEnd == null && offset == dom.childNodes.length) {
        for (web.Node search = dom;; search = search.parentNode!) {
          if (search == this.dom) {
            atEnd = true;
            break;
          }
          if (search.nextSibling != null) break;
        }
      }
    }
    return (atEnd ?? (bias > 0)) ? posAtEnd : posAtStart;
  }

  /// Scan up the dom finding the first desc that is a descendant of this one.
  /// When [onlyNodes] is true, only descs with a document node are returned
  /// (TS models this with overloads returning `NodeViewDesc`).
  ViewDesc? nearestDesc(web.Node dom, [bool onlyNodes = false]) {
    bool first = true;
    for (web.Node? cur = dom; cur != null; cur = cur.parentNode) {
      final desc = getDesc(cur);
      if (desc != null && (!onlyNodes || desc.node != null)) {
        // If dom is outside of this desc's nodeDOM, don't count it.
        final nodeDOM = desc is NodeViewDesc ? desc.nodeDOM : null;
        if (first &&
            nodeDOM != null &&
            !(nodeDOM.nodeType == 1
                ? nodeDOM.contains(dom.nodeType == 1 ? dom : dom.parentNode)
                : nodeDOM == dom)) {
          first = false;
        } else {
          return desc;
        }
      }
    }
    return null;
  }

  ViewDesc? getDesc(web.Node dom) {
    final desc = dom.pmViewDesc;
    for (ViewDesc? cur = desc; cur != null; cur = cur.parent) {
      if (cur == this) return desc;
    }
    return null;
  }

  int posFromDOM(web.Node dom, int offset, int bias) {
    for (web.Node? scan = dom; scan != null; scan = scan.parentNode) {
      final desc = getDesc(scan);
      if (desc != null) return desc.localPosFromDOM(dom, offset, bias);
    }
    return -1;
  }

  /// Find the desc for the node after the given pos, if any. (When a parent
  /// node overrode rendering, there might not be one.)
  ViewDesc? descAt(int pos) {
    int offset = 0;
    for (int i = 0; i < children.length; i++) {
      var child = children[i];
      final end = offset + child.size;
      if (offset == pos && end != offset) {
        while (child.border == 0 && child.children.isNotEmpty) {
          var descended = false;
          for (int j = 0; j < child.children.length; j++) {
            final inner = child.children[j];
            if (inner.size > 0) {
              child = inner;
              descended = true;
              break;
            }
          }
          if (!descended) break;
        }
        return child;
      }
      if (pos < end) return child.descAt(pos - offset - child.border);
      offset = end;
    }
    return null;
  }

  DOMPosition domFromPos(int pos, int side) {
    if (contentDOM == null) return DOMPosition(dom, 0, pos + 1);
    // First find the position in the child array
    int i = 0, offset = 0;
    for (int curPos = 0; i < children.length; i++) {
      final child = children[i];
      final end = curPos + child.size;
      if (end > pos || child is TrailingHackViewDesc) {
        offset = pos - curPos;
        break;
      }
      curPos = end;
    }
    // If this points into the middle of a child, call through
    if (offset != 0) {
      return children[i].domFromPos(offset - children[i].border, side);
    }
    // Go back if there were any zero-length widgets with side >= 0 before
    // this point
    while (i > 0) {
      final prev = children[i - 1];
      if (prev.size == 0 && prev is WidgetViewDesc && prev.side >= 0) {
        i--;
      } else {
        break;
      }
    }
    // Scan towards the first useable node
    if (side <= 0) {
      ViewDesc? prev;
      bool enter = true;
      for (;; i--, enter = false) {
        prev = i > 0 ? children[i - 1] : null;
        if (prev == null || prev.dom.parentNode == contentDOM) break;
      }
      if (prev != null &&
          side != 0 &&
          enter &&
          prev.border == 0 &&
          !prev.domAtom) {
        return prev.domFromPos(prev.size, side);
      }
      return DOMPosition(
          contentDOM!, prev != null ? domIndex(prev.dom) + 1 : 0);
    } else {
      ViewDesc? next;
      bool enter = true;
      for (;; i++, enter = false) {
        next = i < children.length ? children[i] : null;
        if (next == null || next.dom.parentNode == contentDOM) break;
      }
      if (next != null && enter && next.border == 0 && !next.domAtom) {
        return next.domFromPos(0, side);
      }
      return DOMPosition(contentDOM!,
          next != null ? domIndex(next.dom) : contentDOM!.childNodes.length);
    }
  }

  /// Used to find a DOM range in a single parent for a given changed range.
  ParseRangeResult parseRange(int from, int to, [int base = 0]) {
    if (children.isEmpty) {
      return ParseRangeResult(
          contentDOM!, from, to, 0, contentDOM!.childNodes.length);
    }

    int fromOffset = -1, toOffset = -1;
    int offset = base;
    for (int i = 0;; i++) {
      final child = children[i];
      final end = offset + child.size;
      if (fromOffset == -1 && from <= end) {
        final childBase = offset + child.border;
        // FIXME maybe descend mark views to parse a narrower range?
        if (from >= childBase &&
            to <= end - child.border &&
            child.node != null &&
            child.contentDOM != null &&
            contentDOM!.contains(child.contentDOM)) {
          return child.parseRange(from, to, childBase);
        }

        from = offset;
        for (int j = i; j > 0; j--) {
          final prev = children[j - 1];
          if (prev.size != 0 &&
              prev.dom.parentNode == contentDOM &&
              !prev.emptyChildAt(1)) {
            fromOffset = domIndex(prev.dom) + 1;
            break;
          }
          from -= prev.size;
        }
        if (fromOffset == -1) fromOffset = 0;
      }
      if (fromOffset > -1 && (end > to || i == children.length - 1)) {
        to = end;
        for (int j = i + 1; j < children.length; j++) {
          final next = children[j];
          if (next.size != 0 &&
              next.dom.parentNode == contentDOM &&
              !next.emptyChildAt(-1)) {
            toOffset = domIndex(next.dom);
            break;
          }
          to += next.size;
        }
        if (toOffset == -1) toOffset = contentDOM!.childNodes.length;
        break;
      }
      offset = end;
    }
    return ParseRangeResult(contentDOM!, from, to, fromOffset, toOffset);
  }

  bool emptyChildAt(int side) {
    if (border != 0 || contentDOM == null || children.isEmpty) return false;
    final child = children[side < 0 ? 0 : children.length - 1];
    return child.size == 0 || child.emptyChildAt(side);
  }

  web.Node domAfterPos(int pos) {
    final result = domFromPos(pos, 0);
    if (result.node.nodeType != 1 ||
        result.offset == result.node.childNodes.length) {
      throw RangeError('No node after pos $pos');
    }
    return result.node.childNodes.item(result.offset)!;
  }

  /// View descs are responsible for setting any selection that falls entirely
  /// inside of them, so that custom implementations can do custom things with
  /// the selection. Note that this falls apart when a selection starts in
  /// such a node and ends in another, in which case we just use whatever
  /// domFromPos produces as a best effort.
  void setSelection(int anchor, int head, EditorView view,
      [bool force = false]) {
    // If the selection falls entirely in a child, give it to that child
    final from = min(anchor, head), to = max(anchor, head);
    for (int i = 0, offset = 0; i < children.length; i++) {
      final child = children[i];
      final end = offset + child.size;
      if (from > offset && to < end) {
        return child.setSelection(anchor - offset - child.border,
            head - offset - child.border, view, force);
      }
      offset = end;
    }

    var anchorDOM = domFromPos(anchor, anchor != 0 ? -1 : 1);
    var headDOM =
        head == anchor ? anchorDOM : domFromPos(head, head != 0 ? -1 : 1);
    if (!anchorDOM.node.isA<web.Node>() || !headDOM.node.isA<web.Node>()) {
      return;
    }
    final domSel = (view.root as web.Document).getSelection()!;
    final selRange = view.domSelectionRange();

    bool brKludge = false;
    // On Firefox, using Selection.collapse to put the cursor after a BR node
    // for some reason doesn't always work (#1073). On Safari, the cursor
    // sometimes inexplicably visually lags behind its reported position in
    // such situations (#1092).
    if ((browser.gecko || browser.safari) && anchor == head) {
      final node = anchorDOM.node;
      final offset = anchorDOM.offset;
      if (node.nodeType == 3) {
        brKludge = offset != 0 && node.nodeValue![offset - 1] == '\n';
        // Issue #1128
        if (brKludge && offset == node.nodeValue!.length) {
          for (web.Node? scan = node; scan != null; scan = scan.parentNode) {
            final after = scan.nextSibling;
            if (after != null) {
              if (after.nodeName == 'BR') {
                anchorDOM = headDOM =
                    DOMPosition(after.parentNode!, domIndex(after) + 1);
              }
              break;
            }
            final desc = scan.pmViewDesc;
            if (desc != null && desc.node != null && desc.node!.isBlock) break;
          }
        }
      } else {
        final prev = offset > 0 ? node.childNodes.item(offset - 1) : null;
        brKludge = prev != null &&
            (prev.nodeName == 'BR' ||
                (prev.isA<web.HTMLElement>() &&
                    (prev as web.HTMLElement).contentEditable == 'false'));
      }
    }
    // Firefox can act strangely when the selection is in front of an
    // uneditable node. See #1163 and
    // https://bugzilla.mozilla.org/show_bug.cgi?id=1709536
    if (browser.gecko &&
        selRange.focusNode != null &&
        selRange.focusNode != headDOM.node &&
        selRange.focusNode!.nodeType == 1) {
      final after = selRange.focusNode!.childNodes.item(selRange.focusOffset);
      if (after != null &&
          after.isA<web.HTMLElement>() &&
          (after as web.HTMLElement).contentEditable == 'false') {
        force = true;
      }
    }

    if (!(force || (brKludge && browser.safari)) &&
        isEquivalentPosition(anchorDOM.node, anchorDOM.offset,
            selRange.anchorNode, selRange.anchorOffset) &&
        isEquivalentPosition(headDOM.node, headDOM.offset, selRange.focusNode,
            selRange.focusOffset)) {
      return;
    }

    // Selection.extend can be used to create an 'inverted' selection (one
    // where the focus is before the anchor). (TS also feature-detects
    // `domSel.extend` for old browsers; it is always available now.)
    bool domSelExtended = false;
    if (!(brKludge && browser.gecko)) {
      domSel.collapse(anchorDOM.node, anchorDOM.offset);
      try {
        if (anchor != head) domSel.extend(headDOM.node, headDOM.offset);
        domSelExtended = true;
      } catch (_) {
        // In some cases with Chrome the selection is empty after calling
        // collapse, even when it should be valid. This appears to be a bug,
        // but it is difficult to isolate. If this happens fall back to the
        // old path without using extend.
        // Similarly, this could crash on Safari if the editor is hidden, and
        // there was no selection.
      }
    }
    if (!domSelExtended) {
      if (anchor > head) {
        final tmp = anchorDOM;
        anchorDOM = headDOM;
        headDOM = tmp;
      }
      final range = web.document.createRange();
      range.setEnd(headDOM.node, headDOM.offset);
      range.setStart(anchorDOM.node, anchorDOM.offset);
      domSel.removeAllRanges();
      domSel.addRange(range);
    }
  }

  bool ignoreMutation(ViewMutationRecord mutation) {
    return contentDOM == null && mutation.type != 'selection';
  }

  bool get contentLost =>
      contentDOM != null && contentDOM != dom && !dom.contains(contentDOM);

  /// Remove a subtree of the element tree that has been touched by a DOM
  /// change, so that the next update will redraw it.
  void markDirty(int from, int to) {
    int offset = 0;
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      final end = offset + child.size;
      if (offset == end
          ? from <= end && to >= offset
          : from < end && to > offset) {
        final startInside = offset + child.border,
            endInside = end - child.border;
        if (from >= startInside && to <= endInside) {
          dirty = from == offset || to == end ? CONTENT_DIRTY : CHILD_DIRTY;
          if (from == startInside &&
              to == endInside &&
              (child.contentLost || child.dom.parentNode != contentDOM)) {
            child.dirty = NODE_DIRTY;
          } else {
            child.markDirty(from - startInside, to - startInside);
          }
          return;
        } else {
          child.dirty = child.dom == child.contentDOM &&
                  child.dom.parentNode == contentDOM &&
                  child.children.isEmpty
              ? CONTENT_DIRTY
              : NODE_DIRTY;
        }
      }
      offset = end;
    }
    dirty = CONTENT_DIRTY;
  }

  void markParentsDirty() {
    int level = 1;
    for (var node = parent; node != null; node = node.parent, level++) {
      final dirty = level == 1 ? CONTENT_DIRTY : CHILD_DIRTY;
      if (node.dirty < dirty) node.dirty = dirty;
    }
  }

  bool get domAtom => false;

  bool get ignoreForCoords => false;

  bool get ignoreForSelection => false;

  bool isText(String text) => false;
}

/// A widget desc represents a widget decoration, which is a DOM node drawn
/// between the document nodes.
class WidgetViewDesc extends ViewDesc {
  final Decoration widget;

  WidgetViewDesc._(ViewDesc? parent, this.widget, web.Node dom)
      : super(parent, [], dom, null);

  factory WidgetViewDesc(
      ViewDesc parent, Decoration widget, EditorView view, int pos) {
    WidgetViewDesc? self;
    final rawToDOM = (widget.type as WidgetType).toDOM;
    web.Node dom;
    if (rawToDOM is WidgetConstructorFn) {
      dom = rawToDOM(view, () {
        if (self == null) return pos;
        if (self.parent != null) return self.parent!.posBeforeChild(self);
        return null;
      });
    } else if (rawToDOM is Function) {
      int? getPos() {
        if (self == null) return pos;
        if (self.parent != null) return self.parent!.posBeforeChild(self);
        return null;
      }

      dom = (rawToDOM as dynamic)(view, getPos) as web.Node;
    } else {
      dom = rawToDOM as web.Node;
    }
    if (widget.type.spec['raw'] != true) {
      if (dom.nodeType != 1) {
        final wrap = web.document.createElement('span');
        wrap.appendChild(dom);
        dom = wrap;
      }
      (dom as web.HTMLElement).contentEditable = 'false';
      dom.classList.add('ProseMirror-widget');
    }
    final desc = WidgetViewDesc._(parent, widget, dom);
    self = desc;
    return desc;
  }

  @override
  bool matchesWidget(Decoration widget) {
    return dirty == NOT_DIRTY && widget.type.eq(this.widget.type);
  }

  @override
  ViewParseRule parseRule() => ViewParseRule(ignore: true);

  @override
  bool stopEvent(web.Event event) {
    final stop = widget.spec['stopEvent'];
    return stop != null ? stop(event) == true : false;
  }

  @override
  bool ignoreMutation(ViewMutationRecord mutation) {
    return mutation.type != 'selection' ||
        widget.spec['ignoreSelection'] == true;
  }

  @override
  void destroy() {
    widget.type.destroy(dom);
    super.destroy();
  }

  @override
  bool get domAtom => true;

  @override
  bool get ignoreForSelection => widget.type.spec['relaxedSide'] == true;

  int get side => (widget.type as WidgetType).side;
}

class CompositionViewDesc extends ViewDesc {
  final web.Text textDOM;
  final String text;

  CompositionViewDesc(ViewDesc parent, web.Node dom, this.textDOM, this.text)
      : super(parent, [], dom, null);

  @override
  int get size => text.length;

  @override
  int localPosFromDOM(web.Node dom, int offset, int bias) {
    if (dom != textDOM) return posAtStart + (offset != 0 ? size : 0);
    return posAtStart + offset;
  }

  @override
  DOMPosition domFromPos(int pos, int side) {
    return DOMPosition(textDOM, pos);
  }

  @override
  bool ignoreMutation(ViewMutationRecord mut) {
    return mut.type == 'characterData' && mut.target.nodeValue == mut.oldValue;
  }
}

/// A mark desc represents a mark. May have multiple children, depending on
/// how the mark is split. Note that marks are drawn using a fixed nesting
/// order, for simplicity and predictability, so in some cases they will be
/// split more often than would appear necessary.
class MarkViewDesc extends ViewDesc {
  Mark mark;
  final MarkView spec;

  MarkViewDesc(ViewDesc parent, this.mark, web.Node dom,
      web.HTMLElement contentDOM, this.spec)
      : super(parent, [], dom, contentDOM);

  static MarkViewDesc create(
      ViewDesc parent, Mark mark, bool inline, EditorView view) {
    final custom = view.nodeViews[mark.type.name];
    MarkView? spec = custom != null
        ? (custom as dynamic)(mark, view, inline) as MarkView?
        : null;
    if (spec == null) {
      final rendered = renderSpec(
          web.document, mark.type.spec.toDOM!(mark, inline), null, mark.attrs);
      spec = _RenderedMarkView(
          rendered['dom']!, rendered['contentDOM'] as web.HTMLElement?);
    }
    return MarkViewDesc(parent, mark, spec.dom,
        (spec.contentDOM ?? spec.dom) as web.HTMLElement, spec);
  }

  @override
  ViewParseRule? parseRule() {
    if ((dirty & NODE_DIRTY) != 0 || mark.type.spec.reparseInView == true) {
      return null;
    }
    return ViewParseRule(
        mark: mark.type.name, attrs: mark.attrs, contentElement: contentDOM);
  }

  @override
  bool matchesMark(Mark mark) => dirty != NODE_DIRTY && this.mark.eq(mark);

  @override
  void markDirty(int from, int to) {
    super.markDirty(from, to);
    // Move dirty info to nearest node view
    if (dirty != NOT_DIRTY) {
      var parent = this.parent!;
      while (parent.node == null) {
        parent = parent.parent!;
      }
      if (parent.dirty < dirty) parent.dirty = dirty;
      dirty = NOT_DIRTY;
    }
  }

  MarkViewDesc slice(int from, int to, EditorView view) {
    final copy = MarkViewDesc.create(parent!, mark, true, view);
    var nodes = children;
    final size = this.size;
    if (to < size) nodes = replaceNodes(nodes, to, size, view);
    if (from > 0) nodes = replaceNodes(nodes, 0, from, view);
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].parent = copy;
    }
    copy.children = nodes;
    return copy;
  }

  @override
  bool ignoreMutation(ViewMutationRecord mutation) {
    return spec.ignoreMutation != null
        ? spec.ignoreMutation!(mutation)
        : super.ignoreMutation(mutation);
  }

  @override
  void destroy() {
    if (spec.destroy != null) spec.destroy!();
    super.destroy();
  }
}

/// Node view descs are the main, most common type of view desc, and
/// correspond to an actual node in the document. Unlike mark descs, they
/// populate their child array themselves.
class NodeViewDesc extends ViewDesc {
  @override
  PMNode node;
  List<Decoration> outerDeco;
  DecorationSource innerDeco;
  final web.Node nodeDOM;

  NodeViewDesc(ViewDesc? parent, this.node, this.outerDeco, this.innerDeco,
      web.Node dom, web.HTMLElement? contentDOM, this.nodeDOM)
      : super(parent, [], dom, contentDOM);

  /// By default, a node is rendered using the `toDOM` method from the node
  /// type spec. But client code can use the `nodeViews` spec to supply a
  /// custom node view, which can influence various aspects of the way the
  /// node works.
  ///
  /// (Using subclassing for this was intentionally decided against, since
  /// it'd require exposing a whole slew of finicky implementation details to
  /// the user code that they probably will never need.)
  static NodeViewDesc create(
      ViewDesc? parent,
      PMNode node,
      List<Decoration> outerDeco,
      DecorationSource innerDeco,
      EditorView view,
      int pos) {
    final custom = view.nodeViews[node.type.name];
    ViewDesc? descObj;
    NodeView? spec;
    if (custom != null) {
      // (getPos is a function that allows the custom view to find its own
      // position)
      int? getPos() {
        if (descObj == null) return pos;
        if (descObj.parent != null) {
          return descObj.parent!.posBeforeChild(descObj);
        }
        return null;
      }

      spec = (custom as dynamic)(node, view, getPos, outerDeco, innerDeco)
          as NodeView?;
    }

    web.Node? dom = spec?.dom;
    web.HTMLElement? contentDOM = spec?.contentDOM;
    if (node.isText) {
      if (dom == null) {
        dom = web.document.createTextNode(node.text!);
      } else if (dom.nodeType != 3) {
        throw RangeError('Text must be rendered as a DOM text node');
      }
    } else if (dom == null) {
      final rendered = renderSpec(
          web.document, node.type.spec.toDOM!(node), null, node.attrs);
      dom = rendered['dom'];
      contentDOM = rendered['contentDOM'] as web.HTMLElement?;
    }
    if (contentDOM == null &&
        !node.isText &&
        !(dom as web.Node).isA<web.HTMLBRElement>()) {
      // Chrome gets confused by <br contenteditable=false>
      if (dom.isA<web.HTMLElement>()) {
        final elt = dom as web.HTMLElement;
        if (!elt.hasAttribute('contenteditable')) elt.contentEditable = 'false';
        if (node.type.spec.draggable == true) elt.draggable = true;
      }
    }

    final nodeDOM = dom!;
    dom = applyOuterDeco(dom, outerDeco, node);

    if (spec != null) {
      final result = CustomNodeViewDesc(
          parent, node, outerDeco, innerDeco, dom, contentDOM, nodeDOM, spec);
      descObj = result;
      return result;
    } else if (node.isText) {
      return TextViewDesc(parent, node, outerDeco, innerDeco, dom, nodeDOM);
    } else {
      return NodeViewDesc(
          parent, node, outerDeco, innerDeco, dom, contentDOM, nodeDOM);
    }
  }

  @override
  ViewParseRule? parseRule() {
    // Experimental kludge to allow opt-in re-parsing of nodes
    if (node.type.spec.reparseInView == true) return null;
    // FIXME the assumption that this can always return the current attrs
    // means that if the user somehow manages to change the attrs in the dom,
    // that won't be picked up. Not entirely sure whether this is a problem
    final rule = ViewParseRule(node: node.type.name, attrs: node.attrs);
    if (node.type.whitespace == 'pre') rule.preserveWhitespace = 'full';
    if (contentDOM == null) {
      rule.getContent = (dom, schema) => node.content;
    } else if (!contentLost) {
      rule.contentElement = contentDOM;
    } else {
      // Chrome likes to randomly recreate parent nodes when backspacing
      // things. When that happens, this tries to find the new parent.
      for (int i = children.length - 1; i >= 0; i--) {
        final child = children[i];
        if (dom.contains(child.dom.parentNode)) {
          rule.contentElement = child.dom.parentNode as web.HTMLElement?;
          break;
        }
      }
      if (rule.contentElement == null) {
        rule.getContent = (dom, schema) => Fragment.empty;
      }
    }
    return rule;
  }

  @override
  bool matchesNode(
      PMNode node, List<Decoration> outerDeco, DecorationSource innerDeco) {
    return dirty == NOT_DIRTY &&
        node.eq(this.node) &&
        sameOuterDeco(outerDeco, this.outerDeco) &&
        innerDeco.eq(this.innerDeco);
  }

  @override
  int get size => node.nodeSize;

  @override
  int get border => node.isLeaf ? 0 : 1;

  /// Syncs `this.children` to match `this.node.content` and the local
  /// decorations, possibly introducing nesting for marks. Then, in a separate
  /// step, syncs the DOM inside `this.contentDOM` to `this.children`.
  void updateChildren(EditorView view, int pos) {
    final inline = node.inlineContent;
    int off = pos;
    final composition = view.composing ? localCompositionInfo(view, pos) : null;
    final localComposition =
        composition != null && composition.pos > -1 ? composition : null;
    final compositionInChild = composition != null && composition.pos < 0;
    final updater = ViewTreeUpdater(this, localComposition?.node, view);
    iterDeco(node, innerDeco, (widget, i, insideNode) {
      final widgetMarks = widget.spec['marks'];
      if (widgetMarks != null) {
        updater.syncToMarks(
            (widgetMarks as List).cast<Mark>(), inline, view, i);
      } else if ((widget.type as WidgetType).side >= 0 && !insideNode) {
        updater.syncToMarks(
            i == node.childCount ? Mark.none : node.child(i).marks,
            inline,
            view,
            i);
      }
      // If the next node is a desc matching this widget, reuse it, otherwise
      // insert the widget as a new view desc.
      updater.placeWidget(widget, view, off);
    }, (child, outerDeco, innerDeco, i) {
      // Make sure the wrapping mark descs match the node's marks.
      updater.syncToMarks(child.marks, inline, view, i);
      // Try several strategies for drawing this node
      int compIndex = -1;
      if (updater.findNodeMatch(child, outerDeco, innerDeco, i)) {
        // Found precise match with existing node view
      } else if (compositionInChild &&
          view.state.selection.from > off &&
          view.state.selection.to < off + child.nodeSize &&
          (compIndex = updater.findIndexWithChild(composition.node)) > -1 &&
          updater.updateNodeAt(child, outerDeco, innerDeco, compIndex, view)) {
        // Updated the specific node that holds the composition
      } else if (updater.updateNextNode(
          child, outerDeco, innerDeco, view, i, off)) {
        // Could update an existing node to reflect this node
      } else {
        // Add it as a new view
        updater.addNode(child, outerDeco, innerDeco, view, off);
      }
      off += child.nodeSize;
    });
    // Drop all remaining descs after the current position.
    updater.syncToMarks(const [], inline, view, 0);
    if (node.isTextblock) updater.addTextblockHacks();
    updater.destroyRest();

    // Sync the DOM if anything changed
    if (updater.changed || dirty == CONTENT_DIRTY) {
      // May have to protect focused DOM from being changed if a composition
      // is active
      if (localComposition != null) {
        protectLocalComposition(view, localComposition);
      }
      renderDescs(contentDOM!, children, view);
      if (browser.ios) iosHacks(dom as web.HTMLElement);
    }
  }

  LocalComposition? localCompositionInfo(EditorView view, int pos) {
    // Only do something if both the selection and a focused text node are
    // inside of this node
    final sel = view.state.selection;
    final int from = sel.from, to = sel.to;
    if (sel is! TextSelection || from < pos || to > pos + node.content.size) {
      return null;
    }
    final web.Text? textNode = view.input.compositionNode;
    if (textNode == null || !dom.contains(textNode.parentNode)) return null;

    if (node.inlineContent) {
      // Find the text in the focused node in the node, stop if it's not there
      // (may have been modified through other means, in which case it should
      // be overwritten)
      final text = textNode.nodeValue!;
      final textPos =
          findTextInFragment(node.content, text, from - pos, to - pos);
      return textPos < 0 ? null : LocalComposition(textNode, textPos, text);
    } else {
      return LocalComposition(textNode, -1, '');
    }
  }

  void protectLocalComposition(EditorView view, LocalComposition composition) {
    // The node is already part of a local view desc, leave it there
    if (getDesc(composition.node) != null) return;

    // Create a composition view for the orphaned nodes
    web.Node topNode = composition.node;
    for (;; topNode = topNode.parentNode!) {
      if (topNode.parentNode == contentDOM) break;
      while (topNode.previousSibling != null) {
        topNode.parentNode!.removeChild(topNode.previousSibling!);
      }
      while (topNode.nextSibling != null) {
        topNode.parentNode!.removeChild(topNode.nextSibling!);
      }
      if (topNode.pmViewDesc != null) topNode.pmViewDesc = null;
    }
    final desc =
        CompositionViewDesc(this, topNode, composition.node, composition.text);
    view.input.compositionNodes.add(desc);

    // Patch up this.children to contain the composition view
    children = replaceNodes(children, composition.pos,
        composition.pos + composition.text.length, view, desc);
  }

  /// If this desc must be updated to match the given node decoration, do so
  /// and return true.
  bool update(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, EditorView view) {
    if (dirty == NODE_DIRTY || !node.sameMarkup(this.node)) return false;
    updateInner(node, outerDeco, innerDeco, view);
    return true;
  }

  void updateInner(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, EditorView view) {
    updateOuterDeco(outerDeco);
    this.node = node;
    this.innerDeco = innerDeco;
    if (contentDOM != null) updateChildren(view, posAtStart);
    dirty = NOT_DIRTY;
  }

  void updateOuterDeco(List<Decoration> outerDeco) {
    if (sameOuterDeco(outerDeco, this.outerDeco)) return;
    final needsWrap = nodeDOM.nodeType != 1;
    final oldDOM = dom;
    dom = patchOuterDeco(
        dom,
        nodeDOM,
        computeOuterDeco(this.outerDeco, node, needsWrap),
        computeOuterDeco(outerDeco, node, needsWrap));
    if (dom != oldDOM) {
      oldDOM.pmViewDesc = null;
      dom.pmViewDesc = this;
    }
    this.outerDeco = outerDeco;
  }

  /// Mark this node as being the selected node.
  void selectNode() {
    if (nodeDOM.nodeType == 1) {
      final elt = nodeDOM as web.HTMLElement;
      elt.classList.add('ProseMirror-selectednode');
      if (contentDOM != null || node.type.spec.draggable != true) {
        elt.draggable = true;
      }
    }
  }

  /// Remove selected node marking from this node.
  void deselectNode() {
    if (nodeDOM.nodeType == 1) {
      final elt = nodeDOM as web.HTMLElement;
      elt.classList.remove('ProseMirror-selectednode');
      if (contentDOM != null || node.type.spec.draggable != true) {
        elt.removeAttribute('draggable');
      }
    }
  }

  @override
  bool get domAtom => node.isAtom;
}

/// Create a view desc for the top-level document node, to be exported and
/// used by the view class.
NodeViewDesc docViewDesc(PMNode doc, List<Decoration> outerDeco,
    DecorationSource innerDeco, web.HTMLElement dom, EditorView view) {
  applyOuterDeco(dom, outerDeco, doc);
  final docView = NodeViewDesc(null, doc, outerDeco, innerDeco, dom, dom, dom);
  if (docView.contentDOM != null) docView.updateChildren(view, 0);
  return docView;
}

class TextViewDesc extends NodeViewDesc {
  TextViewDesc(ViewDesc? parent, PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, web.Node dom, web.Node nodeDOM)
      : super(parent, node, outerDeco, innerDeco, dom, null, nodeDOM);

  @override
  ViewParseRule parseRule() {
    web.Node? skip = nodeDOM.parentNode;
    while (skip != null && skip != dom && !skip.pmIsDeco) {
      skip = skip.parentNode;
    }
    return ViewParseRule(skip: skip ?? true);
  }

  @override
  bool update(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, EditorView view) {
    if (dirty == NODE_DIRTY ||
        (dirty != NOT_DIRTY && !inParent()) ||
        !node.sameMarkup(this.node)) {
      return false;
    }
    updateOuterDeco(outerDeco);
    if ((dirty != NOT_DIRTY || node.text != this.node.text) &&
        node.text != nodeDOM.nodeValue) {
      nodeDOM.nodeValue = node.text!;
      if (view.trackWrites == nodeDOM) view.trackWrites = null;
    }
    this.node = node;
    dirty = NOT_DIRTY;
    return true;
  }

  bool inParent() {
    final parentDOM = parent!.contentDOM;
    for (web.Node? n = nodeDOM; n != null; n = n.parentNode) {
      if (n == parentDOM) return true;
    }
    return false;
  }

  @override
  DOMPosition domFromPos(int pos, int side) {
    return DOMPosition(nodeDOM, pos);
  }

  @override
  int localPosFromDOM(web.Node dom, int offset, int bias) {
    if (dom == nodeDOM) return posAtStart + min(offset, node.text!.length);
    return super.localPosFromDOM(dom, offset, bias);
  }

  @override
  bool ignoreMutation(ViewMutationRecord mutation) {
    return mutation.type != 'characterData' && mutation.type != 'selection';
  }

  TextViewDesc slice(int from, int to, [EditorView? view]) {
    final node = this.node.cut(from, to);
    final dom = web.document.createTextNode(node.text!);
    return TextViewDesc(parent, node, outerDeco, innerDeco, dom, dom);
  }

  @override
  void markDirty(int from, int to) {
    super.markDirty(from, to);
    if (dom != nodeDOM && (from == 0 || to == nodeDOM.nodeValue!.length)) {
      dirty = NODE_DIRTY;
    }
  }

  @override
  bool get domAtom => false;

  @override
  bool isText(String text) => node.text == text;
}

/// A dummy desc used to tag trailing BR or IMG nodes created to work around
/// contentEditable terribleness.
class TrailingHackViewDesc extends ViewDesc {
  TrailingHackViewDesc(
      super.parent, super.children, super.dom, super.contentDOM);

  @override
  ViewParseRule parseRule() => ViewParseRule(ignore: true);

  @override
  bool matchesHack(String nodeName) =>
      dirty == NOT_DIRTY && dom.nodeName == nodeName;

  @override
  bool get domAtom => true;

  @override
  bool get ignoreForCoords => dom.nodeName == 'IMG';
}

/// A separate subclass is used for customized node views, so that the extra
/// checks only have to be made for nodes that are actually customized.
class CustomNodeViewDesc extends NodeViewDesc {
  final NodeView spec;

  CustomNodeViewDesc(
      ViewDesc? parent,
      PMNode node,
      List<Decoration> outerDeco,
      DecorationSource innerDeco,
      web.Node dom,
      web.HTMLElement? contentDOM,
      web.Node nodeDOM,
      this.spec)
      : super(parent, node, outerDeco, innerDeco, dom, contentDOM, nodeDOM);

  /// A custom `update` method gets to decide whether the update goes through.
  /// If it does, and there's a `contentDOM` node, our logic updates the
  /// children.
  @override
  bool update(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, EditorView view) {
    if (dirty == NODE_DIRTY) return false;
    if (spec.update != null &&
        (this.node.type == node.type || spec.multiType)) {
      final result = spec.update!(node, outerDeco, innerDeco);
      if (result) updateInner(node, outerDeco, innerDeco, view);
      return result;
    } else if (contentDOM == null && !node.isLeaf) {
      return false;
    } else {
      return super.update(node, outerDeco, innerDeco, view);
    }
  }

  @override
  void selectNode() {
    spec.selectNode != null ? spec.selectNode!() : super.selectNode();
  }

  @override
  void deselectNode() {
    spec.deselectNode != null ? spec.deselectNode!() : super.deselectNode();
  }

  @override
  void setSelection(int anchor, int head, EditorView view,
      [bool force = false]) {
    spec.setSelection != null
        ? spec.setSelection!(anchor, head, view.root)
        : super.setSelection(anchor, head, view, force);
  }

  @override
  void destroy() {
    if (spec.destroy != null) spec.destroy!();
    super.destroy();
  }

  @override
  bool stopEvent(web.Event event) {
    return spec.stopEvent != null ? spec.stopEvent!(event) : false;
  }

  @override
  bool ignoreMutation(ViewMutationRecord mutation) {
    return spec.ignoreMutation != null
        ? spec.ignoreMutation!(mutation)
        : super.ignoreMutation(mutation);
  }
}

/// Sync the content of the given DOM node with the nodes associated with the
/// given array of view descs, recursing into mark descs because this should
/// sync the subtree for a whole node at a time.
void renderDescs(
    web.HTMLElement parentDOM, List<ViewDesc> descs, EditorView view) {
  web.Node? dom = parentDOM.firstChild;
  bool written = false;
  for (int i = 0; i < descs.length; i++) {
    final desc = descs[i];
    final childDOM = desc.dom;
    if (childDOM.parentNode == parentDOM) {
      while (childDOM != dom) {
        dom = rm(dom!);
        written = true;
      }
      dom = dom!.nextSibling;
    } else {
      written = true;
      parentDOM.insertBefore(childDOM, dom);
    }
    if (desc is MarkViewDesc) {
      final pos = dom != null ? dom.previousSibling : parentDOM.lastChild;
      renderDescs(desc.contentDOM!, desc.children, view);
      dom = pos != null ? pos.nextSibling : parentDOM.firstChild;
    }
  }
  while (dom != null) {
    dom = rm(dom);
    written = true;
  }
  if (written && view.trackWrites == parentDOM) view.trackWrites = null;
}

/// One level of wrapping produced by outer (node) decorations. The TS code
/// uses a prototype-less object whose properties are the attributes plus an
/// optional `nodeName`; here the attributes live in [attrs] and the node name
/// is a separate field.
class OuterDecoLevel {
  final String? nodeName;
  final Map<String, String> attrs = {};

  OuterDecoLevel([this.nodeName]);
}

final List<OuterDecoLevel> _noDeco = [OuterDecoLevel()];

List<OuterDecoLevel> computeOuterDeco(
    List<Decoration> outerDeco, PMNode node, bool needsWrap) {
  if (outerDeco.isEmpty) return _noDeco;

  var top = needsWrap ? _noDeco[0] : OuterDecoLevel();
  final result = [top];

  for (int i = 0; i < outerDeco.length; i++) {
    final type = outerDeco[i].type;
    final DecorationAttrs? attrs = type is InlineType
        ? type.attrs
        : type is NodeTypeDecoration
            ? type.attrs
            : null;
    if (attrs == null) continue;
    if (attrs['nodeName'] != null) {
      result.add(top = OuterDecoLevel(attrs['nodeName'] as String));
    }

    for (final name in attrs.keys) {
      final val = attrs[name];
      if (val == null) continue;
      if (needsWrap && result.length == 1) {
        result.add(top = OuterDecoLevel(node.isInline ? 'span' : 'div'));
      }
      final strVal = val is String ? val : val.toString();
      if (name == 'class') {
        top.attrs['class'] = top.attrs['class'] != null
            ? '${top.attrs['class']} $strVal'
            : strVal;
      } else if (name == 'style') {
        top.attrs['style'] = top.attrs['style'] != null
            ? '${top.attrs['style']};$strVal'
            : strVal;
      } else if (name != 'nodeName') {
        top.attrs[name] = strVal;
      }
    }
  }

  return result;
}

web.Node patchOuterDeco(web.Node outerDOM, web.Node nodeDOM,
    List<OuterDecoLevel> prevComputed, List<OuterDecoLevel> curComputed) {
  // Shortcut for trivial case
  if (identical(prevComputed, _noDeco) && identical(curComputed, _noDeco)) {
    return nodeDOM;
  }

  web.Node curDOM = nodeDOM;
  for (int i = 0; i < curComputed.length; i++) {
    final deco = curComputed[i];
    OuterDecoLevel? prev = i < prevComputed.length ? prevComputed[i] : null;
    if (i != 0) {
      web.Node? parent;
      if (prev != null &&
          prev.nodeName == deco.nodeName &&
          curDOM != outerDOM &&
          (parent = curDOM.parentNode) != null &&
          parent!.nodeName.toLowerCase() == deco.nodeName) {
        curDOM = parent;
      } else {
        final newParent = web.document.createElement(deco.nodeName!);
        newParent.pmIsDeco = true;
        newParent.appendChild(curDOM);
        prev = _noDeco[0];
        curDOM = newParent;
      }
    }
    patchAttributes(curDOM as web.HTMLElement, prev ?? _noDeco[0], deco);
  }
  return curDOM;
}

final RegExp _stylePropRegExp = RegExp(
    '\\s*([\\w\\-\\xa1-\\uffff]+)\\s*:(?:"(?:\\\\.|[^"])*"|\'(?:\\\\.|[^\'])*\'|\\(.*?\\)|[^;])*');

void patchAttributes(
    web.HTMLElement dom, OuterDecoLevel prev, OuterDecoLevel cur) {
  for (final name in prev.attrs.keys) {
    if (name != 'class' &&
        name != 'style' &&
        name != 'nodeName' &&
        !cur.attrs.containsKey(name)) {
      dom.removeAttribute(name);
    }
  }
  for (final name in cur.attrs.keys) {
    if (name != 'class' &&
        name != 'style' &&
        name != 'nodeName' &&
        cur.attrs[name] != prev.attrs[name]) {
      dom.setAttribute(name, cur.attrs[name]!);
    }
  }
  if (prev.attrs['class'] != cur.attrs['class']) {
    final prevList = prev.attrs['class'] != null
        ? prev.attrs['class']!.split(' ').where((s) => s.isNotEmpty).toList()
        : const <String>[];
    final curList = cur.attrs['class'] != null
        ? cur.attrs['class']!.split(' ').where((s) => s.isNotEmpty).toList()
        : const <String>[];
    for (int i = 0; i < prevList.length; i++) {
      if (!curList.contains(prevList[i])) dom.classList.remove(prevList[i]);
    }
    for (int i = 0; i < curList.length; i++) {
      if (!prevList.contains(curList[i])) dom.classList.add(curList[i]);
    }
    if (dom.classList.length == 0) dom.removeAttribute('class');
  }
  if (prev.attrs['style'] != cur.attrs['style']) {
    final prevStyle = prev.attrs['style'];
    if (prevStyle != null) {
      for (final m in _stylePropRegExp.allMatches(prevStyle)) {
        dom.style.removeProperty(m.group(1)!);
      }
    }
    final curStyle = cur.attrs['style'];
    if (curStyle != null) {
      dom.style.cssText = dom.style.cssText + curStyle;
    }
  }
}

web.Node applyOuterDeco(web.Node dom, List<Decoration> deco, PMNode node) {
  return patchOuterDeco(
      dom, dom, _noDeco, computeOuterDeco(deco, node, !dom.isA<web.Element>()));
}

bool sameOuterDeco(List<Decoration> a, List<Decoration> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!a[i].type.eq(b[i].type)) return false;
  }
  return true;
}

/// Remove a DOM node and return its next sibling.
web.Node? rm(web.Node dom) {
  final next = dom.nextSibling;
  dom.parentNode!.removeChild(dom);
  return next;
}

class _PreMatch {
  /// The fragment index of the first node that is part of the sequence of
  /// matched nodes at the end of the fragment.
  final int index;

  /// A map from matched descs to fragment indices.
  final Map<ViewDesc, int> matched;

  /// The matched descs.
  final List<ViewDesc> matches;

  _PreMatch(this.index, this.matched, this.matches);
}

/// Helper class for incrementally updating a tree of mark descs and the
/// widget and node descs inside of them.
class ViewTreeUpdater {
  /// Index into `this.top`'s child array, represents the current update
  /// position.
  int index = 0;

  /// When entering a mark, the current top and index are pushed onto this.
  final List<Object> stack = [];

  /// Tracks whether anything was changed
  bool changed = false;

  late final _PreMatch _preMatch;
  ViewDesc top;
  final web.Node? lock;
  final EditorView view;

  ViewTreeUpdater(NodeViewDesc top, this.lock, this.view) : top = top {
    _preMatch = _preMatchDescs(top.node.content, top);
  }

  /// Destroy and remove the children between the given indices in `this.top`.
  void destroyBetween(int start, int end) {
    if (start == end) return;
    for (int i = start; i < end; i++) {
      top.children[i].destroy();
    }
    top.children.removeRange(start, end);
    changed = true;
  }

  /// Destroy all remaining children in `this.top`.
  void destroyRest() {
    destroyBetween(index, top.children.length);
  }

  /// Sync the current stack of mark descs with the given array of marks,
  /// reusing existing mark descs when possible.
  void syncToMarks(
      List<Mark> marks, bool inline, EditorView view, int parentIndex) {
    int keep = 0, depth = stack.length >> 1;
    final maxKeep = min(depth, marks.length);
    while (keep < maxKeep &&
        (keep == depth - 1 ? top : stack[(keep + 1) << 1] as ViewDesc)
            .matchesMark(marks[keep]) &&
        marks[keep].type.spec.spanning != false) {
      keep++;
    }

    while (keep < depth) {
      destroyRest();
      top.dirty = NOT_DIRTY;
      index = stack.removeLast() as int;
      top = stack.removeLast() as ViewDesc;
      depth--;
    }
    while (depth < marks.length) {
      stack.add(top);
      stack.add(index + 1);
      int found = -1;
      int scanTo = top.children.length;
      if (parentIndex < _preMatch.index) scanTo = min(index + 3, scanTo);
      for (int i = index; i < scanTo; i++) {
        final next = top.children[i];
        if (next.matchesMark(marks[depth]) && !isLocked(next.dom)) {
          found = i;
          break;
        }
      }
      // When nothing matches, try to update the mark view at this position in
      // place, so a custom mark view can adapt to a changed mark without
      // re-creating its DOM.
      if (found < 0 && index < top.children.length) {
        final cur = top.children[index];
        if (cur is MarkViewDesc &&
            cur.dirty != NODE_DIRTY &&
            cur.mark.type == marks[depth].type &&
            cur.spec.update != null &&
            !isLocked(cur.dom) &&
            cur.spec.update!(marks[depth])) {
          cur.mark = marks[depth];
          found = index;
          changed = true;
        }
      }
      if (found > -1) {
        if (found > index) {
          changed = true;
          destroyBetween(index, found);
        }
        top = top.children[index];
      } else {
        final markDesc = MarkViewDesc.create(top, marks[depth], inline, view);
        top.children.insert(index, markDesc);
        top = markDesc;
        changed = true;
      }
      index = 0;
      depth++;
    }
  }

  /// Try to find a node desc matching the given data. Skip over it and return
  /// true when successful.
  bool findNodeMatch(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, int index) {
    int found = -1;
    bool usedPreMatch = false;
    if (index >= _preMatch.index &&
        index - _preMatch.index < _preMatch.matches.length) {
      final targetDesc = _preMatch.matches[index - _preMatch.index];
      if (targetDesc.parent == top &&
          targetDesc.matchesNode(node, outerDeco, innerDeco)) {
        usedPreMatch = true;
        found = top.children.indexOf(targetDesc, this.index);
      }
    }
    if (!usedPreMatch) {
      final e = min(top.children.length, this.index + 5);
      for (int i = this.index; i < e; i++) {
        final child = top.children[i];
        if (child.matchesNode(node, outerDeco, innerDeco) &&
            !_preMatch.matched.containsKey(child)) {
          found = i;
          break;
        }
      }
    }
    if (found < 0) return false;
    destroyBetween(this.index, found);
    this.index++;
    return true;
  }

  bool updateNodeAt(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, int index, EditorView view) {
    final child = top.children[index] as NodeViewDesc;
    if (child.dirty == NODE_DIRTY && child.dom == child.contentDOM) {
      child.dirty = CONTENT_DIRTY;
    }
    if (!child.update(node, outerDeco, innerDeco, view)) return false;
    destroyBetween(this.index, index);
    this.index++;
    return true;
  }

  int findIndexWithChild(web.Node domNode) {
    for (;;) {
      final parent = domNode.parentNode;
      if (parent == null) return -1;
      if (parent == top.contentDOM) {
        final desc = domNode.pmViewDesc;
        if (desc != null) {
          for (int i = index; i < top.children.length; i++) {
            if (top.children[i] == desc) return i;
          }
        }
        return -1;
      }
      domNode = parent;
    }
  }

  /// Try to update the next node, if any, to the given data. Checks
  /// pre-matches to avoid overwriting nodes that could still be used.
  bool updateNextNode(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, EditorView view, int index, int pos) {
    for (int i = this.index; i < top.children.length; i++) {
      final next = top.children[i];
      if (next is NodeViewDesc) {
        final preMatch = _preMatch.matched[next];
        if (preMatch != null && preMatch != index) return false;
        final nextDOM = next.dom;

        // Can't update if nextDOM is or contains this.lock, except if it's a
        // text node whose content already matches the new text and whose
        // decorations match the new ones.
        final locked = isLocked(nextDOM) &&
            !(node.isText &&
                next.node.isText &&
                next.nodeDOM.nodeValue == node.text &&
                next.dirty != NODE_DIRTY &&
                sameOuterDeco(outerDeco, next.outerDeco));
        if (!locked && next.update(node, outerDeco, innerDeco, view)) {
          destroyBetween(this.index, i);
          if (next.dom != nextDOM) changed = true;
          this.index++;
          return true;
        } else if (!locked) {
          final updated =
              recreateWrapper(next, node, outerDeco, innerDeco, view, pos);
          if (updated != null) {
            destroyBetween(this.index, i);
            top.children[this.index] = updated;
            if (updated.contentDOM != null) {
              updated.dirty = CONTENT_DIRTY;
              updated.updateChildren(view, pos + 1);
              updated.dirty = NOT_DIRTY;
            }
            changed = true;
            this.index++;
            return true;
          }
        }
        break;
      }
    }
    return false;
  }

  /// When a node with content is replaced by a different node with identical
  /// content, move over its children.
  NodeViewDesc? recreateWrapper(
      NodeViewDesc next,
      PMNode node,
      List<Decoration> outerDeco,
      DecorationSource innerDeco,
      EditorView view,
      int pos) {
    if (next.dirty != NOT_DIRTY ||
        node.isAtom ||
        next.children.isEmpty ||
        !next.node.content.eq(node.content) ||
        !sameOuterDeco(outerDeco, next.outerDeco) ||
        !innerDeco.eq(next.innerDeco)) {
      return null;
    }
    final wrapper =
        NodeViewDesc.create(top, node, outerDeco, innerDeco, view, pos);
    if (wrapper.contentDOM != null) {
      wrapper.children = next.children;
      next.children = [];
      for (final ch in wrapper.children) {
        ch.parent = wrapper;
      }
    }
    next.destroy();
    return wrapper;
  }

  /// Insert the node as a newly created node desc.
  void addNode(PMNode node, List<Decoration> outerDeco,
      DecorationSource innerDeco, EditorView view, int pos) {
    final desc =
        NodeViewDesc.create(top, node, outerDeco, innerDeco, view, pos);
    if (desc.contentDOM != null) desc.updateChildren(view, pos + 1);
    top.children.insert(index++, desc);
    changed = true;
  }

  void placeWidget(Decoration widget, EditorView view, int pos) {
    final next = index < top.children.length ? top.children[index] : null;
    if (next != null &&
        next.matchesWidget(widget) &&
        (identical(widget, (next as WidgetViewDesc).widget) ||
            !_widgetDOMHasParent(next.widget))) {
      index++;
    } else {
      final desc = WidgetViewDesc(top, widget, view, pos);
      top.children.insert(index++, desc);
      changed = true;
    }
  }

  static bool _widgetDOMHasParent(Decoration widget) {
    // TS: `(next as any).widget.type.toDOM.parentNode` — when toDOM is a
    // function this is undefined (falsy); when it is a node it is the node's
    // parent.
    final toDOM = (widget.type as WidgetType).toDOM;
    return toDOM is web.Node && toDOM.parentNode != null;
  }

  /// Make sure a textblock looks and behaves correctly in contentEditable.
  void addTextblockHacks() {
    ViewDesc? lastChild = index > 0 ? top.children[index - 1] : null;
    ViewDesc parent = top;
    while (lastChild is MarkViewDesc) {
      parent = lastChild;
      lastChild = parent.children.isNotEmpty ? parent.children.last : null;
    }

    if (lastChild == null || // Empty textblock
        lastChild is! TextViewDesc ||
        RegExp(r'\n$').hasMatch(lastChild.node.text!) ||
        (view.requiresGeckoHackNode &&
            RegExp(r'\s$').hasMatch(lastChild.node.text!))) {
      // Avoid bugs in Safari's cursor drawing (#1165) and Chrome's mouse
      // selection (#1152)
      if ((browser.safari || browser.chrome) &&
          lastChild != null &&
          lastChild.dom.isA<web.HTMLElement>() &&
          (lastChild.dom as web.HTMLElement).contentEditable == 'false') {
        addHackNode('IMG', parent);
      }
      addHackNode('BR', top);
    }
  }

  void addHackNode(String nodeName, ViewDesc parent) {
    if (parent == top &&
        index < parent.children.length &&
        parent.children[index].matchesHack(nodeName)) {
      index++;
    } else {
      final dom = web.document.createElement(nodeName);
      if (nodeName == 'IMG') {
        dom.className = 'ProseMirror-separator';
        (dom as web.HTMLImageElement).alt = '';
      }
      if (nodeName == 'BR') dom.className = 'ProseMirror-trailingBreak';
      final hack = TrailingHackViewDesc(top, [], dom, null);
      if (parent != top) {
        parent.children.add(hack);
      } else {
        parent.children.insert(index++, hack);
      }
      changed = true;
    }
  }

  bool isLocked(web.Node node) {
    return lock != null &&
        (node == lock ||
            (node.nodeType == 1 && node.contains(lock!.parentNode)));
  }
}

/// Iterate from the end of the fragment and array of descs to find directly
/// matching ones, in order to avoid overeagerly reusing those for other
/// nodes. (TS top-level `preMatch` — renamed because it would collide with
/// `ViewTreeUpdater`'s field of the same name.)
_PreMatch _preMatchDescs(Fragment frag, ViewDesc parentDesc) {
  ViewDesc curDesc = parentDesc;
  int descI = curDesc.children.length;
  int fI = frag.childCount;
  final matched = <ViewDesc, int>{};
  final matches = <ViewDesc>[];
  outer:
  while (fI > 0) {
    ViewDesc? desc;
    for (;;) {
      if (descI > 0) {
        final next = curDesc.children[descI - 1];
        if (next is MarkViewDesc) {
          curDesc = next;
          descI = next.children.length;
        } else {
          desc = next;
          descI--;
          break;
        }
      } else if (curDesc == parentDesc) {
        break outer;
      } else {
        // FIXME
        descI = curDesc.parent!.children.indexOf(curDesc);
        curDesc = curDesc.parent!;
      }
    }
    final node = desc.node;
    if (node == null) continue;
    if (!identical(node, frag.child(fI - 1))) break;
    --fI;
    matched[desc] = fI;
    matches.add(desc);
  }
  return _PreMatch(fI, matched, matches.reversed.toList());
}

int compareSide(Decoration a, Decoration b) =>
    (a.type as WidgetType).side - (b.type as WidgetType).side;

/// Stable sort by widget side (JS `Array.sort` is stable; Dart's `List.sort`
/// is not, so an index tiebreaker is used).
void _stableSortBySide(List<Decoration> widgets) {
  final indexed = widgets.asMap().entries.toList();
  indexed.sort((a, b) {
    final d = compareSide(a.value, b.value);
    return d != 0 ? d : a.key - b.key;
  });
  for (int i = 0; i < widgets.length; i++) {
    widgets[i] = indexed[i].value;
  }
}

/// This function abstracts iterating over the nodes and decorations in a
/// fragment. Calls `onNode` for each node, with its local and child
/// decorations. Splits text nodes when there is a decoration starting or
/// ending inside of them. Calls `onWidget` for each widget.
void iterDeco(
    PMNode parent,
    DecorationSource deco,
    void Function(Decoration widget, int index, bool insideNode) onWidget,
    void Function(PMNode node, List<Decoration> outerDeco,
            DecorationSource innerDeco, int index)
        onNode) {
  final locals = deco.locals(parent);
  int offset = 0;
  // Simple, cheap variant for when there are no local decorations
  if (locals.isEmpty) {
    for (int i = 0; i < parent.childCount; i++) {
      final child = parent.child(i);
      onNode(child, locals, deco.forChild(offset, child), i);
      offset += child.nodeSize;
    }
    return;
  }

  int decoIndex = 0;
  final active = <Decoration>[];
  PMNode? restNode;
  for (int parentIndex = 0;;) {
    Decoration? widget;
    List<Decoration>? widgets;
    while (decoIndex < locals.length && locals[decoIndex].to == offset) {
      final next = locals[decoIndex++];
      if (next.isWidget) {
        if (widget == null) {
          widget = next;
        } else {
          (widgets ??= [widget]).add(next);
        }
      }
    }
    if (widget != null) {
      if (widgets != null) {
        _stableSortBySide(widgets);
        for (int i = 0; i < widgets.length; i++) {
          onWidget(widgets[i], parentIndex, restNode != null);
        }
      } else {
        onWidget(widget, parentIndex, restNode != null);
      }
    }

    PMNode child;
    int index;
    if (restNode != null) {
      index = -1;
      child = restNode;
      restNode = null;
    } else if (parentIndex < parent.childCount) {
      index = parentIndex;
      child = parent.child(parentIndex++);
    } else {
      break;
    }

    for (int i = 0; i < active.length; i++) {
      if (active[i].to <= offset) active.removeAt(i--);
    }
    while (decoIndex < locals.length &&
        locals[decoIndex].from <= offset &&
        locals[decoIndex].to > offset) {
      active.add(locals[decoIndex++]);
    }

    int end = offset + child.nodeSize;
    if (child.isText) {
      int cutAt = end;
      if (decoIndex < locals.length && locals[decoIndex].from < cutAt) {
        cutAt = locals[decoIndex].from;
      }
      for (int i = 0; i < active.length; i++) {
        if (active[i].to < cutAt) cutAt = active[i].to;
      }
      if (cutAt < end) {
        restNode = child.cut(cutAt - offset);
        child = child.cut(0, cutAt - offset);
        end = cutAt;
        index = -1;
      }
    } else {
      while (decoIndex < locals.length && locals[decoIndex].to < end) {
        decoIndex++;
      }
    }

    final outerDeco = child.isInline && !child.isLeaf
        ? active.where((d) => !d.isInline).toList()
        : List<Decoration>.of(active);
    onNode(child, outerDeco, deco.forChild(offset, child), index);
    offset = end;
  }
}

/// List markers in Mobile Safari will mysteriously disappear sometimes. This
/// works around that.
void iosHacks(web.HTMLElement dom) {
  if (dom.nodeName == 'UL' || dom.nodeName == 'OL') {
    final oldCSS = dom.style.cssText;
    dom.style.cssText = '$oldCSS; list-style: square !important';
    web.window.getComputedStyle(dom).getPropertyValue('list-style');
    dom.style.cssText = oldCSS;
  }
}

/// JS `String.prototype.slice` semantics (negative indices count from the
/// end, out-of-range indices are clamped).
String _jsSlice(String s, int start, int end) {
  final len = s.length;
  final st = start < 0 ? max(0, len + start) : min(start, len);
  final en = end < 0 ? max(0, len + end) : min(end, len);
  return st >= en ? '' : s.substring(st, en);
}

/// Find a piece of text in an inline fragment, overlapping from-to.
int findTextInFragment(Fragment frag, String text, int from, int to) {
  int pos = 0;
  for (int i = 0; i < frag.childCount && pos <= to;) {
    final child = frag.child(i++);
    final childStart = pos;
    pos += child.nodeSize;
    if (!child.isText) continue;
    String str = child.text!;
    while (i < frag.childCount) {
      final next = frag.child(i++);
      pos += next.nodeSize;
      if (!next.isText) break;
      str += next.text!;
    }
    if (pos >= from) {
      if (pos >= to &&
          _jsSlice(str, to - text.length - childStart, to - childStart) ==
              text) {
        return to - text.length;
      }
      final found = childStart < to
          ? str.lastIndexOf(text, min(to - childStart - 1, str.length))
          : -1;
      if (found >= 0 && found + text.length + childStart >= from) {
        return childStart + found;
      }
      if (from == to &&
          str.length >= (to + text.length) - childStart &&
          _jsSlice(str, to - childStart, to - childStart + text.length) ==
              text) {
        return to;
      }
    }
  }
  return -1;
}

/// Replace range from-to in an array of view descs with replacement (may be
/// null to just delete). This goes very much against the grain of the rest of
/// this code, which tends to create nodes with the right shape in one go,
/// rather than messing with them after creation, but is necessary in the
/// composition hack.
List<ViewDesc> replaceNodes(
    List<ViewDesc> nodes, int from, int to, EditorView view,
    [ViewDesc? replacement]) {
  final result = <ViewDesc>[];
  int off = 0;
  for (int i = 0; i < nodes.length; i++) {
    final child = nodes[i];
    final start = off;
    final end = off += child.size;
    if (start >= to || end <= from) {
      result.add(child);
    } else {
      if (start < from) result.add(_sliceDesc(child, 0, from - start, view));
      if (replacement != null) {
        result.add(replacement);
        replacement = null;
      }
      if (end > to) {
        result.add(_sliceDesc(child, to - start, child.size, view));
      }
    }
  }
  return result;
}

ViewDesc _sliceDesc(ViewDesc child, int from, int to, EditorView view) {
  // TS casts to `MarkViewDesc | TextViewDesc` here.
  if (child is MarkViewDesc) return child.slice(from, to, view);
  if (child is TextViewDesc) return child.slice(from, to, view);
  throw StateError('Cannot slice a ${child.runtimeType}');
}

/// `pmIsDeco` expando used to tag decoration wrapper elements (TS
/// `(parent as any).pmIsDeco = true`).
extension _PmIsDeco on web.Node {
  bool get pmIsDeco {
    final JSAny? value = (this as JSObject).getProperty('pmIsDeco'.toJS);
    if (value == null || value.isUndefinedOrNull) return false;
    return (value as JSBoolean).toDart;
  }

  set pmIsDeco(bool value) {
    (this as JSObject).setProperty('pmIsDeco'.toJS, value.toJS);
  }
}
