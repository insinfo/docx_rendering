import 'dart:math';
import 'package:web/web.dart' as web;
import 'fragment.dart';
import 'replace.dart';
import 'mark.dart';
import 'node.dart';
import 'content.dart';
import 'resolvedpos.dart';
import 'schema.dart';

class ParseOptions {
  final dynamic preserveWhitespace; // bool | "full"
  final List<Map<String, dynamic>>? findPositions;
  final int? from;
  final int? to;
  final PMNode? topNode;
  final ContentMatch? topMatch;
  final ResolvedPos? context;
  final TagParseRule? Function(web.Node)? ruleFromNode;
  final bool? topOpen;

  ParseOptions({
    this.preserveWhitespace,
    this.findPositions,
    this.from,
    this.to,
    this.topNode,
    this.topMatch,
    this.context,
    this.ruleFromNode,
    this.topOpen,
  });
}

abstract class ParseRule {
  final int? priority;
  final bool? consuming;
  final String? context;
  String? mark;
  final bool? ignore;
  final bool? closeParent;
  final bool? skip; // Note: skip could be a node in some cases in TS, we'll keep it simple
  Map<String, dynamic>? attrs;

  ParseRule({
    this.priority,
    this.consuming,
    this.context,
    this.mark,
    this.ignore,
    this.closeParent,
    this.skip,
    this.attrs,
  });
}

class TagParseRule extends ParseRule {
  final String tag;
  final String? namespace;
  String? node;
  final dynamic Function(web.HTMLElement)? getAttrs;
  final dynamic contentElement; // String | HTMLElement | Function
  final Fragment Function(web.Node, Schema)? getContent;
  final dynamic preserveWhitespace; // bool | "full"

  TagParseRule({
    required this.tag,
    this.namespace,
    this.node,
    this.getAttrs,
    this.contentElement,
    this.getContent,
    this.preserveWhitespace,
    super.priority,
    super.consuming,
    super.context,
    super.mark,
    super.ignore,
    super.closeParent,
    super.skip,
    super.attrs,
  });
}

class StyleParseRule extends ParseRule {
  final String style;
  final bool Function(Mark)? clearMark;
  final dynamic Function(String)? getAttrs;

  StyleParseRule({
    required this.style,
    this.clearMark,
    this.getAttrs,
    super.priority,
    super.consuming,
    super.context,
    super.mark,
    super.ignore,
    super.closeParent,
    super.skip,
    super.attrs,
  });
}

class DOMParser {
  final Schema schema;
  final List<ParseRule> rules;
  final List<TagParseRule> tags = [];
  final List<StyleParseRule> styles = [];
  final List<String> matchedStyles = [];
  late bool normalizeLists;

  DOMParser(this.schema, this.rules) {
    for (var rule in rules) {
      if (rule is TagParseRule) {
        tags.add(rule);
      } else if (rule is StyleParseRule) {
        String prop = RegExp(r'[^=]*').stringMatch(rule.style) ?? rule.style;
        if (!matchedStyles.contains(prop)) matchedStyles.add(prop);
        styles.add(rule);
      }
    }

    normalizeLists = !tags.any((r) {
      if (!RegExp(r'^(ul|ol)\b').hasMatch(r.tag) || r.node == null) return false;
      NodeType node = schema.nodes[r.node]!;
      return node.contentMatch.matchType(node) != null;
    });
  }

  PMNode parse(web.Node dom, [ParseOptions? options]) {
    options ??= ParseOptions();
    ParseContext context = ParseContext(this, options, false);
    context.addAll(dom, Mark.none, options.from, options.to);
    return context.finish() as PMNode;
  }

  Slice parseSlice(web.Node dom, [ParseOptions? options]) {
    options ??= ParseOptions();
    ParseContext context = ParseContext(this, options, true);
    context.addAll(dom, Mark.none, options.from, options.to);
    return Slice.maxOpen(context.finish() as Fragment);
  }

  TagParseRule? matchTag(web.Node dom, ParseContext context, [TagParseRule? after]) {
    int start = after != null ? tags.indexOf(after) + 1 : 0;
    for (int i = start; i < tags.length; i++) {
      TagParseRule rule = tags[i];
      if (_matches(dom, rule.tag) &&
          (rule.namespace == null || (dom is web.Element && dom.namespaceURI == rule.namespace)) &&
          (rule.context == null || context.matchesContext(rule.context!))) {
        if (rule.getAttrs != null && dom is web.HTMLElement) {
          dynamic result = rule.getAttrs!(dom);
          if (result == false) continue;
          rule.attrs = result is Map<String, dynamic> ? result : null;
        }
        return rule;
      }
    }
    return null;
  }

