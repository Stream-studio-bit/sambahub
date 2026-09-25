import 'dart:async';

/// Estado de conectividade mantido no app sem acoplar o domínio a plugins
/// específicos de Android, iOS ou Web.
final class ConnectivityService {
  ConnectivityService({bool initialOnline = true}) : _online = initialOnline;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  bool get isOnline => _online;
  Stream<bool> get changes => _controller.stream;

  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}
