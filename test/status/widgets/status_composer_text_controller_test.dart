import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/models/status_text.dart';
import 'package:dan/status/widgets/status_composer_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StatusComposerTextController, () {
    late StatusComposerTextController controller;

    setUp(() {
      final parts = [
        const StatusTextPart(text: ' '),
        ...parseStatusHtml(
          '@<a href="https://fanfou.com/id">饭友 A</a> '
          '<a href="https://example.com/">网页</a> '
          '#<a href="/q/topic">话题</a>#',
        ),
      ];
      controller = StatusComposerTextController(
        text: parts.map((part) => part.text).join(),
        parts: parts,
        cursorAtStart: true,
      );
    });

    tearDown(() => controller.dispose());

    group('activeMention', () {
      test('finds the current token including text after the caret', () {
        controller.value = const TextEditingValue(
          text: '前文 @饭友 后文',
          selection: TextSelection.collapsed(offset: 5),
        );
        expect(controller.activeMention, const TextRange(start: 3, end: 6));
      });
      test('does not suggest during IME composition or selected text', () {
        controller.value = const TextEditingValue(
          text: '@饭',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        );
        expect(controller.activeMention, isNull);
        controller.value = const TextEditingValue(
          text: '@饭',
          selection: TextSelection(baseOffset: 0, extentOffset: 2),
        );
        expect(controller.activeMention, isNull);
      });
    });

    group('insertMention', () {
      test('inserts at the cursor and preserves the trailing text', () {
        controller
          ..text = '你好世界'
          ..insertMention(
            '饭友',
            selection: const TextSelection.collapsed(offset: 2),
          );
        expect(controller.text, '你好 @饭友 世界');
        expect(controller.selection.baseOffset, 7);
      });
      test('replaces selected text and clears the composing range', () {
        controller
          ..text = '你好世界'
          ..insertMention(
            '饭友 A',
            selection: const TextSelection(baseOffset: 0, extentOffset: 2),
          );
        expect(controller.text, '@饭友 A 世界');
        expect(controller.value.composing, TextRange.empty);
      });
      test('appends if no selection is available', () {
        controller
          ..text = ''
          ..insertMention(
            '饭友',
            selection: const TextSelection.collapsed(offset: -1),
          );
        expect(controller.text, '@饭友 ');
      });
    });

    group('startHashtag', () {
      test(
        'inserts hashes at the cursor and places the caret between them',
        () {
          controller
            ..text = '你好世界'
            ..selection = const TextSelection.collapsed(offset: 2)
            ..startHashtag();
          expect(controller.text, '你好##世界');
          expect(
            controller.selection,
            const TextSelection.collapsed(offset: 3),
          );
        },
      );

      test(
        'replaces selected text and places the caret between the hashes',
        () {
          controller
            ..text = '你好世界'
            ..selection = const TextSelection(baseOffset: 1, extentOffset: 3)
            ..startHashtag();
          expect(controller.text, '你##界');
          expect(
            controller.selection,
            const TextSelection.collapsed(offset: 2),
          );
        },
      );
    });

    Future<void> pumpEditor(WidgetTester tester, {ThemeData? theme}) {
      return tester.pumpApp(
        Scaffold(body: TextField(controller: controller)),
        theme: theme,
        themeMode: ThemeMode.light,
      );
    }

    List<TextSpan> spans(WidgetTester tester, {bool withComposing = true}) {
      return controller
          .buildTextSpan(
            context: tester.element(find.byType(TextField)),
            withComposing: withComposing,
          )
          .children!
          .cast<TextSpan>();
    }

    String highlightedText(WidgetTester tester) {
      final color = tester
          .element(find.byType(TextField))
          .appColors
          .wechatLinkText;
      return spans(tester)
          .where((span) => span.style?.color == color)
          .map((span) => span.text)
          .join();
    }

    group('editing', () {
      for (final dark in [false, true]) {
        testWidgets(
          'preserves source highlights after prepending, dark=$dark',
          (
            tester,
          ) async {
            await pumpEditor(
              tester,
              theme: dark ? AppTheme.dark() : AppTheme.light(),
            );
            const prefix = '我的评论😀';
            controller.value = TextEditingValue(
              text: '$prefix${controller.text}',
              selection: const TextSelection.collapsed(offset: prefix.length),
            );
            await tester.pump();

            expect(highlightedText(tester), '@饭友 A网页#话题#');
            expect(controller.selection.baseOffset, prefix.length);
            expect(
              spans(tester).map((span) => span.text).join(),
              controller.text,
            );
          },
        );
      }

      testWidgets('highlights newly typed mentions, URLs and topics', (
        tester,
      ) async {
        await pumpEditor(tester);
        await tester.enterText(
          find.byType(TextField),
          '你好 @小明 https://example.com/?a=1&b=2 #新话题# 普通文字',
        );
        await tester.pump();

        expect(highlightedText(tester), '@小明https://example.com/?a=1&b=2#新话题#');
      });

      testWidgets('removes source highlighting when a link label is edited', (
        tester,
      ) async {
        await pumpEditor(tester);
        final old = controller.text;
        controller.value = TextEditingValue(
          text: old.replaceFirst('网页', '普通文字'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        await tester.pump();

        expect(highlightedText(tester), '@饭友 A#话题#');
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        expect(highlightedText(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    });

    group('composing', () {
      testWidgets('preserves IME underlines across highlighted boundaries', (
        tester,
      ) async {
        await pumpEditor(tester);
        controller.value = controller.value.copyWith(
          composing: const TextRange(start: 0, end: 7),
        );
        await tester.pump();

        expect(highlightedText(tester), '@饭友 A网页#话题#');
        expect(
          spans(tester)
              .where(
                (span) => span.style?.decoration == TextDecoration.underline,
              )
              .map((span) => span.text)
              .join(),
          controller.text.substring(0, 7),
        );
        expect(
          spans(tester, withComposing: false).any(
            (span) => span.style?.decoration == TextDecoration.underline,
          ),
          isFalse,
        );
        controller.value = controller.value.copyWith(
          composing: TextRange.empty,
        );
        expect(
          spans(tester).any(
            (span) => span.style?.decoration == TextDecoration.underline,
          ),
          isFalse,
        );
      });
    });
  });
}
