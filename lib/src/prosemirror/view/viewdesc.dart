import '../model/index.dart';

class ViewDesc {
  final dynamic dom;
  final dynamic contentDOM;

  ViewDesc(this.dom, [this.contentDOM]);

  bool matchesNode(PMNode node, [dynamic outerDeco, dynamic innerDeco]) => true;

  bool update(PMNode node, [dynamic outerDeco, dynamic innerDeco, dynamic view]) => true;

  void updateOuterDeco(dynamic outerDeco) {}

  void destroy() {}
}

class NodeViewDesc extends ViewDesc {
  NodeViewDesc(super.dom, [super.contentDOM]);
}

class MarkView {}
