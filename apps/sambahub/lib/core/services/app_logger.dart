import 'package:flutter/foundation.dart';

/// Logger central do SambaHub.
///
/// Nunca registre senhas, tokens, chaves, payloads de pagamento ou dados
/// pessoais completos em logs de produção.
abstract final class AppLogger {
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    _write('DEBUG', message, error: error, stackTrace: stackTrace);
  }

  static void info(String message) {
    if (!kDebugMode) return;
    _write('INFO', message);
  }

  static void warning(String message, {Object? error}) {
    _write('WARNING', message, error: error);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _write('ERROR', message, error: error, stackTrace: stackTrace);
  }

  static void _write(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final details = [
      '[SambaHub][$level] $message',
      if (error != null) 'error=$error',
      if (stackTrace != null) 'stack=$stackTrace',
    ].join(' | ');
    debugPrint(details);
  }
}
