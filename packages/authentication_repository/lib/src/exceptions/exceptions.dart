/// Base type for sanitized authentication failures.
sealed class AuthenticationFailure implements Exception {
  const AuthenticationFailure();
}

/// Thrown when Fanfou rejects the supplied credentials.
final class InvalidCredentialsFailure extends AuthenticationFailure {
  /// Creates an invalid credentials failure.
  const InvalidCredentialsFailure();
}

/// Thrown when Fanfou returns an unsuccessful response unrelated to invalid
/// credentials.
final class AuthenticationApiFailure extends AuthenticationFailure {
  /// Creates an API failure without retaining the potentially sensitive body.
  const AuthenticationApiFailure({required this.statusCode, this.message});

  /// HTTP status code returned by Fanfou.
  final int statusCode;

  /// Error text returned by Fanfou, when available.
  final String? message;
}

/// Thrown when persisted OAuth credentials cannot be read, written, or cleared.
final class AuthenticationStorageFailure extends AuthenticationFailure {
  /// Creates an authentication persistence failure.
  const AuthenticationStorageFailure();
}

/// Thrown when a successful token response omits required OAuth credentials.
final class MalformedAuthenticationResponseFailure
    extends AuthenticationFailure {
  /// Creates a malformed response failure.
  const MalformedAuthenticationResponseFailure();
}

/// Thrown when OAuth authorization was denied by the user.
final class OAuthAuthorizationDeniedFailure extends AuthenticationFailure {
  /// Creates an OAuth authorization-denied failure.
  const OAuthAuthorizationDeniedFailure();
}

/// Thrown when no OAuth authorization is waiting for a callback.
final class OAuthAuthorizationNotStartedFailure extends AuthenticationFailure {
  /// Creates an OAuth authorization-not-started failure.
  const OAuthAuthorizationNotStartedFailure();
}

/// Thrown when an OAuth callback is missing required values or has an
/// unexpected callback target.
final class InvalidOAuthCallbackFailure extends AuthenticationFailure {
  /// Creates an invalid OAuth callback failure.
  const InvalidOAuthCallbackFailure();
}

/// Thrown when an OAuth callback does not belong to the pending authorization.
final class OAuthAuthorizationStateMismatchFailure
    extends AuthenticationFailure {
  /// Creates an OAuth state-mismatch failure.
  const OAuthAuthorizationStateMismatchFailure();
}

/// Thrown when an unexpected dependency failure occurs.
final class AuthenticationUnknownFailure extends AuthenticationFailure {
  /// Creates an unknown authentication failure.
  const AuthenticationUnknownFailure();
}

/// Thrown when an account identifier is not known to the repository.
final class AccountNotFoundFailure extends AuthenticationFailure {
  /// Creates an account-not-found failure.
  const AccountNotFoundFailure({required this.accountId});

  /// Identifier requested by the caller.
  final String accountId;
}

/// Thrown when a stored account no longer has usable OAuth credentials.
final class AccountUnavailableFailure extends AuthenticationFailure {
  /// Creates an unavailable-account failure.
  const AccountUnavailableFailure({required this.accountId});

  /// Identifier of the unavailable account.
  final String accountId;
}
