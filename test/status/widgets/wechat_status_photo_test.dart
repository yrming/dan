import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/widgets/wechat_status_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(WeChatStatusPhoto, () {
    testWidgets(
      'requests a bounded center-cropped image in a rounded divider frame',
      (tester) async {
        Size? requestedSize;
        BoxFit? requestedFit;
        Alignment? requestedAlignment;

        await tester.pumpApp(
          Align(
            alignment: Alignment.topLeft,
            child: WeChatStatusPhoto(
              sourceImageSize: const Size(1200, 900),
              backgroundColor: Colors.white,
              imageBuilder: (displaySize, fit, alignment) {
                requestedSize = displaySize;
                requestedFit = fit;
                requestedAlignment = alignment;
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),
        );

        final frameFinder = find.descendant(
          of: find.byType(WeChatStatusPhoto),
          matching: find.byType(Container),
        );
        final frame = tester.widget<Container>(frameFinder);
        final decoration = frame.decoration! as BoxDecoration;
        final foregroundDecoration =
            frame.foregroundDecoration! as BoxDecoration;

        expect(requestedSize, const Size(200, 150));
        expect(requestedFit, BoxFit.cover);
        expect(requestedAlignment, Alignment.center);
        expect(tester.getSize(frameFinder), const Size(200, 150));
        expect(frame.clipBehavior, Clip.antiAlias);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(8),
        );
        expect(decoration.border, isNull);
        expect(
          foregroundDecoration.borderRadius,
          BorderRadius.circular(8),
        );
        final border = foregroundDecoration.border! as Border;
        expect(border.top.color, AppColors.danLight.divider);
        expect(border.top.width, 0.5);
      },
    );

    group(wechatStatusPhotoDisplaySize, () {
      test('fits a landscape image proportionally inside 200 by 200', () {
        expect(
          wechatStatusPhotoDisplaySize(
            imageSize: const Size(1200, 900),
          ),
          const Size(200, 150),
        );
      });

      test('fits a portrait image proportionally inside 200 by 200', () {
        expect(
          wechatStatusPhotoDisplaySize(
            imageSize: const Size(900, 1200),
          ),
          const Size(150, 200),
        );
      });

      test('uses the 3 to 1 crop bound for an extra-wide image', () {
        expect(
          wechatStatusPhotoDisplaySize(
            imageSize: const Size(4000, 500),
          ),
          const Size(200, 70),
        );
      });

      test('uses the 1 to 3 crop bound for an extra-tall image', () {
        expect(
          wechatStatusPhotoDisplaySize(
            imageSize: const Size(500, 4000),
          ),
          const Size(70, 200),
        );
      });
    });
  });
}
