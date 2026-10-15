/// Base type for sanitized direct message repository failures.
sealed class DirectMessageRepositoryFailure implements Exception {
  /// Creates a direct message repository failure.
  const DirectMessageRepositoryFailure();
}

/// Thrown when Fanfou returns an unsuccessful direct message response.
final class DirectMessageRepositoryApiFailure
    extends DirectMessageRepositoryFailure {
  /// Creates an API failure without retaining the response body.
  const DirectMessageRepositoryApiFailure({
    required this.statusCode,
    this.message,
  });

  /// HTTP status code returned by Fanfou.
  final int statusCode;

  /// Error text returned by Fanfou, when available.
  final String? message;
}

/// Thrown when a direct message call fails for an unexpected reason.
final class DirectMessageRepositoryUnknownFailure
    extends DirectMessageRepositoryFailure {
  /// Creates an unknown failure.
  const DirectMessageRepositoryUnknownFailure({this.cause});

  /// Original error describing why the call failed, when available.
  ///
  /// The cause is for logs and debugging only and is not part of equality.
  final Object? cause;

  @override
  String toString() =>
      'DirectMessageRepositoryUnknownFailure${cause == null ? '' : ': $cause'}';
}
