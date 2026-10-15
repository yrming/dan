import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFanfouTimestamp', () {
    test('formats minutes ago without spacing', () {
      final source = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toIso8601String();
      expect(formatFanfouTimestamp(source), '5分钟前');
    });

    test('formats hours ago without spacing', () {
      final source = DateTime.now()
          .subtract(const Duration(hours: 3))
          .toIso8601String();
      expect(formatFanfouTimestamp(source), '3小时前');
    });

    test('formats a same-year date with digit-Chinese spacing', () {
      final now = DateTime.now();
      final created = DateTime(now.year, now.month, now.day).subtract(
        const Duration(days: 10),
      );
      final source = created.toIso8601String();
      expect(
        formatFanfouTimestamp(source, compactCalendarDate: true),
        created.year == now.year
            ? '${created.month}月${created.day}日'
            : '${created.year}年${created.month}月${created.day}日',
      );

      if (created.year == now.year) {
        expect(
          formatFanfouTimestamp(source),
          '${created.month} 月 ${created.day} 日',
        );
      } else {
        expect(
          formatFanfouTimestamp(source),
          '${created.year} 年 ${created.month} 月 ${created.day} 日',
        );
      }
    });

    test('formats an earlier-year date with digit-Chinese spacing', () {
      final year = DateTime.now().year - 1;
      expect(
        formatFanfouTimestamp(
          DateTime(year, 1, 5).toIso8601String(),
          compactCalendarDate: true,
        ),
        '$year年1月5日',
      );
      expect(
        formatFanfouTimestamp(DateTime(year, 1, 5).toIso8601String()),
        '$year 年 1 月 5 日',
      );
    });

    test('returns the source unchanged when it cannot be parsed', () {
      expect(formatFanfouTimestamp('not a date'), 'not a date');
    });
  });

  group('formatFanfouCalendarDate', () {
    test('formats an ISO timestamp as an absolute date', () {
      expect(formatFanfouCalendarDate('2023-01-05T12:00:00'), '2023年1月5日');
    });

    test('formats a Twitter-style Fanfou timestamp', () {
      expect(
        formatFanfouCalendarDate('Wed Jan 04 12:00:00 +0000 2023'),
        '2023年1月4日',
      );
    });

    test('returns the source unchanged when it cannot be parsed', () {
      expect(formatFanfouCalendarDate('not a date'), 'not a date');
    });
  });

  group('formatFanfouDateTime', () {
    test('formats an ISO timestamp as an absolute date and time', () {
      final createdAt = DateTime(2023, 1, 5, 3, 4);
      expect(
        formatFanfouDateTime(createdAt.toIso8601String()),
        '2023年1月5日 03:04',
      );
    });

    test('formats a Twitter-style Fanfou timestamp', () {
      final createdAt = tryParseFanfouCreatedAt(
        'Wed Jan 04 12:03:00 +0000 2023',
      )!;
      expect(
        formatFanfouDateTime('Wed Jan 04 12:03:00 +0000 2023'),
        '${createdAt.year}年${createdAt.month}月${createdAt.day}日 '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}',
      );
    });

    test('returns the source unchanged when it cannot be parsed', () {
      expect(formatFanfouDateTime('not a date'), 'not a date');
    });
  });
}
