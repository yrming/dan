import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/moments_status_list_item.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../../helpers/helpers.dart';

void main() {
  group(MomentsStatusListItem, () {
    Future<void> pumpItem(
      WidgetTester tester, {
      String createdAt = '2026-07-28T12:30:00',
      String? previousCreatedAt,
      status_repository.StatusPhotoUrls? photo,
      VoidCallback? onStatusTap,
      VoidCallback? onPhotoTap,
      ThemeMode themeMode = ThemeMode.light,
      double fontSize = 16,
      double width = 390,
    }) async {
      await tester.pumpApp(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: MomentsStatusListItem(
                  status: _status.copyWith(
                    createdAt: createdAt,
                    photo: photo,
                  ),
                  previousCreatedAt: previousCreatedAt,
                  now: DateTime(2026, 10, 12),
                  onStatusTap: onStatusTap,
                  onPhotoTap: onPhotoTap,
                ),
              ),
            ),
          ),
        ),
        theme: AppTheme.light(
          appearance: AppearanceSettings(fontSize: fontSize),
        ),
        darkTheme: AppTheme.dark(
          appearance: AppearanceSettings(fontSize: fontSize),
        ),
        themeMode: themeMode,
      );
    }

    group('dates', () {
      testWidgets('shows the date without repeating the author', (
        tester,
      ) async {
        await pumpItem(tester);

        expect(find.bySemanticsLabel('7月28日'), findsOneWidget);
        expect(find.text(_status.text), findsOneWidget);
        expect(find.text(_status.author.name), findsNothing);
        expect(find.byType(UserAvatar), findsNothing);
        expect(find.text('12:30'), findsNothing);
        expect(find.byType(StatusActionButton), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == AppColors.danLight.groupedBackground,
          ),
          findsNothing,
        );
      });

      testWidgets('hides the date for consecutive messages on the same day', (
        tester,
      ) async {
        await pumpItem(tester, previousCreatedAt: '2026-07-28T18:30:00');

        expect(find.bySemanticsLabel('7月28日'), findsNothing);
        expect(find.text(_status.text), findsOneWidget);
      });

      testWidgets('shows the date when the month changes', (tester) async {
        await pumpItem(tester, previousCreatedAt: '2026-08-28T18:30:00');

        expect(find.bySemanticsLabel('7月28日'), findsOneWidget);
      });

      testWidgets('shows a year heading when entering an older year', (
        tester,
      ) async {
        await pumpItem(
          tester,
          createdAt: '2025-12-31T12:30:00',
          previousCreatedAt: '2026-01-01T12:30:00',
        );

        expect(find.text('2025年'), findsOneWidget);
        expect(find.bySemanticsLabel('12月31日'), findsOneWidget);
      });

      testWidgets(
        'shows the year when the first message is from an older year',
        (tester) async {
          await pumpItem(tester, createdAt: '2025-07-28T12:30:00');

          expect(find.text('2025年'), findsOneWidget);
        },
      );

      testWidgets('does not repeat a year heading within the same year', (
        tester,
      ) async {
        await pumpItem(
          tester,
          createdAt: '2025-07-28T12:30:00',
          previousCreatedAt: '2025-07-29T12:30:00',
        );

        expect(find.text('2025年'), findsNothing);
        expect(find.bySemanticsLabel('7月28日'), findsOneWidget);
      });

      for (final (timestamp, label) in [
        ('2026-10-12T00:00:00', '今天'),
        ('2026-10-11T23:59:00', '昨天'),
      ]) {
        testWidgets('labels $label by calendar day', (tester) async {
          await pumpItem(tester, createdAt: timestamp);

          expect(find.text(label), findsOneWidget);
        });
      }

      testWidgets('preserves an unrecognized timestamp without crashing', (
        tester,
      ) async {
        await pumpItem(tester, createdAt: 'unknown date');

        expect(find.text('unknown date'), findsOneWidget);
        expect(find.text(_status.text), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('interactions', () {
      testWidgets('opens the status from the date and empty row areas', (
        tester,
      ) async {
        var taps = 0;
        await pumpItem(tester, onStatusTap: () => taps++);

        await tester.tap(find.text('07月'));
        await tester.pump();
        await tester.tap(find.text('28'));
        await tester.pump();
        final row = tester.getRect(find.byType(MomentsStatusListItem));
        for (final point in [
          row.topLeft + const Offset(2, 2),
          row.topRight + const Offset(-2, 2),
          row.bottomLeft + const Offset(2, -2),
          row.bottomRight + const Offset(-2, -2),
          Offset(row.right - 20, row.center.dy),
        ]) {
          await tester.tapAt(point);
          await tester.pump();
        }

        expect(taps, 7);
      });

      testWidgets(
        'opens the status from the empty date column on the same day',
        (tester) async {
          var taps = 0;
          await pumpItem(
            tester,
            previousCreatedAt: '2026-07-28T18:30:00',
            onStatusTap: () => taps++,
          );

          final row = tester.getRect(find.byType(MomentsStatusListItem));
          await tester.tapAt(Offset(row.left + 30, row.center.dy));
          await tester.pump();

          expect(taps, 1);
        },
      );

      testWidgets('opens the status from its text', (
        tester,
      ) async {
        var taps = 0;
        await pumpItem(tester, onStatusTap: () => taps++);

        await tester.tap(find.text(_status.text));
        await tester.pump();

        expect(taps, 1);
      });

      testWidgets(
        'opens the photo independently of status detail',
        (
          tester,
        ) async {
          var statusTaps = 0;
          var photoTaps = 0;
          await pumpItem(
            tester,
            photo: _photo,
            onStatusTap: () => statusTaps++,
            onPhotoTap: () => photoTaps++,
          );

          await tester.tap(find.byType(StatusPhoto));
          await tester.pump();

          expect(photoTaps, 1);
          expect(statusTaps, 0);
        },
      );
    });

    group('responsive rendering', () {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('fits a narrow screen with large text in $mode', (
          tester,
        ) async {
          await pumpItem(
            tester,
            photo: _photo,
            themeMode: mode,
            width: 320,
            fontSize: AppearanceSettings.maximumFontSize,
          );

          expect(find.byType(StatusPhoto), findsOneWidget);
          expect(find.text(_status.text), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}

const _status = status_repository.Status(
  id: 'status-a',
  text: '今天的风很舒服，想出去走走。',
  createdAt: '2026-07-28T12:30:00',
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
);

const _photo = status_repository.StatusPhotoUrls(
  largeUrl: 'https://example.com/moments-photo.png',
);
