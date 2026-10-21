import 'package:dan/settings/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AboutPage, () {
    setUp(rootBundle.clear);

    group('renders', () {
      testWidgets('displays the complete bundled about Markdown', (
        tester,
      ) async {
        await tester.pumpApp(const AboutPage());
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 10),
        );

        expect(find.text('关于'), findsOneWidget);
        final source = await rootBundle.loadString('assets/about.md');
        expect(
          tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
          source.trim(),
        );
      });
    });
  });
}
