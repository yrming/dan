import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dan/status/models/status_composer_photo.dart';
import 'package:dan/status/view/status_image_viewer_page.dart';
import 'package:dan/status/widgets/status_composer_photo_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StatusComposerPhotoPicker, () {
    Future<StatusComposerPhoto> createPhoto(
      WidgetTester tester,
      int width,
      int height,
    ) async {
      final bytes = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      });
      return StatusComposerPhoto(path: '/photo.png', bytes: bytes!);
    }

    Future<void> pumpPhoto(
      WidgetTester tester,
      StatusComposerPhoto photo,
    ) async {
      await tester.pumpApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: StatusComposerPhotoPicker(
              photo: photo,
              isBusy: false,
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(StatusComposerPhotoPicker));
        await precacheImage(
          MemoryImage(photo.bytes),
          context,
          onError: (_, _) {},
        );
      });
      await tester.pump();
    }

    group('preview', () {
      testWidgets('animates the photo between thumbnail and viewer both ways', (
        tester,
      ) async {
        final photo = await createPhoto(tester, 1600, 900);
        await pumpPhoto(tester, photo);
        final thumbnail = find.byKey(
          const Key('status-composer-photo-preview'),
        );
        final thumbnailRect = tester.getRect(thumbnail);
        final flyingImage = find.byElementPredicate((element) {
          final widget = element.widget;
          if (widget is! Image || widget.image != MemoryImage(photo.bytes)) {
            return false;
          }
          var insideHero = false;
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget is Hero) insideHero = true;
            return !insideHero;
          });
          return !insideHero;
        });

        await tester.tap(thumbnail);
        await tester.pump();
        await tester.pump(Durations.short2);
        expect(flyingImage, findsOneWidget);
        expect(
          tester.getRect(flyingImage).width,
          greaterThan(thumbnailRect.width),
        );
        expect(tester.getRect(flyingImage).width, lessThan(800));
        await tester.pumpAndSettle();
        expect(flyingImage, findsNothing);

        await tester.tap(find.byType(PhotoView));
        await tester.pump(kDoubleTapTimeout + Durations.short1);
        await tester.pump();
        await tester.pump(Durations.short2);
        expect(flyingImage, findsOneWidget);
        expect(
          tester.getRect(flyingImage).width,
          greaterThan(thumbnailRect.width),
        );
        expect(tester.getRect(flyingImage).width, lessThan(800));
        expect(
          find.ancestor(of: flyingImage, matching: find.byType(ClipRRect)),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect(flyingImage, findsNothing);
        expect(tester.getRect(thumbnail), thumbnailRect);
        expect(find.byType(StatusImageViewerView), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('uses the status viewer to zoom and dismiss a local photo', (
        tester,
      ) async {
        final photo = await createPhoto(tester, 1600, 900);
        await pumpPhoto(tester, photo);
        await tester.tap(
          find.byKey(const Key('status-composer-photo-preview')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StatusImageViewerView), findsOneWidget);
        final viewer = find.byType(PhotoView);
        final photoView = tester.widget<PhotoView>(viewer);
        expect(photoView.imageProvider, MemoryImage(photo.bytes));
        final initialScale = photoView.controller!.scale!;

        await tester.tap(viewer);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(viewer);
        await tester.pumpAndSettle();
        expect(photoView.controller!.scale, greaterThan(initialScale));

        await tester.longPress(viewer);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(StatusImageViewerView), findsOneWidget);

        await tester.tap(viewer);
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        expect(find.byType(StatusImageViewerView), findsNothing);
        expect(
          find.byKey(const Key('status-composer-photo-preview')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows tall photos at full width and dismisses downward', (
        tester,
      ) async {
        await pumpPhoto(tester, await createPhoto(tester, 300, 1200));
        await tester.tap(
          find.byKey(const Key('status-composer-photo-preview')),
        );
        await tester.pumpAndSettle();
        final viewer = tester.widget<PhotoView>(find.byType(PhotoView));
        expect(viewer.basePosition, Alignment.topCenter);
        expect(viewer.controller!.scale, closeTo(800 / 300, 0.01));

        await tester.drag(
          find.byKey(const Key('status-image-viewer-gesture-layer')),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StatusImageViewerView), findsNothing);
        expect(
          find.byKey(const Key('status-composer-photo-preview')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('photo layout', () {
      testWidgets('updates the full-width frame when the photo is replaced', (
        tester,
      ) async {
        final landscape = await createPhoto(tester, 400, 300);
        await pumpPhoto(tester, landscape);
        final preview = find.byKey(const Key('status-composer-photo-preview'));
        expect(tester.getSize(preview), const Size(300, 225));

        final portrait = await createPhoto(tester, 300, 400);
        await pumpPhoto(tester, portrait);
        expect(tester.getSize(preview), const Size(300, 400));
        expect(tester.widget<Image>(preview).fit, BoxFit.fitWidth);
        expect(tester.takeException(), isNull);
      });

      for (final (width, height, expectedSize, alignment) in [
        (300, 900, const Size(300, 400), Alignment.topCenter),
        (900, 300, const Size(300, 168.75), Alignment.center),
      ]) {
        testWidgets('crops a $width by $height photo like a status image', (
          tester,
        ) async {
          await pumpPhoto(tester, await createPhoto(tester, width, height));
          final preview = find.byKey(
            const Key('status-composer-photo-preview'),
          );
          expect(tester.getSize(preview), expectedSize);
          expect(tester.widget<Image>(preview).fit, BoxFit.cover);
          expect(tester.widget<Image>(preview).alignment, alignment);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets(
        'keeps a failed photo removable without a decoding exception',
        (
          tester,
        ) async {
          await pumpPhoto(
            tester,
            StatusComposerPhoto(path: '/broken.png', bytes: Uint8List(0)),
          );
          expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
          expect(
            find.byKey(const Key('status-composer-remove-photo')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
