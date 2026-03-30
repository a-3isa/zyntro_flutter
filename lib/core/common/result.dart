sealed class Result<S, F> {
  const Result();

  bool get isSuccess => this is SuccessResult<S, F>;
  bool get isFailure => this is FailureResult<S, F>;

  S? get valueOrNull => switch (this) {
    SuccessResult<S, F>(value: final value) => value,
    FailureResult<S, F>() => null,
  };

  F? get errorOrNull => switch (this) {
    SuccessResult<S, F>() => null,
    FailureResult<S, F>(error: final error) => error,
  };

  T when<T>({
    required T Function(S value) success,
    required T Function(F error) failure,
  }) {
    return switch (this) {
      SuccessResult<S, F>(value: final value) => success(value),
      FailureResult<S, F>(error: final error) => failure(error),
    };
  }

  T fold<T>(T Function(S value) onSuccess, T Function(F error) onFailure) {
    return when(success: onSuccess, failure: onFailure);
  }

  static Result<S, F> success<S, F>(S value) => SuccessResult<S, F>(value);
  static Result<S, F> failure<S, F>(F error) => FailureResult<S, F>(error);
}

final class SuccessResult<S, F> extends Result<S, F> {
  final S value;
  const SuccessResult(this.value);
}

final class FailureResult<S, F> extends Result<S, F> {
  final F error;
  const FailureResult(this.error);
}
