// Port of prosemirror-view/src/decoration.ts.
import 'dart:math' show max, min;

import 'package:web/web.dart' as web;

import '../model/index.dart';
import '../transform/index.dart';
import 'index.dart';

/// Compare two spec/attrs objects (ported from the TS `compareObjs`, which
/// operates on plain objects; here they are `Map<String, dynamic>`).
bool compareObjs(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) return true;
  for (final p in a.keys) {
    if (a[p] != b[p]) return false;
  }
  for (final p in b.keys) {
    if (!a.containsKey(p)) return false;
  }
  return true;
}

/// A set of attributes to add to a decorated node. Most properties simply
/// directly correspond to DOM attributes of the same name. Exceptions:
/// `nodeName` (wrap the target in an element of this type), `class` (class
/// names _added_ to existing ones), and `style` (CSS _added_ to the existing
/// `style` property).
typedef DecorationAttrs = Map<String, dynamic>;

abstract class DecorationType {
  Map<String, dynamic> get spec;
  Decoration? map(Mappable mapping, Decoration span, int offset, int oldOffset);
  bool valid(PMNode node, Decoration span);
  bool eq(DecorationType other);
  void destroy(web.Node dom);
}

/// TS `WidgetConstructor` is
/// `((view: EditorView, getPos: () => number | undefined) => DOMNode) | DOMNode`.
/// In Dart the widget `toDOM` field is `dynamic` and may hold either a
/// `web.Node` or a `web.Node Function(EditorView view, int? Function() getPos)`.
typedef WidgetConstructorFn = web.Node Function(
    EditorView view, int? Function() getPos);

class WidgetType implements DecorationType {
  @override
  final Map<String, dynamic> spec;

  /// Either a `web.Node` or a [WidgetConstructorFn].
  final dynamic toDOM;
  final int side;

  WidgetType(this.toDOM, Map<String, dynamic>? spec)
      : spec = spec ?? _noSpec,
        side = (spec?['side'] as int?) ?? 0;

  @override
  Decoration? map(Mappable mapping, Decoration span, int offset, int oldOffset) {
    final result = mapping.mapResult(span.from + oldOffset, side < 0 ? -1 : 1);
    return result.deleted
        ? null
        : Decoration(result.pos - offset, result.pos - offset, this);
  }

  @override
  bool valid(PMNode node, Decoration span) => true;

  @override
  bool eq(DecorationType other) {
    return identical(this, other) ||
        (other is WidgetType &&
            ((spec['key'] != null && spec['key'] == other.spec['key']) ||
                (toDOM == other.toDOM && compareObjs(spec, other.spec))));
  }

  @override
  void destroy(web.Node dom) {
    final destroyFn = spec['destroy'];
    if (destroyFn != null) destroyFn(dom);
  }
}

class InlineType implements DecorationType {
  @override
  final Map<String, dynamic> spec;
  final DecorationAttrs attrs;

  InlineType(this.attrs, Map<String, dynamic>? spec) : spec = spec ?? _noSpec;

  @override
  Decoration? map(Mappable mapping, Decoration span, int offset, int oldOffset) {
    final from = mapping.map(
            span.from + oldOffset, spec['inclusiveStart'] == true ? -1 : 1) -
        offset;
    final to = mapping.map(
            span.to + oldOffset, spec['inclusiveEnd'] == true ? 1 : -1) -
        offset;
    return from >= to ? null : Decoration(from, to, this);
  }

  @override
  bool valid(PMNode node, Decoration span) => span.from < span.to;

  @override
  bool eq(DecorationType other) {
    return identical(this, other) ||
        (other is InlineType &&
            compareObjs(attrs, other.attrs) &&
            compareObjs(spec, other.spec));
  }

  /// TS `InlineType.is` — renamed because `is` is a reserved word in Dart.
  static bool isInline(Decoration span) => span.type is InlineType;

