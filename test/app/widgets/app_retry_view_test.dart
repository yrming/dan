import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppRetryView, () {
    for (final reverse in [false, true]) {
      for (final visible in [false, true]) {
        testWidgets(
          'reveals the complete footer only when visible: '
          '$visible, reverse: $reverse',
          (tester) async {
            final controller = ScrollController(
              initialScrollOffset: visible ? 350 : 0,
            );
            addTearDown(controller.dispose);
            await tester.pumpApp(
              Scaffold(
                body: SizedBox(
                  height: 300,
                  child: CustomScrollView(
                    controller: controller,
                    reverse: reverse,
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 600)),
                      SliverToBoxAdapter(
                        child: AppRetryView(
                          message: '很抱歉，出错了，请重试。',
                          revealOnDisplay: true,
                          onRetry: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pump();
            if (visible) {
              final viewport = tester.getRect(find.byType(CustomScrollView));
              final footer = tester.getRect(find.byType(AppRetryView));
              expect(footer.top, greaterThanOrEqualTo(viewport.top - 0.01));
              expect(footer.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
              final message = tester.getRect(
                find.text('很抱歉，出错了，请重试。'),
              );
              final button = tester.getRect(find.byType(FilledButton));
              expect(
                message.top - footer.top,
                closeTo(footer.bottom - button.bottom, 0.01),
              );
            } else {
              expect(controller.offset, 0);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('uses a custom message and keeps the retry action', (
      tester,
    ) async {
      const customMessage = '照片加载失败，请重试。';
      var retries = 0;
      await tester.pumpApp(
        Scaffold(
          body: AppRetryView(
            message: customMessage,
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.text(customMessage), findsOneWidget);
      expect(find.text('很抱歉，出错了，请重试。'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, '重试'));
      await tester.pump();
      expect(retries, 1);
    });

    for (final dark in [false, true]) {
      testWidgets(
        'shows the message above a working retry button, dark=$dark',
        (
          tester,
        ) async {
          var retries = 0;
          await tester.pumpApp(
            Scaffold(body: AppRetryView(onRetry: () => retries++)),
            theme: dark ? AppTheme.dark() : AppTheme.light(),
          );
          final message = find.text('很抱歉，出错了，请重试。');
          final button = find.widgetWithText(FilledButton, '重试');
          expect(message, findsOneWidget);
          expect(button, findsOneWidget);
          expect(
            tester.getBottomLeft(message).dy,
            lessThan(tester.getTopLeft(button).dy),
          );
          await tester.tap(button);
          expect(retries, 1);
        },
      );
    }
  });
}
