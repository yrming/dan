import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/widgets/x_status_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(XStatusPhoto, () {
    Future<
      ({
        Size requestedSize,
        BoxFit requestedFit,
        Alignment requestedAlignment,
        Finder frameFinder,
      })
    >
    pumpXStatusPhoto(
      WidgetTester tester, {
      required Size sourceImageSize,
      double contentWidth = 300,
    }) async {
      Size? requestedSize;
      BoxFit? requestedFit;
      Alignment? requestedAlignment;

      await tester.pumpApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: contentWidth,
            child: XStatusPhoto(
              sourceImageSize: sourceImageSize,
              backgroundColor: Colors.white,
              imageBuilder: (displaySize, fit, alignment) {
                requestedSize = displaySize;
                requestedFit = fit;
                requestedAlignment = alignment;
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),
        ),
      );

      return (
        requestedSize: requestedSize!,
        requestedFit: requestedFit!,
        requestedAlignment: requestedAlignment!,
        frameFinder: find.descendant(
          of: find.byType(XStatusPhoto),
          matching: find.byType(Container),
        ),
      );
    }

    testWidgets('fills the entire image area and preserves a standard image', (
      tester,
    ) async {
      final result = await pumpXStatusPhoto(
        tester,
        sourceImageSize: const Size(1200, 900),
        contentWidth: 500,
      );
      final frame = tester.widget<Container>(result.frameFinder);
      final decoration = frame.decoration! as BoxDecoration;
      final foregroundDecoration = frame.foregroundDecoration! as BoxDecoration;

      expect(result.requestedSize, const Size(500, 375));
      expect(result.requestedFit, BoxFit.fitWidth);
      expect(result.requestedAlignment, Alignment.center);
      expect(tester.getSize(result.frameFinder), const Size(500, 375));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(xStatusPhotoBorderRadius),
      );
      expect(decoration.border, isNull);
      expect(
        foregroundDecoration.borderRadius,
        BorderRadius.circular(xStatusPhotoBorderRadius),
      );
      final border = foregroundDecoration.border! as Border;
      expect(border.top.color, AppColors.danLight.divider);
      expect(border.top.width, 0.5);
    });

    testWidgets('uses the exact image-area width at smaller sizes', (
      tester,
    ) async {
      final result = await pumpXStatusPhoto(
        tester,
        sourceImageSize: const Size(1200, 900),
        contentWidth: 280,
      );

      expect(result.requestedSize, const Size(280, 210));
      expect(result.requestedFit, BoxFit.fitWidth);
    });

    testWidgets('center-crops an extra-wide image to 16 by 9', (tester) async {
      final result = await pumpXStatusPhoto(
        tester,
        sourceImageSize: const Size(2100, 900),
      );

      expect(result.requestedSize, const Size(300, 168.75));
      expect(result.requestedFit, BoxFit.cover);
      expect(result.requestedAlignment, Alignment.center);
    });

    testWidgets('top-crops an extra-tall image to 3 by 4', (tester) async {
      final result = await pumpXStatusPhoto(
        tester,
        sourceImageSize: const Size(900, 1600),
      );

      expect(result.requestedSize, const Size(300, 400));
      expect(result.requestedFit, BoxFit.cover);
      expect(result.requestedAlignment, Alignment.topCenter);
    });

    testWidgets('keeps both frame dimensions at least 100', (tester) async {
      final result = await pumpXStatusPhoto(
        tester,
        sourceImageSize: const Size(1600, 900),
        contentWidth: 100,
      );

      expect(result.requestedSize, const Size.square(100));
      expect(result.requestedFit, BoxFit.cover);
    });
  });
}
