import 'package:dan/app/theme/theme.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(FollowListSkeleton, () {
    for (final dark in [false, true]) {
      testWidgets('supports disabled animations with dark=$dark', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpApp(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: FollowListSkeleton(
                semanticLabel: '正在加载用户列表',
              ),
            ),
          ),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(find.bySemanticsLabel('正在加载用户列表'), findsOneWidget);
        expect(find.byType(ShaderMask), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
        semantics.dispose();
      });
    }
    testWidgets('renders a single footer row in a narrow viewport', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: FollowListSkeleton(
                semanticLabel: '正在加载更多用户',
                itemCount: 1,
                shrinkWrap: true,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
