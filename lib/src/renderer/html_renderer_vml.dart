part of '../html_renderer.dart';

web.HTMLElement _renderContainer(HtmlRenderer self, OpenXmlElement elem, String tagName) {
  final children = elem.children != null 
      ? elem.children!.map((e) => self.renderElement(e)).whereType<web.Node>().toList()
      : <web.Node>[];
  return self.hFunc({
    'tagName': tagName,
    'children': children
  }) as web.HTMLElement;
}

web.Node _renderVmlPicture(HtmlRenderer self, OpenXmlElement elem) {
  return _renderContainer(self, elem, 'div');
}

web.Node _renderVmlElement(HtmlRenderer self, VmlElement elem) {
  final Map<String, dynamic> containerProps = {
    'ns': HtmlNs.svg,
    'tagName': 'svg',
  };
  if (elem.cssStyleText != null) {
    containerProps['style'] = elem.cssStyleText!;
  }
  
  final container = self.hFunc(containerProps) as web.SVGElement;
  final result = _renderVmlChildElement(self, elem);

  if (elem.imageHref?.id != null) {
    self.tasks.add(self.document.loadDocumentImage(elem.imageHref!.id!, self.currentPart).then((url) {
      if (url != null) {
        result.setAttribute('href', url);
      }
    }));
  }

  container.appendChild(result);

  web.window.requestAnimationFrame((double time) {
    final first = container.firstElementChild;
    if (first != null) {
      try {
        final dynamic bboxable = first;
        final bbox = bboxable.getBBox();
        final x = bbox.x as double;
        final width = bbox.width as double;
        final y = bbox.y as double;
        final height = bbox.height as double;
        container.setAttribute('width', '${(x + width).ceil()}');
        container.setAttribute('height', '${(y + height).ceil()}');
      } catch (e) {
        // ignore if getBBox is not available (e.g. headless tests)
      }
    }
  }.toJS);

  return container;
}

web.SVGElement _renderVmlChildElement(HtmlRenderer self, VmlElement elem) {
  final tagName = elem.tagName ?? 'g';
  final result = _createSvgElement(self, tagName);
  
  elem.attrs.forEach((k, v) {
    result.setAttribute(k, v);
  });

  for (final child in elem.children ?? <OpenXmlElement>[]) {
    if (child.type == DomType.vmlElement) {
      result.appendChild(_renderVmlChildElement(self, child as VmlElement));
    } else {
      final rendered = self.renderElement(child);
      if (rendered != null) {
        result.appendChild(rendered);
      }
    }
  }

  return result;
}

web.SVGElement _createSvgElement(HtmlRenderer self, String tagName, [Map<String, dynamic>? props, List<dynamic>? children]) {
  final Map<String, dynamic> elementMap = {
    'ns': HtmlNs.svg,
    'tagName': tagName,
  };
  if (children != null) {
    elementMap['children'] = children;
  }
  if (props != null) {
    elementMap.addAll(props);
  }
  return self.hFunc(elementMap) as web.SVGElement;
}
