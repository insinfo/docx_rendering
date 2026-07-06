part of '../html_renderer.dart';

List<web.Node> _renderMmlElements(HtmlRenderer self, List<OpenXmlElement>? elements) {
  if (elements == null) return [];
  return elements.map((e) => self.renderElement(e)).whereType<web.Node>().toList();
}

web.Node _renderContainerNS(HtmlRenderer self, OpenXmlElement elem, String ns, String tagName, [Map<String, dynamic>? props]) {
  final Map<String, dynamic> elementMap = {
    'ns': ns,
    'tagName': tagName,
    'children': _renderMmlElements(self, elem.children)
  };
  if (props != null) {
    elementMap.addAll(props);
  }
  return self.hFunc(elementMap) as web.Node;
}

web.Node _createMathMLElement(HtmlRenderer self, String tagName, [Map<String, dynamic>? props, List<dynamic>? children]) {
  final Map<String, dynamic> elementMap = {
    'ns': HtmlNs.mathML,
    'tagName': tagName,
  };
  if (children != null) {
    elementMap['children'] = children;
  }
  if (props != null) {
    elementMap.addAll(props);
  }
  return self.hFunc(elementMap) as web.Node;
}

web.Node _renderMmlRadical(HtmlRenderer self, OpenXmlElement elem) {
  final base = (elem.children ?? []).firstWhere((el) => el.type == DomType.mmlBase, orElse: () => OpenXmlElementBase(type: DomType.mmlBase));
  final props = elem.props;
  final hideDegree = props is Map ? props['hideDegree'] == true : false;

  if (hideDegree) {
    return _createMathMLElement(self, 'msqrt', null, [self.renderElement(base)].whereType<web.Node>().toList());
  }

  final degree = (elem.children ?? []).firstWhere((el) => el.type == DomType.mmlDegree, orElse: () => OpenXmlElementBase(type: DomType.mmlDegree));
  return _createMathMLElement(self, 'mroot', null, [self.renderElement(base), self.renderElement(degree)].whereType<web.Node>().toList());
}

web.Node _renderMmlDelimiter(HtmlRenderer self, OpenXmlElement elem) {
  final children = <web.Node>[];
  final props = elem.props;
  final beginChar = (props is Map ? props['beginChar'] : null) as String? ?? '(';
  final endChar = (props is Map ? props['endChar'] : null) as String? ?? ')';

  children.add(_createMathMLElement(self, 'mo', null, [beginChar]));
  children.addAll(_renderMmlElements(self, elem.children));
  children.add(_createMathMLElement(self, 'mo', null, [endChar]));

  return _createMathMLElement(self, 'mrow', null, children);
}

web.Node _renderMmlNary(HtmlRenderer self, OpenXmlElement elem) {
  final children = <web.Node>[];
  final grouped = <DomType, OpenXmlElement>{};
  for (final child in elem.children ?? <OpenXmlElement>[]) {
    grouped[child.type] = child;
  }

  final sup = grouped[DomType.mmlSuperArgument];
  final sub = grouped[DomType.mmlSubArgument];
  
  final supElem = sup != null ? _createMathMLElement(self, 'mo', null, [self.renderElement(sup)].whereType<web.Node>().toList()) : null;
  final subElem = sub != null ? _createMathMLElement(self, 'mo', null, [self.renderElement(sub)].whereType<web.Node>().toList()) : null;

  final props = elem.props;
  final char = (props is Map ? props['char'] : null) as String? ?? '\u222B';
  final charElem = _createMathMLElement(self, 'mo', null, [char]);

  if (supElem != null && subElem != null) {
    children.add(_createMathMLElement(self, 'munderover', null, [charElem, subElem, supElem]));
  } else if (supElem != null) {
    children.add(_createMathMLElement(self, 'mover', null, [charElem, supElem]));
  } else if (subElem != null) {
    children.add(_createMathMLElement(self, 'munder', null, [charElem, subElem]));
  } else {
    children.add(charElem);
  }

  final base = grouped[DomType.mmlBase];
  if (base != null) {
    children.addAll(_renderMmlElements(self, base.children));
  }

  return _createMathMLElement(self, 'mrow', null, children);
}

