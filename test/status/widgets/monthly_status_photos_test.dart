import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/status.dart';
import 'package:dan/status/widgets/monthly_status_photos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_view/photo_view.dart';
import 'package:status_repository/status_repository.dart' as repository;

import '../../helpers/helpers.dart';

void main() {
  group(MonthlyStatusPhotos, () {
    Future<void> pumpAlbum(
      WidgetTester tester,
      List<repository.Status> statuses, {
      double fontSize = 16,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await tester.pumpApp(
        Scaffold(
          body: SizedBox(
            width: 390,
            child: CustomScrollView(
              slivers: [MonthlyStatusPhotos(statuses: statuses)],
            ),
          ),
        ),
        theme: AppTheme.light(
          appearance: AppearanceSettings(fontSize: fontSize),
        ),
        darkTheme: AppTheme.dark(
          appearance: AppearanceSettings(fontSize: fontSize),
        ),
        themeMode: themeMode,
      );
    }

    group('grouping', () {
      testWidgets(
        'merges days in the same month and continues past nine photos',
        (tester) async {
          await pumpAlbum(tester, [
            for (var index = 0; index < 10; index++)
              _photo('$index', '2026-10-12T12:00:00'),
          ]);

          expect(find.text('10月'), findsOneWidget);
          expect(find.byType(CachedNetworkImage), findsNWidgets(10));
          final images = find.byType(CachedNetworkImage);
          expect(
            tester.getTopLeft(images.at(0)).dy,
            tester.getTopLeft(images.at(2)).dy,
          );
          expect(
            tester.getTopLeft(images.at(3)).dy,
            greaterThan(tester.getTopLeft(images.at(0)).dy),
          );
        },
      );

      testWidgets('merges appended photos into the existing month', (
        tester,
      ) async {
        final photos = [_photo('a', '2026-10-12T12:00:00')];
        await pumpAlbum(tester, photos);
        await pumpAlbum(tester, [
          ...photos,
          _photo('b', '2026-10-01T12:00:00'),
          _photo('c', '2026-09-30T12:00:00'),
        ]);

        expect(find.text('10月'), findsOneWidget);
        expect(find.text('09月'), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNWidgets(3));
      });

      testWidgets('keeps the same month in different years separate', (
        tester,
      ) async {
        await pumpAlbum(tester, [
          _photo('a', '2026-10-12T12:00:00'),
          _photo('b', '2025-10-12T12:00:00'),
        ]);

        expect(find.text('10月'), findsNWidgets(2));
        expect(find.text('2025年'), findsOneWidget);
      });

      testWidgets('skips messages without a photo and handles unknown dates', (
        tester,
      ) async {
        await pumpAlbum(tester, [
          _photo('a', 'unknown'),
          _photo('b', '2026-10-12').copyWith(photo: null),
        ]);

        expect(find.text('—'), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('navigation', () {
      testWidgets(
        'passes loaded photos in album order and swipes across months',
        (
          tester,
        ) async {
          final first = _photo('first', '2026-10-12');
          final last = _photo('last', '2026-09-12');
          final pendingImage = _PendingImageProvider();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      MonthlyStatusPhotos(
                        statuses: [
                          first,
                          _photo('text', '2026-10-01').copyWith(photo: null),
                          last,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              GoRoute(
                name: AppRouteName.statusImageViewer,
                path: '/status-image',
                builder: (_, state) {
                  final gallery = state.extra! as StatusImageGallery;
                  expect(gallery.statuses, [first, last]);
                  return RepositoryProvider<StatusImageActionsService>(
                    create: (_) => _MockStatusImageActionsService(),
                    child: StatusImageViewerPage(
                      imageUrl: state.uri.queryParameters['url']!,
                      heroTag: state.uri.queryParameters['heroTag']!,
                      statusId: state.uri.queryParameters['statusId'],
                      gallery: gallery,
                      imageProvider: pendingImage,
                    ),
                  );
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpRouterApp(router);
          await tester.tap(find.byType(CachedNetworkImage).first);
          await tester.pumpTransition();
          expect(
            tester.widget<PhotoView>(find.byType(PhotoView)).semanticLabel,
            'photo first',
          );

          await tester.drag(find.byType(PageView), const Offset(-600, 0));
          await tester.pumpTransition();
          expect(
            tester.widget<PhotoView>(find.byType(PhotoView)).semanticLabel,
            'photo last',
          );

          router.pop();
          await tester.pumpTransition();
          expect(find.byType(MonthlyStatusPhotos), findsOneWidget);
          expect(find.byType(StatusImageViewerPage), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('opens the photo before navigating to its status', (
        tester,
      ) async {
        final status = _photo('selected', '2026-10-12T12:00:00');
        final pendingImage = _PendingImageProvider();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: CustomScrollView(
                  slivers: [
                    MonthlyStatusPhotos(statuses: [status]),
                  ],
                ),
              ),
            ),
            GoRoute(
              name: AppRouteName.statusImageViewer,
              path: '/status-image',
              builder: (_, state) =>
                  RepositoryProvider<StatusImageActionsService>(
                    create: (_) => _MockStatusImageActionsService(),
                    child: StatusImageViewerPage(
                      imageUrl: state.uri.queryParameters['url']!,
                      imageProvider: pendingImage,
                      heroTag: state.uri.queryParameters['heroTag']!,
                      semanticLabel: state.uri.queryParameters['semanticLabel'],
                      userId: state.uri.queryParameters['userId'],
                      statusId: state.uri.queryParameters['statusId'],
                      gallery: state.extra! as StatusImageGallery,
                      initialStatus: (state.extra! as StatusImageGallery)
                          .statusFor(state.uri.queryParameters['statusId']),
                    ),
                  ),
            ),
            GoRoute(
              name: AppRouteName.statusDetail,
              path: '/status/:userId/:statusId',
              builder: (_, state) {
                expect(state.extra, same(status));
                return const Scaffold(body: Text('status detail'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(router);
        final sourceHero = tester.widget<Hero>(find.byType(Hero));
        final thumbnailRect = tester.getRect(find.byType(CachedNetworkImage));
        final flyingImage = find.byElementPredicate((element) {
          if (element.widget is! CachedNetworkImage) return false;
          var insideHero = false;
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget is Hero) insideHero = true;
            return !insideHero;
          });
          return !insideHero;
        });
        await tester.tap(find.byType(CachedNetworkImage));
        await tester.pump();
        await tester.pump(Durations.short2);

        // Even with an undecoded full image, the thumbnail flies on first tap.
        expect(flyingImage, findsOneWidget);
        expect(
          tester.getRect(flyingImage).width,
          greaterThan(thumbnailRect.width),
        );
        expect(tester.getRect(flyingImage).width, lessThan(800));
        await tester.pumpTransition();
        expect(flyingImage, findsNothing);
        expect(
          router.state.uri.queryParameters['heroTag'],
          sourceHero.tag,
        );

        expect(router.state.uri.path, '/status-image');
        expect(
          router.state.uri.queryParameters['url'],
          status.photo!.viewerUrl,
        );
        expect(find.byType(PhotoView), findsOneWidget);
        expect(find.text('status detail'), findsNothing);
        expect(find.text('查看详情'), findsOneWidget);

        await tester.tap(find.text('查看详情'));
        await tester.pumpTransition();

        expect(router.state.uri.path, '/status/user-a/selected');
        expect(find.text('status detail'), findsOneWidget);

        router.pop();
        await tester.pumpTransition();
        expect(find.byType(PhotoView), findsOneWidget);
        expect(find.text('查看详情'), findsOneWidget);

        router.pop();
        await tester.pump();
        await tester.pump(Durations.short2);
        expect(flyingImage, findsOneWidget);
        expect(
          tester.getRect(flyingImage).width,
          greaterThan(thumbnailRect.width),
        );
        expect(tester.getRect(flyingImage).width, lessThan(800));
        await tester.pumpTransition();
        expect(find.byType(MonthlyStatusPhotos), findsOneWidget);
        expect(find.byType(PhotoView), findsNothing);
        expect(flyingImage, findsNothing);
        expect(tester.getRect(find.byType(CachedNetworkImage)), thumbnailRect);
      });
    });

    group('loading and sizing', () {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('keeps three square columns at large font size in $mode', (
          tester,
        ) async {
          await pumpAlbum(
            tester,
            [for (var i = 0; i < 3; i++) _photo('$i', '2026-10-12')],
            fontSize: 20,
            themeMode: mode,
          );
          final images = find.byType(CachedNetworkImage);
          final first = tester.getSize(images.first);
          expect(first.width, closeTo(first.height, 0.01));
          expect(
            tester.getTopLeft(images.first).dy,
            tester.getTopLeft(images.last).dy,
          );
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('uses monthly grid placeholders while loading', (
        tester,
      ) async {
        await tester.pumpApp(
          const Scaffold(
            body: StatusListSkeleton(
              semanticLabel: 'loading photos',
              layout: StatusListLayout.monthlyPhotos,
              itemCount: 3,
            ),
          ),
        );

        expect(find.bySemanticsLabel('loading photos'), findsOneWidget);
        expect(find.byType(MonthlyPhotoRow), findsNWidgets(3));
        expect(find.byType(AspectRatio), findsNWidgets(9));
        expect(tester.takeException(), isNull);
      });
    });
  });
}

repository.Status _photo(String id, String date) => repository.Status(
  id: id,
  text: 'photo $id',
  createdAt: date,
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

class _MockStatusImageActionsService extends Mock
    implements StatusImageActionsService {}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  final _image = Completer<ImageInfo>();

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_image.future);
}
