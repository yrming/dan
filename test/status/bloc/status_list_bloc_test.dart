import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/status/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

void main() {
  group(StatusListBloc, () {
    late status_repository.StatusRepository statusRepository;
    late StreamController<status_repository.StatusChange> statusChanges;

    setUp(() {
      statusRepository = _MockStatusRepository();
      statusChanges =
          StreamController<status_repository.StatusChange>.broadcast();
      when(
        () => statusRepository.statusChanges,
      ).thenAnswer((_) => statusChanges.stream);
    });

    tearDown(() async {
      await statusChanges.close();
    });

    StatusListBloc buildSubject([
      StatusFeed feed = StatusFeed.home,
      String? userId,
    ]) {
      return StatusListBloc(
        statusRepository: statusRepository,
        feed: feed,
        accountId: 'account-a',
        userId: userId,
      );
    }

    test('starts with an immutable initial state', () async {
      final bloc = buildSubject();
      addTearDown(bloc.close);

      expect(bloc.state, StatusListState());
      expect(() => bloc.state.statuses.clear(), throwsUnsupportedError);
    });

    group('search', () {
      blocTest<StatusListBloc, StatusListState>(
        'keeps the initial search prompt after an unrelated deletion',
        build: () => buildSubject(StatusFeed.search),
        act: (bloc) => bloc.add(
          const StatusListStatusChanged(
            status_repository.StatusDeleted(
              accountId: 'account-a',
              statusId: 'other',
            ),
          ),
        ),
        expect: () => <StatusListState>[],
      );

      blocTest<StatusListBloc, StatusListState>(
        'starts without requesting data',
        build: () => buildSubject(StatusFeed.search),
        expect: () => <StatusListState>[],
        verify: (bloc) => expect(bloc.state.status, StatusListStatus.initial),
      );

      blocTest<StatusListBloc, StatusListState>(
        'trims keywords and emits loading then matching statuses',
        setUp: () {
          when(() => statusRepository.searchStatuses(query: '猫')).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.search),
        act: (bloc) => bloc.add(const StatusListSearchSubmitted(' 猫 ')),
        expect: () => [
          StatusListState(status: StatusListStatus.loading, searchQuery: '猫'),
          StatusListState(
            status: StatusListStatus.success,
            searchQuery: '猫',
            statuses: const [_statusA],
            hasMore: false,
          ),
        ],
        verify: (_) =>
            verify(() => statusRepository.searchStatuses(query: '猫')).called(1),
      );

      blocTest<StatusListBloc, StatusListState>(
        'uses the current account search endpoint for mine',
        setUp: () {
          when(() => statusRepository.searchMyStatuses(query: '猫')).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.searchMine),
        act: (bloc) => bloc.add(const StatusListSearchSubmitted('猫')),
        expect: () => [
          StatusListState(status: StatusListStatus.loading, searchQuery: '猫'),
          StatusListState(
            status: StatusListStatus.success,
            searchQuery: '猫',
            statuses: const [_statusA],
            hasMore: false,
          ),
        ],
        verify: (_) => verify(
          () => statusRepository.searchMyStatuses(query: '猫'),
        ).called(1),
      );

      blocTest<StatusListBloc, StatusListState>(
        'uses the selected user id for a profile search',
        setUp: () {
          when(
            () => statusRepository.searchStatuses(
              query: '猫',
              userId: 'user-b',
            ),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.searchUser, 'user-b'),
        act: (bloc) => bloc.add(const StatusListSearchSubmitted('猫')),
        expect: () => [
          StatusListState(status: StatusListStatus.loading, searchQuery: '猫'),
          StatusListState(
            status: StatusListStatus.success,
            searchQuery: '猫',
            statuses: const [_statusA],
            hasMore: false,
          ),
        ],
        verify: (_) => verify(
          () => statusRepository.searchStatuses(
            query: '猫',
            userId: 'user-b',
          ),
        ).called(1),
      );

      blocTest<StatusListBloc, StatusListState>(
        'clears results without requesting an empty keyword',
        build: () => buildSubject(StatusFeed.search),
        seed: () => StatusListState(
          status: StatusListStatus.success,
          searchQuery: '猫',
          statuses: const [_statusA],
        ),
        act: (bloc) => bloc.add(const StatusListSearchSubmitted('   ')),
        expect: () => [StatusListState(hasMore: false)],
        verify: (_) => verifyNever(
          () => statusRepository.searchStatuses(query: any(named: 'query')),
        ),
      );

      blocTest<StatusListBloc, StatusListState>(
        'retries the submitted keyword after a failure and shows empty results',
        setUp: () {
          var calls = 0;
          when(() => statusRepository.searchStatuses(query: '猫')).thenAnswer((
            _,
          ) async {
            if (calls++ == 0) {
              throw const status_repository.StatusRepositoryUnknownFailure();
            }
            return status_repository.StatusPage(
              statuses: const [],
              hasMore: false,
            );
          });
        },
        build: () => buildSubject(StatusFeed.search),
        act: (bloc) async {
          bloc.add(const StatusListSearchSubmitted('猫'));
          await bloc.stream.firstWhere(
            (state) => state.status == StatusListStatus.failure,
          );
          bloc.add(const StatusListInitialLoadRequested());
        },
        expect: () => [
          StatusListState(status: StatusListStatus.loading, searchQuery: '猫'),
          StatusListState(status: StatusListStatus.failure, searchQuery: '猫'),
          StatusListState(status: StatusListStatus.loading, searchQuery: '猫'),
          StatusListState(
            status: StatusListStatus.empty,
            searchQuery: '猫',
            hasMore: false,
          ),
        ],
        errors: () => [isA<status_repository.StatusRepositoryUnknownFailure>()],
        verify: (_) =>
            verify(() => statusRepository.searchStatuses(query: '猫')).called(2),
      );

      blocTest<StatusListBloc, StatusListState>(
        'paginates using the submitted keyword and returned cursor',
        setUp: () {
          when(
            () =>
                statusRepository.searchStatuses(query: '猫', maxId: 'cursor-a'),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusB],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.search),
        seed: () => StatusListState(
          status: StatusListStatus.success,
          searchQuery: '猫',
          statuses: const [_statusA],
          nextCursor: 'cursor-a',
        ),
        act: (bloc) => bloc.add(const StatusListLoadMoreRequested()),
        expect: () => [
          isA<StatusListState>().having(
            (s) => s.loadMoreStatus,
            'loading',
            StatusLoadMoreStatus.inProgress,
          ),
          isA<StatusListState>()
              .having((s) => s.statuses, 'results', [_statusA, _statusB])
              .having((s) => s.hasMore, 'has more', false),
        ],
        verify: (_) => verify(
          () => statusRepository.searchStatuses(query: '猫', maxId: 'cursor-a'),
        ).called(1),
      );

      for (final clear in [false, true]) {
        blocTest<StatusListBloc, StatusListState>(
          'ignores old responses after '
          "${clear ? 'clearing' : 'replacing'} the query",
          build: () => buildSubject(StatusFeed.search),
          act: (bloc) async {
            final oldRequest = Completer<status_repository.StatusPage>();
            when(
              () => statusRepository.searchStatuses(query: 'old'),
            ).thenAnswer((_) => oldRequest.future);
            when(
              () => statusRepository.searchStatuses(query: 'new'),
            ).thenAnswer(
              (_) async => status_repository.StatusPage(
                statuses: const [_statusB],
                hasMore: false,
              ),
            );
            bloc.add(const StatusListSearchSubmitted('old'));
            await bloc.stream.firstWhere(
              (s) => s.status == StatusListStatus.loading,
            );
            bloc.add(StatusListSearchSubmitted(clear ? '' : 'new'));
            await bloc.stream.firstWhere(
              (s) =>
                  s.status ==
                  (clear ? StatusListStatus.initial : StatusListStatus.success),
            );
            oldRequest.complete(
              status_repository.StatusPage(
                statuses: const [_statusA],
                hasMore: false,
              ),
            );
          },
          expect: () => [
            StatusListState(
              status: StatusListStatus.loading,
              searchQuery: 'old',
            ),
            if (clear)
              StatusListState(hasMore: false)
            else ...[
              StatusListState(
                status: StatusListStatus.loading,
                searchQuery: 'new',
              ),
              StatusListState(
                status: StatusListStatus.success,
                searchQuery: 'new',
                statuses: const [_statusB],
                hasMore: false,
              ),
            ],
          ],
        );
      }
    });

    group('initial load', () {
      blocTest<StatusListBloc, StatusListState>(
        'emits [loading, success] when the home timeline returns a page',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: true,
              nextCursor: 'cursor-a',
            ),
          );
        },
        build: buildSubject,
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        expect: () => [
          StatusListState(status: StatusListStatus.loading),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            nextCursor: 'cursor-a',
          ),
        ],
        verify: (_) {
          verify(
            () => statusRepository.getHomeTimeline(),
          ).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'requests the public timeline for the public feed',
        setUp: () {
          when(
            () => statusRepository.getPublicTimeline(),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.public),
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        verify: (_) {
          verify(() => statusRepository.getPublicTimeline()).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'requests mentions for the mentions feed',
        setUp: () {
          when(
            () => statusRepository.getMentions(),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.mentions),
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        verify: (_) {
          verify(() => statusRepository.getMentions()).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'requests the selected user statuses for the user feed',
        setUp: () {
          when(
            () => statusRepository.getUserTimeline(userId: 'user-b'),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.user, 'user-b'),
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        verify: (_) {
          verify(
            () => statusRepository.getUserTimeline(userId: 'user-b'),
          ).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'requests the selected user photos for the photos feed',
        setUp: () {
          when(
            () => statusRepository.getPhotoTimeline(userId: 'user-b'),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.photos, 'user-b'),
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        verify: (_) {
          verify(
            () => statusRepository.getPhotoTimeline(userId: 'user-b'),
          ).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'requests the selected user favorites for the favorites feed',
        setUp: () {
          when(
            () => statusRepository.getFavorites(userId: 'user-b'),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: false,
            ),
          );
        },
        build: () => buildSubject(StatusFeed.favorites, 'user-b'),
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        verify: (_) {
          verify(
            () => statusRepository.getFavorites(userId: 'user-b'),
          ).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'emits [loading, empty] when the repository page is empty',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [],
              hasMore: false,
            ),
          );
        },
        build: buildSubject,
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        expect: () => [
          StatusListState(status: StatusListStatus.loading),
          StatusListState(
            status: StatusListStatus.empty,
            hasMore: false,
          ),
        ],
        verify: (_) {
          verify(() => statusRepository.getHomeTimeline()).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'emits [loading, failure] when the repository throws',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(),
          ).thenThrow(
            const status_repository.StatusRepositoryUnknownFailure(),
          );
        },
        build: buildSubject,
        act: (bloc) => bloc.add(const StatusListInitialLoadRequested()),
        expect: () => [
          StatusListState(status: StatusListStatus.loading),
          StatusListState(status: StatusListStatus.failure),
        ],
        errors: () => [
          isA<status_repository.StatusRepositoryUnknownFailure>(),
        ],
      );
    });

    group('refresh', () {
      blocTest<StatusListBloc, StatusListState>(
        'keeps the pagination frontier and prepends unique refreshed values',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(sinceId: _statusA.id),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusB, _updatedStatusA],
              hasMore: true,
              nextCursor: 'refresh-cursor',
            ),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: 'old-cursor',
        ),
        act: (bloc) => bloc.add(const StatusListRefreshRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            refreshStatus: StatusRefreshStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: 'old-cursor',
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusB, _updatedStatusA],
            nextCursor: 'old-cursor',
          ),
        ],
        verify: (_) {
          verify(
            () => statusRepository.getHomeTimeline(sinceId: _statusA.id),
          ).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'uses the refreshed page cursor when the previous feed was empty',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: true,
              nextCursor: 'refresh-cursor',
            ),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.empty,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const StatusListRefreshRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.empty,
            refreshStatus: StatusRefreshStatus.inProgress,
            hasMore: false,
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            nextCursor: 'refresh-cursor',
          ),
        ],
      );

      blocTest<StatusListBloc, StatusListState>(
        'uses the newest visible mention as sinceId when refreshing',
        setUp: () {
          when(
            () => statusRepository.getMentions(sinceId: _statusA.id),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusB],
              hasMore: true,
              nextCursor: 'refresh-cursor',
            ),
          );
        },
        build: () => buildSubject(StatusFeed.mentions),
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: 'old-cursor',
        ),
        act: (bloc) => bloc.add(const StatusListRefreshRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            refreshStatus: StatusRefreshStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: 'old-cursor',
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusB, _statusA],
            nextCursor: 'old-cursor',
          ),
        ],
        verify: (_) {
          verify(
            () => statusRepository.getMentions(sinceId: _statusA.id),
          ).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'restarts page-based favorites pagination after a refresh',
        setUp: () {
          when(
            () => statusRepository.getFavorites(userId: 'account-a'),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusB],
              hasMore: true,
              nextCursor: '2',
            ),
          );
        },
        build: () => buildSubject(StatusFeed.favorites),
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: '4',
        ),
        act: (bloc) => bloc.add(const StatusListRefreshRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            refreshStatus: StatusRefreshStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: '4',
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusB, _statusA],
            nextCursor: '2',
          ),
        ],
      );

      blocTest<StatusListBloc, StatusListState>(
        'retains existing content and exposes refresh failure',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(sinceId: _statusA.id),
          ).thenThrow(
            const status_repository.StatusRepositoryUnknownFailure(),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: 'cursor-a',
        ),
        act: (bloc) => bloc.add(const StatusListRefreshRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            refreshStatus: StatusRefreshStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: 'cursor-a',
          ),
          StatusListState(
            status: StatusListStatus.success,
            refreshStatus: StatusRefreshStatus.failure,
            statuses: const [_statusA],
            nextCursor: 'cursor-a',
          ),
        ],
        errors: () => [
          isA<status_repository.StatusRepositoryUnknownFailure>(),
        ],
      );
    });

    group('load more', () {
      blocTest<StatusListBloc, StatusListState>(
        'appends unique statuses using the stored cursor',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(
              maxId: 'cursor-a',
            ),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA, _statusB],
              hasMore: true,
              nextCursor: 'cursor-b',
            ),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: 'cursor-a',
        ),
        act: (bloc) => bloc.add(const StatusListLoadMoreRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            loadMoreStatus: StatusLoadMoreStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: 'cursor-a',
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA, _statusB],
            nextCursor: 'cursor-b',
          ),
        ],
      );

      blocTest<StatusListBloc, StatusListState>(
        'continues pagination when a duplicate page advances the cursor',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(
              maxId: 'cursor-a',
            ),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: true,
              nextCursor: 'cursor-b',
            ),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: 'cursor-a',
        ),
        act: (bloc) => bloc.add(const StatusListLoadMoreRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            loadMoreStatus: StatusLoadMoreStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: 'cursor-a',
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            nextCursor: 'cursor-b',
          ),
        ],
      );

      blocTest<StatusListBloc, StatusListState>(
        'stops pagination when a duplicate page does not advance the cursor',
        setUp: () {
          when(
            () => statusRepository.getHomeTimeline(
              maxId: 'cursor-a',
            ),
          ).thenAnswer(
            (_) async => status_repository.StatusPage(
              statuses: const [_statusA],
              hasMore: true,
              nextCursor: 'cursor-a',
            ),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
          nextCursor: 'cursor-a',
        ),
        act: (bloc) => bloc.add(const StatusListLoadMoreRequested()),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            loadMoreStatus: StatusLoadMoreStatus.inProgress,
            statuses: const [_statusA],
            nextCursor: 'cursor-a',
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            hasMore: false,
          ),
        ],
      );
    });

    group('repository changes', () {
      blocTest<StatusListBloc, StatusListState>(
        'keeps the home feed unchanged when a status is published',
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
        ),
        act: (_) => statusChanges.add(
          const status_repository.StatusCreated(
            accountId: 'account-a',
            status: _statusB,
          ),
        ),
        expect: () => <StatusListState>[],
        verify: (bloc) {
          expect(bloc.state.statuses, const [_statusA]);
          verifyNever(() => statusRepository.getHomeTimeline());
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'ignores a created status in the mentions feed',
        build: () => buildSubject(StatusFeed.mentions),
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
        ),
        act: (_) => statusChanges.add(
          const status_repository.StatusCreated(
            accountId: 'account-a',
            status: _statusB,
          ),
        ),
        expect: () => <StatusListState>[],
      );

      blocTest<StatusListBloc, StatusListState>(
        'removes a deleted status published for the active account',
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA, _statusB],
        ),
        act: (_) => statusChanges.add(
          const status_repository.StatusDeleted(
            accountId: 'account-a',
            statusId: 'status-a',
          ),
        ),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusB],
          ),
        ],
      );

      blocTest<StatusListBloc, StatusListState>(
        'ignores a change published for another account',
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
        ),
        act: (_) => statusChanges.add(
          const status_repository.StatusDeleted(
            accountId: 'account-b',
            statusId: 'status-a',
          ),
        ),
        expect: () => <StatusListState>[],
      );

      blocTest<StatusListBloc, StatusListState>(
        'adds a newly favorited status to the favorites feed',
        build: () => buildSubject(StatusFeed.favorites),
        seed: () => StatusListState(
          status: StatusListStatus.empty,
          hasMore: false,
        ),
        act: (_) => statusChanges.add(
          const status_repository.StatusUpdated(
            accountId: 'account-a',
            status: _statusA,
          ),
        ),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            hasMore: false,
          ),
        ],
      );

      blocTest<StatusListBloc, StatusListState>(
        'removes an unfavorited status from the favorites feed',
        build: () => buildSubject(StatusFeed.favorites),
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
        ),
        act: (_) => statusChanges.add(
          const status_repository.StatusUpdated(
            accountId: 'account-a',
            status: _unfavoritedStatusA,
          ),
        ),
        expect: () => [StatusListState(status: StatusListStatus.empty)],
      );
    });

    group('status mutations', () {
      blocTest<StatusListBloc, StatusListState>(
        'calls favoriteStatus and tracks the in-progress identifier',
        setUp: () {
          when(
            () => statusRepository.favoriteStatus(_statusB.id),
          ).thenAnswer((_) async => _statusB.copyWith(isFavorited: true));
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusB],
        ),
        act: (bloc) => bloc.add(
          const StatusListStatusFavoriteToggled('status-b'),
        ),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusB],
            updatingFavoriteStatusIds: const {'status-b'},
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusB],
            favoriteSuccess: const StatusFavoriteSuccess(
              statusId: 'status-b',
              isFavorited: true,
            ),
          ),
        ],
        verify: (_) {
          verify(() => statusRepository.favoriteStatus(_statusB.id)).called(1);
        },
      );

      blocTest<StatusListBloc, StatusListState>(
        'exposes a sanitized deletion failure without removing content',
        setUp: () {
          when(
            () => statusRepository.deleteStatus(_statusA.id),
          ).thenThrow(
            const status_repository.StatusRepositoryUnknownFailure(),
          );
        },
        build: buildSubject,
        seed: () => StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusA],
        ),
        act: (bloc) => bloc.add(
          const StatusListStatusDeletionRequested('status-a'),
        ),
        expect: () => [
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            deletingStatusIds: const {'status-a'},
          ),
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusA],
            actionFailure: const StatusActionFailure(
              statusId: 'status-a',
              action: StatusAction.delete,
            ),
          ),
        ],
        errors: () => [
          isA<status_repository.StatusRepositoryUnknownFailure>(),
        ],
      );
    });
  });
}

const _statusA = status_repository.Status(
  id: 'status-a',
  text: 'hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
  isFavorited: true,
);

const _updatedStatusA = status_repository.Status(
  id: 'status-a',
  text: 'updated hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
  isFavorited: true,
);

const _unfavoritedStatusA = status_repository.Status(
  id: 'status-a',
  text: 'hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
);

const _statusB = status_repository.Status(
  id: 'status-b',
  text: 'older',
  createdAt: 'Tue Jul 27 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'user-b',
    name: 'User B',
    screenName: 'user_b',
  ),
);