  @override
  void destroy(web.Node dom) {}
}

/// TS `NodeType` — renamed to avoid a collision with the schema `NodeType`
/// exported from the model package.
class NodeTypeDecoration implements DecorationType {
  @override
  final Map<String, dynamic> spec;
  final DecorationAttrs attrs;

  NodeTypeDecoration(this.attrs, Map<String, dynamic>? spec)
      : spec = spec ?? _noSpec;

  @override
  Decoration? map(Mappable mapping, Decoration span, int offset, int oldOffset) {
    final from = mapping.mapResult(span.from + oldOffset, 1);
    if (from.deleted) return null;
    final to = mapping.mapResult(span.to + oldOffset, -1);
    if (to.deleted || to.pos <= from.pos) return null;
    return Decoration(from.pos - offset, to.pos - offset, this);
  }

  @override
  bool valid(PMNode node, Decoration span) {
    final io = node.content.findIndex(span.from);
    if (io.offset != span.from) return false;
    final child = node.child(io.index);
    return !child.isText && io.offset + child.nodeSize == span.to;
  }

  @override
  bool eq(DecorationType other) {
    return identical(this, other) ||
        (other is NodeTypeDecoration &&
            compareObjs(attrs, other.attrs) &&
            compareObjs(spec, other.spec));
  }

  @override
  void destroy(web.Node dom) {}
}

/// Decoration objects can be provided to the view through the
/// [`decorations` prop](#view.EditorProps.decorations). They come in
/// several variants—see the static members of this class for details.
class Decoration {
  /// The start position of the decoration.
  final int from;

  /// The end position. Will be the same as `from` for [widget
  /// decorations](#view.Decoration^widget).
  final int to;

  /// @internal
  final DecorationType type;

  /// @internal
  Decoration(this.from, this.to, this.type);

  /// @internal
  Decoration copy(int from, int to) {
    return Decoration(from, to, type);
  }

  /// @internal
  bool eq(Decoration other, [int offset = 0]) {
    return type.eq(other.type) &&
        from + offset == other.from &&
        to + offset == other.to;
  }

  /// @internal
  Decoration? map(Mappable mapping, int offset, int oldOffset) {
    return type.map(mapping, this, offset, oldOffset);
  }

  /// Creates a widget decoration, which is a DOM node that's shown in
  /// the document at the given position. It is recommended that you
  /// delay rendering the widget by passing a function that will be
  /// called when the widget is actually drawn in a view, but you can
  /// also directly pass a DOM node. `getPos` can be used to find the
  /// widget's current document position.
  ///
  /// [toDOM] is either a `web.Node` or a [WidgetConstructorFn].
  ///
  /// Recognized spec properties: `side` (int), `relaxedSide` (bool),
  /// `marks` (List<Mark>), `stopEvent` (bool Function(web.Event)),
  /// `ignoreSelection` (bool), `key` (String),
  /// `destroy` (void Function(web.Node)), plus arbitrary extra properties.
  static Decoration widget(int pos, dynamic toDOM,
      [Map<String, dynamic>? spec]) {
    return Decoration(pos, pos, WidgetType(toDOM, spec));
  }

  /// Creates an inline decoration, which adds the given attributes to
  /// each inline node between `from` and `to`.
  ///
  /// Recognized spec properties: `inclusiveStart` (bool), `inclusiveEnd`
  /// (bool), plus arbitrary extra properties.
  static Decoration inline(int from, int to, DecorationAttrs attrs,
      [Map<String, dynamic>? spec]) {
    return Decoration(from, to, InlineType(attrs, spec));
  }

  /// Creates a node decoration. `from` and `to` should point precisely
  /// before and after a node in the document. That node, and only that
  /// node, will receive the given attributes.
  static Decoration node(int from, int to, DecorationAttrs attrs,
      [Map<String, dynamic>? spec]) {
    return Decoration(from, to, NodeTypeDecoration(attrs, spec));
  }

