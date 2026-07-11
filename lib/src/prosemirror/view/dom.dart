import 'package:web/web.dart' as web;

typedef DOMNode = web.Node;
typedef DOMElement = web.Element;
typedef DOMHTMLElement = web.HTMLElement;
typedef DOMSelection = web.Selection;
typedef DOMSelectionRange = ({
  web.Node? anchorNode,
  int anchorOffset,
  web.Node? focusNode,
  int focusOffset,
});
