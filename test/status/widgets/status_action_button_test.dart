import 'package:dan/status/widgets/status_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StatusActionButton, () {
    group('hit target', () {
      testWidgets('centers a full target without enlarging the layout', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpApp(
          Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(100, 100, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: StatusActionButton(onPressed: () => taps++),
                  ),
                ),
                const SizedBox(height: 100, width: double.infinity),
              ],
            ),
          ),
        );

        final button = find.byType(StatusActionButton);
        final target = find.byKey(
          const Key('wechat-status-action-hit-target'),
        );
        final rect = tester.getRect(target);
        expect(tester.getSize(button), const Size(17, 3));
        expect(rect.size, const Size.square(40));
        expect(rect.center, tester.getCenter(button));
        for (final point in [
          rect.topLeft + const Offset(1, 1),
          rect.topRight + const Offset(-1, 1),
          rect.bottomLeft + const Offset(1, -1),
          rect.bottomRight - const Offset(1, 1),
        ]) {
          await tester.tapAt(point);
          await tester.pump();
        }
        expect(taps, 4);
      });

      testWidgets('scrolls from the target and follows the visible button', (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var taps = 0;
        await tester.pumpApp(
          Scaffold(
            body: SizedBox(
              height: 250,
              child: ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 150),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: StatusActionButton(onPressed: () => taps++),
                    ),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        );

        final target = find.byKey(
          const Key('wechat-status-action-hit-target'),
        );
        await tester.drag(target, const Offset(0, -50));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        expect(taps, 0);
        expect(
          tester.getCenter(target),
          tester.getCenter(find.byType(StatusActionButton)),
        );
        await tester.tap(target);
        await tester.pump();
        expect(taps, 1);

        controller.jumpTo(300);
        await tester.pump();
        expect(target, findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('lets taps pass through when disabled', (tester) async {
        var taps = 0;
        await tester.pumpApp(
          Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const Center(
                child: StatusActionButton(onPressed: null),
              ),
            ),
          ),
        );

        await tester.tapAt(
          tester.getCenter(find.byType(StatusActionButton)) +
              const Offset(10, 10),
        );
        await tester.pump();
        expect(taps, 1);
      });
    });
  });
}
