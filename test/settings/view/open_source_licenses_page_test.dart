import 'package:dan/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(OpenSourceLicensesPage, () {
    setUp(() {
      LicenseRegistry.reset();
      LicenseRegistry.addLicense(
        () => Stream.value(
          const LicenseEntryWithLineBreaks(
            ['example_package'],
            'Example open-source license text.',
          ),
        ),
      );
    });

    tearDown(LicenseRegistry.reset);

    testWidgets('lists bundled packages and opens their license text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpApp(const OpenSourceLicensesPage());
      await tester.pumpAndSettle();

      expect(find.text('旦'), findsOneWidget);
      expect(find.text('example_package'), findsOneWidget);
      await tester.tap(find.text('example_package'));
      await tester.pumpAndSettle();
      expect(find.text('Example open-source license text.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('example_package'), findsOneWidget);
    });
  });
}
