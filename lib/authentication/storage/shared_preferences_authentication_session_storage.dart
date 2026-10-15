import 'dart:convert';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the complete multi-account authentication state as one JSON value.
///
/// OAuth tokens written by this adapter are not encrypted. The single document
/// is versioned so future storage schemas can be migrated deliberately.
final class SharedPreferencesAuthenticationSessionStorage
    implements AuthenticationSessionStorage {
  /// Creates a shared-preferences authentication state store.
  ///
  /// A custom [preferences] instance can be injected by tests.
  SharedPreferencesAuthenticationSessionStorage({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageVersion = 1;
  static const _stateKey = 'dan.authentication.accounts';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<AuthenticatedAccount>> readAccounts() async {
    final state = await _readState();
    return List<AuthenticatedAccount>.unmodifiable(
      state.accounts.map((storedAccount) => storedAccount.account),
    );
  }

  @override
  Future<String?> readActiveAccountId() async {
    return (await _readState()).activeAccountId;
  }

  @override
  Future<AuthenticationSession?> readSession(String accountId) async {
    _validateAccountId(accountId);
    final state = await _readState();
    for (final storedAccount in state.accounts) {
      if (storedAccount.account.id == accountId) {
        return storedAccount.session;
      }
    }
    return null;
  }

  @override
  Future<void> upsertAccount({
    required AuthenticatedAccount account,
    required AuthenticationSession session,
  }) async {
    if (!_isValidAccount(account)) {
      throw ArgumentError('Account metadata is incomplete.');
    }
    if (!session.isValid || account.id != session.accountId) {
      throw ArgumentError('The account and session do not match.');
    }

    final state = await _readState();
    final accounts = List<_StoredAccount>.of(state.accounts);
    final storedAccount = _StoredAccount(
      account: account,
      session: session,
    );
    final index = accounts.indexWhere(
      (candidate) => candidate.account.id == account.id,
    );
    if (index == -1) {
      accounts.add(storedAccount);
    } else {
      accounts[index] = storedAccount;
    }

    await _writeState(
      _StoredAuthenticationState(
        activeAccountId: state.activeAccountId,
        accounts: accounts,
      ),
    );
  }

  @override
  Future<void> setActiveAccountId(String? accountId) async {
    final state = await _readState();
    if (accountId != null) {
      _validateAccountId(accountId);
      final isStored = state.accounts.any(
        (storedAccount) => storedAccount.account.id == accountId,
      );
      if (!isStored) {
        throw StateError('The active account is not stored.');
      }
    }

    await _writeState(
      _StoredAuthenticationState(
        activeAccountId: accountId,
        accounts: state.accounts,
      ),
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    _validateAccountId(accountId);
    final state = await _readState();
    final accounts = state.accounts
        .where((storedAccount) => storedAccount.account.id != accountId)
        .toList(growable: false);
    await _writeState(
      _StoredAuthenticationState(
        activeAccountId: state.activeAccountId == accountId
            ? null
            : state.activeAccountId,
        accounts: accounts,
      ),
    );
  }

  @override
  Future<void> clear() => _preferences.remove(_stateKey);

  Future<_StoredAuthenticationState> _readState() async {
    final source = await _preferences.getString(_stateKey);
    if (source == null) {
      return const _StoredAuthenticationState();
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on Object {
      await _preferences.remove(_stateKey);
      return const _StoredAuthenticationState();
    }
    if (decoded is! Map<String, Object?>) {
      await _preferences.remove(_stateKey);
      return const _StoredAuthenticationState();
    }

    final version = decoded['version'];
    if (version != _storageVersion) {
      throw StateError('Unsupported authentication storage version.');
    }

    final rawActiveAccountId = decoded['activeAccountId'];
    final rawAccounts = decoded['accounts'];
    if ((rawActiveAccountId != null && rawActiveAccountId is! String) ||
        rawAccounts is! List<Object?>) {
      await _preferences.remove(_stateKey);
      return const _StoredAuthenticationState();
    }

    var repaired = false;
    final accountIds = <String>{};
    final accounts = <_StoredAccount>[];
    for (final rawAccount in rawAccounts) {
      final storedAccount = _StoredAccount.fromJson(rawAccount);
      if (storedAccount == null || !accountIds.add(storedAccount.account.id)) {
        repaired = true;
        continue;
      }
      accounts.add(storedAccount);
    }

    final activeAccountId = rawActiveAccountId as String?;
    final normalizedActiveAccountId =
        activeAccountId != null && accountIds.contains(activeAccountId)
        ? activeAccountId
        : null;
    if (normalizedActiveAccountId != activeAccountId) {
      repaired = true;
    }

    final state = _StoredAuthenticationState(
      activeAccountId: normalizedActiveAccountId,
      accounts: accounts,
    );
    if (repaired) {
      await _writeState(state);
    }
    return state;
  }

  Future<void> _writeState(_StoredAuthenticationState state) async {
    if (state.accounts.isEmpty) {
      await _preferences.remove(_stateKey);
      return;
    }
    await _preferences.setString(_stateKey, jsonEncode(state.toJson()));
  }

  static bool _isValidAccount(AuthenticatedAccount account) {
    return account.id.isNotEmpty &&
        account.name.isNotEmpty &&
        account.screenName.isNotEmpty;
  }

  static void _validateAccountId(String accountId) {
    if (accountId.isEmpty) {
      throw ArgumentError('The account identifier must not be empty.');
    }
  }
}

final class _StoredAuthenticationState {
  const _StoredAuthenticationState({
    this.activeAccountId,
    this.accounts = const [],
  });

  final String? activeAccountId;
  final List<_StoredAccount> accounts;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': SharedPreferencesAuthenticationSessionStorage._storageVersion,
      'activeAccountId': activeAccountId,
      'accounts': accounts.map((account) => account.toJson()).toList(),
    };
  }
}

final class _StoredAccount {
  const _StoredAccount({
    required this.account,
    required this.session,
  });

  static _StoredAccount? fromJson(Object? source) {
    if (source is! Map<String, Object?>) {
      return null;
    }
    final id = source['id'];
    final name = source['name'];
    final screenName = source['screenName'];
    final avatarUrl = source['avatarUrl'];
    final description = source['description'];
    final location = source['location'];
    final url = source['url'];
    final protected = source['protected'];
    final following = source['following'];
    final followersCount = source['followersCount'];
    final friendsCount = source['friendsCount'];
    final favoritesCount = source['favoritesCount'];
    final statusesCount = source['statusesCount'];
    final gender = source['gender'];
    final photoCount = source['photoCount'];
    final createdAt = source['createdAt'];
    final birthday = source['birthday'];
    final token = source['token'];
    final tokenSecret = source['tokenSecret'];
    if (id is! String ||
        name is! String ||
        screenName is! String ||
        (avatarUrl != null && avatarUrl is! String) ||
        (description != null && description is! String) ||
        (location != null && location is! String) ||
        (url != null && url is! String) ||
        (protected != null && protected is! bool) ||
        (following != null && following is! bool) ||
        (followersCount != null && followersCount is! int) ||
        (friendsCount != null && friendsCount is! int) ||
        (favoritesCount != null && favoritesCount is! int) ||
        (statusesCount != null && statusesCount is! int) ||
        (gender != null && gender is! String) ||
        (photoCount != null && photoCount is! int) ||
        (createdAt != null && createdAt is! String) ||
        (birthday != null && birthday is! String) ||
        token is! String ||
        tokenSecret is! String) {
      return null;
    }

    final account = AuthenticatedAccount(
      id: id,
      name: name,
      screenName: screenName,
      avatarUrl: avatarUrl as String?,
      description: description as String?,
      location: location as String?,
      url: url as String?,
      protected: protected as bool?,
      following: following as bool?,
      followersCount: followersCount as int?,
      friendsCount: friendsCount as int?,
      favoritesCount: favoritesCount as int?,
      statusesCount: statusesCount as int?,
      gender: gender as String?,
      photoCount: photoCount as int?,
      createdAt: createdAt as String?,
      birthday: birthday as String?,
    );
    final session = AuthenticationSession(
      accountId: id,
      token: token,
      tokenSecret: tokenSecret,
    );
    if (!SharedPreferencesAuthenticationSessionStorage._isValidAccount(
          account,
        ) ||
        !session.isValid ||
        account.id != session.accountId) {
      return null;
    }
    return _StoredAccount(account: account, session: session);
  }

  final AuthenticatedAccount account;
  final AuthenticationSession session;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': account.id,
      'name': account.name,
      'screenName': account.screenName,
      'avatarUrl': account.avatarUrl,
      'description': account.description,
      'location': account.location,
      'url': account.url,
      'protected': account.protected,
      'following': account.following,
      'followersCount': account.followersCount,
      'friendsCount': account.friendsCount,
      'favoritesCount': account.favoritesCount,
      'statusesCount': account.statusesCount,
      'gender': account.gender,
      'photoCount': account.photoCount,
      'createdAt': account.createdAt,
      'birthday': account.birthday,
      'token': session.token,
      'tokenSecret': session.tokenSecret,
    };
  }
}
