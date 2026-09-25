import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuração pública necessária para o cliente Supabase.
///
/// A anon key é própria para o cliente, mas nunca substitui RLS. A service
/// role key não deve existir no Flutter, no Firebase Hosting ou em qualquer
/// bundle mobile.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

/// Ponto único de acesso ao Supabase no aplicativo.
///
/// O serviço encapsula inicialização, sessão e autenticação para impedir que
/// telas conheçam detalhes de configuração ou criem clientes paralelos.
final class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  GoTrueClient get auth => client.auth;

  Session? get currentSession => auth.currentSession;

  User? get currentUser => auth.currentUser;

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórias.',
      );
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      debug: kDebugMode,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String profileType = 'venue',
  }) {
    return auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: <String, dynamic>{
        'name': name.trim(),
        'profile_type': profileType,
      },
    );
  }

  Future<void> signOut() => auth.signOut();

  /// Envia o e-mail de recuperação de senha. O link recebido abre
  /// 'https://samba-hub.web.app/nova-senha', estabelecendo uma sessão
  /// temporária de recuperação (evento [AuthChangeEvent.passwordRecovery]).
  Future<void> resetPasswordForEmail(String email) {
    return auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: 'https://samba-hub.web.app/nova-senha',
    );
  }

  /// Define a nova senha durante o fluxo de recuperação. Requer sessão de
  /// recuperação ativa (usuário chegou via deep link do e-mail).
  Future<UserResponse> updatePassword(String newPassword) {
    return auth.updateUser(UserAttributes(password: newPassword));
  }
}

final class SupabaseConfigurationException implements Exception {
  const SupabaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'SupabaseConfigurationException: $message';
}