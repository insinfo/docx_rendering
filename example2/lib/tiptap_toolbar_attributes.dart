import 'package:ngdart/angular.dart';

// AngularDart's strict template validator requires custom data attributes to
// be declared as directive inputs. These no-op directives keep the portable
// `data-tiptap-*` contract in the rendered DOM for TiptapToolbarController.

@Directive(selector: '[data-tiptap-icon]')
class TiptapIconAttributeDirective {
  @Input('data-tiptap-icon')
  String? value;
}

@Directive(selector: '[data-tiptap-theme-icon]')
class TiptapThemeIconAttributeDirective {
  @Input('data-tiptap-theme-icon')
  String? value;
}

@Directive(selector: '[data-tiptap-action]')
class TiptapActionAttributeDirective {
  @Input('data-tiptap-action')
  String? value;
}

@Directive(selector: '[data-tiptap-command]')
class TiptapCommandAttributeDirective {
  @Input('data-tiptap-command')
  String? value;
}

@Directive(selector: '[data-tiptap-control]')
class TiptapControlAttributeDirective {
  @Input('data-tiptap-control')
  String? value;
}

@Directive(selector: '[data-tiptap-color-indicator]')
class TiptapColorIndicatorAttributeDirective {
  @Input('data-tiptap-color-indicator')
  String? value;
}

@Directive(selector: '[data-tiptap-zoom-value]')
class TiptapZoomValueAttributeDirective {
  @Input('data-tiptap-zoom-value')
  String? value;
}

@Directive(selector: '[data-tiptap-preserve-selection]')
class TiptapPreserveSelectionAttributeDirective {
  @Input('data-tiptap-preserve-selection')
  String? value;
}
