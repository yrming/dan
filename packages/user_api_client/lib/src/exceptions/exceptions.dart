/// Base type for sanitized user API failures.
sealed class UserApiClientFailure implements Exception {
  /// Creates a user API failure.
  const UserApiClientFailure();
}

/// Thrown when Fanfou returns an unsuccessful user API response.
final class UserApiClientApiFailure extends UserApiClientFailure {
  /// Creates an API failure without retaining the response body.
  const UserApiClientApiFailure({required this.statusCode, this.message});

  /// HTTP status code returned by Fanfou.
  final int statusCode;

  /// Error text returned by the API, when available.
  final String? message;
}

/// Thrown when a user request fails for an unexpected reason.
final class UserApiClientUnknownFailure extends UserApiClientFailure {
  /// Creates an unknown user API failure.
  const UserApiClientUnknownFailure();
}
