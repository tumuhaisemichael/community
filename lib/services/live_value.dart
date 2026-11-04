import 'dart:async';

/// Listens to [source] once and keeps the latest value. Every listener of
/// [stream] gets that value immediately, then live updates, so widgets that
/// are rebuilt or recreated never see an empty "loading" state again.
class LiveValue<T> {
  LiveValue(Stream<T> source) {
    _subscription = source.listen(
      (value) {
        _latest = value;
        _hasValue = true;
        _controller.add(value);
      },
      onError: (Object error, StackTrace stack) {
        _error = error;
        _controller.addError(error, stack);
      },
    );
  }

  final StreamController<T> _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _subscription;
  T? _latest;
  bool _hasValue = false;
  Object? _error;

  /// Latest value, or null before the first one arrives.
  T? get latest => _hasValue ? _latest : null;

  late final Stream<T> stream = Stream<T>.multi((listener) {
    if (_hasValue) {
      listener.add(_latest as T);
    } else if (_error != null) {
      listener.addError(_error!);
    }
    final sub = _controller.stream.listen(
      listener.add,
      onError: listener.addError,
    );
    listener.onCancel = sub.cancel;
  });

  void close() {
    _subscription.cancel();
    _controller.close();
  }
}
