import 'dart:convert';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferencesAsync extends Mock
    implements SharedPreferencesAsync {}

void main() {
  group(SharedPreferencesAuthenticationSessionStorage, () {
    late SharedPreferencesAsync preferences;
    late String? storedState;
    late List<String> operations;
    late SharedPreferencesAuthenticationSessionStorage subject;

    setUp(() {
      preferences = _MockSharedPreferencesAsync();
      storedState = null;
      operations = <String>[];

      when(() => preferences.getString(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        operations.add('read:$key');
        return key == _stateKey ? storedState : null;
      });
      when(
        () => preferences.setString(any(), any()),
      ).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        final value = invocation.positionalArguments[1] as String;
        operations.add('write:$key');
        if (key == _stateKey) {
          storedState = value;
        }
      });
      when(() => preferences.remove(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        operations.add('delete:$key');
        if (key == _stateKey) {
          storedState = null;
        }
      });

      subject = SharedPreferencesAuthenticationSessionStorage(
        preferences: preferences,
      );
    });

    group('readAccounts', () {
      test(
        'returns an empty list when the state document is missing',
        () async {
          final accounts = await subject.readAccounts();

          expect(accounts, isEmpty);
          verify(() => preferences.getString(_stateKey)).called(1);
        },
      );

      test('returns multiple profiles in their stored order', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account2, _session2),
            _storedAccount(_account1, _session1),
          ],
          activeAccountId: '2',
        );

        final accounts = await subject.readAccounts();

        expect(accounts, <AuthenticatedAccount>[_account2, _account1]);
        verify(() => preferences.getString(_stateKey)).called(1);
      });

      test('reads legacy account summaries without profile fields', () async {
        storedState = _stateJson(
          accounts: [
            <String, Object?>{
              'id': _account1.id,
              'name': _account1.name,
              'screenName': _account1.screenName,
              'avatarUrl': _account1.avatarUrl,
              'token': _session1.token,
              'tokenSecret': _session1.tokenSecret,
            },
          ],
          activeAccountId: _account1.id,
        );

        final accounts = await subject.readAccounts();

        expect(
          accounts,
          [
            AuthenticatedAccount(
              id: _account1.id,
              name: _account1.name,
              screenName: _account1.screenName,
              avatarUrl: _account1.avatarUrl,
            ),
          ],
        );
      });

      test(
        'deletes a malformed state document and returns an empty list',
        () async {
          storedState = '{not-json';

          final accounts = await subject.readAccounts();

          expect(accounts, isEmpty);
          expect(storedState, isNull);
          verify(() => preferences.remove(_stateKey)).called(1);
        },
      );

      test('repairs invalid, duplicate, and stale account data', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account1, _session1),
            <String, Object?>{'profile': 'invalid'},
            _storedAccount(_account1, _session1),
            _storedAccount(_account2, _session2),
          ],
          activeAccountId: 'missing',
        );

        final accounts = await subject.readAccounts();
        final repairedState = _decodeState(storedState!);

        expect(accounts, <AuthenticatedAccount>[_account1, _account2]);
        expect(repairedState['activeAccountId'], isNull);
        expect(
          repairedState['accounts'],
          isA<List<Object?>>().having(
            (accounts) => accounts.length,
            'length',
            2,
          ),
        );
        verify(() => preferences.setString(_stateKey, any())).called(1);
      });

      test(
        'preserves an unsupported version and throws a state error',
        () async {
          storedState = _stateJson(
            version: 2,
            accounts: [_storedAccount(_account1, _session1)],
          );
          final originalState = storedState;

          await expectLater(subject.readAccounts(), throwsStateError);

          expect(storedState, originalState);
          verifyNever(() => preferences.remove(_stateKey));
          verifyNever(() => preferences.setString(_stateKey, any()));
        },
      );

      test('propagates platform preference failures', () async {
        final failure = PlatformException(code: 'unavailable');
        when(() => preferences.getString(_stateKey)).thenThrow(failure);

        await expectLater(subject.readAccounts(), throwsA(same(failure)));
      });
    });

    group('readActiveAccountId', () {
      test('returns the active account from the state document', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account1, _session1),
            _storedAccount(_account2, _session2),
          ],
          activeAccountId: '2',
        );

        expect(await subject.readActiveAccountId(), '2');
      });

      test('clears a stale active account identifier', () async {
        storedState = _stateJson(
          accounts: [_storedAccount(_account1, _session1)],
          activeAccountId: '2',
        );

        expect(await subject.readActiveAccountId(), isNull);
        expect(_decodeState(storedState!)['activeAccountId'], isNull);
      });
    });

    group('readSession', () {
      test('returns the session for the requested account only', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account1, _session1),
            _storedAccount(_account2, _session2),
          ],
          activeAccountId: '1',
        );

        final session = await subject.readSession('2');

        expect(session?.accountId, _session2.accountId);
        expect(session?.token, _session2.token);
        expect(session?.tokenSecret, _session2.tokenSecret);
      });

      test('returns null when the requested account is not stored', () async {
        storedState = _stateJson(
          accounts: [_storedAccount(_account1, _session1)],
        );

        expect(await subject.readSession('2'), isNull);
      });
    });

    group('upsertAccount', () {
      test('writes flat account and session fields in one document', () async {
        await subject.upsertAccount(
          account: _account1,
          session: _session1,
        );

        final state = _decodeState(storedState!);
        final accounts = state['accounts']! as List<Object?>;
        final storedAccount = accounts.single! as Map<String, Object?>;
        expect(state['version'], 1);
        expect(storedAccount['id'], _account1.id);
        expect(storedAccount['name'], _account1.name);
        expect(storedAccount['screenName'], _account1.screenName);
        expect(storedAccount['avatarUrl'], _account1.avatarUrl);
        expect(storedAccount['description'], _account1.description);
        expect(storedAccount['location'], _account1.location);
        expect(storedAccount['url'], _account1.url);
        expect(storedAccount['protected'], _account1.protected);
        expect(storedAccount['following'], _account1.following);
        expect(storedAccount['followersCount'], _account1.followersCount);
        expect(storedAccount['friendsCount'], _account1.friendsCount);
        expect(storedAccount['favoritesCount'], _account1.favoritesCount);
        expect(storedAccount['statusesCount'], _account1.statusesCount);
        expect(storedAccount['gender'], _account1.gender);
        expect(storedAccount['photoCount'], _account1.photoCount);
        expect(storedAccount['createdAt'], _account1.createdAt);
        expect(storedAccount['birthday'], _account1.birthday);
        expect(storedAccount['token'], _session1.token);
        expect(storedAccount['tokenSecret'], _session1.tokenSecret);
        expect(storedAccount, isNot(contains('profile')));
        expect(storedAccount, isNot(contains('session')));
        expect(storedAccount, isNot(contains('accountId')));
        expect(
          operations.where((operation) => operation.startsWith('write:')),
          <String>['write:$_stateKey'],
        );
      });

      test('updates an existing account without changing its order', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account1, _session1),
            _storedAccount(_account2, _session2),
          ],
          activeAccountId: '2',
        );
        const updatedAccount = AuthenticatedAccount(
          id: '1',
          name: 'Updated',
          screenName: 'updated',
        );
        const updatedSession = AuthenticationSession(
          accountId: '1',
          token: 'updated-token',
          tokenSecret: 'updated-secret',
        );

        await subject.upsertAccount(
          account: updatedAccount,
          session: updatedSession,
        );

        expect(await subject.readAccounts(), <AuthenticatedAccount>[
          updatedAccount,
          _account2,
        ]);
        expect(await subject.readActiveAccountId(), '2');
      });

      test('rejects a session belonging to a different account', () async {
        expect(
          () => subject.upsertAccount(
            account: _account1,
            session: _session2,
          ),
          throwsArgumentError,
        );
        verifyNever(() => preferences.setString(_stateKey, any()));
      });
    });

    group('setActiveAccountId', () {
      test('stores an identifier belonging to a stored account', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account1, _session1),
            _storedAccount(_account2, _session2),
          ],
        );

        await subject.setActiveAccountId('2');

        expect(_decodeState(storedState!)['activeAccountId'], '2');
      });

      test('clears the active account while preserving accounts', () async {
        storedState = _stateJson(
          accounts: [_storedAccount(_account1, _session1)],
          activeAccountId: '1',
        );

        await subject.setActiveAccountId(null);

        final state = _decodeState(storedState!);
        expect(state['activeAccountId'], isNull);
        expect(
          state['accounts'],
          isA<List<Object?>>().having(
            (accounts) => accounts.length,
            'length',
            1,
          ),
        );
      });

      test('rejects an identifier that is not stored', () async {
        storedState = _stateJson(
          accounts: [_storedAccount(_account1, _session1)],
        );

        await expectLater(subject.setActiveAccountId('2'), throwsStateError);

        verifyNever(() => preferences.setString(_stateKey, any()));
      });
    });

    group('deleteAccount', () {
      test(
        'deletes an inactive account and preserves the active account',
        () async {
          storedState = _stateJson(
            accounts: [
              _storedAccount(_account1, _session1),
              _storedAccount(_account2, _session2),
            ],
            activeAccountId: '1',
          );

          await subject.deleteAccount('2');

          expect(await subject.readAccounts(), <AuthenticatedAccount>[
            _account1,
          ]);
          expect(await subject.readActiveAccountId(), '1');
        },
      );

      test('clears the active identifier when deleting its account', () async {
        storedState = _stateJson(
          accounts: [
            _storedAccount(_account1, _session1),
            _storedAccount(_account2, _session2),
          ],
          activeAccountId: '1',
        );

        await subject.deleteAccount('1');

        expect(await subject.readAccounts(), <AuthenticatedAccount>[_account2]);
        expect(await subject.readActiveAccountId(), isNull);
      });

      test('removes the state key after deleting the final account', () async {
        storedState = _stateJson(
          accounts: [_storedAccount(_account1, _session1)],
          activeAccountId: '1',
        );

        await subject.deleteAccount('1');

        expect(storedState, isNull);
        verify(() => preferences.remove(_stateKey)).called(1);
      });
    });

    group('clear', () {
      test('removes the single authentication state key', () async {
        storedState = _stateJson(
          accounts: [_storedAccount(_account1, _session1)],
          activeAccountId: '1',
        );

        await subject.clear();

        expect(storedState, isNull);
        verify(() => preferences.remove(_stateKey)).called(1);
      });
    });
  });
}

