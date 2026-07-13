/// Quill Delta core (compose/transform/diff/invert), vendored from the
/// mature `dart_quill` implementation with `package:collection` replaced
/// by a local deep-equality helper (runtime dependency budget: only
/// `package:web`). Pure Dart — runs on VM, JS and Wasm.
library;

export 'src/quill_delta/index.dart';
