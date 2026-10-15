import 'package:authentication_repository/src/models/authenticated_account.dart';
import 'package:authentication_repository/src/models/authentication_status.dart';
import 'package:equatable/equatable.dart';

/// Immutable view of all stored accounts and the active account.
final class AuthenticationSnapshot extends Equatable {
  AuthenticationSnapshot._({
    required this.status,
    required List<AuthenticatedAccount> accounts,
    required this.activeAccount,
  }) : accounts = List<AuthenticatedAccount>.unmodifiable(accounts);

  /// Creates a snapshot while persisted accounts are being resolved.
  factory AuthenticationSnapshot.unknown({
    List<AuthenticatedAccount> accounts = const [],
  }) {
    return AuthenticationSnapshot._(
      status: AuthenticationStatus.unknown,
      accounts: accounts,
      activeAccount: null,
    );
  }

  /// Creates a snapshot with no currently active account.
  factory AuthenticationSnapshot.unauthenticated({
    List<AuthenticatedAccount> accounts = const [],
  }) {
    return AuthenticationSnapshot._(
      status: AuthenticationStatus.unauthenticated,
      accounts: accounts,
      activeAccount: null,
    );
  }

  /// Creates a snapshot with a verified active account.
  factory AuthenticationSnapshot.authenticated({
    required List<AuthenticatedAccount> accounts,
    required AuthenticatedAccount activeAccount,
  }) {
    return AuthenticationSnapshot._(
      status: AuthenticationStatus.authenticated,
      accounts: accounts,
      activeAccount: activeAccount,
    );
  }

  /// Current authentication status.
  final AuthenticationStatus status;

  /// All accounts known to the application.
  final List<AuthenticatedAccount> accounts;

  /// Currently active account, when one has been verified.
  final AuthenticatedAccount? activeAccount;

  @override
  List<Object?> get props => [status, accounts, activeAccount];

  @override
  bool get stringify => false;
}