  /// The spec provided when creating this decoration. Can be useful
  /// if you've stored extra information in that object.
  Map<String, dynamic> get spec => type.spec;

  /// @internal — TS `get inline`; renamed because Dart does not allow an
  /// instance member with the same name as the static `Decoration.inline`.
  bool get isInline => type is InlineType;

  /// @internal — TS `get widget`; renamed because Dart does not allow an
  /// instance member with the same name as the static `Decoration.widget`.
  bool get isWidget => type is WidgetType;
}

const List<Decoration> _none = [];
const List<Object> _noneChildren = [];
const Map<String, dynamic> _noSpec = {};

/// An object that can [provide](#view.EditorProps.decorations)
/// decorations. Implemented by [DecorationSet], and passed to
/// [node views](#view.EditorProps.nodeViews).
abstract class DecorationSource {
  /// Map the set of decorations in response to a change in the
  /// document.
  DecorationSource map(Mapping mapping, PMNode node);

  /// @internal
  List<Decoration> locals(PMNode node);

  /// Extract a DecorationSource containing decorations for the given
  /// child node at the given offset.
  DecorationSource forChild(int offset, PMNode child);

  /// @internal
  bool eq(DecorationSource other);

  /// Call the given function for each decoration set in the group.
  void forEachSet(void Function(DecorationSet set) f);
}

/// A collection of [decorations](#view.Decoration), organized in such
/// a way that the drawing algorithm can efficiently use and compare
/// them. This is a persistent data structure—it is not modified,
/// updates create a new value.
class DecorationSet implements DecorationSource {
  /// @internal
  final List<Decoration> local;

  /// @internal
  /// Alternating triples of `int from, int to, DecorationSet set`
  /// (the TS `(number | DecorationSet)[]` flat array).
  final List<Object> children;

  /// @internal
  DecorationSet(List<Decoration> local, List<Object> children)
      : local = local.isNotEmpty ? local : _none,
        children = children.isNotEmpty ? children : _noneChildren;

  /// Create a set of decorations, using the structure of the given
  /// document. This will consume (modify) the `decorations` array, so
  /// you must make a copy if you want need to preserve that.
  static DecorationSet create(PMNode doc, List<Decoration> decorations) {
    return decorations.isNotEmpty
        ? buildTree(List<Decoration?>.of(decorations), doc, 0, null)
        : empty;
  }

  /// Find all decorations in this set which touch the given range
  /// (including decorations that start or end directly at the
  /// boundaries) and match the given predicate on their spec. When
  /// `start` and `end` are omitted, all decorations in the set are
  /// considered. When `predicate` isn't given, all decorations are
  /// assumed to match.
  List<Decoration> find(
      [int? start,
      int? end,
      bool Function(Map<String, dynamic> spec)? predicate]) {
    final result = <Decoration>[];
    _findInner(start ?? 0, end ?? 1000000000, result, 0, predicate);
    return result;
  }

  void _findInner(int start, int end, List<Decoration> result, int offset,
      bool Function(Map<String, dynamic> spec)? predicate) {
    for (int i = 0; i < local.length; i++) {
      final span = local[i];
      if (span.from <= end &&
          span.to >= start &&
          (predicate == null || predicate(span.spec))) {
        result.add(span.copy(span.from + offset, span.to + offset));
      }
    }
    for (int i = 0; i < children.length; i += 3) {
      if ((children[i] as int) < end && (children[i + 1] as int) > start) {
        final childOff = (children[i] as int) + 1;
        (children[i + 2] as DecorationSet)._findInner(
            start - childOff, end - childOff, result, offset + childOff,
            predicate);
      }
    }
  }

