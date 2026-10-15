import 'package:dan/status/widgets/status_list_item_tap_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StatusListItemTapTarget, () {
    testWidgets('calls onTap without displaying a Material ink response', (
      tester,
    ) async {
      var tapCount = 0;
      await tester.pumpApp(
        Material(
          child: StatusListItemTapTarget(
            onTap: () => tapCount++,
            child: const Text('Status'),
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));

      expect(
        inkWell.splashFactory ??
            Theme.of(tester.element(find.byType(InkWell))).splashFactory,
        NoSplash.splashFactory,
      );
      expect(
        inkWell.overlayColor?.resolve({WidgetState.pressed}),
        Colors.transparent,
      );

      await tester.tap(find.text('Status'));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('keeps interactive content exposed as a semantic button', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpApp(
        Material(
          child: StatusListItemTapTarget(
            onTap: () {},
            child: const Text('Status'),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.text('Status'));

      expect(semantics.flagsCollection.isButton, isTrue);
      semanticsHandle.dispose();
    });
  });
}