const _stateKey = 'dan.authentication.accounts';

const _account1 = AuthenticatedAccount(
  id: '1',
  name: 'One',
  screenName: 'one',
  avatarUrl: 'https://example.com/one.png',
  description: 'One biography',
  location: 'Shanghai',
  url: 'https://fanfou.com/one',
  protected: true,
  following: false,
  followersCount: 12,
  friendsCount: 8,
  favoritesCount: 5,
  statusesCount: 42,
  gender: '男',
  photoCount: 7,
  createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
  birthday: '1990-01-02',
);
const _account2 = AuthenticatedAccount(
  id: '2',
  name: 'Two',
  screenName: 'two',
);
const _session1 = AuthenticationSession(
  accountId: '1',
  token: 'token-one',
  tokenSecret: 'secret-one',
);
const _session2 = AuthenticationSession(
  accountId: '2',
  token: 'token-two',
  tokenSecret: 'secret-two',
);

String _stateJson({
  int version = 1,
  String? activeAccountId,
  List<Object?> accounts = const [],
}) {
  return jsonEncode(<String, Object?>{
    'version': version,
    'activeAccountId': activeAccountId,
    'accounts': accounts,
  });
}

Map<String, Object?> _storedAccount(
  AuthenticatedAccount account,
  AuthenticationSession session,
) {
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

Map<String, Object?> _decodeState(String source) {
  return jsonDecode(source) as Map<String, Object?>;
}
