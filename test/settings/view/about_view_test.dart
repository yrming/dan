import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/app.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AboutView, () {
    group('bottom image', () {
      testWidgets(
        'reveals the image while pulling past the bottom',
        (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(320, 480));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpApp(
            AboutView(
              buildInfo: const AppBuildInfo(
                version: '2.3.4',
                buildNumber: '56',
              ),
              onStoryPressed: () {},
              onUserAgreementPressed: () {},
              onPrivacyPolicyPressed: () {},
            ),
          );
          await tester.pumpAndSettle();

          final image = find.byKey(const Key('about-bottom-image'));
          final scrollView = find.byType(SingleChildScrollView);
          final viewport = tester.getRect(scrollView);
          expect(tester.getTopLeft(image).dy, greaterThan(viewport.bottom));
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable))
                .position
                .maxScrollExtent,
            greaterThan(0),
          );

          await tester.ensureVisible(find.text('© 2026 YRM'));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(image).dy, greaterThan(viewport.bottom));

          final gesture = await tester.startGesture(viewport.center);
          for (var i = 0; i < 10; i++) {
            await gesture.moveBy(const Offset(0, -40));
            await tester.pump();
          }

          final imageRect = tester.getRect(image);
          expect(imageRect.top, lessThan(viewport.bottom));
          expect(imageRect.left, viewport.left + AppSpacing.md);
          expect(imageRect.width, viewport.width - AppSpacing.md * 2);
          expect(imageRect.bottom, viewport.bottom - AppSpacing.md);

          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(image).dy, greaterThan(viewport.bottom));
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('document actions', () {
      testWidgets(
        'keeps all links reachable on a small screen with large text',
        (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(320, 480));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final opened = <String>[];
          await tester.pumpApp(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: AboutView(
                buildInfo: const AppBuildInfo(
                  version: '2.3.4',
                  buildNumber: '56',
                ),
                onStoryPressed: () => opened.add('why'),
                onUserAgreementPressed: () => opened.add('user-agreement'),
                onPrivacyPolicyPressed: () => opened.add('privacy-policy'),
              ),
            ),
            theme: AppTheme.dark(
              appearance: const AppearanceSettings(fontSize: 20),
            ),
          );
          await tester.pumpAndSettle();

          for (final document in [
            'why',
            'user-agreement',
            'privacy-policy',
          ]) {
            final link = find.byKey(Key('about-$document-row'));
            await tester.ensureVisible(link);
            await tester.pumpAndSettle();
            await tester.tap(link);
          }

          expect(opened, ['why', 'user-agreement', 'privacy-policy']);
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
