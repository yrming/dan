/// Thrown when the server rejects a block lookup or mutation.
final class BlockActionFailure implements Exception {
  /// Creates a failure with optional server feedback.
  const BlockActionFailure({this.message});

  /// Error text returned by the server, when available.
  final String? message;
}
