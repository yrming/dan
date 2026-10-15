import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('statusPhotoBorderRadiusFor', () {
    test('returns the radius for each status photo style', () {
      expect(
        statusPhotoBorderRadiusFor(StatusPhotoStyle.wechat),
        wechatStatusPhotoBorderRadius,
      );
      expect(
        statusPhotoBorderRadiusFor(StatusPhotoStyle.x),
        xStatusPhotoBorderRadius,
      );
    });
  });

  group(StatusPhoto, () {
    for (final style in StatusPhotoStyle.values) {
      group('loading ${style.name} photos', () {
        late Completer<ImageInfo> imageResult;

        tearDown(() {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        });

        Future<void> pumpPhoto(WidgetTester tester) async {
          imageResult = Completer<ImageInfo>();
          final imageStream = OneFrameImageStreamCompleter(imageResult.future);
          PaintingBinding.instance.imageCache.putIfAbsent(
            CachedNetworkImageProvider(
              _controlledImageUrl,
              maxHeight: style == StatusPhotoStyle.wechat ? 200 : null,
            ),
            () => imageStream,
          );
          if (style == StatusPhotoStyle.wechat) {
            final resizedKey = await const ResizeImage(
              CachedNetworkImageProvider(_controlledImageUrl),
              height: 200,
            ).obtainKey(ImageConfiguration.empty);
            PaintingBinding.instance.imageCache.putIfAbsent(
              resizedKey,
              () => imageStream,
            );
          }
          await tester.pumpApp(
            MediaQuery(
              data: const MediaQueryData(),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: switch (style) {
                    StatusPhotoStyle.wechat => const StatusPhoto.wechat(
                      imageUrl: _controlledImageUrl,
                      semanticLabel: _semanticLabel,
                      heroTag: _heroTag,
                    ),
                    StatusPhotoStyle.x => const StatusPhoto.x(
                      imageUrl: _controlledImageUrl,
                      semanticLabel: _semanticLabel,
                      heroTag: _heroTag,
                    ),
                  },
                ),
              ),
            ),
          );
        }

        testWidgets('animates a skeleton while the image is pending', (
          tester,
        ) async {
          await pumpPhoto(tester);

          final initialMask = tester.widget<ShaderMask>(
            find.byType(ShaderMask),
          );
          await tester.pump(Durations.medium2);

          expect(find.byType(AppShimmer), findsOneWidget);
          expect(
            tester.getSize(find.byType(AppShimmer)),
            style == StatusPhotoStyle.wechat
                ? const Size(300, 150)
                : const Size(300, 225),
          );
          expect(
            tester.widget<ShaderMask>(find.byType(ShaderMask)),
            isNot(same(initialMask)),
          );
        });

        testWidgets('replaces the skeleton when the image loads', (
          tester,
        ) async {
          await pumpPhoto(tester);
          expect(find.byType(AppShimmer), findsOneWidget);

          final image = await tester.runAsync(
            () => createTestImage(width: 400, height: 300),
          );
          imageResult.complete(ImageInfo(image: image!));
          await tester.pump();
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 2),
          );

          expect(find.byType(AppShimmer), findsNothing);
          expect(find.byType(CachedNetworkImage), findsOneWidget);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
        });

        testWidgets('replaces the skeleton with retry when loading fails', (
          tester,
        ) async {
          await pumpPhoto(tester);
          imageResult.completeError(Exception('Image unavailable'));
          await tester.pump();

          expect(find.byType(AppShimmer), findsNothing);
          expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
          expect(
            tester.widget<IconButton>(find.byType(IconButton)).onPressed,
            isNotNull,
          );
        });
      });
    }

    testWidgets('keeps a static skeleton when animations are disabled', (
      tester,
    ) async {
      await tester.pumpApp(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StatusPhoto.x(
            imageUrl: _imageUrl,
            semanticLabel: _semanticLabel,
            heroTag: _heroTag,
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets(
      'renders the X placeholder before image dimensions resolve',
      (
        tester,
      ) async {
        await tester.pumpApp(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: StatusPhoto.x(
                imageUrl: _imageUrl,
                semanticLabel: _semanticLabel,
                heroTag: _heroTag,
              ),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(AppShimmer), findsOneWidget);
        expect(find.bySemanticsLabel(_semanticLabel), findsOneWidget);
        expect(find.byType(Hero), findsOneWidget);
        expect(tester.widget<Hero>(find.byType(Hero)).tag, _heroTag);
      },
    );

    testWidgets('calls onTap when the thumbnail is tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpApp(
        StatusPhoto.x(
          imageUrl: _imageUrl,
          semanticLabel: _semanticLabel,
          heroTag: _heroTag,
          onTap: () => tapCount += 1,
        ),
      );

      await tester.tap(find.byType(StatusPhoto));

      expect(tapCount, 1);
    });

    testWidgets('keeps the thumbnail visible as its Hero placeholder', (
      tester,
    ) async {
      const placeholderChild = Text('thumbnail placeholder');
      await tester.pumpApp(
        const StatusPhoto.x(
          imageUrl: _imageUrl,
          semanticLabel: _semanticLabel,
          heroTag: _heroTag,
        ),
      );

      final hero = tester.widget<Hero>(find.byType(Hero));
      final placeholder = hero.placeholderBuilder!(
        tester.element(find.byType(Hero)),
        const Size.square(180),
        placeholderChild,
      );

      expect(placeholder, same(placeholderChild));
    });

    test(
      'returns a stable Hero tag from the scope, status id, and image URL',
      () {
        expect(
          statusPhotoHeroTag(
            scope: 'home',
            statusId: 'status-a',
            imageUrl: _imageUrl,
          ),
          'status-photo-home-status-a-$_imageUrl',
        );
      },
    );
  });
}

const _controlledImageUrl = 'https://example.com/controlled-status-photo.png';
const _imageUrl = 'https://example.com/status-photo.png';
const _semanticLabel = 'status photo';
const _heroTag =
    'status-photo-home-status-a-https://example.com/status-photo.png';
