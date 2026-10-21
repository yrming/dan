import 'package:dan/settings/view/markdown_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(MarkdownDocumentView, () {
    // Keep cached asset futures from crossing widget test async scopes.
    setUp(rootBundle.clear);

    testWidgets('parses headings, emphasis, lists, and links', (tester) async {
      await tester.pumpApp(
        const MarkdownDocumentView(
          title: 'Markdown',
          assetPath: 'assets/user-agreement.md',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('一、协议范围与服务性质'), findsOneWidget);
      expect(find.text('饭否用户协议'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        find.text(
          '版本：1.0\n'
          '生效日期：2026 年 9 月 25 日\n'
          '最后更新日期：2026 年 9 月 25 日\n'
          '运营主体：YRM',
        ),
        findsOneWidget,
      );

      // Reflow the same loaded document on a narrow phone and verify that
      // the final section remains reachable without layout errors.
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -20000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('联系邮箱：dan@yrm.dev').hitTestable(), findsOneWidget);
    });

    group('email links', () {
      for (final asset in ['user-agreement', 'privacy-policy']) {
        testWidgets('opens the system mail app from $asset', (tester) async {
          const channel = MethodChannel('plugins.flutter.io/url_launcher');
          final calls = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              calls.add(call);
              return true;
            },
          );
          addTearDown(
            () =>
                tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                  channel,
                  null,
                ),
          );

          rootBundle.evict('assets/$asset.md');
          await tester.pumpApp(
            MarkdownDocumentView(
              title: 'Markdown',
              assetPath: 'assets/$asset.md',
            ),
          );
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -20000),
          );
          await tester.pumpAndSettle();
          final editable = tester.state<EditableTextState>(
            find.text('联系邮箱：dan@yrm.dev'),
          );
          final box = editable.renderEditable
              .getBoxesForSelection(
                const TextSelection(baseOffset: 5, extentOffset: 16),
              )
              .first;
          await tester.tapAt(
            editable.renderEditable.localToGlobal(box.toRect().center),
          );
          await tester.pump();

          expect(calls, hasLength(1));
          expect(calls.single.method, 'launch');
          expect(
            calls.single.arguments,
            containsPair('url', 'mailto:dan@yrm.dev'),
          );
          expect(calls.single.arguments, containsPair('useSafariVC', false));
          expect(calls.single.arguments, containsPair('useWebView', false));
        });
      }
    });

    testWidgets('shows retry when the Markdown asset cannot be loaded', (
      tester,
    ) async {
      await tester.pumpApp(
        const MarkdownDocumentView(
          title: 'Missing document',
          assetPath: 'assets/missing.md',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('很抱歉，出错了，请重试。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });
  });
}
