/// Application-level authentication state.
enum AuthenticationStatus {
  /// The persisted session has not been checked yet.
  unknown,

  /// A Fanfou account has been verified.
  authenticated,

  /// No valid Fanfou session is available.
  unauthenticated,
}
