import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/status/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;
import 'package:user_repository/user_repository.dart';

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group(StatusDetailCubit, () {
    late status_repository.StatusRepository repository;
    late UserRepository userRepository;
    late status_repository.Status reply;
    late status_repository.Status nestedReply;

    setUp(() {
      repository = _MockStatusRepository();
      userRepository = _MockUserRepository();
      when(
        () => userRepository.getUser(any()),
      ).thenAnswer((_) async => _originUser);
      reply = _status.copyWith(
        id: 'reply',
        inReplyToStatusId: _status.id,
        inReplyToUserId: _originUser.id,
      );
      nestedReply = _status.copyWith(
        id: 'nested',
        inReplyToStatusId: reply.id,
        inReplyToUserId: 'reply-author',
      );
      when(() => repository.getStatus(any())).thenAnswer((_) async => _status);
      when(
        () => repository.getContextTimeline(any()),
      ).thenAnswer((_) async => []);
      when(() => repository.deleteStatus(any())).thenAnswer((_) async {});
    });

    StatusDetailCubit buildSubject({status_repository.Status? initialStatus}) {
      return StatusDetailCubit(
        statusRepository: repository,
        userRepository: userRepository,
        statusId: initialStatus?.id ?? _status.id,
        initialStatus: initialStatus,
      );
    }

    group('load', () {
      for (final parentId in [null, '']) {
        for (final cached in [false, true]) {
          blocTest<StatusDetailCubit, StatusDetailState>(
            'skips context on load, refresh and retry for parent=$parentId '
            'with cached=$cached',
            build: () {
              final original = _status.copyWith(inReplyToStatusId: parentId);
              when(
                () => repository.getStatus(_status.id),
              ).thenAnswer((_) async => original);
              return buildSubject(initialStatus: cached ? original : null);
            },
            act: (cubit) async {
              await cubit.load();
              await cubit.refresh();
              await cubit.retry();
            },
            verify: (cubit) {
              expect(cubit.state.status, StatusDetailStatus.success);
              expect(cubit.state.statusDetail?.id, _status.id);
              expect(cubit.state.replies, isEmpty);
              verifyNever(() => repository.getContextTimeline(any()));
              if (cached) {
                verifyNever(() => repository.getStatus(any()));
              } else {
                verify(() => repository.getStatus(_status.id)).called(1);
              }
            },
          );
        }
      }

      blocTest<StatusDetailCubit, StatusDetailState>(
        'loads context when a fetched status is a reply',
        build: () {
          when(
            () => repository.getStatus(reply.id),
          ).thenAnswer((_) async => reply);
          when(
            () => repository.getContextTimeline(reply.id),
          ).thenAnswer((_) async => [_status, reply]);
          return StatusDetailCubit(
            statusRepository: repository,
            userRepository: userRepository,
            statusId: reply.id,
          );
        },
        act: (cubit) => cubit.load(),
        skip: 2,
        expect: () => [
          StatusDetailState(
            status: StatusDetailStatus.success,
            contextStatus: StatusDetailStatus.success,
            statusDetail: _status,
            replies: [reply],
          ),
        ],
        verify: (_) =>
            verify(() => repository.getContextTimeline(reply.id)).called(1),
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'uses the context original when an intermediate reply is missing',
        build: () {
          when(
            () => repository.getContextTimeline(nestedReply.id),
          ).thenAnswer((_) async => [_status, nestedReply]);
          return buildSubject(initialStatus: nestedReply);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<StatusDetailState>(),
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status,
            contextStatus: StatusDetailStatus.success,
            replies: [nestedReply],
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getContextTimeline(reply.id));
          verifyNever(() => repository.getStatus(reply.id));
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'loads an original status without requesting context',
        build: buildSubject,
        act: (cubit) => cubit.load(),
        expect: () => [
          StatusDetailState(
            status: StatusDetailStatus.loading,
            contextStatus: StatusDetailStatus.loading,
          ),
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status,
            contextStatus: StatusDetailStatus.success,
          ),
        ],
        verify: (_) {
          verify(() => repository.getStatus(_status.id)).called(1);
          verifyNever(() => repository.getContextTimeline(any()));
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'displays a cached original without requesting status or context',
        build: () => buildSubject(initialStatus: _status),
        act: (cubit) async {
          await cubit.load();
          await cubit.load();
        },
        expect: () => [
          isA<StatusDetailState>().having(
            (s) => s.contextStatus,
            'context',
            StatusDetailStatus.loading,
          ),
          isA<StatusDetailState>().having(
            (s) => s.contextStatus,
            'context',
            StatusDetailStatus.success,
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getStatus(any()));
          verifyNever(() => repository.getContextTimeline(any()));
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'resolves the original and deduplicates replies in parent-first order',
        build: () {
          when(
            () => repository.getContextTimeline(nestedReply.id),
          ).thenAnswer((_) async => [nestedReply, reply, reply, _status]);
          return buildSubject(initialStatus: nestedReply);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<StatusDetailState>(),
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status,
            contextStatus: StatusDetailStatus.success,
            replies: [reply, nestedReply],
          ),
        ],
        verify: (cubit) {
          verifyNever(() => repository.getStatus(any()));
          expect(cubit.state.replies.clear, throwsUnsupportedError);
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'follows truncated context back to the original and keeps all replies',
        build: () {
          when(
            () => repository.getContextTimeline(nestedReply.id),
          ).thenAnswer((_) async => [nestedReply]);
          when(
            () => repository.getContextTimeline(reply.id),
          ).thenAnswer((_) async => [reply, nestedReply]);
          when(
            () => repository.getContextTimeline(_status.id),
          ).thenAnswer((_) async => [_status, reply]);
          return buildSubject(initialStatus: nestedReply);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<StatusDetailState>(),
          StatusDetailState(
            status: StatusDetailStatus.success,
            contextStatus: StatusDetailStatus.success,
            statusDetail: _status,
            replies: [reply, nestedReply],
          ),
        ],
        verify: (_) {
          verify(() => repository.getContextTimeline(reply.id)).called(1);
          verify(() => repository.getContextTimeline(_status.id)).called(1);
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'fetches an omitted parent and preserves the selected reply',
        build: () => buildSubject(initialStatus: reply),
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<StatusDetailState>(),
          StatusDetailState(
            status: StatusDetailStatus.success,
            contextStatus: StatusDetailStatus.success,
            statusDetail: _status,
            replies: [reply],
          ),
        ],
        verify: (_) => verify(() => repository.getStatus(_status.id)).called(1),
      );

      for (final code in [403, 404]) {
        blocTest<StatusDetailCubit, StatusDetailState>(
          'keeps replies with an unavailable original for API failure $code',
          build: () {
            when(
              () => repository.getContextTimeline(nestedReply.id),
            ).thenAnswer((_) async => [reply, nestedReply]);
            when(() => repository.getContextTimeline(_status.id)).thenThrow(
              status_repository.StatusRepositoryApiFailure(statusCode: code),
            );
            return buildSubject(initialStatus: nestedReply);
          },
          act: (cubit) => cubit.load(),
          expect: () => [
            isA<StatusDetailState>(),
            StatusDetailState(
              status: StatusDetailStatus.success,
              contextStatus: StatusDetailStatus.success,
              statusDetail: _unavailableStatus,
              replies: [reply, nestedReply],
              originUnavailable: true,
            ),
          ],
          verify: (_) {
            verify(() => userRepository.getUser(_originUser.id)).called(1);
            verifyNever(() => userRepository.getUser('reply-author'));
          },
        );
      }

      blocTest<StatusDetailCubit, StatusDetailState>(
        'shows a retryable failure when fetching the selected status fails',
        build: () {
          when(
            () => repository.getStatus(any()),
          ).thenThrow(const status_repository.StatusRepositoryUnknownFailure());
          return buildSubject();
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<StatusDetailState>(),
          StatusDetailState(
            status: StatusDetailStatus.failure,
            contextStatus: StatusDetailStatus.failure,
          ),
        ],
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'retains the cached status on network failure and succeeds on retry',
        build: () {
          when(
            () => repository.getContextTimeline(any()),
          ).thenThrow(const status_repository.StatusRepositoryUnknownFailure());
          return buildSubject(initialStatus: reply);
        },
        act: (cubit) async {
          await cubit.load();
          when(
            () => repository.getContextTimeline(any()),
          ).thenAnswer((_) async => [_status, reply]);
          await cubit.retry();
        },
        expect: () => [
          isA<StatusDetailState>(),
          isA<StatusDetailState>()
              .having(
                (s) => s.contextStatus,
                'context',
                StatusDetailStatus.failure,
              )
              .having((s) => s.statusDetail, 'cached status', reply)
              .having((s) => s.originUnavailable, 'unavailable', false),
          isA<StatusDetailState>(),
          isA<StatusDetailState>()
              .having((s) => s.statusDetail, 'original', _status)
              .having((s) => s.replies, 'replies', [reply]),
        ],
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'stops a cyclic reply chain with a retryable error',
        build: () {
          final cyclic = reply.copyWith(inReplyToStatusId: nestedReply.id);
          when(
            () => repository.getContextTimeline(any()),
          ).thenAnswer((_) async => [cyclic, nestedReply]);
          return buildSubject(initialStatus: nestedReply);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<StatusDetailState>(),
          isA<StatusDetailState>().having(
            (s) => s.contextStatus,
            'context',
            StatusDetailStatus.failure,
          ),
        ],
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'ignores duplicate loads and completion after closing',
        build: () => buildSubject(initialStatus: reply),
        act: (cubit) async {
          final request = Completer<List<status_repository.Status>>();
          when(
            () => repository.getContextTimeline(any()),
          ).thenAnswer((_) => request.future);
          final loading = cubit.load();
          await cubit.load();
          await cubit.close();
          request.complete([_status]);
          await loading;
        },
        expect: () => [isA<StatusDetailState>()],
        verify: (_) => verify(
          () => repository.getContextTimeline(reply.id),
        ).called(1),
      );
    });

    group('unavailable origin author', () {
      for (final cached in [false, true]) {
        blocTest<StatusDetailCubit, StatusDetailState>(
          'keeps context when author lookup fails with cached=$cached',
          build: () {
            when(() => repository.getContextTimeline(reply.id)).thenThrow(
              const status_repository.StatusRepositoryApiFailure(
                statusCode: 404,
              ),
            );
            when(
              () => userRepository.getUser(_originUser.id),
            ).thenThrow(Exception('profile unavailable'));
            when(
              () => userRepository.getCachedUser(_originUser.id),
            ).thenReturn(cached ? _originUser : null);
            return buildSubject(initialStatus: reply);
          },
          act: (cubit) => cubit.load(),
          expect: () => [
            isA<StatusDetailState>(),
            isA<StatusDetailState>()
                .having(
                  (s) => s.contextStatus,
                  'loaded',
                  StatusDetailStatus.success,
                )
                .having((s) => s.originUnavailable, 'unavailable', true)
                .having((s) => s.replies, 'replies', [reply])
                .having(
                  (s) => s.statusDetail!.author.id,
                  'author id',
                  _originUser.id,
                )
                .having(
                  (s) => s.statusDetail!.author.name,
                  'name',
                  cached ? _originUser.name : '',
                )
                .having(
                  (s) => s.statusDetail!.author.avatarUrl,
                  'avatar',
                  cached ? _originUser.avatarUrl : null,
                ),
          ],
          verify: (_) =>
              verify(() => userRepository.getUser(_originUser.id)).called(1),
        );
      }

      for (final userId in [null, '']) {
        blocTest<StatusDetailCubit, StatusDetailState>(
          'uses an unknown author when the parent user id is $userId',
          build: () {
            when(() => repository.getContextTimeline(reply.id)).thenThrow(
              const status_repository.StatusRepositoryApiFailure(
                statusCode: 403,
              ),
            );
            return buildSubject(
              initialStatus: reply.copyWith(inReplyToUserId: userId),
            );
          },
          act: (cubit) => cubit.load(),
          expect: () => [
            isA<StatusDetailState>(),
            isA<StatusDetailState>()
                .having((s) => s.originUnavailable, 'unavailable', true)
                .having((s) => s.statusDetail!.author.id, 'unknown id', '')
                .having(
                  (s) => s.statusDetail!.author.avatarUrl,
                  'unknown avatar',
                  isNull,
                ),
          ],
          verify: (_) => verifyNever(() => userRepository.getUser(any())),
        );
      }

      blocTest<StatusDetailCubit, StatusDetailState>(
        'ignores author lookup completion after closing the page',
        build: () => buildSubject(initialStatus: reply),
        act: (cubit) async {
          final request = Completer<UserProfile>();
          final started = Completer<void>();
          when(() => repository.getContextTimeline(reply.id)).thenThrow(
            const status_repository.StatusRepositoryApiFailure(statusCode: 404),
          );
          when(() => userRepository.getUser(_originUser.id)).thenAnswer((_) {
            started.complete();
            return request.future;
          });
          final loading = cubit.load();
          await started.future;
          await cubit.close();
          request.complete(_originUser);
          await loading;
        },
        expect: () => [isA<StatusDetailState>()],
      );
    });

    group('refresh', () {
      blocTest<StatusDetailCubit, StatusDetailState>(
        'reloads around the selected reply after resolving the original',
        build: () {
          when(
            () => repository.getContextTimeline(reply.id),
          ).thenAnswer((_) async => [_status, reply]);
          return buildSubject(initialStatus: reply);
        },
        act: (cubit) async {
          await cubit.load();
          when(
            () => repository.getContextTimeline(reply.id),
          ).thenAnswer((_) async => [_status, reply, nestedReply]);
          await cubit.refresh();
        },
        skip: 3,
        expect: () => [
          isA<StatusDetailState>().having(
            (s) => s.replies,
            'new replies',
            [reply, nestedReply],
          ),
        ],
        verify: (_) => verify(
          () => repository.getContextTimeline(reply.id),
        ).called(2),
      );
    });

    group('delete', () {
      blocTest<StatusDetailCubit, StatusDetailState>(
        'skips context when deletion leaves the original selected',
        build: () {
          when(
            () => repository.getContextTimeline(reply.id),
          ).thenAnswer((_) async => [_status, reply]);
          when(
            () => repository.getContextTimeline(_status.id),
          ).thenAnswer((_) async => [_status]);
          return buildSubject(initialStatus: reply);
        },
        act: (cubit) async {
          await cubit.load();
          await cubit.deleteReply(reply.id);
          await cubit.refresh();
        },
        skip: 4,
        expect: () => [
          isA<StatusDetailState>()
              .having((s) => s.statusDetail, 'original', _status)
              .having((s) => s.replies, 'replies', isEmpty),
        ],
        verify: (_) {
          verify(() => repository.getContextTimeline(reply.id)).called(1);
          verifyNever(() => repository.getContextTimeline(_status.id));
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'retains a reply when deletion fails',
        build: () {
          when(() => repository.deleteStatus(reply.id)).thenThrow(
            const status_repository.StatusRepositoryUnknownFailure(),
          );
          return buildSubject(initialStatus: _status);
        },
        seed: () => StatusDetailState(
          status: StatusDetailStatus.success,
          statusDetail: _status,
          replies: [reply],
        ),
        act: (cubit) => cubit.deleteReply(reply.id),
        expect: () => <StatusDetailState>[],
        errors: () => [isA<status_repository.StatusRepositoryUnknownFailure>()],
        verify: (cubit) => expect(cubit.state.replies, [reply]),
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'deletes the displayed original rather than the route reply',
        build: () {
          when(
            () => repository.getContextTimeline(reply.id),
          ).thenAnswer((_) async => [_status, reply]);
          return buildSubject(initialStatus: reply);
        },
        act: (cubit) async {
          await cubit.load();
          await cubit.delete();
        },
        verify: (_) {
          verify(() => repository.deleteStatus(_status.id)).called(1);
          verifyNever(() => repository.deleteStatus(reply.id));
        },
      );

      blocTest<StatusDetailCubit, StatusDetailState>(
        'removes only the deleted reply after repository success',
        build: () => buildSubject(initialStatus: _status),
        seed: () => StatusDetailState(
          status: StatusDetailStatus.success,
          statusDetail: _status,
          replies: [reply, nestedReply],
        ),
        act: (cubit) => cubit.deleteReply(reply.id),
        expect: () => [
          isA<StatusDetailState>()
              .having((s) => s.statusDetail, 'original', _status)
              .having((s) => s.replies, 'remaining replies', [nestedReply]),
        ],
        verify: (_) =>
            verify(() => repository.deleteStatus(reply.id)).called(1),
      );
    });
  });
}

const _status = status_repository.Status(
  id: 'status-a',
  text: 'hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
);

const _originUser = UserProfile(
  id: 'origin-author',
  name: 'Original Author',
  screenName: 'original',
  avatarUrl: 'https://example.com/origin.png',
);

const _unavailableStatus = status_repository.Status(
  id: 'status-a',
  text: '',
  createdAt: '',
  author: status_repository.StatusAuthor(
    id: 'origin-author',
    name: 'Original Author',
    screenName: 'original',
    avatarUrl: 'https://example.com/origin.png',
  ),
);