  StyleParseRule? matchStyle(String prop, String value, ParseContext context, [StyleParseRule? after]) {
    int start = after != null ? styles.indexOf(after) + 1 : 0;
    for (int i = start; i < styles.length; i++) {
      StyleParseRule rule = styles[i];
      String style = rule.style;
      if (!style.startsWith(prop) ||
          (rule.context != null && !context.matchesContext(rule.context!)) ||
          (style.length > prop.length &&
              (style.codeUnitAt(prop.length) != 61 || style.substring(prop.length + 1) != value))) {
        continue;
      }
      if (rule.getAttrs != null) {
        dynamic result = rule.getAttrs!(value);
        if (result == false) continue;
        rule.attrs = result is Map<String, dynamic> ? result : null;
      }
      return rule;
    }
    return null;
  }

  static List<ParseRule> schemaRules(Schema schema) {
    List<ParseRule> result = [];
    void insert(ParseRule rule) {
      int priority = rule.priority ?? 50;
      int i = 0;
      for (; i < result.length; i++) {
        int nextPriority = result[i].priority ?? 50;
        if (nextPriority < priority) break;
      }
      result.insert(i, rule);
    }

    for (String name in schema.marks.keys) {
      var parseDOM = schema.marks[name]!.spec.parseDOM;
      if (parseDOM != null) {
        for (var rule in parseDOM) {
          ParseRule newRule = _copyRule(rule);
          if (!(newRule.mark != null || newRule.ignore == true || (newRule is StyleParseRule && newRule.clearMark != null))) {
            newRule.mark = name;
          }
          insert(newRule);
        }
      }
    }

    for (String name in schema.nodes.keys) {
      var parseDOM = schema.nodes[name]!.spec.parseDOM;
      if (parseDOM != null) {
        for (var rule in parseDOM) {
          TagParseRule newRule = _copyRule(rule) as TagParseRule;
          if (newRule.node == null && newRule.ignore != true && newRule.mark == null) {
            newRule.node = name;
          }
          insert(newRule);
        }
      }
    }

    return result;
  }

  static DOMParser fromSchema(Schema schema) {
    schema.cached['domParser'] ??= DOMParser(schema, DOMParser.schemaRules(schema));
    return schema.cached['domParser'] as DOMParser;
  }
}

ParseRule _copyRule(ParseRule rule) {
  if (rule is TagParseRule) {
    return TagParseRule(
      tag: rule.tag,
      namespace: rule.namespace,
      node: rule.node,
      getAttrs: rule.getAttrs,
      contentElement: rule.contentElement,
      getContent: rule.getContent,
      preserveWhitespace: rule.preserveWhitespace,
      priority: rule.priority,
      consuming: rule.consuming,
      context: rule.context,
      mark: rule.mark,
      ignore: rule.ignore,
      closeParent: rule.closeParent,
      skip: rule.skip,
      attrs: rule.attrs != null ? Map.from(rule.attrs!) : null,
    );
  } else {
    rule = rule as StyleParseRule;
    return StyleParseRule(
      style: rule.style,
      clearMark: rule.clearMark,
      getAttrs: rule.getAttrs,
      priority: rule.priority,
      consuming: rule.consuming,
      context: rule.context,
      mark: rule.mark,
      ignore: rule.ignore,
      closeParent: rule.closeParent,
      skip: rule.skip,
      attrs: rule.attrs != null ? Map.from(rule.attrs!) : null,
    );
  }
}

const blockTags = {
  "address": true, "article": true, "aside": true, "blockquote": true, "body": true, "canvas": true,
  "dd": true, "div": true, "dl": true, "fieldset": true, "figcaption": true, "figure": true,
  "footer": true, "form": true, "h1": true, "h2": true, "h3": true, "h4": true, "h5": true,
  "h6": true, "header": true, "hgroup": true, "hr": true, "li": true, "noscript": true, "ol": true,
  "output": true, "p": true, "pre": true, "section": true, "table": true, "tfoot": true, "ul": true
};

const ignoreTags = {
  "head": true, "noscript": true, "object": true, "script": true, "style": true, "title": true
};

const listTags = {"ol": true, "ul": true};

