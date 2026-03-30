import '../../../../core/errors/app_exception.dart';

enum AuthDataExceptionType { auth, network, cache, server, unknown }

class AuthDataException extends AppException {
  final AuthDataExceptionType type;

  const AuthDataException({
    required super.message,
    required this.type,
    super.code,
  });

  factory AuthDataException.auth({
    required String message,
    required String code,
  }) {
    return AuthDataException(
      message: message,
      type: AuthDataExceptionType.auth,
      code: code,
    );
  }

  factory AuthDataException.network([String? message]) {
    return AuthDataException(
      message: message ?? 'Network error. Please check your connection.',
      type: AuthDataExceptionType.network,
      code: 'network-request-failed',
    );
  }

  factory AuthDataException.cache([String? message]) {
    return AuthDataException(
      message: message ?? 'Failed to read local cache.',
      type: AuthDataExceptionType.cache,
      code: 'cache-error',
    );
  }

  factory AuthDataException.server([String? message]) {
    return AuthDataException(
      message: message ?? 'A server error occurred.',
      type: AuthDataExceptionType.server,
      code: 'server-error',
    );
  }

  factory AuthDataException.unknown([String? message]) {
    return AuthDataException(
      message: message ?? 'An unknown authentication error occurred.',
      type: AuthDataExceptionType.unknown,
      code: 'unknown-error',
    );
  }
}
