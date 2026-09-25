sealed class Failure {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;
}

final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

final class PermissionFailure extends Failure {
  const PermissionFailure({required super.message, super.code});
}

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message, super.code});
}

final class UnknownFailure extends Failure {
  const UnknownFailure({required super.message, super.code});
}