const int OPT_PRESERVE_WS = 1;
const int OPT_PRESERVE_WS_FULL = 2;
const int OPT_OPEN_LEFT = 4;

int _wsOptionsFor(NodeType? type, dynamic preserveWhitespace, int base) {
  if (preserveWhitespace != null) {
    return (preserveWhitespace != false ? OPT_PRESERVE_WS : 0) |
           (preserveWhitespace == "full" ? OPT_PRESERVE_WS_FULL : 0);
  }
  return type != null && type.whitespace == "pre" ? OPT_PRESERVE_WS | OPT_PRESERVE_WS_FULL : base & ~OPT_OPEN_LEFT;
}

class NodeContext {
  NodeType? type;
  Map<String, dynamic>? attrs;
  List<Mark> marks;
  bool solid;
  ContentMatch? match;
  int options;
  List<PMNode> content = [];

  NodeContext(this.type, this.attrs, this.marks, this.solid, ContentMatch? match, this.options) {
    this.match = match ?? ((options & OPT_OPEN_LEFT) > 0 ? null : type?.contentMatch);
  }

  List<NodeType>? findWrapping(NodeType nodeType) {
    if (match == null) {
      if (type == null) return [];
      Fragment? fill = type!.contentMatch.fillBefore(Fragment.empty); // Simplified from Fragment.from(node)
      if (fill != null) {
        match = type!.contentMatch.matchFragment(fill);
      } else {
        ContentMatch start = type!.contentMatch;
        List<NodeType>? wrap = start.findWrapping(nodeType);
        if (wrap != null) {
          match = start;
          return wrap;
        } else {
          return null;
        }
      }
    }
    return match!.findWrapping(nodeType);
  }

  dynamic finish(bool openEnd) {
    if ((options & OPT_PRESERVE_WS) == 0) {
      PMNode? last = content.isNotEmpty ? content.last : null;
      if (last != null && last.isText) {
        String text = last.text!;
        Match? m = RegExp(r'[ \t\r\n\u000c]+$').firstMatch(text);
        if (m != null) {
          if (text.length == m.group(0)!.length) {
            content.removeLast();
          } else {
            content[content.length - 1] = (last as TextNode).withText(text.substring(0, text.length - m.group(0)!.length));
          }
        }
      }
    }
    Fragment frag = Fragment.from(content);
    if (!openEnd && match != null) {
      Fragment? filled = match!.fillBefore(Fragment.empty, true);
      if (filled != null) frag = frag.append(filled);
    }
    return type != null ? type!.create(attrs, frag, marks) : frag;
  }

  bool inlineContext(web.Node node) {
    if (type != null) return type!.inlineContent;
    if (content.isNotEmpty) return content[0].isInline;
    if (node.parentNode != null) {
      String name = (node.parentNode! as web.Element).tagName.toLowerCase();
      return !blockTags.containsKey(name);
    }
    return true;
  }
}

class ParseContext {
  final DOMParser parser;
  final ParseOptions options;
  final bool isOpen;
  
  int open = 0;
  List<Map<String, dynamic>>? find;
  bool needsBlock = false;
  List<NodeContext> nodes = [];
  bool localPreserveWS = false;

  ParseContext(this.parser, this.options, this.isOpen) {
    PMNode? topNode = options.topNode;
    int topOptions = _wsOptionsFor(null, options.preserveWhitespace, 0) | (isOpen ? OPT_OPEN_LEFT : 0);
    
    NodeContext topContext;
    if (topNode != null) {
      topContext = NodeContext(topNode.type, topNode.attrs, [], true,
                               options.topMatch ?? topNode.type.contentMatch, topOptions);
    } else if (isOpen) {
      topContext = NodeContext(null, null, [], true, null, topOptions);
    } else {
      topContext = NodeContext(parser.schema.topNodeType, null, [], true, null, topOptions);
    }
    nodes = [topContext];
    find = options.findPositions;
  }

  NodeContext get top => nodes[open];

  void addDOM(web.Node dom, List<Mark> marks) {
    if (dom.nodeType == 3) {
      addTextNode(dom as web.Text, marks);
    } else if (dom.nodeType == 1) {
      addElement(dom as web.HTMLElement, marks);
    }
  }

