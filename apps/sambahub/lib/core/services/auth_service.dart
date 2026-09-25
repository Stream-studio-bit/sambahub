import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Fachada de autenticação para impedir que as telas dependam diretamente do
/// cliente Supabase.
final class AuthService {
  AuthService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  User? get currentUser => _supabase.currentUser;
  Session? get currentSession => _supabase.currentSession;
  bool get isAuthenticated => currentSession != null;
  Stream<AuthState> get authStateChanges => _supabase.authStateChanges;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _supabase.signIn(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) {
    return _supabase.signUp(email: email, password: password, name: name);
  }

  Future<void> signOut() => _supabase.signOut();

  Future<void> resetPassword(String email) {
    return _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }
}
