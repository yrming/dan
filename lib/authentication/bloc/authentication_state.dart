part of 'authentication_bloc.dart';

/// Application-level authentication state.
sealed class AuthenticationState extends Equatable {
  const AuthenticationState();

  @override
  List<Object?> get props => const [];
}

/// Authentication restoration has not started.
final class AuthenticationInitial extends AuthenticationState {
  /// Creates the initial authentication state.
  const AuthenticationInitial();
}

/// Stored accounts are being restored or verified.
final class AuthenticationLoadInProgress extends AuthenticationState {
  /// Creates a loading authentication state.
  const AuthenticationLoadInProgress();
}

/// One account is verified and active.
final class AuthenticationAuthenticated extends AuthenticationState {
  /// Creates an authenticated state from [snapshot].
  const AuthenticationAuthenticated(this.snapshot);

  /// Current accounts and active account.
  final AuthenticationSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

/// No verified account is currently active.
final class AuthenticationUnauthenticated extends AuthenticationState {
  /// Creates an unauthenticated state from [snapshot].
  const AuthenticationUnauthenticated(this.snapshot);

  /// Accounts retained by the repository, if any.
  final AuthenticationSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

/// Stored authentication state could not be restored.
final class AuthenticationRestoreFailure extends AuthenticationState {
  /// Creates a sanitized authentication failure state.
  const AuthenticationRestoreFailure();
}
