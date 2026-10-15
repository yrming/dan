import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/widgets/status_detail_skeleton.dart';
import 'package:dan/status/widgets/status_list_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StatusDetailSkeleton, () {
    group('loading regions', () {
      for (final dark in [false, true]) {
        testWidgets('announces both regions with reduced motion, dark=$dark', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await tester.pumpApp(
            const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: StatusDetailSkeleton(
                  semanticLabel: '正在加载动态详情',
                  contextSemanticLabel: '正在加载上下文',
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

          expect(find.bySemanticsLabel('正在加载动态详情'), findsOneWidget);
          expect(find.bySemanticsLabel('正在加载上下文'), findsOneWidget);
          expect(find.byType(ShaderMask), findsNothing);
          expect(tester.binding.hasScheduledFrame, isFalse);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('shows original and context shimmer in a narrow viewport', (
        tester,
      ) async {
        await tester.pumpApp(
          const Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: StatusDetailSkeleton(
                  semanticLabel: '正在加载动态详情',
                  contextSemanticLabel: '正在加载上下文',
                ),
              ),
            ),
          ),
        );

        expect(find.byType(StatusListSkeleton), findsOneWidget);
        expect(find.byType(ShaderMask), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    });
  });
}