  void addTextNode(web.Text dom, List<Mark> marks) {
    String value = dom.data;
    NodeContext topContext = top;
    dynamic preserveWS = (topContext.options & OPT_PRESERVE_WS_FULL) > 0 ? "full"
        : localPreserveWS || (topContext.options & OPT_PRESERVE_WS) > 0;
    Schema schema = parser.schema;

    if (preserveWS == "full" || topContext.inlineContext(dom) || RegExp(r'[^ \t\r\n\u000c]').hasMatch(value)) {
      if (preserveWS != "full" && preserveWS != true) {
        value = value.replaceAll(RegExp(r'[ \t\r\n\u000c]+'), " ");
        if (RegExp(r'^[ \t\r\n\u000c]').hasMatch(value) && open == nodes.length - 1) {
          PMNode? nodeBefore = topContext.content.isNotEmpty ? topContext.content.last : null;
          web.Node? domNodeBefore = dom.previousSibling;
          if (nodeBefore == null ||
              (domNodeBefore is web.Element && domNodeBefore.tagName == 'BR') ||
              (nodeBefore.isText && RegExp(r'[ \t\r\n\u000c]$').hasMatch(nodeBefore.text!))) {
            value = value.substring(1);
          }
        }
      } else if (preserveWS == "full") {
        value = value.replaceAll(RegExp(r'\r\n?'), "\n");
      } else if (schema.linebreakReplacement != null && RegExp(r'[\r\n]').hasMatch(value) && topContext.findWrapping(schema.linebreakReplacement!) != null) {
        List<String> lines = value.split(RegExp(r'\r?\n|\r'));
        for (int i = 0; i < lines.length; i++) {
          if (i > 0) insertNode(schema.linebreakReplacement!.create(), marks, true);
          if (lines[i].isNotEmpty) insertNode(schema.text(lines[i]), marks, !RegExp(r'\S').hasMatch(lines[i]));
        }
        value = "";
      } else {
        value = value.replaceAll(RegExp(r'\r?\n|\r'), " ");
      }
      if (value.isNotEmpty) insertNode(schema.text(value), marks, !RegExp(r'\S').hasMatch(value));
      findInText(dom);
    } else {
      findInside(dom);
    }
  }

  void addElement(web.HTMLElement dom, List<Mark> marks, [TagParseRule? matchAfter]) {
    bool outerWS = localPreserveWS;
    NodeContext topContext = top;
    if (dom.tagName == "PRE") localPreserveWS = true;
    
    String name = dom.tagName.toLowerCase();
    if (listTags.containsKey(name) && parser.normalizeLists) _normalizeList(dom);
    
    TagParseRule? rule;
    if (options.ruleFromNode != null) {
      rule = options.ruleFromNode!(dom);
    }
    if (rule == null) {
      rule = parser.matchTag(dom, this, matchAfter);
    }

    if (rule != null ? rule.ignore == true : ignoreTags.containsKey(name)) {
      findInside(dom);
      ignoreFallback(dom, marks);
    } else if (rule == null || rule.skip == true || rule.closeParent == true) {
      if (rule != null && rule.closeParent == true) open = max(0, open - 1);
      
      bool sync = false;
      bool oldNeedsBlock = needsBlock;
      if (blockTags.containsKey(name)) {
        if (top.content.isNotEmpty && top.content[0].isInline && open > 0) {
          open--;
          topContext = top;
        }
        sync = true;
        if (topContext.type == null) needsBlock = true;
      } else if (dom.firstChild == null) {
        leafFallback(dom, marks);
        localPreserveWS = outerWS;
        return;
      }

      List<Mark>? innerMarks = (rule != null && rule.skip == true) ? marks : readStyles(dom, marks);
      if (innerMarks != null) addAll(dom, innerMarks);
      if (sync) this.sync(topContext);
      needsBlock = oldNeedsBlock;
    } else {
      List<Mark>? innerMarks = readStyles(dom, marks);
      if (innerMarks != null) {
        addElementByRule(dom, rule, innerMarks, rule.consuming == false ? rule : null);
      }
    }
    localPreserveWS = outerWS;
  }

  void leafFallback(web.Node dom, List<Mark> marks) {
    if (dom is web.Element && dom.tagName == "BR" && top.type != null && top.type!.inlineContent) {
      // Create text node equivalent of "\n" ?
      // Simplified: Just ignore for now or add schema text
    }
  }

  void ignoreFallback(web.Node dom, List<Mark> marks) {
    if (dom is web.Element && dom.tagName == "BR" && (top.type == null || !top.type!.inlineContent)) {
      findPlace(parser.schema.text("-"), marks, true);
    }
  }

  List<Mark>? readStyles(web.HTMLElement dom, List<Mark> marks) {
    // Highly simplified since retrieving computed styles across all browsers is complex.
    return marks;
  }