  /// Map the set of decorations in response to a change in the
  /// document. When [onRemove] is given, it will be called for each
  /// decoration that gets dropped as a result of the mapping, passing
  /// the spec of that decoration.
  @override
  DecorationSet map(Mapping mapping, PMNode doc,
      {void Function(Map<String, dynamic> decorationSpec)? onRemove}) {
    if (identical(this, empty) || mapping.maps.isEmpty) return this;
    return mapInner(mapping, doc, 0, 0, onRemove);
  }

  /// @internal
  DecorationSet mapInner(Mapping mapping, PMNode node, int offset,
      int oldOffset, void Function(Map<String, dynamic> spec)? onRemove) {
    List<Decoration>? newLocal;
    for (int i = 0; i < local.length; i++) {
      final mapped = local[i].map(mapping, offset, oldOffset);
      if (mapped != null && mapped.type.valid(node, mapped)) {
        (newLocal ??= []).add(mapped);
      } else if (onRemove != null) {
        onRemove(local[i].spec);
      }
    }

    if (children.isNotEmpty) {
      return mapChildren(
          children, newLocal ?? [], mapping, node, offset, oldOffset, onRemove);
    } else {
      return newLocal != null
          ? DecorationSet(newLocal..sort(byPos), [])
          : empty;
    }
  }

  /// Add the given array of decorations to the ones in the set,
  /// producing a new set. Needs access to the current document to
  /// create the appropriate tree structure.
  DecorationSet add(PMNode doc, List<Decoration> decorations) {
    if (decorations.isEmpty) return this;
    if (identical(this, empty)) return DecorationSet.create(doc, decorations);
    return _addInner(doc, List<Decoration?>.of(decorations), 0);
  }

  DecorationSet _addInner(PMNode doc, List<Decoration?> decorations, int offset) {
    List<Object>? children;
    int childIndex = 0;
    doc.forEach((childNode, childOffset, index) {
      final baseOffset = childOffset + offset;
      final found = takeSpansForNode(decorations, childNode, baseOffset);
      if (found == null) return;

      final kids = children ??= List<Object>.of(this.children);
      while (childIndex < kids.length &&
          (kids[childIndex] as int) < childOffset) {
        childIndex += 3;
      }
      if (childIndex < kids.length && kids[childIndex] == childOffset) {
        kids[childIndex + 2] = (kids[childIndex + 2] as DecorationSet)
            ._addInner(childNode, found, baseOffset + 1);
      } else {
        kids.insertAll(childIndex, [
          childOffset,
          childOffset + childNode.nodeSize,
          buildTree(found, childNode, baseOffset + 1, null)
        ]);
      }
      childIndex += 3;
    });

    final local = moveSpans(withoutNulls(decorations), -offset);
    for (int i = 0; i < local.length; i++) {
      if (!local[i].type.valid(doc, local[i])) local.removeAt(i--);
    }

    return DecorationSet(
        local.isNotEmpty ? ([...this.local, ...local]..sort(byPos)) : this.local,
        children ?? this.children);
  }

  /// Create a new set that contains the decorations in this set, minus
  /// the ones in the given array.
  DecorationSet remove(List<Decoration> decorations) {
    if (decorations.isEmpty || identical(this, empty)) return this;
    return _removeInner(List<Decoration?>.of(decorations), 0);
  }

  DecorationSet _removeInner(List<Decoration?> decorations, int offset) {
    var children = this.children;
    var local = this.local;
    for (int i = 0; i < children.length; i += 3) {
      List<Decoration?>? found;
      final from = (children[i] as int) + offset;
      final to = (children[i + 1] as int) + offset;
      for (int j = 0; j < decorations.length; j++) {
        final span = decorations[j];
        if (span != null && span.from > from && span.to < to) {
          decorations[j] = null;
          (found ??= []).add(span);
        }
      }
      if (found == null) continue;
      if (identical(children, this.children)) {
        children = List<Object>.of(this.children);
      }
      final removed =
          (children[i + 2] as DecorationSet)._removeInner(found, from + 1);
      if (!identical(removed, empty)) {
        children[i + 2] = removed;
      } else {
        children.removeRange(i, i + 3);
        i -= 3;
      }
    }
    if (local.isNotEmpty) {
      for (int i = 0; i < decorations.length; i++) {
        final span = decorations[i];
        if (span != null) {
          for (int j = 0; j < local.length; j++) {
            if (local[j].eq(span, offset)) {
              if (identical(local, this.local)) {
                local = List<Decoration>.of(this.local);
              }
              local.removeAt(j--);
            }
          }
        }
      }
    }
    if (identical(children, this.children) && identical(local, this.local)) {
      return this;
    }
    return local.isNotEmpty || children.isNotEmpty
        ? DecorationSet(local, children)
        : empty;
  }

