part of 'authentication_bloc.dart';

/// Events handled by [AuthenticationBloc].
sealed class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => const [];
}

/// Requests restoration and continuous authentication-state synchronization.
final class AuthenticationSubscriptionRequested extends AuthenticationEvent {
  /// Creates an authentication subscription request.
  const AuthenticationSubscriptionRequested();
}

/// Requests removal of every stored account and its credentials.
final class AuthenticationSignOutRequested extends AuthenticationEvent {
  /// Creates a sign-out request.
  const AuthenticationSignOutRequested();
}

/// Requests activation of one of the stored accounts.
final class AuthenticationAccountSwitchRequested extends AuthenticationEvent {
  /// Creates an account-switch request.
  const AuthenticationAccountSwitchRequested(this.accountId);

  /// Identifier of the account to activate.
  final String accountId;

  @override
  List<Object> get props => [accountId];
}
