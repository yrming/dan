/// Opens the Fanfou authorization page and returns its callback URI.
abstract interface class OAuthAuthorizationService {
  /// Callback URI registered by the application.
  Uri get callbackUri;

  /// Runs one system-browser authorization session.
  Future<Uri> authorize(Uri authorizationUri);
}

/// Base type for sanitized browser authorization failures.
sealed class OAuthAuthorizationServiceFailure implements Exception {
  const OAuthAuthorizationServiceFailure();
}

/// Thrown when the user closes the browser authorization session.
final class OAuthAuthorizationCancelled
    extends OAuthAuthorizationServiceFailure {
  /// Creates a cancellation failure.
  const OAuthAuthorizationCancelled();
}

/// Thrown when the browser authorization session cannot be completed.
final class OAuthAuthorizationLaunchFailure
    extends OAuthAuthorizationServiceFailure {
  /// Creates a sanitized browser authorization failure.
  const OAuthAuthorizationLaunchFailure();
}
