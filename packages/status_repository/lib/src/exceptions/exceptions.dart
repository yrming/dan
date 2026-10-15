/// Base type for sanitized status repository failures.
sealed class StatusRepositoryFailure implements Exception {
  /// Creates a status repository failure.
  const StatusRepositoryFailure();
}

/// Thrown when a photo cannot be prepared within the upload size limit.
final class StatusRepositoryPhotoPreparationFailure
    extends StatusRepositoryFailure {
  /// Creates a sanitized photo preparation failure.
  const StatusRepositoryPhotoPreparationFailure();
}

/// Thrown when a filename or image signature is unsupported or mismatched.
final class StatusRepositoryPhotoFormatFailure extends StatusRepositoryFailure {
  /// Creates a sanitized unsupported-photo failure.
  const StatusRepositoryPhotoFormatFailure();
}

/// Thrown when Fanfou returns an unsuccessful status API response.
final class StatusRepositoryApiFailure extends StatusRepositoryFailure {
  /// Creates an API failure without retaining the potentially sensitive body.
  const StatusRepositoryApiFailure({required this.statusCode, this.message});

  /// HTTP status code returned by Fanfou.
  final int statusCode;

  /// Error text returned by Fanfou, when available.
  final String? message;
}

/// Thrown when a status API call fails for an unexpected reason.
final class StatusRepositoryUnknownFailure extends StatusRepositoryFailure {
  /// Creates an unknown failure.
  const StatusRepositoryUnknownFailure({this.cause});

  /// Original error describing why the call failed, when available.
  ///
  /// The cause is for logs and debugging only and is not part of equality.
  final Object? cause;

  @override
  String toString() =>
      'StatusRepositoryUnknownFailure${cause == null ? '' : ': $cause'}';
}
