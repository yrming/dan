import 'package:authentication_repository/src/models/models.dart';

/// Persistence boundary for OAuth credentials and account metadata.
///
/// Callers choose the platform storage implementation at the composition root.
/// Implementations must document whether credentials are encrypted at rest.
abstract interface class AuthenticationSessionStorage {
  /// Reads stored account metadata.
  Future<List<AuthenticatedAccount>> readAccounts();

  /// Reads the identifier of the account selected on the previous run.
  Future<String?> readActiveAccountId();

  /// Reads OAuth credentials for [accountId] only.
  Future<AuthenticationSession?> readSession(String accountId);

  /// Adds or updates [account] and its [session].
  ///
  /// Implementations must verify that `account.id == session.accountId`.
  Future<void> upsertAccount({
    required AuthenticatedAccount account,
    required AuthenticationSession session,
  });

  /// Persists the active account identifier, or clears it when `null`.
  Future<void> setActiveAccountId(String? accountId);

  /// Removes one account and its credentials.
  ///
  /// If [accountId] is active, the persisted active identifier must also be
  /// cleared.
  Future<void> deleteAccount(String accountId);

  /// Removes every account and all OAuth credentials.
  Future<void> clear();
}
