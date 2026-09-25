import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';
import 'failure.dart';

abstract final class FailureMapper {
  static Failure from(Object error) {
    if (error is Failure) return error;

    if (error is AuthException) {
      return AuthFailure(message: _authMessage(error), code: error.statusCode);
    }

    if (error is PostgrestException) {
      return _fromPostgrest(error);
    }

    if (error is AppException) {
      return _fromAppException(error);
    }

    return const UnknownFailure(
      message: 'Ocorreu um erro inesperado. Tente novamente.',
    );
  }

  static Failure _fromPostgrest(PostgrestException error) {
    final code = error.code;
    if (code == '42501' || code == 'PGRST301') {
      return PermissionFailure(
          message: 'Você não tem permissão para esta ação.', code: code);
    }
    if (code == 'PGRST116') {
      return NotFoundFailure(message: 'Registro não encontrado.', code: code);
    }
    if (code != null && code.startsWith('23')) {
      return ValidationFailure(
          message: 'Os dados informados não puderam ser salvos.', code: code);
    }
    return NetworkFailure(
        message: 'Não foi possível acessar os dados.', code: code);
  }

  static Failure _fromAppException(AppException error) {
    return switch (error) {
      AuthenticationException() =>
        AuthFailure(message: error.message, code: error.code),
      AuthorizationException() =>
        PermissionFailure(message: error.message, code: error.code),
      NetworkException() =>
        NetworkFailure(message: error.message, code: error.code),
      ValidationException() =>
        ValidationFailure(message: error.message, code: error.code),
      ResourceNotFoundException() =>
        NotFoundFailure(message: error.message, code: error.code),
      _ => UnknownFailure(message: error.message, code: error.code),
    };
  }

  static String _authMessage(AuthException error) {
    if (error.statusCode == '400' ||
        error.message.toLowerCase().contains('invalid')) {
      return 'E-mail ou senha inválidos.';
    }
    if (error.message.toLowerCase().contains('already registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    return 'Não foi possível autenticar. Tente novamente.';
  }
}
