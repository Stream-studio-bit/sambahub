import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Serviço leve para observar a sessão atual sem duplicar listeners nas telas.
final class SessionService {
  SessionService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;
  StreamSubscription<AuthState>? _subscription;
  final _controller = StreamController<Session?>.broadcast();

  Session? get current => _supabase.currentSession;
  Stream<Session?> get changes => _controller.stream;

  void start() {
    _subscription ??= _supabase.authStateChanges.listen((state) {
      _controller.add(state.session);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