  /// Returns a [DecorationSet] or a [DecorationGroup].
  @override
  DecorationSource forChild(int offset, PMNode node) {
    if (identical(this, empty)) return this;
    if (node.isLeaf) return DecorationSet.empty;

    DecorationSet? child;
    List<Decoration>? local;
    for (int i = 0; i < children.length; i += 3) {
      if ((children[i] as int) >= offset) {
        if (children[i] == offset) child = children[i + 2] as DecorationSet;
        break;
      }
    }
    final int start = offset + 1, end = start + node.content.size;
    for (int i = 0; i < this.local.length; i++) {
      final dec = this.local[i];
      if (dec.from < end && dec.to > start && dec.type is InlineType) {
        final int from = max(start, dec.from) - start,
            to = min(end, dec.to) - start;
        if (from < to) (local ??= []).add(dec.copy(from, to));
      }
    }
    if (local != null) {
      final localSet = DecorationSet(local..sort(byPos), []);
      return child != null ? DecorationGroup([localSet, child]) : localSet;
    }
    return child ?? empty;
  }

  /// @internal
  @override
  bool eq(DecorationSource other) {
    if (identical(this, other)) return true;
    if (other is! DecorationSet ||
        local.length != other.local.length ||
        children.length != other.children.length) {
      return false;
    }
    for (int i = 0; i < local.length; i++) {
      if (!local[i].eq(other.local[i])) return false;
    }
    for (int i = 0; i < children.length; i += 3) {
      if (children[i] != other.children[i] ||
          children[i + 1] != other.children[i + 1] ||
          !(children[i + 2] as DecorationSet)
              .eq(other.children[i + 2] as DecorationSet)) {
        return false;
      }
    }
    return true;
  }

  /// @internal
  @override
  List<Decoration> locals(PMNode node) {
    return removeOverlap(localsInner(node));
  }

  /// @internal
  List<Decoration> localsInner(PMNode node) {
    if (identical(this, empty)) return _none;
    if (node.inlineContent || !local.any(InlineType.isInline)) return local;
    final result = <Decoration>[];
    for (int i = 0; i < local.length; i++) {
      if (local[i].type is! InlineType) result.add(local[i]);
    }
    return result;
  }

  /// The empty set of decorations.
  static final DecorationSet empty = DecorationSet([], []);

  /// @internal — TS exposes `removeOverlap` as a static on DecorationSet too.
  static List<Decoration> removeOverlap(List<Decoration> spans) =>
      _removeOverlap(spans);

  @override
  void forEachSet(void Function(DecorationSet set) f) {
    f(this);
  }
}

/// An abstraction that allows the code dealing with decorations to
/// treat multiple DecorationSet objects as if it were a single object
/// with (a subset of) the same interface.
class DecorationGroup implements DecorationSource {
  final List<DecorationSet> members;

  DecorationGroup(this.members);

  @override
  DecorationSource map(Mapping mapping, PMNode doc) {
    final mappedDecos =
        members.map((member) => member.map(mapping, doc)).toList();
    return DecorationGroup.from(mappedDecos);
  }

