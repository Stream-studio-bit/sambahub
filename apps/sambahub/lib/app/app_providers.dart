import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';
import '../core/services/edge_function_service.dart';
import '../core/services/session_service.dart';
import '../core/services/supabase_service.dart';
import 'app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(supabase: ref.watch(supabaseServiceProvider));
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  final service = SessionService(supabase: ref.watch(supabaseServiceProvider));
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

final edgeFunctionServiceProvider = Provider<EdgeFunctionService>((ref) {
  return EdgeFunctionService(
    client: ref.watch(supabaseServiceProvider).client,
  );
});
