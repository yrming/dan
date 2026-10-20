import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_view/photo_view.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart' as repository;

import '../../helpers/helpers.dart';

class _MockStatusImageActionsService extends Mock
    implements StatusImageActionsService {}

void main() {
  group(StatusImageViewerPage, () {
    late StatusImageActionsService imageActionsService;

    setUp(() {
      imageActionsService = _MockStatusImageActionsService();
      when(() => imageActionsService.share(any())).thenAnswer((_) async {});
      when(
        () => imageActionsService.saveToGallery(any()),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpViewer(
      WidgetTester tester, {
      ImageProvider<Object>? imageProvider,
      String imageUrl = _imageUrl,
      StatusImageGallery? gallery,
      String? statusId,
    }) {
      return tester.pumpApp(
        RepositoryProvider<StatusImageActionsService>.value(
          value: imageActionsService,
          child: StatusImageViewerPage(
            imageUrl: imageUrl,
            heroTag: _heroTag,
            semanticLabel: _semanticLabel,
            imageProvider: imageProvider,
            gallery: gallery,
            statusId: statusId,
          ),
        ),
      );
    }

    group('album paging', () {
      late StatusImageGallery gallery;
      late ImageProvider<Object> imageProvider;

      setUp(() {
        gallery = StatusImageGallery(
          statuses: [
            for (final id in ['a', 'b', 'c']) _albumPhoto(id),
          ],
        );
      });

      Future<void> loadImage(WidgetTester tester) async {
        final image = await tester.runAsync(
          () => _createTestImage(width: 1600, height: 900),
        );
        imageProvider = _TestImageProvider(image!);
        addTearDown(() async => imageProvider.evict());
      }

      Future<void> swipe(WidgetTester tester, double dx) async {
        await tester.drag(find.byType(PageView), Offset(dx, 0));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      void expectPhoto(WidgetTester tester, String id) {
        final photo = tester.widget<PhotoView>(find.byType(PhotoView));
        expect(photo.semanticLabel, 'photo $id');
        expect(
          photo.heroAttributes!.tag,
          statusPhotoHeroTag(
            scope: 'monthly-photos',
            statusId: id,
            imageUrl: _albumPhoto(id).photo!.viewerUrl,
          ),
        );
      }

      testWidgets(
        'starts at the selected photo and swipes in both directions',
        (
          tester,
        ) async {
          await loadImage(tester);
          await pumpViewer(
            tester,
            imageProvider: imageProvider,
            gallery: gallery,
            statusId: 'b',
          );
          await tester.pump();
          await tester.pump();
          expectPhoto(tester, 'b');

          await swipe(tester, -600);
          expectPhoto(tester, 'c');
          await swipe(tester, -600);
          expectPhoto(tester, 'c');
          await swipe(tester, 600);
          expectPhoto(tester, 'b');
          await swipe(tester, 600);
          expectPhoto(tester, 'a');
          await swipe(tester, 600);
          expectPhoto(tester, 'a');
          expect(tester.takeException(), isNull);
        },
      );

      for (final dx in [-500.0, 500.0]) {
        for (final cancel in [false, true]) {
          testWidgets(
            'keeps the current photo during a downward drag followed by '
            '$dx horizontal movement and restores paging after '
            '${cancel ? 'cancellation' : 'release'}',
            (tester) async {
              await loadImage(tester);
              await pumpViewer(
                tester,
                imageProvider: imageProvider,
                gallery: gallery,
                statusId: 'b',
              );
              await tester.pump();
              await tester.pump();
              final pageController = tester
                  .widget<PageView>(find.byType(PageView))
                  .controller!;
              final gesture = await tester.startGesture(
                tester.getCenter(find.byType(PhotoView)),
              );
              await gesture.moveBy(const Offset(0, 10));
              await tester.pump();
              for (var move = 0; move < 5; move++) {
                await gesture.moveBy(Offset(dx / 5, 0));
                await tester.pump(const Duration(milliseconds: 16));
              }
              await tester.pump();

              expect(pageController.page, 1);
              expectPhoto(tester, 'b');

              if (cancel) {
                await gesture.cancel();
              } else {
                await tester.pump(const Duration(seconds: 1));
                await gesture.up();
              }
              await tester.pumpAndSettle();
              expectPhoto(tester, 'b');

              await swipe(tester, dx < 0 ? -600 : 600);
              expectPhoto(tester, dx < 0 ? 'c' : 'a');
              expect(tester.takeException(), isNull);
            },
          );
        }
      }

      testWidgets('floats date and details over the full photo viewport', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await loadImage(tester);
        await pumpViewer(
          tester,
          imageProvider: imageProvider,
          gallery: gallery,
          statusId: 'b',
        );
        await tester.pump();
        await tester.pump();

        final viewport = Offset.zero & tester.view.physicalSize;
        expect(tester.getRect(find.byType(PhotoView)), viewport);
        final date = tester.getRect(find.text('2026年10月12日'));
        final detailsLabel = tester
            .element(find.byType(PhotoView))
            .l10n
            .statusImageViewerViewStatusLabel;
        final details = tester.getRect(
          find.widgetWithText(FilledButton, detailsLabel),
        );
        expect(date.center.dx, viewport.center.dx);
        expect(date.top, greaterThanOrEqualTo(44));
        expect(date.bottom, lessThan(viewport.height / 4));
        expect(details.left, greaterThan(viewport.width / 2));
        expect(details.top, greaterThan(viewport.height * 3 / 4));
        expect(details.bottom, lessThanOrEqualTo(viewport.bottom - 34));
        expect(details.right, lessThanOrEqualTo(viewport.right));
      });

      for (final date in ['2025-01-02', '', 'invalid']) {
        testWidgets('handles single album photo date $date', (tester) async {
          await loadImage(tester);
          await pumpViewer(
            tester,
            imageProvider: imageProvider,
            gallery: StatusImageGallery(
              statuses: [_albumPhoto('a').copyWith(createdAt: date)],
            ),
            statusId: 'a',
          );
          await tester.pump();
          expect(find.byType(PageView), findsNothing);
          expect(
            find.text('2025年1月2日'),
            date == '2025-01-02' ? findsOneWidget : findsNothing,
          );
          expect(find.text('invalid'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('pans a zoomed photo before switching pages', (tester) async {
        await loadImage(tester);
        await pumpViewer(
          tester,
          imageProvider: imageProvider,
          gallery: gallery,
          statusId: 'b',
        );
        await tester.pump();
        await tester.pump();
        final controller =
            tester
                  .widget<PhotoView>(
                    find.byType(PhotoView),
                  )
                  .controller!
              ..scale = 2;
        await tester.pump();

        await swipe(tester, -100);
        expectPhoto(tester, 'b');
        expect(controller.position.dx, lessThan(0));
        expect(tester.takeException(), isNull);
      });

      testWidgets('opens the current status and saves the current photo', (
        tester,
      ) async {
        await loadImage(tester);
        final router = _buildRouter(
          imageActionsService: imageActionsService,
          imageProvider: imageProvider,
          gallery: gallery,
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(router);
        unawaited(router.push<void>('/viewer'));
        await tester.pump();
        await tester.pump();
        await swipe(tester, -600);
        expectPhoto(tester, 'c');

        final detailsLabel = tester
            .element(find.byType(PhotoView))
            .l10n
            .statusImageViewerViewStatusLabel;
        await tester.tap(find.text(detailsLabel));
        await tester.pumpTransition();
        expect(find.text('status c'), findsOneWidget);
        expect(router.state.extra, same(gallery.statuses.last));
        router.pop();
        await tester.pumpTransition();

        await tester.longPress(find.byType(PhotoView));
        await tester.pumpTransition();
        final context = tester.element(find.byType(PhotoView));
        await tester.tap(find.text(context.l10n.statusImageViewerSaveLabel));
        await tester.pumpTransition();
        verify(
          () => imageActionsService.saveToGallery(
            _albumPhoto('c').photo!.viewerUrl,
          ),
        ).called(1);
      });

      testWidgets('dismisses the gallery after swiping to another photo', (
        tester,
      ) async {
        await loadImage(tester);
        final router = _buildRouter(
          imageActionsService: imageActionsService,
          imageProvider: imageProvider,
          gallery: gallery,
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(router);
        unawaited(router.push<void>('/viewer'));
        await tester.pump();
        await tester.pump();
        await swipe(tester, -600);
        await tester.drag(find.byType(PhotoView), const Offset(0, 500));
        await tester.pumpTransition();
        expect(find.text('timeline'), findsOneWidget);
        expect(find.byType(StatusImageViewerPage), findsNothing);
      });

      testWidgets(
        'falls back to the linked photo without a matching album item',
        (
          tester,
        ) async {
          await loadImage(tester);
          await pumpViewer(
            tester,
            imageProvider: imageProvider,
            gallery: gallery,
            statusId: 'missing',
          );
          await tester.pump();
          expect(find.byType(PageView), findsNothing);
          expect(
            tester.widget<PhotoView>(find.byType(PhotoView)).semanticLabel,
            _semanticLabel,
          );
        },
      );
    });

    testWidgets('uses PhotoView for Hero, zoom, and vertical slide out', (
      tester,
    ) async {
      await pumpViewer(tester);

      final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
      final imageProvider = photoView.imageProvider;
      expect(imageProvider, isA<CachedNetworkImageProvider>());
      expect(
        (imageProvider! as CachedNetworkImageProvider).url,
        _imageUrl,
      );
      expect(photoView.semanticLabel, _semanticLabel);
      expect(photoView.heroAttributes?.tag, _heroTag);
      expect(photoView.heroAttributes?.flightShuttleBuilder, isNull);
      expect(photoView.initialScale, PhotoViewComputedScale.contained);
      expect(photoView.minScale, PhotoViewComputedScale.contained);
      expect(
        (photoView.maxScale! as PhotoViewComputedScale).multiplier,
        4,
      );
      expect(photoView.onTapUp, isNotNull);
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(PhotoViewGestureDetectorScope), findsNothing);
      expect(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
        findsOneWidget,
      );
    });

    testWidgets('scrolls a width-fitted long image vertically', (
      tester,
    ) async {
      final image = await tester.runAsync(
        () => _createTestImage(width: 100, height: 1000),
      );
      final imageProvider = _TestImageProvider(image!);
      addTearDown(() async {
        await imageProvider.evict();
      });
      await pumpViewer(tester, imageProvider: imageProvider);
      await tester.pump();
      await tester.pump();

      var photoView = tester.widget<PhotoView>(find.byType(PhotoView));
      final controller = photoView.controller!;

      expect(photoView.basePosition, Alignment.topCenter);
      expect(photoView.initialScale, moreOrLessEquals(8));
      expect(controller.position, Offset.zero);

      await tester.drag(find.byType(PhotoView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(Durations.short1);

      photoView = tester.widget<PhotoView>(find.byType(PhotoView));
      expect(photoView.disableGestures, isFalse);
      expect(controller.position.dy, lessThan(0));
    });

    testWidgets('zooms on the first double-tap after the image is reloaded', (
      tester,
    ) async {
      final image1 = await tester.runAsync(
        () => _createTestImage(width: 1600, height: 900),
      );
      final image2 = await tester.runAsync(
        () => _createTestImage(width: 1600, height: 900),
      );
      final imageProvider1 = _TestImageProvider(image1!);
      final imageProvider2 = _TestImageProvider(image2!);
      addTearDown(() async {
        await imageProvider1.evict();
        await imageProvider2.evict();
      });

      Widget build(ImageProvider<Object> imageProvider) =>
          RepositoryProvider<StatusImageActionsService>.value(
            value: imageActionsService,
            child: StatusImageViewerPage(
              imageUrl: _imageUrl,
              heroTag: _heroTag,
              semanticLabel: _semanticLabel,
              imageProvider: imageProvider,
            ),
          );

      await tester.pumpApp(build(imageProvider1));
      await tester.pump();
      await tester.pump();

      // Reload the viewer with a different provider. This runs the reset path
      // that fires after the PhotoView has already been built.
      await tester.pumpApp(build(imageProvider2));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
      final controller = photoView.controller!;

      await tester.tap(find.byType(PhotoView));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byType(PhotoView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.scale, greaterThan(0.5));
    });

    testWidgets('double-tap toggles between zoomed-in and fit-to-screen', (
      tester,
    ) async {
      final image = await tester.runAsync(
        () => _createTestImage(width: 1600, height: 900),
      );
      final imageProvider = _TestImageProvider(image!);
      addTearDown(() async {
        await imageProvider.evict();
      });
      await pumpViewer(tester, imageProvider: imageProvider);
      await tester.pump();
      await tester.pump();

      final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
      final controller = photoView.controller!;
      const fitScale = 0.5;
      const coveringScale = 600 / 900;

      // First double-tap zooms in to fill the screen.
      await _doubleTap(tester);
      expect(controller.scale, moreOrLessEquals(coveringScale));

      // Second double-tap zooms back out to fit-to-screen.
      await _doubleTap(tester);
      expect(controller.scale, moreOrLessEquals(fitScale));
    });

    testWidgets('returns to the previous route after a downward slide', (
      tester,
    ) async {
      final image = await tester.runAsync(
        () => _createTestImage(width: 100, height: 1000),
      );
      final imageProvider = _TestImageProvider(image!);
      addTearDown(() async {
        await imageProvider.evict();
      });
      final router = _buildRouter(
        imageActionsService: imageActionsService,
        imageProvider: imageProvider,
      );
      await tester.pumpRouterApp(router);
      unawaited(router.push<void>('/viewer'));
      await tester.pump();

      expect(find.byType(StatusImageViewerPage), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
        const Offset(0, 500),
      );
      await tester.pump(Durations.medium2);
      await tester.pump(Durations.medium2);

      expect(find.text('timeline'), findsOneWidget);
      expect(find.byType(StatusImageViewerPage), findsNothing);
    });

    testWidgets(
      'uses the status photo corner radius when a single tap closes the viewer',
      (tester) async {
        final image = await tester.runAsync(
          () => _createTestImage(width: 1600, height: 900),
        );
        final imageProvider = _TestImageProvider(image!);
        addTearDown(() async {
          await imageProvider.evict();
        });
        final router = _buildRouter(
          imageActionsService: imageActionsService,
          imageProvider: imageProvider,
        );
        await tester.pumpRouterApp(router);
        unawaited(router.push<void>('/viewer'));
        await tester.pump();
        await tester.pump();

        expect(
          tester
              .widget<PhotoView>(find.byType(PhotoView))
              .heroAttributes
              ?.flightShuttleBuilder,
          isNull,
        );

        await tester.tap(find.byType(PhotoView));
        await tester.pump(kDoubleTapTimeout);

        final closingPhotoView = tester.widget<PhotoView>(
          find.byType(PhotoView),
        );
        expect(closingPhotoView.disableGestures, isTrue);
        expect(
          closingPhotoView.heroAttributes?.flightShuttleBuilder,
          isNotNull,
        );
        final roundedPhoto = find.byKey(
          const Key('status-image-viewer-rounded-photo'),
        );
        expect(roundedPhoto, findsOneWidget);
        final clip = tester
            .widget<ClipRRect>(roundedPhoto)
            .clipper!
            .getClip(tester.getSize(roundedPhoto));
        expect(clip.tlRadiusX, xStatusPhotoBorderRadius);
        expect(clip.trRadiusX, clip.tlRadiusX);
        expect(clip.blRadiusX, clip.tlRadiusX);
        expect(clip.brRadiusX, clip.tlRadiusX);

        await tester.pump();

        expect(find.text('timeline'), findsOneWidget);
        expect(find.byType(StatusImageViewerPage), findsNothing);
      },
    );

    testWidgets('stays open after a short downward slide', (tester) async {
      final router = _buildRouter(imageActionsService: imageActionsService);
      await tester.pumpRouterApp(router);
      unawaited(router.push<void>('/viewer'));
      await tester.pump();

      await tester.drag(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
        const Offset(0, 50),
      );
      await tester.pump(Durations.medium2);

      expect(find.byType(StatusImageViewerPage), findsOneWidget);
    });

    testWidgets('can start another downward slide while reset is animating', (
      tester,
    ) async {
      final router = _buildRouter(imageActionsService: imageActionsService);
      await tester.pumpRouterApp(router);
      unawaited(router.push<void>('/viewer'));
      await tester.pump(Durations.medium2);

      final gestureLayer = find.byKey(
        const Key('status-image-viewer-gesture-layer'),
      );
      final firstGesture = await tester.startGesture(
        tester.getCenter(gestureLayer),
      );
      await firstGesture.moveBy(const Offset(0, 50));
      await firstGesture.up();

      // Start the retry before the short-slide reset animation has had a
      // frame to complete. This used to be ignored by the viewer.
      final secondGesture = await tester.startGesture(
        tester.getCenter(gestureLayer),
      );
      await secondGesture.moveBy(const Offset(0, 300));
      await secondGesture.up();
      await tester.pump(Durations.medium2);
      await tester.pump(Durations.medium2);

      expect(find.text('timeline'), findsOneWidget);
      expect(find.byType(StatusImageViewerPage), findsNothing);
    });

    testWidgets('recognizes a downward slide with small directional jitter', (
      tester,
    ) async {
      final router = _buildRouter(imageActionsService: imageActionsService);
      await tester.pumpRouterApp(router);
      unawaited(router.push<void>('/viewer'));
      await tester.pump(Durations.medium2);

      final gestureLayer = find.byKey(
        const Key('status-image-viewer-gesture-layer'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(gestureLayer),
      );
      for (var index = 0; index < 12; index++) {
        await gesture.moveBy(Offset(index.isEven ? 25 : -25, 20));
      }
      await gesture.up();
      await tester.pump(Durations.medium2);
      await tester.pump(Durations.medium2);

      expect(find.text('timeline'), findsOneWidget);
      expect(find.byType(StatusImageViewerPage), findsNothing);
    });

    testWidgets(
      'uses the status photo corner radius while sliding downward',
      (tester) async {
        final image = await tester.runAsync(
          () => _createTestImage(width: 1600, height: 900),
        );
        final imageProvider = _TestImageProvider(image!);
        addTearDown(() async {
          await imageProvider.evict();
        });
        await pumpViewer(tester, imageProvider: imageProvider);
        await tester.pump();
        await tester.pump();

        final gesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const Key('status-image-viewer-gesture-layer')),
          ),
        );
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();

        expect(
          tester
              .widget<PhotoView>(find.byType(PhotoView))
              .heroAttributes
              ?.flightShuttleBuilder,
          isNotNull,
        );

        final roundedPhoto = find.byKey(
          const Key('status-image-viewer-rounded-photo'),
        );
        expect(roundedPhoto, findsOneWidget);
        final clip = tester
            .widget<ClipRRect>(roundedPhoto)
            .clipper!
            .getClip(
              tester.getSize(roundedPhoto),
            );
        final scale = tester.widget<AnimatedScale>(
          find.ancestor(
            of: roundedPhoto,
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(
          clip.tlRadiusX * scale.scale,
          moreOrLessEquals(xStatusPhotoBorderRadius),
        );
        expect(clip.trRadiusX, clip.tlRadiusX);
        expect(clip.blRadiusX, clip.tlRadiusX);
        expect(clip.brRadiusX, clip.tlRadiusX);

        await gesture.up();
        await tester.pump(Durations.short2);
        await tester.pump(Durations.medium2);
      },
    );

    testWidgets('shows a failure affordance when the image URL is empty', (
      tester,
    ) async {
      await pumpViewer(tester, imageUrl: ' ');

      expect(find.byType(PhotoView), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('long-pressing the image opens the action sheet', (
      tester,
    ) async {
      await pumpViewer(tester);
      final context = tester.element(find.byType(PhotoView));

      await tester.longPress(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('status-image-viewer-action-sheet')),
        findsOneWidget,
      );
      expect(
        find.text(context.l10n.statusImageViewerShareLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.l10n.statusImageViewerSaveLabel),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('status-image-viewer-save-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('status-image-viewer-share-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('status-image-viewer-action-group')),
        findsOneWidget,
      );
      expect(find.byIcon(RemixIcons.download_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.share_box_line), findsOneWidget);
    });

    testWidgets('groups action items with a hairline divider', (tester) async {
      await pumpViewer(tester);

      await tester.longPress(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byKey(const Key('status-image-viewer-action-sheet')),
      );
      final saveAction = find.byKey(
        const Key('status-image-viewer-save-action'),
      );
      final shareAction = find.byKey(
        const Key('status-image-viewer-share-action'),
      );
      final actionGroup = find.byKey(
        const Key('status-image-viewer-action-group'),
      );
      final divider = find.byKey(
        const Key('status-image-viewer-action-divider'),
      );
      final saveRect = tester.getRect(saveAction);
      final shareRect = tester.getRect(shareAction);
      final groupRect = tester.getRect(actionGroup);
      final dividerRect = tester.getRect(divider);
      final saveLabel = find.descendant(
        of: saveAction,
        matching: find.text(context.l10n.statusImageViewerSaveLabel),
      );
      final saveIcon = find.descendant(
        of: saveAction,
        matching: find.byIcon(RemixIcons.download_line),
      );
      final material = tester.widget<Material>(
        find.descendant(of: actionGroup, matching: find.byType(Material)).first,
      );
      final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));

      expect(saveRect.height, AppLayout.actionSheetItemHeight);
      expect(shareRect.height, AppLayout.actionSheetItemHeight);
      expect(
        dividerRect.height,
        AppLayout.actionSheetDividerThickness,
      );
      expect(dividerRect.width, groupRect.width);
      expect(dividerRect.top, saveRect.bottom);
      expect(shareRect.top, dividerRect.bottom);
      expect(
        groupRect.height,
        2 * AppLayout.actionSheetItemHeight +
            AppLayout.actionSheetDividerThickness,
      );
      expect(tester.getRect(saveLabel).left - saveRect.left, AppSpacing.md);
      expect(saveRect.right - tester.getRect(saveIcon).right, AppSpacing.md);
      expect(
        bottomSheet.backgroundColor,
        context.appColors.actionSheetBackground,
      );
      expect(material.color, context.appColors.bgBase);
      expect(
        material.borderRadius,
        BorderRadius.circular(AppLayout.actionSheetGroupRadius),
      );
    });

    testWidgets('shares the image from the action sheet', (tester) async {
      await pumpViewer(tester);

      await tester.longPress(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
      );
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byKey(const Key('status-image-viewer-action-sheet')),
      );
      await tester.tap(find.text(context.l10n.statusImageViewerShareLabel));
      await tester.pumpAndSettle();

      verify(() => imageActionsService.share(_imageUrl)).called(1);
      expect(
        find.byKey(const Key('status-image-viewer-action-sheet')),
        findsNothing,
      );
    });

    testWidgets('saves the image to the gallery and confirms', (tester) async {
      await pumpViewer(tester);
      final context = tester.element(find.byType(PhotoView));

      await tester.longPress(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.l10n.statusImageViewerSaveLabel));
      await tester.pumpAndSettle();

      verify(() => imageActionsService.saveToGallery(_imageUrl)).called(1);
      expect(
        find.text(context.l10n.statusImageViewerSavedToGalleryLabel),
        findsOneWidget,
      );
    });

    testWidgets('reports a failure when saving does not complete', (
      tester,
    ) async {
      when(() => imageActionsService.saveToGallery(any())).thenAnswer(
        (_) async => throw const StatusImageGallerySaveFailure(),
      );
      await pumpViewer(tester);
      final context = tester.element(find.byType(PhotoView));

      await tester.longPress(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.l10n.statusImageViewerSaveLabel));
      await tester.pumpAndSettle();

      verify(() => imageActionsService.saveToGallery(_imageUrl)).called(1);
      expect(
        find.text(context.l10n.statusImageViewerActionFailureLabel),
        findsOneWidget,
      );
    });

    testWidgets('closes the action sheet without dispatching on scrim tap', (
      tester,
    ) async {
      await pumpViewer(tester);

      await tester.longPress(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(30, 50));
      await tester.pumpAndSettle();

      verifyNever(() => imageActionsService.share(any()));
      verifyNever(() => imageActionsService.saveToGallery(any()));
      expect(
        find.byKey(const Key('status-image-viewer-action-sheet')),
        findsNothing,
      );
    });
  });

  group('statusImageViewerUsesWidthFitFor', () {
    test('returns true for an image taller than the viewport aspect ratio', () {
      expect(
        statusImageViewerUsesWidthFitFor(
          imageSize: const Size(1080, 4000),
          viewportSize: const Size(390, 844),
        ),
        isTrue,
      );
    });

    test('returns false for regular portrait and landscape images', () {
      expect(
        statusImageViewerUsesWidthFitFor(
          imageSize: const Size(1200, 1600),
          viewportSize: const Size(390, 844),
        ),
        isFalse,
      );
      expect(
        statusImageViewerUsesWidthFitFor(
          imageSize: const Size(1600, 900),
          viewportSize: const Size(390, 844),
        ),
        isFalse,
      );
    });

    test('returns false for invalid image or viewport dimensions', () {
      expect(
        statusImageViewerUsesWidthFitFor(
          imageSize: Size.zero,
          viewportSize: const Size(390, 844),
        ),
        isFalse,
      );
      expect(
        statusImageViewerUsesWidthFitFor(
          imageSize: const Size(1080, 4000),
          viewportSize: Size.zero,
        ),
        isFalse,
      );
    });
  });

  group('statusImageViewerInitialScaleFor', () {
    test('matches a long image to the full viewport width', () {
      final scale = statusImageViewerInitialScaleFor(
        imageSize: const Size(1080, 4000),
        viewportSize: const Size(390, 844),
      );

      expect(scale, moreOrLessEquals(390 / 1080));
      expect(1080 * scale, moreOrLessEquals(390));
    });

    test('fully contains a regular image in the viewport', () {
      final scale = statusImageViewerInitialScaleFor(
        imageSize: const Size(1600, 900),
        viewportSize: const Size(390, 844),
      );

      expect(scale, moreOrLessEquals(390 / 1600));
    });

    test('returns 1 for invalid image or viewport dimensions', () {
      expect(
        statusImageViewerInitialScaleFor(
          imageSize: Size.zero,
          viewportSize: const Size(390, 844),
        ),
        1,
      );
    });
  });

  group('statusImageViewerZoomScaleStateFor', () {
    test('returns covering for regular portrait and landscape images', () {
      expect(
        statusImageViewerZoomScaleStateFor(
          imageSize: const Size(1200, 1600),
          viewportSize: const Size(390, 844),
        ),
        PhotoViewScaleState.covering,
      );
      expect(
        statusImageViewerZoomScaleStateFor(
          imageSize: const Size(1600, 900),
          viewportSize: const Size(390, 844),
        ),
        PhotoViewScaleState.covering,
      );
    });

    test('returns originalSize for width-fitted long images', () {
      expect(
        statusImageViewerZoomScaleStateFor(
          imageSize: const Size(1080, 4000),
          viewportSize: const Size(390, 844),
        ),
        PhotoViewScaleState.originalSize,
      );
    });
  });

  group('statusImageViewerShouldPopForSlide', () {
    test('returns true after passing the distance threshold', () {
      expect(
        statusImageViewerShouldPopForSlide(
          distance: 200,
          viewportHeight: 800,
          velocity: 0,
        ),
        isTrue,
      );
    });

    test('returns true for a short fast downward fling', () {
      expect(
        statusImageViewerShouldPopForSlide(
          distance: 30,
          viewportHeight: 800,
          velocity: 1200,
        ),
        isTrue,
      );
    });

    test('returns false for a short slow downward drag', () {
      expect(
        statusImageViewerShouldPopForSlide(
          distance: 50,
          viewportHeight: 800,
          velocity: 200,
        ),
        isFalse,
      );
    });
  });
}

GoRouter _buildRouter({
  required StatusImageActionsService imageActionsService,
  ImageProvider<Object>? imageProvider,
  StatusImageGallery? gallery,
}) {
  return GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (_, _) => const Scaffold(body: Text('timeline')),
      ),
      GoRoute(
        path: '/viewer',
        pageBuilder: (_, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: RepositoryProvider<StatusImageActionsService>.value(
            value: imageActionsService,
            child: StatusImageViewerPage(
              imageUrl: _imageUrl,
              heroTag: _heroTag,
              semanticLabel: _semanticLabel,
              imageProvider: imageProvider,
              gallery: gallery,
              statusId: gallery == null ? null : 'b',
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.statusDetail,
        path: '/status/:userId/:statusId',
        builder: (_, state) => Scaffold(
          body: Text('status ${state.pathParameters['statusId']}'),
        ),
      ),
    ],
  );
}

repository.Status _albumPhoto(String id) => repository.Status(
  id: id,
  text: 'photo $id',
  createdAt: '2026-10-12',
  author: const repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
  photo: repository.StatusPhotoUrls(
    imageUrl: 'https://example.com/$id.png',
    largeUrl: 'https://example.com/$id-large.png',
  ),
);

Future<void> _doubleTap(WidgetTester tester) async {
  await tester.tap(find.byType(PhotoView));
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(find.byType(PhotoView));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<ui.Image> _createTestImage({
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.white, BlendMode.src);
  return recorder.endRecording().toImage(width, height);
}

class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  const _TestImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image)),
    );
  }
}

const _imageUrl = 'https://example.com/status-photo-large.png';
const _heroTag = 'status-photo-home-status-a';
const _semanticLabel = 'status photo';