  void addElementByRule(web.HTMLElement dom, TagParseRule rule, List<Mark> marks, [TagParseRule? continueAfter]) {
    bool sync = false;
    NodeType? nodeType;
    if (rule.node != null) {
      nodeType = parser.schema.nodes[rule.node];
      if (nodeType != null) {
        if (!nodeType.isLeaf) {
          List<Mark>? inner = enter(nodeType, rule.attrs, marks, rule.preserveWhitespace);
          if (inner != null) {
            sync = true;
            marks = inner;
          }
        } else if (!insertNode(nodeType.create(rule.attrs), marks, dom.tagName == "BR")) {
          leafFallback(dom, marks);
        }
      }
    } else {
      MarkType markType = parser.schema.marks[rule.mark!]!;
      marks = List.from(marks)..add(markType.create(rule.attrs));
    }
    
    NodeContext startIn = top;

    if (nodeType != null && nodeType.isLeaf) {
      findInside(dom);
    } else if (continueAfter != null) {
      addElement(dom, marks, continueAfter);
    } else if (rule.getContent != null) {
      findInside(dom);
      Fragment content = rule.getContent!(dom, parser.schema);
      for (int i = 0; i < content.childCount; i++) {
        insertNode(content.child(i), marks, false);
      }
    } else {
      web.Node contentDOM = dom;
      if (rule.contentElement is String) {
        contentDOM = dom.querySelector(rule.contentElement as String) ?? dom;
      } else if (rule.contentElement is Function) {
        contentDOM = (rule.contentElement as Function)(dom);
      }
      
      findAround(dom, contentDOM, true);
      addAll(contentDOM, marks);
      findAround(dom, contentDOM, false);
    }
    if (sync && this.sync(startIn)) open--;
  }

  void addAll(web.Node parent, List<Mark> marks, [int? startIndex, int? endIndex]) {
    int index = startIndex ?? 0;
    web.Node? dom = startIndex != null ? _childAt(parent, startIndex) : parent.firstChild;
    web.Node? end = endIndex != null ? _childAt(parent, endIndex) : null;
    
    for (; dom != null && dom != end; dom = dom.nextSibling, ++index) {
      findAtPoint(parent, index);
      addDOM(dom, marks);
    }
    findAtPoint(parent, index);
  }

  web.Node? _childAt(web.Node parent, int index) {
    web.NodeList children = parent.childNodes;
    if (index >= 0 && index < children.length) return children.item(index);
    return null;
  }

  List<Mark>? findPlace(PMNode node, List<Mark> marks, bool cautious) {
    List<NodeType>? route;
    NodeContext? syncCtx;
    for (int depth = open, penalty = 0; depth >= 0; depth--) {
      NodeContext cx = nodes[depth];
      List<NodeType>? found = cx.findWrapping(node.type);
      if (found != null && (route == null || route.length > found.length + penalty)) {
        route = found;
        syncCtx = cx;
        if (found.isEmpty) break;
      }
      if (cx.solid) {
        if (cautious) break;
        penalty += 2;
      }
    }
    if (route == null) return null;
    sync(syncCtx!);
    for (int i = 0; i < route.length; i++) {
      marks = enterInner(route[i], null, marks, false);
    }
    return marks;
  }

  bool insertNode(PMNode node, List<Mark> marks, bool cautious) {
    if (node.isInline && needsBlock && top.type == null) {
      NodeType? block = textblockFromContext();
      if (block != null) marks = enterInner(block, null, marks);
    }
    List<Mark>? innerMarks = findPlace(node, marks, cautious);
    if (innerMarks != null) {
      closeExtra();
      NodeContext topContext = top;
      if (topContext.match != null) topContext.match = topContext.match!.matchType(node.type);
      List<Mark> nodeMarks = [];
      for (Mark m in [...innerMarks, ...node.marks]) {
        if (topContext.type != null ? topContext.type!.allowsMarkType(m.type) : _markMayApply(m.type, node.type)) {
          nodeMarks = m.addToSet(nodeMarks);
        }
      }
      topContext.content.add(node.mark(nodeMarks));
      return true;
    }
    return false;
  }

  List<Mark>? enter(NodeType type, Map<String, dynamic>? attrs, List<Mark> marks, [dynamic preserveWS]) {
    List<Mark>? innerMarks = findPlace(type.create(attrs), marks, false);
    if (innerMarks != null) innerMarks = enterInner(type, attrs, marks, true, preserveWS);
    return innerMarks;
  }

