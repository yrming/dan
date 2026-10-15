import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/status/cubit/status_mention_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart';

class _MockStatusRepository extends Mock implements StatusRepository {}

const _author = StatusAuthor(
  id: 'friend',
  name: '饭友',
  screenName: 'FriendName',
);
const _other = StatusAuthor(id: 'other', name: '另一位', screenName: 'other');
Status _status(String id, StatusAuthor author, {bool self = false}) =>
    Status(id: id, text: '@me', createdAt: '', author: author, isSelf: self);
void main() {
  group(StatusMentionCubit, () {
    late StatusRepository repository;
    setUp(() {
      repository = _MockStatusRepository();
      when(() => repository.getMentions(limit: 60)).thenAnswer(
        (_) async =>
            StatusPage(statuses: [_status('1', _author)], hasMore: false),
      );
    });
    StatusMentionCubit build() =>
        StatusMentionCubit(statusRepository: repository);
    group('load', () {
      blocTest<StatusMentionCubit, StatusMentionState>(
        'deduplicates recent mention authors and excludes self in API order',
        setUp: () => when(() => repository.getMentions(limit: 60)).thenAnswer(
          (_) async => StatusPage(
            statuses: [
              _status('4', _author),
              _status('3', _other),
              _status('2', _author),
              _status('1', _other, self: true),
            ],
            hasMore: true,
          ),
        ),
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [
          StatusMentionState(loading: true),
          StatusMentionState(users: const [_author, _other]),
        ],
        verify: (_) =>
            verify(() => repository.getMentions(limit: 60)).called(1),
      );
      blocTest<StatusMentionCubit, StatusMentionState>(
        'shows an empty result when no one has mentioned the account',
        setUp: () => when(() => repository.getMentions(limit: 60)).thenAnswer(
          (_) async => StatusPage(statuses: const [], hasMore: false),
        ),
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [StatusMentionState(loading: true), StatusMentionState()],
      );
      blocTest<StatusMentionCubit, StatusMentionState>(
        'retries failures',
        setUp: () => when(
          () => repository.getMentions(limit: 60),
        ).thenThrow(Exception('offline')),
        build: build,
        act: (cubit) async {
          await cubit.load();
          when(() => repository.getMentions(limit: 60)).thenAnswer(
            (_) async =>
                StatusPage(statuses: [_status('1', _author)], hasMore: false),
          );
          await cubit.load();
        },
        expect: () => [
          StatusMentionState(loading: true),
          StatusMentionState(failed: true),
          StatusMentionState(loading: true),
          StatusMentionState(users: const [_author]),
        ],
      );
    });
    group('queryChanged', () {
      for (final query in ['饭友', 'FRIENDNAME', 'FRIEND']) {
        blocTest<StatusMentionCubit, StatusMentionState>(
          'filters recent authors locally using $query',
          build: build,
          act: (cubit) async {
            await cubit.load();
            cubit
              ..queryChanged(query)
              ..queryChanged('missing')
              ..queryChanged('');
          },
          expect: () => [
            StatusMentionState(loading: true),
            StatusMentionState(users: const [_author]),
            StatusMentionState(query: query, users: const [_author]),
            StatusMentionState(query: 'missing'),
            StatusMentionState(users: const [_author]),
          ],
          verify: (_) {
            verify(() => repository.getMentions(limit: 60)).called(1);
            verifyNoMoreInteractions(repository);
          },
        );
      }
      blocTest<StatusMentionCubit, StatusMentionState>(
        'applies the latest query when the request completes',
        build: build,
        act: (cubit) async {
          final pending = Completer<StatusPage>();
          when(
            () => repository.getMentions(limit: 60),
          ).thenAnswer((_) => pending.future);
          final load = cubit.load();
          cubit.queryChanged('饭友');
          pending.complete(
            StatusPage(statuses: [_status('1', _author)], hasMore: false),
          );
          await load;
        },
        expect: () => [
          StatusMentionState(loading: true),
          StatusMentionState(query: '饭友', loading: true),
          StatusMentionState(query: '饭友', users: const [_author]),
        ],
      );
    });
  });
}
