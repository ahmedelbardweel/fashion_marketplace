/// A stream/track announcement is not proof that a decoded frame exists.
/// Garment revalidation may reuse only a stream already confirmed by rendering.
class RemoteFrameGate<T extends Object> {
  T? _current;
  T? _rendered;
  T? get readyStream => _rendered;

  void attach(T? stream) {
    _current = stream;
    _rendered = null;
  }

  void markRendered(T? stream) {
    if (stream != null && identical(stream, _current)) _rendered = stream;
  }
}
