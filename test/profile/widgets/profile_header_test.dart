import 'package:dan/app/theme/theme.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';

import '../../helpers/helpers.dart';

void _noop() {}

void main() {
  group(ProfileHeader, () {
    testWidgets('keeps the header height when the follow action appears', (
      tester,
    ) async {
      Future<void> pumpHeader({String? label}) => tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeader(
              id: 'user-a',
              name: 'User A',
              screenName: 'user_a',
              friendsCount: 385,
              followersCount: 3042,
              followActionLabel: label,
              showFollowActionSkeleton: label == null,
              onFollowActionPressed: () {},
              onMessagePressed: () {},
            ),
          ),
        ),
      );

      await pumpHeader();
      final initialHeight = tester.getSize(find.byType(ProfileHeader)).height;
      for (final label in ['关注', '已关注', '互相关注']) {
        await pumpHeader(label: label);
        expect(find.text(label), findsOneWidget);
        expect(
          tester.getSize(find.byType(ProfileHeader)).height,
          initialHeight,
        );
      }
    });

    testWidgets('shows the follow action below the follow summary', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpApp(
        ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          avatarKey: const Key('avatar'),
          followActionLabel: '互相关注',
          onFollowActionPressed: () => pressed = true,
        ),
      );

      final action = find.byKey(const Key('user-profile-follow-action'));
      expect(action, findsOneWidget);
      expect(
        tester.getCenter(action).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.byKey(const Key('user-profile-follow-summary')),
              )
              .dy,
        ),
      );

      await tester.tap(action);
      expect(pressed, isTrue);
    });

    testWidgets('styles the message action with the base surface and text', (
      tester,
    ) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          followActionLabel: '关注',
          onFollowActionPressed: _noop,
          onMessagePressed: _noop,
        ),
      );

      final context = tester.element(find.byType(ProfileHeader));
      final messageButton = tester.widget<FilledButton>(
        find.byKey(const Key('user-profile-message-action')),
      );
      final followButton = tester.widget<FilledButton>(
        find.byKey(const Key('user-profile-follow-action')),
      );
      final style = messageButton.style!;
      final followTextStyle = followButton.style!.textStyle!.resolve({});
      final messageTextStyle = style.textStyle!.resolve({});
      final shape =
          style.shape?.resolve({}) ??
          Theme.of(context).filledButtonTheme.style!.shape!.resolve({});
      final side = style.side!.resolve({});

      expect(followButton.style?.backgroundColor, isNull);
      expect(followButton.style?.side, isNull);
      expect(followTextStyle!.fontSize, 16);
      expect(messageTextStyle!.fontSize, 16);
      expect(style.backgroundColor!.resolve({}), context.appColors.bgBase);
      expect(style.foregroundColor!.resolve({}), context.appColors.textBase);
      expect(side, BorderSide(color: context.appColors.divider, width: 0.5));
      expect(
        shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('user-profile-follow-action'))),
        tester.getSize(find.byKey(const Key('user-profile-message-action'))),
      );
      expect(
        tester
            .getRect(find.byKey(const Key('user-profile-message-action')))
            .left,
        closeTo(
          tester
                  .getRect(find.byKey(const Key('user-profile-follow-action')))
                  .right +
              10,
          0.000001,
        ),
      );
      expect(find.byIcon(RemixIcons.send_ins_line), findsOneWidget);
    });

    group('registration tooltip', () {
      testWidgets('shows elapsed whole days and crosses out the joke on tap', (
        tester,
      ) async {
        final registeredAt = DateTime.now().subtract(
          const Duration(days: 1234, hours: 12),
        );
        await tester.pumpApp(
          ProfileHeader(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
            registeredAt: registeredAt.toUtc().toIso8601String(),
          ),
        );
        final message = find.text('3700 多年');
        expect(message, findsNothing);

        await tester.tap(find.byKey(const Key('user-profile-registered-at')));
        await tester.pump(const Duration(milliseconds: 200));

        expect(message, findsOneWidget);
        final line = find.byKey(
          const Key('profile-registration-strikethrough'),
        );
        expect(tester.getCenter(line).dy, tester.getCenter(message).dy);
        expect(tester.getSize(line).width, tester.getSize(message).width);
        expect(
          find.textContaining('1234 天', findRichText: true),
          findsOneWidget,
        );

        await tester.tapAt(const Offset(750, 550));
        await tester.pump(const Duration(milliseconds: 200));

        expect(message, findsNothing);
      });

      for (final entry in {
        'less than a day ago': const Duration(hours: 12),
        'in the future': const Duration(days: -1),
      }.entries) {
        testWidgets('shows zero days when registered ${entry.key}', (
          tester,
        ) async {
          await tester.pumpApp(
            ProfileHeader(
              id: 'user-a',
              name: 'User A',
              screenName: 'user_a',
              registeredAt: DateTime.now()
                  .subtract(entry.value)
                  .toIso8601String(),
            ),
          );

          await tester.tap(find.byKey(const Key('user-profile-registered-at')));
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.textContaining('0 天', findRichText: true),
            findsOneWidget,
          );
        });
      }

      testWidgets('keeps an unparseable registration date without a tooltip', (
        tester,
      ) async {
        await tester.pumpApp(
          const ProfileHeader(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
            registeredAt: 'unknown',
          ),
        );

        await tester.tap(find.text('注册于unknown'));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('注册于unknown'), findsOneWidget);
        expect(find.byType(Tooltip), findsNothing);
      });
    });

    testWidgets('opens a valid HTTPS URL with the external launcher', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      Uri? launchedUri;
      await tester.pumpApp(
        ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          url: 'https://example.com/profile',
          externalLinkLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );
      final linkFinder = find.byKey(const Key('user-profile-url-link'));

      await tester.tap(linkFinder);
      await tester.pump();

      expect(launchedUri, Uri.parse('https://example.com/profile'));
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
      expect(tester.getSize(linkFinder).height, greaterThanOrEqualTo(24));
      expect(tester.getSemantics(linkFinder).flagsCollection.isLink, isTrue);
      semanticsHandle.dispose();
    });

    testWidgets(
      'shows the location and registration date as thin pill tags on one row',
      (tester) async {
        await tester.pumpApp(
          const ProfileHeader(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
            location: '上海',
            registeredAt: '2023-01-05T12:00:00',
            url: 'https://example.com/profile',
          ),
        );

        final locationFinder = find.byKey(const Key('user-profile-location'));
        final registeredFinder = find.byKey(
          const Key('user-profile-registered-at'),
        );
        expect(locationFinder, findsOneWidget);
        expect(registeredFinder, findsOneWidget);
        expect(find.text('上海'), findsOneWidget);
        expect(find.text('注册于2023年1月5日'), findsOneWidget);

        expect(
          tester.getTopLeft(registeredFinder).dy,
          tester.getTopLeft(locationFinder).dy,
        );
        expect(
          tester.getTopLeft(locationFinder).dx,
          closeTo(tester.getTopRight(registeredFinder).dx + 12, 0.000001),
        );
        expect(
          tester.getTopLeft(registeredFinder).dx,
          lessThan(tester.getTopLeft(locationFinder).dx),
        );

        for (final finder in [locationFinder, registeredFinder]) {
          final text = tester.widget<Text>(
            find.descendant(of: finder, matching: find.byType(Text)),
          );
          expect(text.style?.fontSize, 13);
          expect(text.style?.color, AppColors.danLight.textSecondary);

          final container = tester.widget<Container>(finder);
          final decoration = container.decoration! as BoxDecoration;
          expect(
            container.padding,
            const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
          );
          expect(decoration.borderRadius, BorderRadius.circular(45));
          final border = (decoration.border! as Border).top;
          expect(border.width, 0.5);
          expect(border.color, AppColors.danLight.divider);
        }
      },
    );

    for (final width in [320.0, 390.0]) {
      testWidgets('spaces wrapped profile tags 12 apart at width $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpApp(
          const Scaffold(
            body: SingleChildScrollView(
              child: ProfileHeader(
                id: 'user-a',
                name: 'User A',
                screenName: 'user_a',
                location: '海外 波斯尼亚和黑塞哥维那',
                registeredAt: '2008-07-04T12:00:00',
              ),
            ),
          ),
        );

        final registeredRect = tester.getRect(
          find.byKey(const Key('user-profile-registered-at')),
        );
        final locationRect = tester.getRect(
          find.byKey(const Key('user-profile-location')),
        );
        expect(
          locationRect.top - registeredRect.bottom,
          closeTo(12, 0.000001),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows the registration tag without a location', (
      tester,
    ) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          registeredAt: '2023-01-05T12:00:00',
        ),
      );

      expect(
        find.byKey(const Key('user-profile-registered-at')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('user-profile-location')), findsNothing);
    });

    testWidgets(
      'spaces description, URL, location, and follow summary 12 apart',
      (
        tester,
      ) async {
        await tester.pumpApp(
          const ProfileHeader(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
            description: '简介',
            url: 'https://example.com/profile',
            location: '上海',
            registeredAt: '2023-01-05T12:00:00',
          ),
        );

        double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
        double bottom(Key key) => tester.getBottomLeft(find.byKey(key)).dy;

        expect(
          top(const Key('user-profile-url-link')),
          closeTo(bottom(const Key('user-profile-description')) + 12, 0.000001),
        );
        expect(
          top(const Key('user-profile-location')),
          closeTo(bottom(const Key('user-profile-url-link')) + 12, 0.000001),
        );
        expect(
          top(const Key('user-profile-registered-at')),
          top(const Key('user-profile-location')),
        );
        expect(
          top(const Key('user-profile-follow-row')),
          closeTo(bottom(const Key('user-profile-location')) + 12, 0.000001),
        );
      },
    );

    testWidgets(
      'spaces the URL and follow summary 12 apart without a location',
      (
        tester,
      ) async {
        await tester.pumpApp(
          const ProfileHeader(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
            url: 'https://example.com/profile',
          ),
        );

        expect(
          tester
              .getTopLeft(find.byKey(const Key('user-profile-follow-row')))
              .dy,
          closeTo(
            tester
                    .getBottomLeft(
                      find.byKey(const Key('user-profile-url-link')),
                    )
                    .dy +
                12,
            0.000001,
          ),
        );
      },
    );

    testWidgets('hides the location when it is blank', (tester) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          location: '  ',
        ),
      );

      expect(find.byKey(const Key('user-profile-location')), findsNothing);
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
    });

    testWidgets('hides the registration tag when it is blank', (tester) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          registeredAt: '  ',
        ),
      );

      expect(
        find.byKey(const Key('user-profile-registered-at')),
        findsNothing,
      );
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
    });

    testWidgets('hides a URL with an unsupported scheme', (tester) async {
      await tester.pumpApp(
        ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          url: 'javascript:alert(1)',
          externalLinkLauncher: (_) async => true,
        ),
      );

      expect(find.byKey(const Key('user-profile-url')), findsNothing);
      expect(find.byKey(const Key('user-profile-url-link')), findsNothing);
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
    });

    testWidgets('shows follow requests when the active count is available', (
      tester,
    ) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          friendsCount: 8,
          followersCount: 12,
          friendRequestCount: 4,
        ),
      );

      expect(find.text('8 关注'), findsOneWidget);
      expect(find.text('12 粉丝'), findsOneWidget);
      expect(find.text('4 申请关注'), findsOneWidget);
    });

    testWidgets('hides follow requests when the active count is zero', (
      tester,
    ) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          friendsCount: 8,
          followersCount: 12,
          friendRequestCount: 0,
        ),
      );

      expect(find.text('8 关注'), findsOneWidget);
      expect(find.text('12 粉丝'), findsOneWidget);
      expect(find.text('0 申请关注'), findsNothing);
    });

    testWidgets('hides a URL without an HTTP scheme', (tester) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          url: 'www.example.com/profile',
        ),
      );

      expect(find.byKey(const Key('user-profile-url')), findsNothing);
      expect(find.byKey(const Key('user-profile-url-link')), findsNothing);
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
    });

    testWidgets('hides an HTTP URL without a domain suffix', (tester) async {
      await tester.pumpApp(
        const ProfileHeader(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
          url: 'http://bbbbbb',
        ),
      );

      expect(find.byKey(const Key('user-profile-url')), findsNothing);
      expect(find.byKey(const Key('user-profile-url-link')), findsNothing);
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
    });
  });
}
