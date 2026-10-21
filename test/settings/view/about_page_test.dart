import 'package:dan/app/app.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AboutPage, () {
    group('renders', () {
      testWidgets(
        'shows the app identity, version, copyright, and legal links',
        (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(320, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpApp(
            RepositoryProvider.value(
              value: const AppBuildInfo(version: '2.3.4', buildNumber: '56'),
              child: const AboutPage(),
            ),
          );
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 10),
          );
          final version = find.text('版本 2.3.4（Build 56）');
          final copyright = find.text('© 2026 YRM');
          expect(version.hitTestable(), findsOneWidget);
          expect(copyright.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(version).dy,
            greaterThan(tester.getBottomLeft(find.text('旦')).dy),
          );
          expect(
            tester.getTopLeft(copyright).dy,
            greaterThan(tester.getBottomLeft(version).dy),
          );
          expect(find.text('为什么').hitTestable(), findsOneWidget);
          expect(
            find.byKey(const Key('about-user-agreement-row')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('about-privacy-policy-row')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'omits the build label when the build number is unavailable',
        (
          tester,
        ) async {
          await tester.pumpApp(
            RepositoryProvider.value(
              value: const AppBuildInfo(version: '2.3.4'),
              child: const AboutPage(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('版本 2.3.4'), findsOneWidget);
          expect(find.textContaining('Build'), findsNothing);
          expect(find.text('© 2026 YRM'), findsOneWidget);
        },
      );

      testWidgets('omits the version when metadata is unavailable', (
        tester,
      ) async {
        await tester.pumpApp(const AboutPage());
        await tester.pumpAndSettle();

        expect(find.text('关于'), findsOneWidget);
        expect(find.text('© 2026 YRM'), findsOneWidget);
        expect(find.textContaining('版本 '), findsNothing);
      });
    });
  });
}