web.Node _renderMmlPreSubSuper(HtmlRenderer self, OpenXmlElement elem) {
  final children = <web.Node>[];
  final grouped = <DomType, OpenXmlElement>{};
  for (final child in elem.children ?? <OpenXmlElement>[]) {
    grouped[child.type] = child;
  }

  final sup = grouped[DomType.mmlSuperArgument];
  final sub = grouped[DomType.mmlSubArgument];
  
  final supElem = sup != null ? _createMathMLElement(self, 'mo', null, [self.renderElement(sup)].whereType<web.Node>().toList()) : null;
  final subElem = sub != null ? _createMathMLElement(self, 'mo', null, [self.renderElement(sub)].whereType<web.Node>().toList()) : null;
  final stubElem = _createMathMLElement(self, 'mo');

  children.add(_createMathMLElement(self, 'msubsup', null, [stubElem, subElem, supElem].whereType<web.Node>().toList()));
  
  final base = grouped[DomType.mmlBase];
  if (base != null) {
    children.addAll(_renderMmlElements(self, base.children));
  }

  return _createMathMLElement(self, 'mrow', null, children);
}

web.Node _renderMmlGroupChar(HtmlRenderer self, OpenXmlElement elem) {
  final props = elem.props;
  final tagName = (props is Map && props['verticalJustification'] == 'bot') ? 'mover' : 'munder';
  final result = _renderContainerNS(self, elem, HtmlNs.mathML, tagName) as web.HTMLElement;

  if (props is Map && props['char'] != null) {
    result.appendChild(_createMathMLElement(self, 'mo', null, [props['char'].toString()]));
  }

  return result;
}

web.Node _renderMmlBar(HtmlRenderer self, OpenXmlElement elem) {
  final style = <String, String>{};
  final props = elem.props;
  final position = props is Map ? props['position'] : null;

  switch (position) {
    case 'top':
      style['text-decoration'] = 'overline';
      break;
    case 'bottom':
      style['text-decoration'] = 'underline';
      break;
  }

  return _renderContainerNS(self, elem, HtmlNs.mathML, 'mrow', {'style': style});
}

web.Node _renderMmlRun(HtmlRenderer self, OpenXmlElement elem) {
  final Map<String, dynamic> css = Map<String, dynamic>.from(elem.cssStyle ?? {});
  css.remove('\$lang');
  
  final className = cx([
    elem.className,
    elem.styleName != null ? _processStyleName(self, elem.styleName) : null
  ]);

  final elementMap = <String, dynamic>{
    'ns': HtmlNs.mathML,
    'tagName': 'ms',
    'className': className,
    'style': css,
    'children': _renderMmlElements(self, elem.children)
  };

  if (elem.cssStyle != null && elem.cssStyle!['\$lang'] != null) {
    elementMap['lang'] = elem.cssStyle!['\$lang'];
  }

  return self.hFunc(elementMap) as web.Node;
}

web.Node _renderMllList(HtmlRenderer self, OpenXmlElement elem) {
  final renderedChildren = _renderMmlElements(self, elem.children);
  final mtrChildren = renderedChildren.map((x) => _createMathMLElement(self, 'mtr', null, [
    _createMathMLElement(self, 'mtd', null, [x])
  ])).toList();

  final Map<String, dynamic> css = Map<String, dynamic>.from(elem.cssStyle ?? {});
  css.remove('\$lang');
  
  final className = cx([
    elem.className,
    elem.styleName != null ? _processStyleName(self, elem.styleName) : null
  ]);

  final elementMap = <String, dynamic>{
    'ns': HtmlNs.mathML,
    'tagName': 'mtable',
    'className': className,
    'style': css,
    'children': mtrChildren
  };

  if (elem.cssStyle != null && elem.cssStyle!['\$lang'] != null) {
    elementMap['lang'] = elem.cssStyle!['\$lang'];
  }

  return self.hFunc(elementMap) as web.Node;
}
