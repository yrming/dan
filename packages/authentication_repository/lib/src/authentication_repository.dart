import 'dart:async';

import 'package:authentication_repository/src/authentication_client_factory.dart';
import 'package:authentication_repository/src/exceptions/exceptions.dart';
import 'package:authentication_repository/src/models/models.dart';
import 'package:authentication_repository/src/session_storage.dart';
import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:fanfou_error_parser/fanfou_error_parser.dart';

/// Manages multiple Fanfou accounts and the active authenticated account.
///
/// Passwords are forwarded to Fanfou's XAuth endpoint only and are never
/// retained. Account metadata and OAuth sessions are persisted by the injected
/// [AuthenticationSessionStorage] implementation.
class AuthenticationRepository {
  /// Creates a multi-account authentication repository.
  factory AuthenticationRepository({
    required AuthenticationClientFactory clientFactory,
    required AuthenticationSessionStorage sessionStorage,
  }) {
    return AuthenticationRepository._(clientFactory, sessionStorage);
  }

  AuthenticationRepository._(this._clientFactory, this._sessionStorage);

  final AuthenticationClientFactory _clientFactory;
  final AuthenticationSessionStorage _sessionStorage;
  final StreamController<AuthenticationSnapshot> _authenticationController =
      StreamController<AuthenticationSnapshot>.broadcast();

  AuthenticationSnapshot _currentAuthentication =
      AuthenticationSnapshot.unknown();
  _PendingOAuthAuthorization? _pendingOAuthAuthorization;

  /// Emits changes to stored accounts and the active account.
  Stream<AuthenticationSnapshot> get authentication =>
      _authenticationController.stream;

  /// Most recently resolved authentication snapshot.
  AuthenticationSnapshot get currentAuthentication => _currentAuthentication;

  /// Creates a Fanfou client scoped to the current active account.
  ///
  /// The caller owns the returned client and must close it after the API call
  /// completes. This method does not verify the stored session on every call;
  /// account restoration and account switching own verification.
  Future<fanfou.FanfouClient> createClientForActiveAccount() async {
    final activeAccount = _currentAuthentication.activeAccount;
    if (activeAccount == null) {
      throw const AuthenticationUnknownFailure();
    }

    final AuthenticationSession? session;
    try {
      session = await _sessionStorage.readSession(activeAccount.id);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }

    if (session == null ||
        !session.isValid ||
        session.accountId != activeAccount.id) {
      throw AccountUnavailableFailure(accountId: activeAccount.id);
    }

    return _clientFactory(session: session);
  }

  /// Restores stored accounts and verifies the previously active account.
  ///
  /// Rejected or malformed sessions are removed one at a time. If the previous
  /// active account is unavailable, the next stored account is attempted.
  /// Temporary API failures preserve all remaining accounts for a later retry.
  Future<AuthenticationSnapshot> restoreAccounts() async {
    final List<AuthenticatedAccount> storedAccounts;
    final String? activeAccountId;
    try {
      storedAccounts = await _sessionStorage.readAccounts();
      activeAccountId = await _sessionStorage.readActiveAccountId();
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }

    final accounts = _deduplicateAccounts(storedAccounts);
    if (accounts.isEmpty) {
      try {
        await _sessionStorage.setActiveAccountId(null);
      } on Object catch (_) {
        throw const AuthenticationStorageFailure();
      }
      return _emit(AuthenticationSnapshot.unauthenticated());
    }

    _currentAuthentication = AuthenticationSnapshot.unknown(
      accounts: accounts,
    );
    return _activateFirstAvailable(
      accounts,
      preferredAccountId: activeAccountId,
    );
  }

