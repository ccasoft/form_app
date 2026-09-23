// Web stub. Same public shape as face_embedding_backend_io.dart's
// FaceEmbeddingInterpreter, but does nothing real — face login/
// enrollment UI is gated behind kIsWeb everywhere it's offered, so
// this should never actually be called. If it somehow is, fail loudly
// rather than silently pretending to work.
class FaceEmbeddingInterpreter {
  FaceEmbeddingInterpreter._();

  static Future<FaceEmbeddingInterpreter> load(String assetPath) async {
    throw UnsupportedError(
        'Face recognition is not supported on web. This should never be reached — '
        'face login/enrollment UI must be gated behind kIsWeb.');
  }

  void run(Object input, Object output) {
    throw UnsupportedError('Face recognition is not supported on web.');
  }

  void close() {}
}
