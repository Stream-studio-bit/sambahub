abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '${runtimeType.toString()}: $message';
}

final class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.cause});
}

final class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.code, super.cause});
}

final class AuthorizationException extends AppException {
  const AuthorizationException(super.message, {super.code, super.cause});
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause});
}

final class ResourceNotFoundException extends AppException {
  const ResourceNotFoundException(super.message, {super.code, super.cause});
}

final class UnknownAppException extends AppException {
  const UnknownAppException(super.message, {super.code, super.cause});
}
