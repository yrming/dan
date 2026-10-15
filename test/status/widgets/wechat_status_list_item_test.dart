import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_list_item_tap_target.dart';
import 'package:dan/status/widgets/wechat_status_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../../helpers/helpers.dart';

void main() {
  group(WeChatStatusListItem, () {
    group('action hit target', () {
      for (final fontSize in [12.0, 16.0, 20.0]) {
        for (final direction in TextDirection.values) {
          for (final textScale in [1.0, 2.0]) {
            testWidgets(
              'keeps the last dot 16 from the edge and handles target taps '
              'at $fontSize in $direction with text scale $textScale',
              (tester) async {
                var actionTapCount = 0;
                var statusTapCount = 0;
                await tester.pumpApp(
                  Scaffold(
                    body: Directionality(
                      textDirection: direction,
                      child: MediaQuery(
                        data: MediaQueryData(
                          textScaler: TextScaler.linear(textScale),
                        ),
                        child: Column(
                          children: [
                            WeChatStatusListItem(
                              status: _status,
                              authorName: _status.author.name,
                              onAuthorTap: null,
                              onStatusTap: () => statusTapCount++,
                              onActionTap: () => actionTapCount++,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  theme: AppTheme.light(
                    appearance: AppearanceSettings(fontSize: fontSize),
                  ),
                  themeMode: ThemeMode.light,
                );

                final button = find.byType(StatusActionButton);
                final target = find.byKey(
                  const Key('wechat-status-action-hit-target'),
                );
                final targetRect = tester.getRect(target);
                final itemRect = tester.getRect(
                  find.byType(WeChatStatusListItem),
                );
                final dots = find.descendant(
                  of: button,
                  matching: find.byType(DecoratedBox),
                );
                expect(targetRect.size, const Size.square(40));
                expect(
                  tester.getSize(button),
                  Size(17 * fontSize / 16, 3 * fontSize / 16),
                );
                final metadataRow = find
                    .ancestor(
                      of: button,
                      matching: find.byType(Row),
                    )
                    .first;
                expect(
                  tester.getSize(metadataRow).height,
                  tester.getSize(find.textContaining('7月28日')).height,
                );
                final lastDotRect = tester.getRect(dots.last);
                final trailingInset = direction == TextDirection.ltr
                    ? itemRect.right - lastDotRect.right
                    : lastDotRect.left - itemRect.left;
                expect(trailingInset, 16);
                expect(targetRect.center, tester.getCenter(dots.at(1)));

                final points = [
                  lastDotRect.center,
                  targetRect.center,
                  targetRect.topLeft + const Offset(1, 1),
                  targetRect.topRight + const Offset(-1, 1),
                  targetRect.bottomLeft + const Offset(1, -1),
                  targetRect.bottomRight - const Offset(1, 1),
                ];
                for (final point in points) {
                  await tester.tapAt(point);
                  await tester.pump();
                }
                expect(actionTapCount, points.length);
                expect(statusTapCount, 0);

                await tester.tap(find.text(_status.text));
                await tester.pump();
                expect(statusTapCount, 1);
                expect(actionTapCount, points.length);
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    });

    testWidgets(
      'displays WeChat metadata and calls onStatusTap from the body',
      (tester) async {
        var tapCount = 0;
        var authorTapCount = 0;
        var actionTapCount = 0;
        await tester.pumpApp(
          WeChatStatusListItem(
            status: _status,
            authorName: _status.author.name,
            onAuthorTap: () => authorTapCount++,
            onStatusTap: () => tapCount++,
            onActionTap: () => actionTapCount++,
          ),
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
        );

        expect(find.text(_status.author.name), findsOneWidget);
        expect(
          find.textContaining('@${_status.author.screenName}'),
          findsNothing,
        );
        expect(find.textContaining('7月28日'), findsOneWidget);
        expect(find.byType(StatusActionButton), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz), findsNothing);
        final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(avatar.size, 44);
        expect(avatar.borderRadius, isNull);
        expect(avatar.borderColor, AppColors.danLight.divider);
        expect(avatar.borderWidth, 0.5);
        final avatarContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(Container),
          ),
        );
        final avatarDecoration =
            avatarContainer.foregroundDecoration! as BoxDecoration;
        final avatarBorder = avatarDecoration.border! as Border;
        expect(avatarDecoration.shape, BoxShape.circle);
        expect(avatarBorder.top.color, AppColors.danLight.divider);
        expect(avatarBorder.top.width, 0.5);
        expect(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(ClipOval),
          ),
          findsOneWidget,
        );

        final author = tester.widget<Text>(find.text(_status.author.name));
        expect(author.style?.color, AppColors.danLight.textBase);
        expect(author.style?.height, 1);
        expect(author.textHeightBehavior, isNull);

        await tester.tap(find.byType(StatusListItemTapTarget).at(1));
        await tester.pump();

        expect(authorTapCount, 1);
        expect(tapCount, 0);

        await tester.tap(find.text(_status.author.name));
        await tester.pump();

        expect(authorTapCount, 2);
        expect(tapCount, 0);

        await tester.tap(find.text(_status.text));
        await tester.pump();

        expect(tapCount, 1);

        await tester.tap(find.textContaining('7月28日'));
        await tester.pump();

        expect(tapCount, 2);

        await tester.tap(find.byType(StatusActionButton));
        await tester.pump();

        expect(actionTapCount, 1);
        expect(tapCount, 2);
        expect(
          tester.getSize(find.byType(StatusActionButton)),
          const Size(17, 3),
        );
        final actionHitTarget = find.byKey(
          const Key('wechat-status-action-hit-target'),
        );
        expect(
          tester.getSize(actionHitTarget),
          const Size.square(statusActionButtonHitTargetSize),
        );
        final actionHitTargetRect = tester.getRect(actionHitTarget);
        await tester.tapAt(
          actionHitTargetRect.topLeft + const Offset(2, 2),
        );
        await tester.pump();
        expect(actionTapCount, 2);
        final tooltip = MaterialLocalizations.of(
          tester.element(find.byType(StatusActionButton)),
        ).moreButtonTooltip;
        final semantics = tester.getSemantics(find.byTooltip(tooltip));
        expect(semantics.label, tooltip);
        expect(semantics.flagsCollection.isButton, isTrue);
      },
    );

    testWidgets(
      'colors mentions, hashtags, and links with the WeChat link color',
      (tester) async {
        const status = status_repository.Status(
          id: 'status-links',
          text:
              '你好 @<a href="https://fanfou.com/user-a">user_a</a>，一起看 #<a href="/q/Flutter">Flutter开发</a>#、<a href="https://example.com/docs?q=flutter#section">文档</a>。',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          author: _statusAuthor,
        );
        await tester.pumpApp(
          WeChatStatusListItem(
            status: status,
            authorName: status.author.name,
            onAuthorTap: null,
            onStatusTap: null,
          ),
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
        );

        final body = tester.widget<Text>(
          find.descendant(
            of: find.byType(StatusBodyText),
            matching: find.byType(Text),
          ),
        );
        final textSpan = body.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final linkSpans = spans.where(
          (span) => span.style?.color == AppColors.danLight.wechatLinkText,
        );

        expect(
          linkSpans.map((span) => span.text),
          [
            '@user_a',
            '#Flutter开发#',
            '文档',
          ],
        );
        expect(textSpan.style?.color, AppColors.danLight.textBase);
        expect(spans.any((span) => span.text == '。'), isTrue);
      },
    );

    testWidgets(
      'displays ten-pixel spacing when text is empty',
      (tester) async {
        const status = status_repository.Status(
          id: 'status-empty',
          text: '',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          author: _statusAuthor,
        );
        await tester.pumpApp(
          WeChatStatusListItem(
            status: status,
            authorName: status.author.name,
            onAuthorTap: null,
            onStatusTap: null,
          ),
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
        );

        expect(find.byType(StatusBodyText), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.height == 6,
          ),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.height == 10,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'appends the status source after the timestamp when showSource is set',
      (tester) async {
        const status = status_repository.Status(
          id: 'status-source',
          text: 'hello',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          author: _statusAuthor,
          source: '旦',
        );
        await tester.pumpApp(
          WeChatStatusListItem(
            status: status,
            authorName: status.author.name,
            onAuthorTap: null,
            onStatusTap: null,
            showSource: true,
          ),
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
        );

        expect(find.textContaining('7月28日 · 旦'), findsOneWidget);
      },
    );

    testWidgets(
      'hides the status source by default and when it is absent',
      (tester) async {
        await tester.pumpApp(
          WeChatStatusListItem(
            status: _status,
            authorName: _status.author.name,
            onAuthorTap: null,
            onStatusTap: null,
          ),
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
        );

        expect(find.textContaining('·'), findsNothing);
      },
    );

    testWidgets(
      'uses distinct author and mention colors in dark mode',
      (
        tester,
      ) async {
        const status = status_repository.Status(
          id: 'status-dark-link',
          text: '@<a href="https://fanfou.com/user-a">user_a</a>',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          author: _statusAuthor,
        );
        await tester.pumpApp(
          WeChatStatusListItem(
            status: status,
            authorName: status.author.name,
            onAuthorTap: null,
            onStatusTap: null,
          ),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
        );

        final author = tester.widget<Text>(find.text(status.author.name));
        final body = tester.widget<Text>(
          find.descendant(
            of: find.byType(StatusBodyText),
            matching: find.byType(Text),
          ),
        );
        final textSpan = body.textSpan! as TextSpan;
        final mentionSpan = textSpan.children!.cast<TextSpan>().singleWhere(
          (span) => span.text == '@user_a',
        );
        final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));

        expect(author.style?.color, AppColors.danDark.textBase);
        expect(mentionSpan.style?.color, AppColors.danDark.wechatLinkText);
        expect(avatar.borderColor, AppColors.danDark.divider);
        expect(avatar.borderWidth, 0.5);
      },
    );
  });
}

const _status = status_repository.Status(
  id: 'status-a',
  text: 'hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: _statusAuthor,
);

const _statusAuthor = status_repository.StatusAuthor(
  id: 'user-a',
  name: 'User A',
  screenName: 'user_a',
);
