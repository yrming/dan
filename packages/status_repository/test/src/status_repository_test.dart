import 'dart:io';

import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

class _MockPhotoUploadPreparer extends Mock
    implements StatusPhotoUploadPreparer {}

class _MockPreparedStatusPhoto extends Mock implements PreparedStatusPhoto {}

class _MockFanfouClient extends Mock implements fanfou.FanfouClient {}

class _MockStatusesApi extends Mock implements fanfou.StatusesApi {}

class _MockPhotosApi extends Mock implements fanfou.PhotosApi {}

class _MockSearchApi extends Mock implements fanfou.SearchApi {}

class _MockFavoritesApi extends Mock implements fanfou.FavoritesApi {}

void main() {
  group(StatusRepository, () {
    late fanfou.FanfouClient fanfouClient;
    late fanfou.StatusesApi statusesApi;
    late fanfou.PhotosApi photosApi;
    late fanfou.SearchApi searchApi;
    late fanfou.FavoritesApi favoritesApi;
    late StatusRepository subject;

    setUpAll(() => registerFallbackValue(File('/fallback.png')));

    setUp(() {
      fanfouClient = _MockFanfouClient();
      statusesApi = _MockStatusesApi();
      photosApi = _MockPhotosApi();
      searchApi = _MockSearchApi();
      when(() => fanfouClient.search).thenReturn(searchApi);
      favoritesApi = _MockFavoritesApi();
      when(() => fanfouClient.statuses).thenReturn(statusesApi);
      when(() => fanfouClient.photos).thenReturn(photosApi);
      when(() => fanfouClient.favorites).thenReturn(favoritesApi);
      when(() => fanfouClient.close()).thenReturn(null);
      subject = StatusRepository(
        clientFactory: () async => fanfouClient,
        activeAccountIdProvider: () => 'account-a',
      );
    });

    tearDown(() async {
      await subject.close();
    });

    for (final endpoint in [
      'getHomeTimeline',
      'getPublicTimeline',
      'getMentions',
      'getUserTimeline',
      'getPhotoTimeline',
    ]) {
      group('$endpoint pagination', () {
        for (final count in [0, 2, 19, 20]) {
          test('sets pagination correctly for $count of 20 statuses', () async {
            final response = List.generate(
              count,
              (index) =>
                  index == count - 1 ? _olderFanfouStatus : _fanfouStatus,
            );
            Future<List<fanfou.Status>> request() => switch (endpoint) {
              'getHomeTimeline' => statusesApi.homeTimeline(
                format: 'html',
                count: 20,
              ),
              'getPublicTimeline' => statusesApi.publicTimeline(
                format: 'html',
                count: 20,
              ),
              'getMentions' => statusesApi.mentions(format: 'html', count: 20),
              'getUserTimeline' => statusesApi.userTimeline(
                id: 'user-a',
                format: 'html',
                count: 20,
              ),
              'getPhotoTimeline' => photosApi.userTimeline(
                id: 'user-a',
                format: 'html',
                count: 20,
              ),
              _ => throw StateError(endpoint),
            };
            when(request).thenAnswer((_) async => response);

            final result = await switch (endpoint) {
              'getHomeTimeline' => subject.getHomeTimeline(),
              'getPublicTimeline' => subject.getPublicTimeline(),
              'getMentions' => subject.getMentions(),
              'getUserTimeline' => subject.getUserTimeline(userId: 'user-a'),
              'getPhotoTimeline' => subject.getPhotoTimeline(userId: 'user-a'),
              _ => throw StateError(endpoint),
            };

            expect(result.statuses, hasLength(count));
            expect(result.hasMore, count == 20);
            expect(result.nextCursor, count == 20 ? _olderStatus.id : null);
            verify(request).called(1);
          });
        }
      });
    }

    group('getContextTimeline', () {
      test('maps reply relationships and requests HTML context', () async {
        final response = fanfou.Status(
          id: 'reply',
          text: '<b>reply</b>',
          createdAt: '2026-09-28T12:00:00Z',
          inReplyToStatusId: 'original',
          inReplyToUserId: 'original-author',
        );
        when(
          () => statusesApi.contextTimeline('reply', format: 'html'),
        ).thenAnswer((_) async => [response]);

        final result = await subject.getContextTimeline('reply');

        expect(result.single.id, 'reply');
        expect(result.single.text, '<b>reply</b>');
        expect(result.single.inReplyToStatusId, 'original');
        expect(result.single.inReplyToUserId, 'original-author');
        expect(result.clear, throwsUnsupportedError);
        verify(
          () => statusesApi.contextTimeline('reply', format: 'html'),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test(
        'returns an empty conversation when the API returns no statuses',
        () async {
          when(
            () => statusesApi.contextTimeline('original', format: 'html'),
          ).thenAnswer((_) async => []);
          expect(await subject.getContextTimeline('original'), isEmpty);
        },
      );

      test('normalizes empty parent identifiers to null', () async {
        when(
          () => statusesApi.contextTimeline('original', format: 'html'),
        ).thenAnswer(
          (_) async => [
            fanfou.Status(
              id: 'original',
              text: 'hello',
              createdAt: '',
              inReplyToStatusId: '',
              inReplyToUserId: '',
            ),
          ],
        );
        final result = await subject.getContextTimeline('original');
        expect(result.single.inReplyToStatusId, isNull);
        expect(result.single.inReplyToUserId, isNull);
      });

      test(
        'sanitizes a failed context request and closes the client',
        () async {
          when(
            () => statusesApi.contextTimeline('reply', format: 'html'),
          ).thenThrow(fanfou.FanfouApiException(404, 'private body'));
          await expectLater(
            subject.getContextTimeline('reply'),
            throwsA(
              isA<StatusRepositoryApiFailure>().having(
                (e) => e.statusCode,
                'status code',
                404,
              ),
            ),
          );
          verify(() => fanfouClient.close()).called(1);
        },
      );
    });

    group('getHomeTimeline', () {
      test('returns a status-id page when the API call succeeds', () async {
        when(
          () => statusesApi.homeTimeline(
            format: 'html',
            count: 2,
            maxId: 'cursor-a',
          ),
        ).thenAnswer((_) async => [_fanfouStatus, _olderFanfouStatus]);

        final result = await subject.getHomeTimeline(
          limit: 2,
          maxId: 'cursor-a',
        );

        expect(
          result,
          StatusPage(
            statuses: const [_status, _olderStatus],
            hasMore: true,
            nextCursor: _olderStatus.id,
          ),
        );
        verify(
          () => statusesApi.homeTimeline(
            format: 'html',
            count: 2,
            maxId: 'cursor-a',
          ),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test(
        'ends pagination when a short response advances maxId',
        () async {
          when(
            () => statusesApi.homeTimeline(
              format: 'html',
              count: 20,
              maxId: 'cursor-a',
            ),
          ).thenAnswer((_) async => [_fanfouStatus]);

          final result = await subject.getHomeTimeline(maxId: 'cursor-a');

          expect(result.hasMore, isFalse);
          expect(result.nextCursor, isNull);
        },
      );

      test(
        'stops pagination when the response does not advance maxId',
        () async {
          when(
            () => statusesApi.homeTimeline(
              format: 'html',
              count: 1,
              maxId: _status.id,
            ),
          ).thenAnswer((_) async => [_fanfouStatus]);

          final result = await subject.getHomeTimeline(
            limit: 1,
            maxId: _status.id,
          );

          expect(result.hasMore, isFalse);
          expect(result.nextCursor, isNull);
        },
      );
    });

    group('searchStatuses', () {
      test('maps query, HTML results and pagination cursors', () async {
        when(
          () => searchApi.publicTimeline(
            '猫',
            count: 2,
            format: 'html',
            sinceId: 'new',
            maxId: 'old',
          ),
        ).thenAnswer((_) async => [_fanfouStatus, _olderFanfouStatus]);
        final result = await subject.searchStatuses(
          query: '  猫  ',
          limit: 2,
          sinceId: 'new',
          maxId: 'old',
        );
        expect(
          result,
          StatusPage(
            statuses: const [_status, _olderStatus],
            hasMore: true,
            nextCursor: _olderStatus.id,
          ),
        );
        verify(
          () => searchApi.publicTimeline(
            '猫',
            count: 2,
            format: 'html',
            sinceId: 'new',
            maxId: 'old',
          ),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test('returns an empty page when no statuses match', () async {
        when(
          () => searchApi.publicTimeline('猫', count: 20, format: 'html'),
        ).thenAnswer((_) async => []);
        expect(
          await subject.searchStatuses(query: '猫'),
          StatusPage(statuses: const [], hasMore: false),
        );
      });

      test('searches the current account without sending an id', () async {
        when(
          () => searchApi.userTimeline(
            '猫',
            count: 20,
            format: 'html',
          ),
        ).thenAnswer((_) async => []);

        final result = await subject.searchMyStatuses(query: '猫');

        expect(result.statuses, isEmpty);
        verify(
          () => searchApi.userTimeline(
            '猫',
            count: 20,
            format: 'html',
          ),
        ).called(1);
      });

      test('searches a selected user with the user id', () async {
        when(
          () => searchApi.userTimeline(
            '猫',
            id: 'user-a',
            count: 20,
            format: 'html',
          ),
        ).thenAnswer((_) async => []);

        final result = await subject.searchStatuses(
          query: '猫',
          userId: 'user-a',
        );

        expect(result.statuses, isEmpty);
        verify(
          () => searchApi.userTimeline(
            '猫',
            id: 'user-a',
            count: 20,
            format: 'html',
          ),
        ).called(1);
      });

      test('rejects empty keywords without a network request', () async {
        await expectLater(
          subject.searchStatuses(query: '  '),
          throwsArgumentError,
        );
        verifyZeroInteractions(searchApi);
      });

      test('maps failures and closes the client', () async {
        when(
          () => searchApi.publicTimeline('猫', count: 20, format: 'html'),
        ).thenThrow(Exception('network failure'));
        await expectLater(
          subject.searchStatuses(query: '猫'),
          throwsA(isA<StatusRepositoryUnknownFailure>()),
        );
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('getPublicTimeline', () {
      test('returns a status-id page when the API call succeeds', () async {
        when(
          () => statusesApi.publicTimeline(
            format: 'html',
            count: 2,
            sinceId: 'status-newer',
            maxId: 'cursor-a',
          ),
        ).thenAnswer((_) async => [_fanfouStatus, _olderFanfouStatus]);

        final result = await subject.getPublicTimeline(
          limit: 2,
          sinceId: 'status-newer',
          maxId: 'cursor-a',
        );

        expect(
          result,
          StatusPage(
            statuses: const [_status, _olderStatus],
            hasMore: true,
            nextCursor: _olderStatus.id,
          ),
        );
        verify(
          () => statusesApi.publicTimeline(
            format: 'html',
            count: 2,
            sinceId: 'status-newer',
            maxId: 'cursor-a',
          ),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('getMentions', () {
      test('maps the opaque cursor to maxId', () async {
        when(
          () => statusesApi.mentions(
            format: 'html',
            count: 30,
            maxId: 'max-a',
          ),
        ).thenAnswer((_) async => [_fanfouStatus]);

        await subject.getMentions(limit: 30, maxId: 'max-a');

        verify(
          () => statusesApi.mentions(
            format: 'html',
            count: 30,
            maxId: 'max-a',
          ),
        ).called(1);
      });

      test('maps the newest visible status to sinceId', () async {
        when(
          () => statusesApi.mentions(
            format: 'html',
            count: 20,
            sinceId: 'newest-a',
          ),
        ).thenAnswer((_) async => [_fanfouStatus]);

        await subject.getMentions(sinceId: 'newest-a');

        verify(
          () => statusesApi.mentions(
            format: 'html',
            count: 20,
            sinceId: 'newest-a',
          ),
        ).called(1);
      });
    });

    group('getUserTimeline', () {
      test(
        'requests the selected user statuses with the default limit',
        () async {
          when(
            () => statusesApi.userTimeline(
              id: 'user-a',
              format: 'html',
              count: 20,
              sinceId: 'newer-a',
              maxId: 'cursor-a',
            ),
          ).thenAnswer((_) async => [_fanfouStatus]);

          final result = await subject.getUserTimeline(
            userId: 'user-a',
            sinceId: 'newer-a',
            maxId: 'cursor-a',
          );

          expect(result.statuses, const [_status]);
          verify(
            () => statusesApi.userTimeline(
              id: 'user-a',
              format: 'html',
              count: 20,
              sinceId: 'newer-a',
              maxId: 'cursor-a',
            ),
          ).called(1);
        },
      );
    });

    group('getPhotoTimeline', () {
      test(
        'requests the selected user photos with the default limit',
        () async {
          when(
            () => photosApi.userTimeline(
              id: 'user-a',
              format: 'html',
              count: 20,
              sinceId: 'newer-a',
              maxId: 'cursor-a',
            ),
          ).thenAnswer((_) async => [_fanfouStatus]);

          final result = await subject.getPhotoTimeline(
            userId: 'user-a',
            sinceId: 'newer-a',
            maxId: 'cursor-a',
          );

          expect(result.statuses, const [_status]);
          verify(
            () => photosApi.userTimeline(
              id: 'user-a',
              format: 'html',
              count: 20,
              sinceId: 'newer-a',
              maxId: 'cursor-a',
            ),
          ).called(1);
        },
      );
    });

    group('getFavorites', () {
      test('requests 20 statuses by default', () async {
        when(
          () => favoritesApi.list(
            id: 'account-a',
            format: 'html',
            count: 20,
            page: 1,
          ),
        ).thenAnswer((_) async => const []);

        await subject.getFavorites(userId: 'account-a');

        verify(
          () => favoritesApi.list(
            id: 'account-a',
            format: 'html',
            count: 20,
            page: 1,
          ),
        ).called(1);
      });

      test('maps the opaque cursor to the next page number', () async {
        when(
          () => favoritesApi.list(
            id: 'user-a',
            format: 'html',
            count: 1,
            page: 3,
          ),
        ).thenAnswer((_) async => [_fanfouStatus]);

        final result = await subject.getFavorites(
          userId: 'user-a',
          limit: 1,
          cursor: '3',
        );

        expect(result.nextCursor, '4');
        expect(result.hasMore, isTrue);
        verify(
          () => favoritesApi.list(
            id: 'user-a',
            format: 'html',
            count: 1,
            page: 3,
          ),
        ).called(1);
      });

      test('throws $ArgumentError for a malformed cursor', () {
        expect(
          subject.getFavorites(
            userId: 'user-a',
            cursor: 'not-a-page',
          ),
          throwsArgumentError,
        );
        verifyNever(() => fanfouClient.favorites);
      });
    });

    group('getStatus', () {
      test('returns mapped $Status when the API call succeeds', () async {
        when(
          () => statusesApi.show('status-a', format: 'html'),
        ).thenAnswer((_) async => _fanfouStatus);

        final result = await subject.getStatus('status-a');

        expect(result, _status);
        verify(() => statusesApi.show('status-a', format: 'html')).called(1);
      });

      test('extracts the client name from an HTML anchor source', () async {
        when(() => statusesApi.show('status-a', format: 'html')).thenAnswer(
          (_) async => _buildFanfouStatus(
            _status.copyWith(
              source: '<a href="https://fanfou.com" target="_blank">旦</a>',
            ),
          ),
        );

        final result = await subject.getStatus('status-a');

        expect(result.source, '旦');
      });

      test('keeps a plain text source unchanged', () async {
        when(() => statusesApi.show('status-a', format: 'html')).thenAnswer(
          (_) async => _buildFanfouStatus(_status.copyWith(source: '网页版饭否')),
        );

        final result = await subject.getStatus('status-a');

        expect(result.source, '网页版饭否');
      });

      test('returns a null source for an empty value', () async {
        when(() => statusesApi.show('status-a', format: 'html')).thenAnswer(
          (_) async => _buildFanfouStatus(_status.copyWith(source: '  ')),
        );

        final result = await subject.getStatus('status-a');

        expect(result.source, isNull);
      });
    });

    group('createStatus', () {
      for (final reply in [true, false]) {
        test(
          'forwards source identifiers to the API for reply=$reply',
          () async {
            when(
              () => statusesApi.update(
                _status.text,
                format: 'html',
                inReplyToStatusId: reply ? 'original-status' : null,
                repostStatusId: reply ? null : 'original-status',
              ),
            ).thenAnswer((_) async => _fanfouStatus);
            final change = expectLater(
              subject.statusChanges,
              emits(
                const StatusCreated(accountId: 'account-a', status: _status),
              ),
            );

            final result = await subject.createStatus(
              '  ${_status.text}  ',
              inReplyToStatusId: reply ? 'original-status' : null,
              repostStatusId: reply ? null : 'original-status',
            );

            expect(result, _status);
            await change;
            verify(
              () => statusesApi.update(
                _status.text,
                format: 'html',
                inReplyToStatusId: reply ? 'original-status' : null,
                repostStatusId: reply ? null : 'original-status',
              ),
            ).called(1);
          },
        );
      }

      test('publishes $StatusCreated for the active account', () async {
        when(
          () => statusesApi.update(_status.text, format: 'html'),
        ).thenAnswer((_) async => _fanfouStatus);
        final change = expectLater(
          subject.statusChanges,
          emits(
            const StatusCreated(
              accountId: 'account-a',
              status: _status,
            ),
          ),
        );

        final result = await subject.createStatus('  ${_status.text}  ');

        expect(result, _status);
        await change;
        verify(
          () => statusesApi.update(_status.text, format: 'html'),
        ).called(1);
      });

      test('throws $ArgumentError for whitespace-only text', () {
        expect(subject.createStatus('   '), throwsArgumentError);
        verifyNever(
          () => statusesApi.update(any(), format: any(named: 'format')),
        );
      });
    });

    group('createPhotoStatus', () {
      late StatusPhotoUploadPreparer preparer;
      late PreparedStatusPhoto preparedPhoto;

      setUp(() async {
        await subject.close();
        preparer = _MockPhotoUploadPreparer();
        preparedPhoto = _MockPreparedStatusPhoto();
        when(() => preparedPhoto.file).thenReturn(File('/prepared.jpg'));
        when(preparedPhoto.dispose).thenAnswer((_) async {});
        when(
          () => preparer.prepare(any()),
        ).thenAnswer((_) async => preparedPhoto);
        subject = StatusRepository(
          clientFactory: () async => fanfouClient,
          activeAccountIdProvider: () => 'account-a',
          photoUploadPreparer: preparer,
        );
      });

      test(
        'does not upload or emit a created status when preparation fails',
        () async {
          when(
            () => preparer.prepare(any()),
          ).thenThrow(const StatusRepositoryPhotoPreparationFailure());
          final changes = <StatusChange>[];
          final subscription = subject.statusChanges.listen(changes.add);
          addTearDown(subscription.cancel);
          await expectLater(
            subject.createPhotoStatus(photoPath: '/photo.png'),
            throwsA(isA<StatusRepositoryPhotoPreparationFailure>()),
          );
          verifyNever(
            () => photosApi.upload(any(), format: any(named: 'format')),
          );
          verifyNever(() => fanfouClient.close());
          expect(changes, isEmpty);
        },
      );

      for (final text in ['', '  配图文字  ']) {
        test('uploads a photo with optional text="$text"', () async {
          when(
            () => photosApi.upload(
              any(),
              status: any(named: 'status'),
              format: 'html',
            ),
          ).thenAnswer((_) async => _fanfouStatus);
          final change = expectLater(
            subject.statusChanges,
            emits(const StatusCreated(accountId: 'account-a', status: _status)),
          );

          final result = await subject.createPhotoStatus(
            photoPath: '/photo.png',
            text: text,
          );

          expect(result, _status);
          await change;
          final file =
              verify(
                    () => photosApi.upload(
                      captureAny(),
                      status: text.trim().isEmpty ? null : text.trim(),
                      format: 'html',
                    ),
                  ).captured.single
                  as File;
          expect(file.path, '/prepared.jpg');
          final original =
              verify(() => preparer.prepare(captureAny())).captured.single
                  as File;
          expect(original.path, '/photo.png');
          verify(preparedPhoto.dispose).called(1);
          verify(() => fanfouClient.close()).called(1);
          verifyNever(() => statusesApi.update(any()));
        });
      }

      test('maps an upload failure and closes the client', () async {
        when(
          () => photosApi.upload(any(), format: 'html'),
        ).thenThrow(fanfou.FanfouApiException(413, 'too large'));
        final changes = <StatusChange>[];
        final subscription = subject.statusChanges.listen(changes.add);
        addTearDown(subscription.cancel);

        await expectLater(
          subject.createPhotoStatus(photoPath: '/photo.png'),
          throwsA(
            isA<StatusRepositoryApiFailure>().having(
              (failure) => failure.statusCode,
              'statusCode',
              413,
            ),
          ),
        );
        expect(changes, isEmpty);
        verify(preparedPhoto.dispose).called(1);
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('deleteStatus', () {
      test('publishes $StatusDeleted for the active account', () async {
        when(
          () => statusesApi.destroy(_status.id, format: 'html'),
        ).thenAnswer((_) async => _fanfouStatus);
        final change = expectLater(
          subject.statusChanges,
          emits(
            const StatusDeleted(
              accountId: 'account-a',
              statusId: 'status-a',
            ),
          ),
        );

        await subject.deleteStatus(_status.id);

        await change;
        verify(
          () => statusesApi.destroy(_status.id, format: 'html'),
        ).called(1);
      });
    });

    group('favoriteStatus', () {
      test('publishes an updated favorited status', () async {
        when(
          () => favoritesApi.create(_status.id, format: 'html'),
        ).thenAnswer((_) async => _unfavoritedFanfouStatus);
        final change = expectLater(
          subject.statusChanges,
          emits(
            StatusUpdated(
              accountId: 'account-a',
              status: _status.copyWith(isFavorited: true),
            ),
          ),
        );

        final result = await subject.favoriteStatus(
          _status.id,
          currentStatus: _status.copyWith(isFavorited: false),
        );

        expect(result.isFavorited, isTrue);
        await change;
      });
    });

    group('unfavoriteStatus', () {
      test('publishes an updated unfavorited status', () async {
        when(
          () => favoritesApi.destroy(_status.id, format: 'html'),
        ).thenAnswer((_) async => _fanfouStatus);
        final change = expectLater(
          subject.statusChanges,
          emits(
            StatusUpdated(
              accountId: 'account-a',
              status: _status.copyWith(isFavorited: false),
            ),
          ),
        );

        final result = await subject.unfavoriteStatus(
          _status.id,
          currentStatus: _status,
        );

        expect(result.isFavorited, isFalse);
        await change;
      });

      test(
        'preserves the current status when the mutation response is malformed',
        () async {
          final malformedText = [
            'a:3:{i:0;s:1:"1";i:1;i:23513027;i:2;s:143:"',
            _status.text,
            '";}',
          ].join();
          when(
            () => favoritesApi.destroy(_status.id, format: 'html'),
          ).thenAnswer(
            (_) async => fanfou.Status(
              id: _status.id,
              createdAt: _status.createdAt,
              text: malformedText,
              favorited: false,
            ),
          );

          final result = await subject.unfavoriteStatus(
            _status.id,
            currentStatus: _status,
          );

          expect(result, _status.copyWith(isFavorited: false));
          expect(result.text, _status.text);
          expect(result.photo, _status.photo);
          expect(result.author, _status.author);
        },
      );
    });

    test(
      'throws $StatusRepositoryApiFailure for Fanfou API failures',
      () async {
        when(
          () => statusesApi.homeTimeline(format: 'html', count: 20),
        ).thenThrow(fanfou.FanfouApiException(503, 'sensitive body'));

        await expectLater(
          subject.getHomeTimeline(),
          throwsA(
            isA<StatusRepositoryApiFailure>().having(
              (failure) => failure.statusCode,
              'statusCode',
              503,
            ),
          ),
        );
        verify(() => fanfouClient.close()).called(1);
      },
    );

    test('throws $StatusRepositoryUnknownFailure for factory failures', () {
      subject = StatusRepository(
        clientFactory: () async => throw StateError('missing session'),
        activeAccountIdProvider: () => 'account-a',
      );

      expect(
        subject.getHomeTimeline(),
        throwsA(
          isA<StatusRepositoryUnknownFailure>().having(
            (failure) => failure.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
      verifyNever(() => fanfouClient.close());
    });

    test('rejects mutations without an active account', () {
      subject = StatusRepository(
        clientFactory: () async => fanfouClient,
        activeAccountIdProvider: () => null,
      );

      expect(
        subject.deleteStatus(_status.id),
        throwsA(isA<StatusRepositoryUnknownFailure>()),
      );
      verifyNever(
        () => statusesApi.destroy(any(), format: any(named: 'format')),
      );
    });
  });
}

const _status = Status(
  id: 'status-a',
  text: 'hello fanfou',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
    gender: '男',
    avatarUrl: 'https://example.com/large.png',
    description: 'Status author biography',
    url: 'https://example.com/user-a',
    location: 'Shanghai',
    createdAt: 'Fri Mar 1 00:00:00 +0000 2019',
    protected: true,
    following: false,
    followersCount: 12,
    friendsCount: 8,
    favoritesCount: 5,
    statusesCount: 42,
    photoCount: 7,
  ),
  photo: StatusPhotoUrls(
    thumbnailUrl: 'https://example.com/photo-thumb.png',
    imageUrl: 'https://example.com/photo.png',
    largeUrl: 'https://example.com/photo-large.png',
  ),
  isFavorited: true,
  isSelf: true,
);

const _olderStatus = Status(
  id: 'status-b',
  text: 'older fanfou',
  createdAt: 'Tue Jul 27 00:00:00 +0000 2026',
  author: StatusAuthor(
    id: 'user-b',
    name: 'User B',
    screenName: 'user_b',
  ),
);

final fanfou.Status _fanfouStatus = _buildFanfouStatus(_status);
final fanfou.Status _unfavoritedFanfouStatus = _buildFanfouStatus(
  _status.copyWith(isFavorited: false),
);
final fanfou.Status _olderFanfouStatus = _buildFanfouStatus(_olderStatus);

fanfou.Status _buildFanfouStatus(Status status) {
  final photo = status.photo;
  return fanfou.Status(
    id: status.id,
    createdAt: status.createdAt,
    text: status.text,
    source: status.source,
    favorited: status.isFavorited,
    isSelf: status.isSelf,
    photo: photo == null
        ? null
        : fanfou.Photo(
            imageUrl: photo.imageUrl ?? photo.viewerUrl,
            thumbUrl: photo.thumbnailUrl ?? photo.displayUrl,
            largeUrl: photo.largeUrl,
          ),
    user: fanfou.User(
      id: status.author.id,
      name: status.author.name,
      screenName: status.author.screenName,
      gender: status.author.gender,
      profileImageUrl: status.author.avatarUrl == null
          ? null
          : 'https://example.com/small.png',
      profileImageUrlLarge: status.author.avatarUrl,
      description: status.author.description,
      url: status.author.url,
      location: status.author.location,
      createdAt: status.author.createdAt,
      protected: status.author.protected,
      following: status.author.following,
      followersCount: status.author.followersCount,
      friendsCount: status.author.friendsCount,
      favouritesCount: status.author.favoritesCount,
      statusesCount: status.author.statusesCount,
      photoCount: status.author.photoCount,
    ),
  );
}
