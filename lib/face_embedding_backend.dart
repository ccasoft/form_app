// Platform-conditional export. tflite_flutter transitively imports
// dart:ffi, which does not exist as a library on the web compiler at
// all — that's a hard COMPILE failure, not something a runtime kIsWeb
// check can prevent, since the import itself still has to resolve.
//
// dart.library.io is available on Android/iOS/desktop but not web, so
// this picks the real implementation there, and a no-op stub on web
// that compiles cleanly but throws if actually called (it never
// should be — all face-login UI is gated behind kIsWeb already).
export 'face_embedding_backend_stub.dart'
    if (dart.library.io) 'face_embedding_backend_io.dart';
