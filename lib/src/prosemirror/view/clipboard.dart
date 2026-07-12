// Port of prosemirror-view/src/clipboard.ts.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../model/index.dart';
import '../model/to_dom.dart';
import '../model/from_dom.dart';
import 'browser.dart' as browser;
import 'index.dart';

/// Serialize the given slice for the clipboard. Returns the wrapping
/// DOM element, the plain-text representation, and the (possibly
/// transformed) slice.
///
/// The TS version returns `{dom: HTMLElement, text: string, slice: Slice}`;
/// here that is expressed as a Dart record.
({web.HTMLElement dom, String text, Slice slice}) serializeForClipboard(
    EditorView view, Slice slice) {
  view.someProp('transformCopied', (f) {
    slice = f(slice, view) as Slice;
  });

  List<dynamic> context = [];
  Fragment content = slice.content;
  int openStart = slice.openStart, openEnd = slice.openEnd;
  while (openStart > 1 &&
      openEnd > 1 &&
      content.childCount == 1 &&
      content.firstChild!.childCount == 1) {
    openStart--;
    openEnd--;
    PMNode node = content.firstChild!;
    context.add(node.type.name);
    context.add(
        !identical(node.attrs, node.type.defaultAttrs) ? node.attrs : null);
    content = node.content;
  }

  DOMSerializer serializer =
      view.someProp('clipboardSerializer') as DOMSerializer? ??
          DOMSerializer.fromSchema(view.state.schema);
  web.Document doc = detachedDoc();
  web.HTMLElement wrap = doc.createElement('div') as web.HTMLElement;
  wrap.appendChild(serializer.serializeFragment(content, document: doc));

  web.Node? firstChild = wrap.firstChild;
  List<String>? needsWrap;
  int wrappers = 0;
  while (firstChild != null &&
      firstChild.nodeType == 1 &&
      (needsWrap = wrapMap[firstChild.nodeName.toLowerCase()]) != null) {
    for (int i = needsWrap!.length - 1; i >= 0; i--) {
      web.Element wrapper = doc.createElement(needsWrap[i]);
      while (wrap.firstChild != null) {
        wrapper.appendChild(wrap.firstChild!);
      }
      wrap.appendChild(wrapper);
      wrappers++;
    }
    firstChild = wrap.firstChild;
  }

  if (firstChild != null && firstChild.nodeType == 1) {
    (firstChild as web.Element).setAttribute('data-pm-slice',
        '$openStart $openEnd${wrappers > 0 ? " -$wrappers" : ""} ${jsonEncode(context)}');
  }

  String text =
      view.someProp('clipboardTextSerializer', (f) => f(slice, view))
              as String? ??
          slice.content
              .textBetween(0, slice.content.size, blockSeparator: '\n\n');

  return (dom: wrap, text: text, slice: slice);
}

