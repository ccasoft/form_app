// Re-fetches [fetch] every [interval] and emits the result — lets
// StreamBuilder-based screens (ported from the console app) keep
// working without a real push/websocket backend. Ported from the
// console's api_client.dart; everything else in that file is
// superseded by ApiService.
Stream<T> officePollingStream<T>(Future<T> Function() fetch,
    {Duration interval = const Duration(seconds: 5)}) async* {
  while (true) {
    try {
      yield await fetch();
    } catch (_) {
      // Swallow transient network errors between polls; the next tick retries.
    }
    await Future.delayed(interval);
  }
}