  @override
  DecorationSource forChild(int offset, PMNode child) {
    if (child.isLeaf) return DecorationSet.empty;
    var found = <DecorationSet>[];
    for (int i = 0; i < members.length; i++) {
      final result = members[i].forChild(offset, child);
      if (identical(result, DecorationSet.empty)) continue;
      if (result is DecorationGroup) {
        found = [...found, ...result.members];
      } else {
        found.add(result as DecorationSet);
      }
    }
    return DecorationGroup.from(found);
  }

  @override
  bool eq(DecorationSource other) {
    if (other is! DecorationGroup || other.members.length != members.length) {
      return false;
    }
    for (int i = 0; i < members.length; i++) {
      if (!members[i].eq(other.members[i])) return false;
    }
    return true;
  }

  @override
  List<Decoration> locals(PMNode node) {
    List<Decoration>? result;
    bool sorted = true;
    for (int i = 0; i < members.length; i++) {
      final locals = members[i].localsInner(node);
      if (locals.isEmpty) continue;
      if (result == null) {
        result = locals;
      } else {
        if (sorted) {
          result = result.toList();
          sorted = false;
        }
        for (int j = 0; j < locals.length; j++) {
          result.add(locals[j]);
        }
      }
    }
    return result != null
        ? removeOverlap(sorted ? result : (result..sort(byPos)))
        : _none;
  }

  /// Create a group for the given array of decoration sets, or return
  /// a single set when possible.
  static DecorationSource from(List<DecorationSource> members) {
    switch (members.length) {
      case 0:
        return DecorationSet.empty;
      case 1:
        return members[0];
      default:
        if (members.every((m) => m is DecorationSet)) {
          return DecorationGroup(members.cast<DecorationSet>().toList());
        }
        final result = <DecorationSet>[];
        for (final m in members) {
          if (m is DecorationSet) {
            result.add(m);
          } else {
            result.addAll((m as DecorationGroup).members);
          }
        }
        return DecorationGroup(result);
    }
  }

  @override
  void forEachSet(void Function(DecorationSet set) f) {
    for (int i = 0; i < members.length; i++) {
      members[i].forEachSet(f);
    }
  }
}