/// Read a slice of content from the clipboard (or drop data).
Slice? parseFromClipboard(EditorView view, String text, String? html,
    bool plainText, ResolvedPos $context) {
  bool inCode = $context.parent.type.spec.code == true;
  web.HTMLElement? dom;
  Slice? slice;
  if ((html == null || html.isEmpty) && text.isEmpty) return null;
  bool asText =
      text.isNotEmpty && (plainText || inCode || html == null || html.isEmpty);
  if (asText) {
    view.someProp('transformPastedText', (f) {
      text = f(text, inCode || plainText, view) as String;
    });
    if (inCode) {
      slice = Slice(
          Fragment.from(
              view.state.schema.text(text.replaceAll(RegExp(r'\r\n?'), '\n'))),
          0,
          0);
      view.someProp('transformPasted', (f) {
        slice = f(slice, view, true) as Slice;
      });
      return slice;
    }
    dynamic parsed = view.someProp(
        'clipboardTextParser', (f) => f(text, $context, plainText, view));
    if (parsed != null) {
      slice = parsed as Slice;
    } else {
      List<Mark> marks = $context.marks();
      Schema schema = view.state.schema;
      DOMSerializer serializer = DOMSerializer.fromSchema(schema);
      web.HTMLElement divDom =
          web.document.createElement('div') as web.HTMLElement;
      dom = divDom;
      for (String block in text.split(RegExp(r'(?:\r\n?|\n)+'))) {
        web.Node p = divDom.appendChild(web.document.createElement('p'));
        if (block.isNotEmpty) {
          p.appendChild(serializer.serializeNode(schema.text(block, marks)));
        }
      }
    }
  } else {
    view.someProp('transformPastedHTML', (f) {
      html = f(html, view) as String;
    });
    dom = readHTML(html!);
    if (browser.webkit) restoreReplacedSpaces(dom);
  }

  web.Element? contextNode = dom?.querySelector('[data-pm-slice]');
  RegExpMatch? sliceData;
  if (contextNode != null) {
    sliceData = RegExp(r'^(\d+) (\d+)(?: -(\d+))? (.*)')
        .firstMatch(contextNode.getAttribute('data-pm-slice') ?? '');
  }
  if (sliceData != null && sliceData.group(3) != null) {
    for (int i = int.parse(sliceData.group(3)!); i > 0; i--) {
      web.Node? child = dom!.firstChild;
      while (child != null && child.nodeType != 1) {
        child = child.nextSibling;
      }
      if (child == null) break;
      dom = child as web.HTMLElement;
    }
  }

  if (slice == null) {
    DOMParser parser = view.someProp('clipboardParser') as DOMParser? ??
        view.someProp('domParser') as DOMParser? ??
        DOMParser.fromSchema(view.state.schema);
    slice = parser.parseSlice(
        dom!,
        ParseOptions(
          preserveWhitespace: asText || sliceData != null,
          context: $context,
          ruleFromNode: (web.Node dom) {
            if (dom.nodeName == 'BR' &&
                dom.nextSibling == null &&
                dom.parentNode != null &&
                !inlineParents.hasMatch(dom.parentNode!.nodeName)) {
              return TagParseRule(tag: 'br', ignore: true);
            }
            return null;
          },
        ));
  }
  if (sliceData != null) {
    slice = addContext(
        closeSlice(slice, int.parse(sliceData.group(1)!),
            int.parse(sliceData.group(2)!)),
        sliceData.group(4)!);
  } else {
    // HTML wasn't created by ProseMirror. Make sure top-level siblings are coherent
    slice = Slice.maxOpen(normalizeSiblings(slice.content, $context), true);
    if (slice.openStart > 0 || slice.openEnd > 0) {
      int openStart = 0, openEnd = 0;
      for (PMNode? node = slice.content.firstChild;
          openStart < slice.openStart && node!.type.spec.isolating != true;
          openStart++, node = node.firstChild) {}
      for (PMNode? node = slice.content.lastChild;
          openEnd < slice.openEnd && node!.type.spec.isolating != true;
          openEnd++, node = node.lastChild) {}
      slice = closeSlice(slice, openStart, openEnd);
    }
  }

  view.someProp('transformPasted', (f) {
    slice = f(slice, view, asText) as Slice;
  });
  return slice;
}

final RegExp inlineParents = RegExp(
    r'^(a|abbr|acronym|b|cite|code|del|em|i|ins|kbd|label|output|q|ruby|s|samp|span|strong|sub|sup|time|u|tt|var)$',
    caseSensitive: false);

// Takes a slice parsed with parseSlice, which means there hasn't been
// any content-expression checking done on the top nodes, tries to
// find a parent node in the current context that might fit the nodes,
// and if successful, rebuilds the slice so that it fits into that parent.
//
// This addresses the problem that Transform.replace expects a
// coherent slice, and will fail to place a set of siblings that don't
// fit anywhere in the schema.
Fragment normalizeSiblings(Fragment fragment, ResolvedPos $context) {
  if (fragment.childCount < 2) return fragment;
  for (int d = $context.depth; d >= 0; d--) {
    PMNode parent = $context.node(d);
    ContentMatch match = parent.contentMatchAt($context.index(d));
    List<NodeType>? lastWrap;
    List<PMNode>? result = [];
    fragment.forEach((node, offset, index) {
      if (result == null) return;
      List<NodeType>? wrap = match.findWrapping(node.type);
      if (wrap == null) {
        result = null;
        return;
      }
      PMNode? inLast;
      if (result!.isNotEmpty && lastWrap!.isNotEmpty) {
        inLast =
            addToSibling(wrap, lastWrap!, node, result![result!.length - 1], 0);
      }
      if (inLast != null) {
        result![result!.length - 1] = inLast;
      } else {
        if (result!.isNotEmpty) {
          result![result!.length - 1] =
              closeRight(result![result!.length - 1], lastWrap!.length);
        }
        PMNode wrapped = withWrappers(node, wrap);
        result!.add(wrapped);
        match = match.matchType(wrapped.type)!;
        lastWrap = wrap;
      }
    });
    if (result != null) return Fragment.from(result);
  }
  return fragment;
}

