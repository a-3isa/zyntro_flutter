class AuthFailure {
  final String message;
  final String? code;

  const AuthFailure({required this.message, this.code});

  factory AuthFailure.validation(String message, {String? code}) {
    return AuthFailure(message: message, code: code ?? 'validation-error');
  }

  factory AuthFailure.unknown([String? message]) {
    return AuthFailure(
      message: message ?? 'Authentication failed. Please try again.',
      code: 'unknown-error',
    );
  }
}
