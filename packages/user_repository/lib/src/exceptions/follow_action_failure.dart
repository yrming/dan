/// Thrown when the server rejects a follow or unfollow action.
final class FollowActionFailure implements Exception {
  /// Creates a failure with optional server feedback.
  const FollowActionFailure({this.message});

  /// Error text returned by the server, when available.
  final String? message;
}