PMNode withWrappers(PMNode node, List<NodeType> wrap, [int from = 0]) {
  for (int i = wrap.length - 1; i >= from; i--) {
    node = wrap[i].create(null, Fragment.from(node));
  }
  return node;
}

// Used to group adjacent nodes wrapped in similar parents by
// normalizeSiblings into the same parent node
PMNode? addToSibling(List<NodeType> wrap, List<NodeType> lastWrap, PMNode node,
    PMNode sibling, int depth) {
  if (depth < wrap.length &&
      depth < lastWrap.length &&
      wrap[depth] == lastWrap[depth]) {
    PMNode? inner =
        addToSibling(wrap, lastWrap, node, sibling.lastChild!, depth + 1);
    if (inner != null) {
      return sibling
          .copy(sibling.content.replaceChild(sibling.childCount - 1, inner));
    }
    ContentMatch match = sibling.contentMatchAt(sibling.childCount);
    if (match.matchType(
            depth == wrap.length - 1 ? node.type : wrap[depth + 1]) !=
        null) {
      return sibling.copy(sibling.content
          .append(Fragment.from(withWrappers(node, wrap, depth + 1))));
    }
  }
  return null;
}

PMNode closeRight(PMNode node, int depth) {
  if (depth == 0) return node;
  Fragment fragment = node.content
      .replaceChild(node.childCount - 1, closeRight(node.lastChild!, depth - 1));
  Fragment fill =
      node.contentMatchAt(node.childCount).fillBefore(Fragment.empty, true)!;
  return node.copy(fragment.append(fill));
}

Fragment closeRange(
    Fragment fragment, int side, int from, int to, int depth, int openEnd) {
  PMNode node = side < 0 ? fragment.firstChild! : fragment.lastChild!;
  Fragment inner = node.content;
  if (fragment.childCount > 1) openEnd = 0;
  if (depth < to - 1) {
    inner = closeRange(inner, side, from, to, depth + 1, openEnd);
  }
  if (depth >= from) {
    inner = side < 0
        ? node
            .contentMatchAt(0)
            .fillBefore(inner, openEnd <= depth)!
            .append(inner)
        : inner.append(node
            .contentMatchAt(node.childCount)
            .fillBefore(Fragment.empty, true)!);
  }
  return fragment.replaceChild(
      side < 0 ? 0 : fragment.childCount - 1, node.copy(inner));
}

Slice closeSlice(Slice slice, int openStart, int openEnd) {
  if (openStart < slice.openStart) {
    slice = Slice(
        closeRange(
            slice.content, -1, openStart, slice.openStart, 0, slice.openEnd),
        openStart,
        slice.openEnd);
  }
  if (openEnd < slice.openEnd) {
    slice = Slice(closeRange(slice.content, 1, openEnd, slice.openEnd, 0, 0),
        slice.openStart, openEnd);
  }
  return slice;
}

// Trick from jQuery -- some elements must be wrapped in other
// elements for innerHTML to work. I.e. if you do `div.innerHTML =
// "<td>..</td>"` the table cells are ignored.
const Map<String, List<String>> wrapMap = {
  'thead': ['table'],
  'tbody': ['table'],
  'tfoot': ['table'],
  'caption': ['table'],
  'colgroup': ['table'],
  'col': ['table', 'colgroup'],
  'tr': ['table', 'tbody'],
  'td': ['table', 'tbody', 'tr'],
  'th': ['table', 'tbody', 'tr'],
};

web.Document detachedDoc() {
  return web.document.implementation.createHTMLDocument('title');
}

JSObject? _policy;