DecorationSet mapChildren(
    List<Object> oldChildren,
    List<Decoration> newLocal,
    Mapping mapping,
    PMNode node,
    int offset,
    int oldOffset,
    void Function(Map<String, dynamic> spec)? onRemove) {
  final children = List<Object>.of(oldChildren);

  // Mark the children that are directly touched by changes, and
  // move those that are after the changes.
  for (int i = 0, baseOffset = oldOffset; i < mapping.maps.length; i++) {
    int moved = 0;
    mapping.maps[i].forEach((oldStart, oldEnd, newStart, newEnd) {
      final dSize = (newEnd - newStart) - (oldEnd - oldStart);
      for (int j = 0; j < children.length; j += 3) {
        final end = children[j + 1] as int;
        if (end < 0 || oldStart > end + baseOffset - moved) continue;
        final start = (children[j] as int) + baseOffset - moved;
        if (oldEnd >= start) {
          children[j + 1] = oldStart <= start ? -2 : -1;
        } else if (oldStart >= baseOffset && dSize != 0) {
          children[j] = (children[j] as int) + dSize;
          children[j + 1] = (children[j + 1] as int) + dSize;
        }
      }
      moved += dSize;
    });
    baseOffset = mapping.maps[i].map(baseOffset, -1);
  }

  // Find the child nodes that still correspond to a single node,
  // recursively call mapInner on them and update their positions.
  bool mustRebuild = false;
  for (int i = 0; i < children.length; i += 3) {
    if ((children[i + 1] as int) < 0) {
      // Touched nodes
      if (children[i + 1] == -2) {
        mustRebuild = true;
        children[i + 1] = -1;
        continue;
      }
      final from = mapping.map((oldChildren[i] as int) + oldOffset);
      final fromLocal = from - offset;
      if (fromLocal < 0 || fromLocal >= node.content.size) {
        mustRebuild = true;
        continue;
      }
      // Must read oldChildren because children was tagged with -1
      final to = mapping.map((oldChildren[i + 1] as int) + oldOffset, -1);
      final toLocal = to - offset;
      final io = node.content.findIndex(fromLocal);
      final childNode = node.maybeChild(io.index);
      if (childNode != null &&
          io.offset == fromLocal &&
          io.offset + childNode.nodeSize == toLocal) {
        final mapped = (children[i + 2] as DecorationSet).mapInner(mapping,
            childNode, from + 1, (oldChildren[i] as int) + oldOffset + 1,
            onRemove);
        if (!identical(mapped, DecorationSet.empty)) {
          children[i] = fromLocal;
          children[i + 1] = toLocal;
          children[i + 2] = mapped;
        } else {
          children[i + 1] = -2;
          mustRebuild = true;
        }
      } else {
        mustRebuild = true;
      }
    }
  }

  // Remaining children must be collected and rebuilt into the appropriate structure
  if (mustRebuild) {
    final decorations = mapAndGatherRemainingDecorations(children, oldChildren,
        List<Decoration?>.of(newLocal), mapping, offset, oldOffset, onRemove);
    final built = buildTree(decorations, node, 0, onRemove);
    newLocal = List<Decoration>.of(built.local);
    for (int i = 0; i < children.length; i += 3) {
      if ((children[i + 1] as int) < 0) {
        children.removeRange(i, i + 3);
        i -= 3;
      }
    }
    for (int i = 0, j = 0; i < built.children.length; i += 3) {
      final from = built.children[i] as int;
      while (j < children.length && (children[j] as int) < from) {
        j += 3;
      }
      children.insertAll(j, [
        built.children[i],
        built.children[i + 1],
        built.children[i + 2]
      ]);
    }
  }

  return DecorationSet(newLocal..sort(byPos), children);
}

List<Decoration> moveSpans(List<Decoration> spans, int offset) {
  if (offset == 0 || spans.isEmpty) return spans;
  final result = <Decoration>[];
  for (int i = 0; i < spans.length; i++) {
    final span = spans[i];
    result.add(Decoration(span.from + offset, span.to + offset, span.type));
  }
  return result;
}

List<Decoration?> mapAndGatherRemainingDecorations(
    List<Object> children,
    List<Object> oldChildren,
    List<Decoration?> decorations,
    Mapping mapping,
    int offset,
    int oldOffset,
    void Function(Map<String, dynamic> spec)? onRemove) {
  // Gather all decorations from the remaining marked children
  void gather(DecorationSet set, int oldOffset) {
    for (int i = 0; i < set.local.length; i++) {
      final mapped = set.local[i].map(mapping, offset, oldOffset);
      if (mapped != null) {
        decorations.add(mapped);
      } else if (onRemove != null) {
        onRemove(set.local[i].spec);
      }
    }
    for (int i = 0; i < set.children.length; i += 3) {
      gather(set.children[i + 2] as DecorationSet,
          (set.children[i] as int) + oldOffset + 1);
    }
  }

  for (int i = 0; i < children.length; i += 3) {
    if (children[i + 1] == -1) {
      gather(children[i + 2] as DecorationSet,
          (oldChildren[i] as int) + oldOffset + 1);
    }
  }

  return decorations;
}

List<Decoration?>? takeSpansForNode(
    List<Decoration?> spans, PMNode node, int offset) {
  if (node.isLeaf) return null;
  final end = offset + node.nodeSize;
  List<Decoration?>? found;
  for (int i = 0; i < spans.length; i++) {
    final span = spans[i];
    if (span != null && span.from > offset && span.to < end) {
      (found ??= []).add(span);
      spans[i] = null;
    }
  }
  return found;
}

