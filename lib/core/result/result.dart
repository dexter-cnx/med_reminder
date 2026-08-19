sealed class Result<T> {
  const Result();

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  });

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failed<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => onSuccess(value);
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);
  final Failure failure;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => onFailure(failure);
}

class Failure {
  const Failure({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'Failure($code): $message';
}