JSAny _maybeWrapTrusted(String html) {
  JSAny? trustedTypes = (web.window as JSObject).getProperty('trustedTypes'.toJS);
  if (trustedTypes == null || trustedTypes.isUndefinedOrNull) return html.toJS;
  // With the require-trusted-types-for CSP, Chrome will block
  // innerHTML, even on a detached document. This wraps the string in
  // a way that makes the browser allow us to use its parser again.
  JSObject tt = trustedTypes as JSObject;
  if (_policy == null) {
    JSAny? defaultPolicy = tt.getProperty('defaultPolicy'.toJS);
    if (defaultPolicy != null && !defaultPolicy.isUndefinedOrNull) {
      _policy = defaultPolicy as JSObject;
    } else {
      JSObject options = JSObject();
      options.setProperty('createHTML'.toJS, ((JSString s) => s).toJS);
      _policy = tt.callMethod<JSObject>(
          'createPolicy'.toJS, 'ProseMirrorClipboard'.toJS, options);
    }
  }
  return _policy!.callMethod<JSAny>('createHTML'.toJS, html.toJS);
}

web.HTMLElement readHTML(String html) {
  RegExpMatch? metas = RegExp(r'^(\s*<meta [^>]*>)*').firstMatch(html);
  if (metas != null) html = html.substring(metas.group(0)!.length);
  web.Document doc = detachedDoc();
  web.Element elt = doc.body!;
  RegExpMatch? firstTag =
      RegExp(r'<([a-z][^>\s]+)', caseSensitive: false).firstMatch(html);
  List<String>? wrap;
  if (firstTag != null) wrap = wrapMap[firstTag.group(1)!.toLowerCase()];
  if (wrap != null) {
    html = wrap.map((n) => '<$n>').join() +
        html +
        wrap.reversed.map((n) => '</$n>').join();
  }
  elt.innerHTML = _maybeWrapTrusted(html);
  if (wrap != null) {
    for (int i = 0; i < wrap.length; i++) {
      elt = elt.querySelector(wrap[i]) ?? elt;
    }
  }
  // Inline styles defined in the pasted content, so that parse rules pick them up
  for (int i = 0; i < doc.styleSheets.length; i++) {
    web.StyleSheet? sheet = doc.styleSheets.item(i);
    if (sheet == null || !sheet.isA<web.CSSStyleSheet>()) continue;
    web.CSSRuleList rules = (sheet as web.CSSStyleSheet).cssRules;
    for (int j = 0; j < rules.length; j++) {
      web.CSSRule? rule = rules.item(j);
      if (rule != null && rule.isA<web.CSSStyleRule>()) {
        web.CSSStyleRule styleRule = rule as web.CSSStyleRule;
        // In package:web 1.1.x `CSSStyleRule.style` is typed as JSObject.
        web.CSSStyleDeclaration ruleStyle =
            styleRule.style as web.CSSStyleDeclaration;
        web.NodeList matches = elt.querySelectorAll(styleRule.selectorText);
        for (int k = 0; k < matches.length; k++) {
          web.HTMLElement match = matches.item(k) as web.HTMLElement;
          match.style.cssText += ruleStyle.cssText;
        }
      }
    }
  }
  return elt as web.HTMLElement;
}

// Webkit browsers do some hard-to-predict replacement of regular
// spaces with non-breaking spaces when putting content on the
// clipboard. This tries to convert such non-breaking spaces (which
// will be wrapped in a plain span on Chrome, a span with class
// Apple-converted-space on Safari) back to regular spaces.
void restoreReplacedSpaces(web.HTMLElement dom) {
  web.NodeList nodes = dom.querySelectorAll(browser.chrome
      ? 'span:not([class]):not([style])'
      : 'span.Apple-converted-space');
  for (int i = 0; i < nodes.length; i++) {
    web.Node node = nodes.item(i)!;
    if (node.childNodes.length == 1 &&
        node.textContent == String.fromCharCode(0xa0) && // U+00A0 nbsp
        node.parentNode != null) {
      node.parentNode!
          .replaceChild(dom.ownerDocument!.createTextNode(' '), node);
    }
  }
}

Slice addContext(Slice slice, String context) {
  if (slice.size == 0) return slice;
  Schema schema = slice.content.firstChild!.type.schema;
  List<dynamic> array;
  try {
    array = jsonDecode(context) as List<dynamic>;
  } catch (e) {
    return slice;
  }
  Fragment content = slice.content;
  int openStart = slice.openStart, openEnd = slice.openEnd;
  for (int i = array.length - 2; i >= 0; i -= 2) {
    NodeType? type = schema.nodes[array[i]];
    if (type == null || type.hasRequiredAttrs()) break;
    content = Fragment.from(type.create(
        (array[i + 1] as Map?)?.cast<String, dynamic>(), content));
    openStart++;
    openEnd++;
  }
  return Slice(content, openStart, openEnd);
}
