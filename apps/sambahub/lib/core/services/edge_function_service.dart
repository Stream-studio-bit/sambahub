import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Gateway único para Edge Functions do SambaHub.
final class EdgeFunctionService {
  EdgeFunctionService({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.functions.invoke(functionName, body: body);
    final data = response.data;
    if (data is! Map) {
      throw const EdgeFunctionException(
          'A Edge Function retornou um formato inválido.');
    }

    final payload = Map<String, dynamic>.from(data);
    final error = payload['error'];
    if (error != null) {
      final message = error is Map ? error['message'] : error.toString();
      throw EdgeFunctionException(
          message?.toString() ?? 'A operação não foi concluída.');
    }
    return payload;
  }
}

final class EdgeFunctionException implements Exception {
  const EdgeFunctionException(this.message);

  final String message;

  @override
  String toString() => 'EdgeFunctionException: $message';
}
