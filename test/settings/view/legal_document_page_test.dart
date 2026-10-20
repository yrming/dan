import 'package:dan/settings/view/legal_document_page.dart';
import 'package:dan/settings/view/markdown_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(LegalDocumentPage, () {
    testWidgets('renders the bundled user agreement Markdown', (tester) async {
      await tester.pumpApp(const LegalDocumentPage());
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownDocumentView), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('用户协议'), findsOneWidget);
      expect(find.text('「旦」用户协议'), findsOneWidget);
      expect(find.textContaining('title: 用户协议'), findsNothing);
      expect(find.textContaining('related:'), findsNothing);
    });

    testWidgets('renders the bundled privacy policy Markdown', (tester) async {
      await tester.pumpApp(const LegalDocumentPage(privacyPolicy: true));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownDocumentView), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.text('「旦」隐私政策'), findsOneWidget);
      expect(find.textContaining('title: 隐私政策'), findsNothing);
    });

    testWidgets('uses the active application theme for the document', (
      tester,
    ) async {
      await tester.pumpApp(
        const LegalDocumentPage(),
        themeMode: ThemeMode.dark,
      );
      expect(
        find.descendant(
          of: find.byType(MarkdownDocumentView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox && widget.color == const Color(0xFF0F0F0F),
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
