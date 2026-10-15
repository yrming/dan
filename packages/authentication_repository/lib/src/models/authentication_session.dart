/// OAuth credentials required to restore a Fanfou session.
///
/// This value is intentionally not [Object.toString]-inspectable because it
/// contains secrets. The chosen storage implementation determines whether
/// these values are encrypted at rest.
final class AuthenticationSession {
  /// Creates an authentication session.
  const AuthenticationSession({
    required this.accountId,
    required this.token,
    required this.tokenSecret,
  });

  /// Stable Fanfou account identifier associated with these credentials.
  final String accountId;

  /// OAuth access token.
  final String token;

  /// OAuth access token secret.
  final String tokenSecret;

  /// Whether both OAuth credential values are present.
  bool get isValid =>
      accountId.isNotEmpty && token.isNotEmpty && tokenSecret.isNotEmpty;

  @override
  String toString() => 'AuthenticationSession(<redacted>)';
}