List<T> withoutNulls<T extends Object>(List<T?> array) {
  final result = <T>[];
  for (int i = 0; i < array.length; i++) {
    final item = array[i];
    if (item != null) result.add(item);
  }
  return result;
}

// Build up a tree that corresponds to a set of decorations. `offset`
// is a base offset that should be subtracted from the `from` and `to`
// positions in the spans (so that we don't have to allocate new spans
// for recursive calls).
DecorationSet buildTree(List<Decoration?> spans, PMNode node, int offset,
    void Function(Map<String, dynamic> spec)? onRemove) {
  final children = <Object>[];
  node.forEach((childNode, localStart, index) {
    final found = takeSpansForNode(spans, childNode, localStart + offset);
    if (found != null) {
      final subtree =
          buildTree(found, childNode, offset + localStart + 1, onRemove);
      if (!identical(subtree, DecorationSet.empty)) {
        children
            .addAll([localStart, localStart + childNode.nodeSize, subtree]);
      }
    }
  });
  final locals = moveSpans(withoutNulls(spans), -offset)..sort(byPos);
  for (int i = 0; i < locals.length; i++) {
    if (!locals[i].type.valid(node, locals[i])) {
      if (onRemove != null) onRemove(locals[i].spec);
      locals.removeAt(i--);
    }
  }
  return locals.isNotEmpty || children.isNotEmpty
      ? DecorationSet(locals, children)
      : DecorationSet.empty;
}

// Used to sort decorations so that ones with a low start position
// come first, and within a set with the same start position, those
// with an smaller end position come first.
int byPos(Decoration a, Decoration b) {
  return a.from != b.from ? a.from - b.from : a.to - b.to;
}

// Scan a sorted array of decorations for partially overlapping spans,
// and split those so that only fully overlapping spans are left (to
// make subsequent rendering easier). Will return the input array if
// no partially overlapping spans are found (the common case).
List<Decoration> removeOverlap(List<Decoration> spans) => _removeOverlap(spans);

List<Decoration> _removeOverlap(List<Decoration> spans) {
  List<Decoration> working = spans;
  for (int i = 0; i < working.length - 1; i++) {
    final span = working[i];
    if (span.from != span.to) {
      for (int j = i + 1; j < working.length; j++) {
        final next = working[j];
        if (next.from == span.from) {
          if (next.to != span.to) {
            if (identical(working, spans)) working = List<Decoration>.of(spans);
            // Followed by a partially overlapping larger span. Split that
            // span.
            working[j] = next.copy(next.from, span.to);
            insertAhead(working, j + 1, next.copy(span.to, next.to));
          }
          continue;
        } else {
          if (next.from < span.to) {
            if (identical(working, spans)) working = List<Decoration>.of(spans);
            // The end of this one overlaps with a subsequent span. Split
            // this one.
            working[i] = span.copy(span.from, next.from);
            insertAhead(working, j, span.copy(next.from, span.to));
          }
          break;
        }
      }
    }
  }
  return working;
}

void insertAhead(List<Decoration> array, int i, Decoration deco) {
  while (i < array.length && byPos(deco, array[i]) > 0) {
    i++;
  }
  array.insert(i, deco);
}

/// Get the decorations associated with the current props of a view.
DecorationSource viewDecorations(EditorView view) {
  final found = <DecorationSource>[];
  view.someProp('decorations', (f) {
    final result = f(view.state);
    if (result != null && !identical(result, DecorationSet.empty)) {
      found.add(result as DecorationSource);
    }
    return null;
  });
  // TODO(port): the TS version also pushes the cursor-wrapper decoration
  // (`view.cursorWrapper.deco`) here; `EditorView.cursorWrapper` has not been
  // ported yet. Re-add once the full EditorView port lands:
  //   if (view.cursorWrapper != null)
  //     found.add(DecorationSet.create(view.state.doc, [view.cursorWrapper!.deco]));
  return DecorationGroup.from(found);
}
