import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/status/cubit/status_image_viewer_cubit.dart';
import 'package:dan/status/services/status_image_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatusImageActionsService extends Mock
    implements StatusImageActionsService {}

void main() {
  const imageUrl = 'https://example.com/status-photo-large.png';
  const blankImageUrl = '   ';

  group(StatusImageViewerCubit, () {
    late StatusImageActionsService imageActionsService;

    setUp(() {
      imageActionsService = _MockStatusImageActionsService();
      when(() => imageActionsService.share(any())).thenAnswer((_) async {});
      when(
        () => imageActionsService.saveToGallery(any()),
      ).thenAnswer((_) async {});
    });

    StatusImageViewerCubit buildCubit() {
      return StatusImageViewerCubit(
        imageActionsService: imageActionsService,
      );
    }

    group('shareRequested', () {
      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'keeps the state idle when $StatusImageActionsService shares the image',
        build: buildCubit,
        act: (cubit) => cubit.shareRequested(imageUrl),
        verify: (_) {
          verify(() => imageActionsService.share(imageUrl)).called(1);
        },
      );

      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'emits a share failure when sharing fails',
        setUp: () {
          when(() => imageActionsService.share(any())).thenThrow(
            const StatusImageShareFailure(),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.shareRequested(imageUrl),
        expect: () => <StatusImageViewerState>[
          const StatusImageViewerState(
            action: StatusImageViewerAction.share,
            status: StatusImageViewerActionStatus.failure,
          ),
        ],
      );

      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'ignores a blank image URL',
        build: buildCubit,
        act: (cubit) => cubit.shareRequested(blankImageUrl),
        expect: () => <StatusImageViewerState>[],
        verify: (_) {
          verifyNever(() => imageActionsService.share(any()));
        },
      );
    });

    group('saveToGalleryRequested', () {
      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'emits [inProgress, success] when the image is saved',
        build: buildCubit,
        act: (cubit) => cubit.saveToGalleryRequested(imageUrl),
        expect: () => <StatusImageViewerState>[
          const StatusImageViewerState(
            action: StatusImageViewerAction.save,
            status: StatusImageViewerActionStatus.inProgress,
          ),
          const StatusImageViewerState(
            action: StatusImageViewerAction.save,
            status: StatusImageViewerActionStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => imageActionsService.saveToGallery(imageUrl),
          ).called(1);
        },
      );

      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'emits [inProgress, failure] when saving fails',
        setUp: () {
          when(() => imageActionsService.saveToGallery(any())).thenThrow(
            const StatusImageGallerySaveFailure(),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.saveToGalleryRequested(imageUrl),
        expect: () => <StatusImageViewerState>[
          const StatusImageViewerState(
            action: StatusImageViewerAction.save,
            status: StatusImageViewerActionStatus.inProgress,
          ),
          const StatusImageViewerState(
            action: StatusImageViewerAction.save,
            status: StatusImageViewerActionStatus.failure,
          ),
        ],
      );

      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'ignores requests while another action is still running',
        setUp: () {
          when(() => imageActionsService.saveToGallery(any())).thenAnswer(
            (_) => Completer<void>().future,
          );
        },
        build: buildCubit,
        act: (cubit) {
          unawaited(cubit.saveToGalleryRequested(imageUrl));
          return cubit.saveToGalleryRequested(imageUrl);
        },
        expect: () => <StatusImageViewerState>[
          const StatusImageViewerState(
            action: StatusImageViewerAction.save,
            status: StatusImageViewerActionStatus.inProgress,
          ),
        ],
        verify: (_) {
          verify(
            () => imageActionsService.saveToGallery(imageUrl),
          ).called(1);
        },
      );

      blocTest<StatusImageViewerCubit, StatusImageViewerState>(
        'ignores a blank image URL',
        build: buildCubit,
        act: (cubit) => cubit.saveToGalleryRequested(blankImageUrl),
        expect: () => <StatusImageViewerState>[],
        verify: (_) {
          verifyNever(() => imageActionsService.saveToGallery(any()));
        },
      );
    });
  });
}