  List<Mark> enterInner(NodeType type, Map<String, dynamic>? attrs, List<Mark> marks, [bool solid = false, dynamic preserveWS]) {
    closeExtra();
    NodeContext topContext = top;
    if (topContext.match != null) topContext.match = topContext.match!.matchType(type);
    int options = _wsOptionsFor(type, preserveWS, topContext.options);
    if ((topContext.options & OPT_OPEN_LEFT) > 0 && topContext.content.isEmpty) options |= OPT_OPEN_LEFT;
    
    List<Mark> applyMarks = [];
    List<Mark> nextMarks = [];
    for (Mark m in marks) {
      if (topContext.type != null ? topContext.type!.allowsMarkType(m.type) : _markMayApply(m.type, type)) {
        applyMarks = m.addToSet(applyMarks);
      } else {
        nextMarks.add(m);
      }
    }
    
    nodes.add(NodeContext(type, attrs, applyMarks, solid, null, options));
    open++;
    return nextMarks;
  }

  void closeExtra([bool openEnd = false]) {
    int i = nodes.length - 1;
    if (i > open) {
      for (; i > open; i--) {
        nodes[i - 1].content.add(nodes[i].finish(openEnd) as PMNode);
      }
      nodes.length = open + 1;
    }
  }

  dynamic finish() {
    open = 0;
    closeExtra(isOpen);
    return nodes[0].finish(isOpen || (options.topOpen == true));
  }

  bool sync(NodeContext to) {
    for (int i = open; i >= 0; i--) {
      if (nodes[i] == to) {
        open = i;
        return true;
      } else if (localPreserveWS) {
        nodes[i].options |= OPT_PRESERVE_WS;
      }
    }
    return false;
  }

  int get currentPos {
    closeExtra();
    int pos = 0;
    for (int i = open; i >= 0; i--) {
      List<PMNode> content = nodes[i].content;
      for (int j = content.length - 1; j >= 0; j--) {
        pos += content[j].nodeSize;
      }
      if (i > 0) pos++;
    }
    return pos;
  }

  void findAtPoint(web.Node parent, int offset) {
    // Optional metrics mapping
  }

  void findInside(web.Node parent) {}

  void findAround(web.Node parent, web.Node content, bool before) {}

  void findInText(web.Text textNode) {}

  bool matchesContext(String context) {
    return false; // Simplified
  }

  NodeType? textblockFromContext() {
    ResolvedPos? ctx = options.context;
    if (ctx != null) {
      for (int d = ctx.depth; d >= 0; d--) {
        NodeType? deflt = ctx.node(d).contentMatchAt(ctx.indexAfter(d)).defaultType;
        if (deflt != null && deflt.isTextblock && deflt.defaultAttrs.isNotEmpty) return deflt;
      }
    }
    for (String name in parser.schema.nodes.keys) {
      NodeType type = parser.schema.nodes[name]!;
      if (type.isTextblock && type.defaultAttrs.isNotEmpty) return type;
    }
    return null;
  }
}

bool _matches(web.Node dom, String selector) {
  if (dom is web.Element) {
    return dom.matches(selector);
  }
  return false;
}

void _normalizeList(web.Node dom) {
  web.Node? prevItem;
  web.Node? child = dom.firstChild;
  while (child != null) {
    web.Node? next = child.nextSibling;
    String? name = child is web.Element ? child.tagName.toLowerCase() : null;
    if (name != null && listTags.containsKey(name) && prevItem != null) {
      prevItem.appendChild(child);
    } else if (name == "li") {
      prevItem = child;
    } else if (name != null) {
      prevItem = null;
    }
    child = next;
  }
}

bool _markMayApply(MarkType markType, NodeType nodeType) {
  Map<String, NodeType> nodes = nodeType.schema.nodes;
  for (String name in nodes.keys) {
    NodeType parent = nodes[name]!;
    if (!parent.allowsMarkType(markType)) continue;
    
    List<ContentMatch> seen = [];
    bool scan(ContentMatch match) {
      seen.add(match);
      for (int i = 0; i < match.edgeCount; i++) {
        var edge = match.edge(i);
        if (edge.type == nodeType) return true;
        if (!seen.contains(edge.next) && scan(edge.next)) return true;
      }
      return false;
    }
    if (scan(parent.contentMatch)) return true;
  }
  return false;
}
