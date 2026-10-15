import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/status/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

class _MockDraftRepository extends Mock
    implements status_repository.StatusDraftRepository {}

class _MockStatusPhotoPicker extends Mock implements StatusPhotoPicker {}

void main() {
  group(StatusComposerCubit, () {
    late status_repository.StatusRepository statusRepository;
    late StatusPhotoPicker photoPicker;

    setUp(() {
      statusRepository = _MockStatusRepository();
      photoPicker = _MockStatusPhotoPicker();
    });

    StatusComposerCubit buildSubject() {
      return StatusComposerCubit(
        statusRepository: statusRepository,
        photoPicker: photoPicker,
      );
    }

    test('starts with an empty draft that cannot be published', () {
      final cubit = buildSubject();
      addTearDown(cubit.close);

      expect(cubit.state, const StatusComposerState());
      expect(cubit.state.canPublish, isFalse);
    });

    group('local draft lifecycle', () {
      late status_repository.StatusDraftRepository drafts;
      setUpAll(() {
        registerFallbackValue(status_repository.StatusDraft(content: ''));
      });
      setUp(() {
        drafts = _MockDraftRepository();
        when(() => drafts.load('account')).thenAnswer((_) async => null);
        when(() => drafts.save(any(), any())).thenAnswer((_) async {});
        when(() => drafts.clear(any())).thenAnswer((_) async {});
      });
      StatusComposerCubit buildDraftSubject() => StatusComposerCubit(
        statusRepository: statusRepository,
        photoPicker: photoPicker,
        draftRepository: drafts,
        accountId: 'account',
      );
      blocTest<StatusComposerCubit, StatusComposerState>(
        'restores text and photo for the captured account',
        setUp: () => when(() => drafts.load('account')).thenAnswer(
          (_) async => status_repository.StatusDraft(
            content: ' 草稿 ',
            photoPath: '/saved.png',
            photoBytes: Uint8List.fromList([1, 2]),
          ),
        ),
        build: buildDraftSubject,
        act: (cubit) => cubit.restoreDraft(),
        expect: () => [
          const StatusComposerState(draftStatus: StatusDraftStatus.loading),
          StatusComposerState(
            content: ' 草稿 ',
            draftStatus: StatusDraftStatus.restored,
            photo: StatusComposerPhoto(
              path: '/saved.png',
              bytes: Uint8List.fromList([1, 2]),
            ),
          ),
        ],
        verify: (_) => verify(() => drafts.load('account')).called(1),
      );
      blocTest<StatusComposerCubit, StatusComposerState>(
        'finishes loading when there is no saved draft',
        build: buildDraftSubject,
        act: (cubit) => cubit.restoreDraft(),
        expect: () => const [
          StatusComposerState(draftStatus: StatusDraftStatus.loading),
          StatusComposerState(draftStatus: StatusDraftStatus.restored),
        ],
      );
      blocTest<StatusComposerCubit, StatusComposerState>(
        'preserves an unreadable saved draft when the empty editor closes',
        setUp: () =>
            when(() => drafts.load('account')).thenThrow(Exception('disk')),
        build: buildDraftSubject,
        act: (cubit) async {
          await cubit.restoreDraft();
          await cubit.finishDraft(keep: false);
        },
        expect: () => const [
          StatusComposerState(draftStatus: StatusDraftStatus.loading),
          StatusComposerState(draftStatus: StatusDraftStatus.failure),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) => verifyNever(() => drafts.clear(any())),
      );
      for (final keep in [true, false]) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'finishes the current draft with keep=$keep',
          build: buildDraftSubject,
          seed: () => const StatusComposerState(content: '  草稿 '),
          act: (cubit) => cubit.finishDraft(keep: keep),
          expect: () => const [
            StatusComposerState(
              content: '  草稿 ',
              draftStatus: StatusDraftStatus.saving,
            ),
            StatusComposerState(content: '  草稿 '),
          ],
          verify: (_) {
            if (keep) {
              verify(
                () => drafts.save(
                  'account',
                  status_repository.StatusDraft(content: '  草稿 '),
                ),
              ).called(1);
            } else {
              verify(() => drafts.clear('account')).called(1);
            }
          },
        );
      }
      blocTest<StatusComposerCubit, StatusComposerState>(
        'clears a successfully published draft',
        setUp: () => when(
          () => statusRepository.createStatus('草稿'),
        ).thenAnswer((_) async => _status),
        build: buildDraftSubject,
        seed: () => const StatusComposerState(content: '草稿'),
        act: (cubit) => cubit.publish(),
        expect: () => const [
          StatusComposerState(
            content: '草稿',
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '草稿',
            submissionStatus: StatusComposerSubmissionStatus.success,
          ),
        ],
        verify: (_) => verify(() => drafts.clear('account')).called(1),
      );
      blocTest<StatusComposerCubit, StatusComposerState>(
        'retains the saved draft after a failed publication',
        setUp: () => when(
          () => statusRepository.createStatus('草稿'),
        ).thenThrow(Exception('network')),
        build: buildDraftSubject,
        seed: () => const StatusComposerState(content: '草稿'),
        act: (cubit) => cubit.publish(),
        expect: () => const [
          StatusComposerState(
            content: '草稿',
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '草稿',
            submissionStatus: StatusComposerSubmissionStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) => verifyNever(() => drafts.clear(any())),
      );
      blocTest<StatusComposerCubit, StatusComposerState>(
        'keeps publication successful if local cleanup fails',
        setUp: () {
          when(
            () => statusRepository.createStatus('草稿'),
          ).thenAnswer((_) async => _status);
          when(() => drafts.clear('account')).thenThrow(Exception('disk'));
        },
        build: buildDraftSubject,
        seed: () => const StatusComposerState(content: '草稿'),
        act: (cubit) => cubit.publish(),
        expect: () => const [
          StatusComposerState(
            content: '草稿',
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '草稿',
            submissionStatus: StatusComposerSubmissionStatus.success,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
      for (final reply in [true, false]) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'never restores or changes original drafts for reply=$reply',
          build: () => StatusComposerCubit(
            statusRepository: statusRepository,
            photoPicker: photoPicker,
            draftRepository: drafts,
            accountId: 'account',
            inReplyToStatusId: reply ? 'id' : null,
            repostStatusId: reply ? null : 'id',
          ),
          act: (cubit) async {
            await cubit.restoreDraft();
            await cubit.finishDraft(keep: true);
          },
          expect: () => <StatusComposerState>[],
          verify: (_) => verifyZeroInteractions(drafts),
        );
      }
    });

    group('initialContent', () {
      blocTest<StatusComposerCubit, StatusComposerState>(
        'publishes a prefilled draft without requiring an edit',
        setUp: () {
          when(
            () => statusRepository.createStatus('@饭友 正文'),
          ).thenAnswer((_) async => _status);
        },
        build: () => StatusComposerCubit(
          statusRepository: statusRepository,
          photoPicker: photoPicker,
          initialContent: ' @饭友 正文',
        ),
        act: (cubit) {
          expect(cubit.state.content, ' @饭友 正文');
          expect(cubit.state.canPublish, isTrue);
          return cubit.publish();
        },
        expect: () => const [
          StatusComposerState(
            content: ' @饭友 正文',
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: ' @饭友 正文',
            submissionStatus: StatusComposerSubmissionStatus.success,
          ),
        ],
        verify: (_) {
          verify(() => statusRepository.createStatus('@饭友 正文')).called(1);
        },
      );
    });

    group('photo selection', () {
      late StatusComposerPhoto photo;
      late Completer<StatusComposerPhoto?> selection;
      late Completer<status_repository.Status> upload;
      setUp(() {
        selection = Completer<StatusComposerPhoto?>();
        upload = Completer<status_repository.Status>();
        photo = StatusComposerPhoto(
          path: '/photo.png',
          bytes: Uint8List.fromList([1, 2, 3]),
        );
      });

      blocTest<StatusComposerCubit, StatusComposerState>(
        'selects a photo, preserves it while typing, and removes it',
        setUp: () =>
            when(() => photoPicker.pickPhoto()).thenAnswer((_) async => photo),
        build: buildSubject,
        act: (cubit) async {
          await cubit.pickPhoto();
          expect(cubit.state.canPublish, isTrue);
          cubit
            ..contentChanged('配图文字')
            ..removePhoto();
        },
        expect: () => [
          const StatusComposerState(
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
          StatusComposerState(photo: photo),
          StatusComposerState(content: '配图文字', photo: photo),
          const StatusComposerState(content: '配图文字'),
        ],
        verify: (_) => verify(() => photoPicker.pickPhoto()).called(1),
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'keeps the previous photo and draft when selection is cancelled',
        setUp: () =>
            when(() => photoPicker.pickPhoto()).thenAnswer((_) async => null),
        build: buildSubject,
        seed: () => StatusComposerState(content: '草稿', photo: photo),
        act: (cubit) => cubit.pickPhoto(),
        expect: () => [
          StatusComposerState(
            content: '草稿',
            photo: photo,
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
          StatusComposerState(content: '草稿', photo: photo),
        ],
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'preserves the previous photo and draft on unsupported selection',
        setUp: () => when(() => photoPicker.pickPhoto()).thenThrow(
          const status_repository.StatusRepositoryPhotoFormatFailure(),
        ),
        build: buildSubject,
        seed: () => StatusComposerState(content: '草稿', photo: photo),
        act: (cubit) => cubit.pickPhoto(),
        expect: () => [
          StatusComposerState(
            content: '草稿',
            photo: photo,
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
          StatusComposerState(
            content: '草稿',
            photo: photo,
            photoSelectionStatus: StatusPhotoSelectionStatus.unsupportedFormat,
          ),
        ],
        errors: () => [
          isA<status_repository.StatusRepositoryPhotoFormatFailure>(),
        ],
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'reports unsupported upload format without discarding the draft',
        setUp: () =>
            when(
              () => statusRepository.createPhotoStatus(
                photoPath: photo.path,
                text: '草稿',
              ),
            ).thenThrow(
              const status_repository.StatusRepositoryPhotoFormatFailure(),
            ),
        build: buildSubject,
        seed: () => StatusComposerState(content: '草稿', photo: photo),
        act: (cubit) => cubit.publish(),
        expect: () => [
          StatusComposerState(
            content: '草稿',
            photo: photo,
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '草稿',
            photo: photo,
            submissionStatus:
                StatusComposerSubmissionStatus.unsupportedPhotoFormat,
          ),
        ],
        errors: () => [
          isA<status_repository.StatusRepositoryPhotoFormatFailure>(),
        ],
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'preserves the draft after a selection failure and allows retry',
        setUp: () {
          var attempts = 0;
          when(() => photoPicker.pickPhoto()).thenAnswer((_) async {
            if (attempts++ == 0) throw const StatusPhotoPickFailure();
            return photo;
          });
        },
        build: buildSubject,
        seed: () => const StatusComposerState(content: '草稿'),
        act: (cubit) async {
          await cubit.pickPhoto();
          await cubit.pickPhoto();
        },
        expect: () => [
          const StatusComposerState(
            content: '草稿',
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
          const StatusComposerState(
            content: '草稿',
            photoSelectionStatus: StatusPhotoSelectionStatus.failure,
          ),
          const StatusComposerState(
            content: '草稿',
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
          StatusComposerState(content: '草稿', photo: photo),
        ],
        errors: () => [isA<StatusPhotoPickFailure>()],
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'blocks duplicate selection and publishing until selection completes',
        setUp: () => when(
          () => photoPicker.pickPhoto(),
        ).thenAnswer((_) => selection.future),
        build: buildSubject,
        seed: () => const StatusComposerState(content: '草稿'),
        act: (cubit) async {
          final picking = cubit.pickPhoto();
          await cubit.pickPhoto();
          await cubit.publish();
          cubit.removePhoto();
          selection.complete(photo);
          await picking;
        },
        expect: () => [
          const StatusComposerState(
            content: '草稿',
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
          StatusComposerState(content: '草稿', photo: photo),
        ],
        verify: (_) {
          verify(() => photoPicker.pickPhoto()).called(1);
          verifyNever(() => statusRepository.createStatus(any()));
        },
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'ignores a picker result after the composer is closed',
        setUp: () =>
            when(() => photoPicker.pickPhoto()).thenAnswer((_) async => photo),
        build: buildSubject,
        act: (cubit) async {
          final picking = cubit.pickPhoto();
          await cubit.close();
          await picking;
        },
        expect: () => const [
          StatusComposerState(
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
        ],
      );

      for (final reply in [true, false]) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'does not select a photo for reply=$reply',
          build: () => StatusComposerCubit(
            statusRepository: statusRepository,
            photoPicker: photoPicker,
            inReplyToStatusId: reply ? 'original' : null,
            repostStatusId: reply ? null : 'original',
          ),
          act: (cubit) => cubit.pickPhoto(),
          expect: () => <StatusComposerState>[],
          verify: (_) => verifyNever(() => photoPicker.pickPhoto()),
        );
      }

      for (final text in ['', '配图文字']) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'publishes a photo with text="$text" and prevents duplicate uploads',
          setUp: () => when(
            () => statusRepository.createPhotoStatus(
              photoPath: photo.path,
              text: text,
            ),
          ).thenAnswer((_) => upload.future),
          build: buildSubject,
          seed: () => StatusComposerState(content: text, photo: photo),
          act: (cubit) async {
            final publishing = cubit.publish();
            await cubit.publish();
            await cubit.pickPhoto();
            cubit
              ..removePhoto()
              ..contentChanged('忽略的编辑');
            upload.complete(_status);
            await publishing;
          },
          expect: () => [
            StatusComposerState(
              content: text,
              photo: photo,
              submissionStatus: StatusComposerSubmissionStatus.inProgress,
            ),
            StatusComposerState(
              content: text,
              photo: photo,
              submissionStatus: StatusComposerSubmissionStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => statusRepository.createPhotoStatus(
                photoPath: photo.path,
                text: text,
              ),
            ).called(1);
            verifyNever(() => photoPicker.pickPhoto());
            verifyNever(() => statusRepository.createStatus(any()));
          },
        );
      }

      blocTest<StatusComposerCubit, StatusComposerState>(
        'retains the photo and text after upload failure for retry',
        setUp: () {
          var attempts = 0;
          when(
            () => statusRepository.createPhotoStatus(
              photoPath: photo.path,
              text: '草稿',
            ),
          ).thenAnswer((_) async {
            if (attempts++ == 0) {
              throw const status_repository.StatusRepositoryUnknownFailure();
            }
            return _status;
          });
        },
        build: buildSubject,
        seed: () => StatusComposerState(content: '草稿', photo: photo),
        act: (cubit) async {
          await cubit.publish();
          await cubit.publish();
        },
        expect: () => [
          StatusComposerState(
            content: '草稿',
            photo: photo,
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '草稿',
            photo: photo,
            submissionStatus: StatusComposerSubmissionStatus.failure,
          ),
          StatusComposerState(
            content: '草稿',
            photo: photo,
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '草稿',
            photo: photo,
            submissionStatus: StatusComposerSubmissionStatus.success,
          ),
        ],
        errors: () => [isA<status_repository.StatusRepositoryUnknownFailure>()],
      );
    });

    group('contentChanged', () {
      for (final (text, remaining) in [
        ('字' * 139, 1),
        ('字' * 140, 0),
        ('字' * 141, -1),
        ('a中👨‍👩‍👧‍👦👍🏽e\u0301', 135),
        (' 空\n', 137),
      ]) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'counts complete characters with $remaining remaining',
          build: buildSubject,
          act: (cubit) => cubit.contentChanged(text),
          expect: () => [StatusComposerState(content: text)],
          verify: (cubit) {
            expect(cubit.state.remainingCharacters, remaining);
            expect(cubit.state.canPublish, remaining >= 0);
          },
        );
      }

      blocTest<StatusComposerCubit, StatusComposerState>(
        'stores the draft and enables publishing for visible text',
        build: buildSubject,
        act: (cubit) => cubit.contentChanged('新的动态'),
        expect: () => const [StatusComposerState(content: '新的动态')],
        verify: (cubit) {
          expect(cubit.state.canPublish, isTrue);
        },
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'keeps publishing disabled for whitespace-only text',
        build: buildSubject,
        act: (cubit) => cubit.contentChanged('   '),
        expect: () => const [StatusComposerState(content: '   ')],
        verify: (cubit) {
          expect(cubit.state.canPublish, isFalse);
        },
      );
    });

    group('publish', () {
      for (final withPhoto in [false, true]) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'rejects overlong drafts including attachments=$withPhoto',
          build: buildSubject,
          seed: () => StatusComposerState(
            content: '字' * 141,
            photo: withPhoto
                ? StatusComposerPhoto(path: '/photo.png', bytes: Uint8List(0))
                : null,
          ),
          act: (cubit) => cubit.publish(),
          expect: () => const <StatusComposerState>[],
          verify: (_) => verifyZeroInteractions(statusRepository),
        );
      }

      blocTest<StatusComposerCubit, StatusComposerState>(
        'allows publishing after reducing an overlong draft to 140 characters',
        setUp: () => when(
          () => statusRepository.createStatus('字' * 140),
        ).thenAnswer((_) async => _status),
        build: buildSubject,
        seed: () => StatusComposerState(content: '字' * 141),
        act: (cubit) async {
          cubit.contentChanged('字' * 140);
          await cubit.publish();
        },
        expect: () => [
          StatusComposerState(content: '字' * 140),
          StatusComposerState(
            content: '字' * 140,
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '字' * 140,
            submissionStatus: StatusComposerSubmissionStatus.success,
          ),
        ],
        verify: (_) => verify(
          () => statusRepository.createStatus('字' * 140),
        ).called(1),
      );

      for (final reply in [true, false]) {
        blocTest<StatusComposerCubit, StatusComposerState>(
          'preserves source identifiers after editing and retrying, '
          'reply=$reply',
          setUp: () {
            var attempts = 0;
            when(
              () => statusRepository.createStatus(
                '编辑后的正文',
                inReplyToStatusId: reply ? 'original-status' : null,
                repostStatusId: reply ? null : 'original-status',
              ),
            ).thenAnswer((_) async {
              if (attempts++ == 0) {
                throw const status_repository.StatusRepositoryUnknownFailure();
              }
              return _status;
            });
          },
          build: () => StatusComposerCubit(
            statusRepository: statusRepository,
            photoPicker: photoPicker,
            initialContent: '@饭友 正文',
            inReplyToStatusId: reply ? 'original-status' : null,
            repostStatusId: reply ? null : 'original-status',
          ),
          act: (cubit) async {
            cubit.contentChanged(' 编辑后的正文 ');
            await cubit.publish();
            await cubit.publish();
          },
          expect: () => const [
            StatusComposerState(content: ' 编辑后的正文 '),
            StatusComposerState(
              content: ' 编辑后的正文 ',
              submissionStatus: StatusComposerSubmissionStatus.inProgress,
            ),
            StatusComposerState(
              content: ' 编辑后的正文 ',
              submissionStatus: StatusComposerSubmissionStatus.failure,
            ),
            StatusComposerState(
              content: ' 编辑后的正文 ',
              submissionStatus: StatusComposerSubmissionStatus.inProgress,
            ),
            StatusComposerState(
              content: ' 编辑后的正文 ',
              submissionStatus: StatusComposerSubmissionStatus.success,
            ),
          ],
          errors: () => [
            isA<status_repository.StatusRepositoryUnknownFailure>(),
          ],
          verify: (_) {
            verify(
              () => statusRepository.createStatus(
                '编辑后的正文',
                inReplyToStatusId: reply ? 'original-status' : null,
                repostStatusId: reply ? null : 'original-status',
              ),
            ).called(2);
          },
        );
      }

      blocTest<StatusComposerCubit, StatusComposerState>(
        'emits [inProgress, success] when the repository creates the status',
        setUp: () {
          when(
            () => statusRepository.createStatus('新的动态'),
          ).thenAnswer((_) async => _status);
        },
        build: buildSubject,
        seed: () => const StatusComposerState(content: '  新的动态  '),
        act: (cubit) => cubit.publish(),
        expect: () => const [
          StatusComposerState(
            content: '  新的动态  ',
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '  新的动态  ',
            submissionStatus: StatusComposerSubmissionStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => statusRepository.createStatus('新的动态'),
          ).called(1);
        },
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'emits [inProgress, failure] when the repository throws',
        setUp: () {
          when(
            () => statusRepository.createStatus('新的动态'),
          ).thenThrow(
            const status_repository.StatusRepositoryUnknownFailure(),
          );
        },
        build: buildSubject,
        seed: () => const StatusComposerState(content: '新的动态'),
        act: (cubit) => cubit.publish(),
        expect: () => const [
          StatusComposerState(
            content: '新的动态',
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
          StatusComposerState(
            content: '新的动态',
            submissionStatus: StatusComposerSubmissionStatus.failure,
          ),
        ],
        errors: () => [
          isA<status_repository.StatusRepositoryUnknownFailure>(),
        ],
      );

      blocTest<StatusComposerCubit, StatusComposerState>(
        'does not call the repository for an empty draft',
        build: buildSubject,
        act: (cubit) => cubit.publish(),
        expect: () => const <StatusComposerState>[],
        verify: (_) {
          verifyNever(() => statusRepository.createStatus(any()));
        },
      );
    });
  });
}

const _status = status_repository.Status(
  id: 'status-a',
  text: '新的动态',
  createdAt: 'Tue Aug 25 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'account-a',
    name: 'Account',
    screenName: 'account',
  ),
);
