import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('showAppActionSheet', () {
    testWidgets('covers the bottom navigation bar from a nested navigator', (
      tester,
    ) async {
      const bottomNavigationBarKey = Key('bottom-navigation-bar');
      const sheetKey = Key('action-sheet');

      await tester.pumpApp(
        Scaffold(
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showAppActionSheet(
                    context,
                    sheetKey: sheetKey,
                    groups: [
                      AppActionSheetGroup(
                        children: const [
                          AppActionSheetItem(
                            label: '回复',
                            icon: Icons.reply,
                          ),
                        ],
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          bottomNavigationBar: const SizedBox(
            key: bottomNavigationBarKey,
            height: 80,
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final bottomNavigationBarRect = tester.getRect(
        find.byKey(bottomNavigationBarKey),
      );
      final sheetRect = tester.getRect(find.byKey(sheetKey));
      final modalBarrierRect = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is ModalBarrier && widget.dismissible,
        ),
      );

      expect(sheetRect.bottom, greaterThan(bottomNavigationBarRect.top));
      expect(modalBarrierRect.overlaps(bottomNavigationBarRect), isTrue);
    });
  });
}
