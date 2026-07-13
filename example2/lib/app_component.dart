import 'package:ngdart/angular.dart';

import 'tiptap_docx_editor_component.dart';

@Component(
  selector: 'docx-editor-app',
  templateUrl: 'app_component.html',
  styleUrls: <String>['app_component.css'],
  directives: <Object>[TiptapDocxEditorComponent],
  changeDetection: ChangeDetectionStrategy.onPush,
)
class AppComponent {}
