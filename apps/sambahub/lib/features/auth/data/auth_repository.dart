import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/services/supabase_service.dart';
import '../domain/auth_user.dart';

final class AuthRepository {
  AuthRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  AuthUser? get currentUser {
    final user = _supabase.currentUser;
    if (user == null) return null;
    return _toAuthUser(user);
  }

  Stream<AuthUser?> get userChanges => _supabase.authStateChanges.map((state) {
        final user = state.session?.user;
        return user == null ? null : _toAuthUser(user);
      });

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.signIn(email: email, password: password);
    final user = response.user;
    if (user == null)
      throw const AuthRepositoryException(
          'Usuário não retornado pelo Supabase.');
    return _toAuthUser(user);
  }

  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final response =
        await _supabase.signUp(email: email, password: password, name: name);
    final user = response.user;
    return user == null ? null : _toAuthUser(user);
  }

  Future<void> signOut() => _supabase.signOut();

  Future<void> resetPassword(String email) {
    return _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  AuthUser _toAuthUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }
}

final class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => 'AuthRepositoryException: $message';
}
