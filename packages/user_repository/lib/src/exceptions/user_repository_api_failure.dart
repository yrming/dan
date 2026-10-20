/// Thrown when the server rejects a user list request.
final class UserRepositoryApiFailure implements Exception {
  /// Creates a failure with optional parsed server feedback.
  const UserRepositoryApiFailure({required this.statusCode, this.message});

  /// HTTP status returned by the server.
  final int statusCode;

  /// Error text returned by the server, when available.
  final String? message;
}