  /// Adds or refreshes an account and makes it active.
  ///
  /// A failed login never removes or changes another stored account.
  Future<AuthenticatedAccount> addAccount({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const InvalidCredentialsFailure();
    }

    final client = _clientFactory();
    try {
      final tokenData = await client.oauth.getAccessTokenWithXAuth(
        normalizedUsername,
        password,
      );
      final token = tokenData['oauth_token'];
      final tokenSecret = tokenData['oauth_token_secret'];
      if (token == null ||
          token.isEmpty ||
          tokenSecret == null ||
          tokenSecret.isEmpty) {
        throw const MalformedAuthenticationResponseFailure();
      }

      return await _verifyAndPersistAccount(
        client: client,
        token: token,
        tokenSecret: tokenSecret,
      );
    } on AuthenticationFailure {
      rethrow;
    } on fanfou.FanfouApiException catch (error) {
      if (_isUnauthorized(error.statusCode)) {
        throw const InvalidCredentialsFailure();
      }
      throw AuthenticationApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (_) {
      throw const AuthenticationUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Starts browser-based OAuth 1.0a authorization.
  ///
  /// The temporary request-token secret is retained only in memory on the
  /// isolated Fanfou client. Starting another authorization invalidates the
  /// previous pending callback.
  Future<Uri> beginOAuthAuthorization({required Uri callbackUri}) async {
    if (!_isValidCallbackTarget(callbackUri)) {
      throw const InvalidOAuthCallbackFailure();
    }

    cancelOAuthAuthorization();
    final client = _clientFactory();
    try {
      final tokenData = await client.oauth.getRequestToken(
        callbackUrl: callbackUri.toString(),
      );
      final requestToken = tokenData['oauth_token'];
      final requestTokenSecret = tokenData['oauth_token_secret'];
      if (requestToken == null ||
          requestToken.isEmpty ||
          requestTokenSecret == null ||
          requestTokenSecret.isEmpty) {
        throw const MalformedAuthenticationResponseFailure();
      }

      final authorizationUri = Uri.parse(
        client.oauth.getAuthorizationUrl(
          requestToken,
          callbackUrl: callbackUri.toString(),
        ),
      );
      _pendingOAuthAuthorization = _PendingOAuthAuthorization(
        client: client,
        requestToken: requestToken,
        callbackUri: callbackUri,
      );
      return authorizationUri;
    } on AuthenticationFailure {
      client.close();
      rethrow;
    } on fanfou.FanfouApiException catch (error) {
      client.close();
      throw AuthenticationApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (_) {
      client.close();
      throw const AuthenticationUnknownFailure();
    }
  }

  /// Completes the pending OAuth authorization and activates its account.
  Future<AuthenticatedAccount> completeOAuthAuthorization(
    Uri authorizationCallbackUri,
  ) async {
    final pending = _pendingOAuthAuthorization;
    if (pending == null) {
      throw const OAuthAuthorizationNotStartedFailure();
    }
    _pendingOAuthAuthorization = null;

    try {
      if (!_matchesCallbackTarget(
        authorizationCallbackUri,
        pending.callbackUri,
      )) {
        throw const InvalidOAuthCallbackFailure();
      }

      final deniedToken = authorizationCallbackUri.queryParameters['denied'];
      if (deniedToken != null) {
        if (deniedToken != pending.requestToken) {
          throw const OAuthAuthorizationStateMismatchFailure();
        }
        throw const OAuthAuthorizationDeniedFailure();
      }

      final callbackToken =
          authorizationCallbackUri.queryParameters['oauth_token'];
      final verifier =
          authorizationCallbackUri.queryParameters['oauth_verifier'];
      if (callbackToken == null || callbackToken.isEmpty) {
        throw const InvalidOAuthCallbackFailure();
      }
      if (callbackToken != pending.requestToken) {
        throw const OAuthAuthorizationStateMismatchFailure();
      }

      final tokenData = await pending.client.oauth.getAccessToken(
        pending.requestToken,
        verifier: verifier == null || verifier.isEmpty ? null : verifier,
      );
      final token = tokenData['oauth_token'];
      final tokenSecret = tokenData['oauth_token_secret'];
      if (token == null ||
          token.isEmpty ||
          tokenSecret == null ||
          tokenSecret.isEmpty) {
        throw const MalformedAuthenticationResponseFailure();
      }

      return await _verifyAndPersistAccount(
        client: pending.client,
        token: token,
        tokenSecret: tokenSecret,
      );
    } on AuthenticationFailure {
      rethrow;
    } on fanfou.FanfouApiException catch (error) {
      throw AuthenticationApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (_) {
      throw const AuthenticationUnknownFailure();
    } finally {
      pending.client.close();
    }
  }

  /// Invalidates and releases an unfinished OAuth authorization.
  void cancelOAuthAuthorization() {
    _pendingOAuthAuthorization?.client.close();
    _pendingOAuthAuthorization = null;
  }

  /// Verifies and activates a stored account.
  Future<AuthenticatedAccount> switchAccount(String accountId) async {
    final target = _accountById(
      _currentAuthentication.accounts,
      accountId,
    );
    if (target == null) {
      throw AccountNotFoundFailure(accountId: accountId);
    }
    if (_currentAuthentication.activeAccount?.id == accountId) {
      return target;
    }

    try {
      final verifiedAccount = await _verifyStoredAccount(target);
      try {
        await _sessionStorage.setActiveAccountId(verifiedAccount.id);
      } on Object catch (_) {
        throw const AuthenticationStorageFailure();
      }

      final accounts = _upsertAccount(
        _currentAuthentication.accounts,
        verifiedAccount,
      );
      _emit(
        AuthenticationSnapshot.authenticated(
          accounts: accounts,
          activeAccount: verifiedAccount,
        ),
      );
      return verifiedAccount;
    } on AccountUnavailableFailure {
      final accounts = _withoutAccount(
        _currentAuthentication.accounts,
        accountId,
      );
      final activeAccount = _currentAuthentication.activeAccount;
      if (activeAccount == null) {
        _emit(AuthenticationSnapshot.unauthenticated(accounts: accounts));
      } else {
        _emit(
          AuthenticationSnapshot.authenticated(
            accounts: accounts,
            activeAccount: activeAccount,
          ),
        );
      }
      rethrow;
    }
  }

  /// Removes one account without affecting other stored accounts.
  ///
  /// Removing the active account attempts to activate the next available one.
  Future<void> removeAccount(String accountId) async {
    final account = _accountById(
      _currentAuthentication.accounts,
      accountId,
    );
    if (account == null) {
      throw AccountNotFoundFailure(accountId: accountId);
    }

    try {
      await _sessionStorage.deleteAccount(accountId);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }

    final accounts = _withoutAccount(
      _currentAuthentication.accounts,
      accountId,
    );
    if (_currentAuthentication.activeAccount?.id != accountId) {
      final activeAccount = _currentAuthentication.activeAccount;
      if (activeAccount == null) {
        _emit(AuthenticationSnapshot.unauthenticated(accounts: accounts));
      } else {
        _emit(
          AuthenticationSnapshot.authenticated(
            accounts: accounts,
            activeAccount: activeAccount,
          ),
        );
      }
      return;
    }

    if (accounts.isEmpty) {
      _emit(AuthenticationSnapshot.unauthenticated());
      return;
    }

    _currentAuthentication = AuthenticationSnapshot.unknown(
      accounts: accounts,
    );
    await _activateFirstAvailable(accounts);
  }

  /// Removes every account and OAuth session.
  Future<void> removeAllAccounts() async {
    try {
      await _sessionStorage.clear();
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }
    _emit(AuthenticationSnapshot.unauthenticated());
  }

  /// Updates persisted metadata for an already authenticated account.
  ///
  /// This is used when a profile refresh returns newer public account data.
  /// OAuth credentials are read from storage and kept unchanged.
  Future<AuthenticatedAccount> updateAccount(
    AuthenticatedAccount account,
  ) async {
    final existingAccount = _accountById(
      _currentAuthentication.accounts,
      account.id,
    );
    if (existingAccount == null) {
      throw AccountNotFoundFailure(accountId: account.id);
    }

    final AuthenticationSession? session;
    try {
      session = await _sessionStorage.readSession(account.id);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }
    if (session == null ||
        !session.isValid ||
        session.accountId != account.id) {
      throw AccountUnavailableFailure(accountId: account.id);
    }

    try {
      await _sessionStorage.upsertAccount(
        account: account,
        session: session,
      );
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }

    final accounts = _upsertAccount(_currentAuthentication.accounts, account);
    final activeAccount = _currentAuthentication.activeAccount;
    if (activeAccount?.id == account.id) {
      _emit(
        AuthenticationSnapshot.authenticated(
          accounts: accounts,
          activeAccount: account,
        ),
      );
    } else if (activeAccount != null) {
      _emit(
        AuthenticationSnapshot.authenticated(
          accounts: accounts,
          activeAccount: activeAccount,
        ),
      );
    } else {
      _currentAuthentication = AuthenticationSnapshot.unknown(
        accounts: accounts,
      );
    }
    return account;
  }

  /// Releases pending OAuth resources and the status stream.
  Future<void> close() async {
    cancelOAuthAuthorization();
    await _authenticationController.close();
  }

  Future<AuthenticatedAccount> _verifyAndPersistAccount({
    required fanfou.FanfouClient client,
    required String token,
    required String tokenSecret,
  }) async {
    final account = _mapAccount(
      await client.account.verifyCredentials(format: 'html'),
    );
    final session = AuthenticationSession(
      accountId: account.id,
      token: token,
      tokenSecret: tokenSecret,
    );

    try {
      await _sessionStorage.upsertAccount(
        account: account,
        session: session,
      );
      await _sessionStorage.setActiveAccountId(account.id);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }

    final accounts = _upsertAccount(
      _currentAuthentication.accounts,
      account,
    );
    _emit(
      AuthenticationSnapshot.authenticated(
        accounts: accounts,
        activeAccount: account,
      ),
    );
    return account;
  }

  Future<AuthenticationSnapshot> _activateFirstAvailable(
    List<AuthenticatedAccount> accounts, {
    String? preferredAccountId,
  }) async {
    var remainingAccounts = List<AuthenticatedAccount>.of(accounts);
    final preferredAccount = preferredAccountId == null
        ? null
        : _accountById(remainingAccounts, preferredAccountId);
    final candidates = <AuthenticatedAccount>[
      ?preferredAccount,
      ...remainingAccounts.where(
        (account) => account.id != preferredAccount?.id,
      ),
    ];

    for (final candidate in candidates) {
      try {
        final verifiedAccount = await _verifyStoredAccount(candidate);
        remainingAccounts = _upsertAccount(
          remainingAccounts,
          verifiedAccount,
        );
        try {
          await _sessionStorage.setActiveAccountId(verifiedAccount.id);
        } on Object catch (_) {
          throw const AuthenticationStorageFailure();
        }
        return _emit(
          AuthenticationSnapshot.authenticated(
            accounts: remainingAccounts,
            activeAccount: verifiedAccount,
          ),
        );
      } on AccountUnavailableFailure {
        remainingAccounts = _withoutAccount(
          remainingAccounts,
          candidate.id,
        );
      } on AuthenticationFailure {
        _emit(AuthenticationSnapshot.unknown(accounts: remainingAccounts));
        rethrow;
      }
    }

    try {
      await _sessionStorage.setActiveAccountId(null);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }
    return _emit(
      AuthenticationSnapshot.unauthenticated(accounts: remainingAccounts),
    );
  }

  Future<AuthenticatedAccount> _verifyStoredAccount(
    AuthenticatedAccount storedAccount,
  ) async {
    final AuthenticationSession? session;
    try {
      session = await _sessionStorage.readSession(storedAccount.id);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }

    if (session == null ||
        !session.isValid ||
        session.accountId != storedAccount.id) {
      await _deleteUnavailableAccount(storedAccount.id);
      throw AccountUnavailableFailure(accountId: storedAccount.id);
    }

    final client = _clientFactory(session: session);
    try {
      final verifiedAccount = _mapAccount(
        await client.account.verifyCredentials(format: 'html'),
      );
      if (verifiedAccount.id != storedAccount.id) {
        await _deleteUnavailableAccount(storedAccount.id);
        throw AccountUnavailableFailure(accountId: storedAccount.id);
      }
      if (verifiedAccount != storedAccount) {
        try {
          await _sessionStorage.upsertAccount(
            account: verifiedAccount,
            session: session,
          );
        } on Object catch (_) {
          throw const AuthenticationStorageFailure();
        }
      }
      return verifiedAccount;
    } on AuthenticationFailure {
      rethrow;
    } on fanfou.FanfouApiException catch (error) {
      if (_isUnauthorized(error.statusCode)) {
        await _deleteUnavailableAccount(storedAccount.id);
        throw AccountUnavailableFailure(accountId: storedAccount.id);
      }
      throw AuthenticationApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (_) {
      throw const AuthenticationUnknownFailure();
    } finally {
      client.close();
    }
  }

  Future<void> _deleteUnavailableAccount(String accountId) async {
    try {
      await _sessionStorage.deleteAccount(accountId);
    } on Object catch (_) {
      throw const AuthenticationStorageFailure();
    }
  }

  AuthenticatedAccount _mapAccount(fanfou.User user) {
    return AuthenticatedAccount(
      id: user.id,
      name: user.name,
      screenName: user.screenName,
      avatarUrl: user.profileImageUrlLarge ?? user.profileImageUrl,
      description: user.description,
      location: user.location,
      url: user.url,
      protected: user.protected,
      following: user.following,
      followersCount: user.followersCount,
      friendsCount: user.friendsCount,
      favoritesCount: user.favouritesCount,
      statusesCount: user.statusesCount,
      gender: user.gender,
      photoCount: user.photoCount,
      createdAt: user.createdAt,
      birthday: user.birthday,
    );
  }

  List<AuthenticatedAccount> _deduplicateAccounts(
    List<AuthenticatedAccount> accounts,
  ) {
    final accountsById = <String, AuthenticatedAccount>{};
    for (final account in accounts) {
      if (account.id.isNotEmpty) {
        accountsById[account.id] = account;
      }
    }
    return List<AuthenticatedAccount>.unmodifiable(accountsById.values);
  }

  List<AuthenticatedAccount> _upsertAccount(
    List<AuthenticatedAccount> accounts,
    AuthenticatedAccount account,
  ) {
    final updatedAccounts = List<AuthenticatedAccount>.of(accounts);
    final index = updatedAccounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      updatedAccounts.add(account);
    } else {
      updatedAccounts[index] = account;
    }
    return List<AuthenticatedAccount>.unmodifiable(updatedAccounts);
  }

  List<AuthenticatedAccount> _withoutAccount(
    List<AuthenticatedAccount> accounts,
    String accountId,
  ) {
    return List<AuthenticatedAccount>.unmodifiable(
      accounts.where((account) => account.id != accountId),
    );
  }

  AuthenticatedAccount? _accountById(
    List<AuthenticatedAccount> accounts,
    String accountId,
  ) {
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  bool _isUnauthorized(int statusCode) =>
      statusCode == 401 || statusCode == 403;

  bool _isValidCallbackTarget(Uri callbackUri) {
    return callbackUri.scheme.isNotEmpty &&
        callbackUri.host.isNotEmpty &&
        callbackUri.path.isNotEmpty &&
        !callbackUri.hasQuery &&
        !callbackUri.hasFragment;
  }

  bool _matchesCallbackTarget(Uri actual, Uri expected) {
    return actual.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        actual.host.toLowerCase() == expected.host.toLowerCase() &&
        actual.path == expected.path &&
        actual.hasPort == expected.hasPort &&
        (!actual.hasPort || actual.port == expected.port);
  }

  AuthenticationSnapshot _emit(AuthenticationSnapshot snapshot) {
    _currentAuthentication = snapshot;
    _authenticationController.add(snapshot);
    return snapshot;
  }
}

final class _PendingOAuthAuthorization {
  const _PendingOAuthAuthorization({
    required this.client,
    required this.requestToken,
    required this.callbackUri,
  });

  final fanfou.FanfouClient client;
  final String requestToken;
  final Uri callbackUri;
}
