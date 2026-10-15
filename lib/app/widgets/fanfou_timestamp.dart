/// Formats a Fanfou creation timestamp for display.
///
/// [compactCalendarDate] removes spacing around calendar date units.
String formatFanfouTimestamp(
  String source, {
  bool compactCalendarDate = false,
}) {
  final createdAt = tryParseFanfouCreatedAt(source);
  if (createdAt == null) return source;

  final difference = DateTime.now().difference(createdAt);
  if (difference.isNegative || difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}小时前';
  }
  if (difference.inDays < 2) {
    return '昨天';
  }

  final now = DateTime.now();
  if (createdAt.year == now.year) {
    return compactCalendarDate
        ? '${createdAt.month}月${createdAt.day}日'
        : '${createdAt.month} 月 ${createdAt.day} 日';
  }
  return compactCalendarDate
      ? '${createdAt.year}年${createdAt.month}月${createdAt.day}日'
      : '${createdAt.year} 年 ${createdAt.month} 月 ${createdAt.day} 日';
}

/// Formats a Fanfou creation timestamp for chat transcripts.
///
/// Mirrors the WeChat chat style: clock time for today, a `yesterday`
/// prefix for the previous day, and calendar dates beyond that.
String formatConversationTimestamp(String source) {
  final createdAt = tryParseFanfouCreatedAt(source);
  if (createdAt == null) return source;

  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final clockTime =
      '${twoDigits(createdAt.hour)}:${twoDigits(createdAt.minute)}';
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfThatDay = DateTime(
    createdAt.year,
    createdAt.month,
    createdAt.day,
  );
  final dayDifference = startOfToday.difference(startOfThatDay).inDays;

  if (dayDifference <= 0) return clockTime;
  if (dayDifference == 1) return '昨天 $clockTime';
  if (createdAt.year == now.year) {
    return '${createdAt.month}月${createdAt.day}日 $clockTime';
  }
  return '${createdAt.year}年${createdAt.month}月${createdAt.day}日 $clockTime';
}

/// Formats a Fanfou timestamp as an absolute calendar date, for example
/// `2023年1月5日`, for contexts that do not use relative time.
String formatFanfouCalendarDate(String source) {
  final createdAt = tryParseFanfouCreatedAt(source);
  if (createdAt == null) return source;
  return '${createdAt.year}年${createdAt.month}月${createdAt.day}日';
}

/// Formats a Fanfou timestamp as an absolute date and clock time.
String formatFanfouDateTime(String source) {
  final createdAt = tryParseFanfouCreatedAt(source);
  if (createdAt == null) return source;

  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${createdAt.year}年${createdAt.month}月${createdAt.day}日 '
      '${twoDigits(createdAt.hour)}:${twoDigits(createdAt.minute)}';
}

/// Parses a Fanfou creation timestamp, or returns `null` when unparseable.
DateTime? tryParseFanfouCreatedAt(String source) {
  final normalized = source.trim();
  if (normalized.isEmpty) return null;

  final isoDate = DateTime.tryParse(normalized);
  if (isoDate != null) return isoDate.toLocal();

  return _parseTwitterDate(normalized) ?? _parseRfc1123Date(normalized);
}

DateTime? _parseTwitterDate(String source) {
  final match = RegExp(
    r'^[A-Za-z]{3}\s+([A-Za-z]{3})\s+(\d{1,2})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT|UTC)\s+(\d{4})$',
  ).firstMatch(source);
  if (match == null) return null;

  return _dateTimeFromParts(
    year: match.group(7),
    monthName: match.group(1),
    day: match.group(2),
    hour: match.group(3),
    minute: match.group(4),
    second: match.group(5),
    timeZone: match.group(6),
  );
}

DateTime? _parseRfc1123Date(String source) {
  final match = RegExp(
    r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT|UTC)$',
  ).firstMatch(source);
  if (match == null) return null;

  return _dateTimeFromParts(
    year: match.group(3),
    monthName: match.group(2),
    day: match.group(1),
    hour: match.group(4),
    minute: match.group(5),
    second: match.group(6),
    timeZone: match.group(7),
  );
}

DateTime? _dateTimeFromParts({
  required String? year,
  required String? monthName,
  required String? day,
  required String? hour,
  required String? minute,
  required String? second,
  required String? timeZone,
}) {
  final month = _monthByName[monthName];
  final timeZoneOffset = _timeZoneOffset(timeZone);
  if (month == null || timeZoneOffset == null) return null;

  final parsedYear = int.tryParse(year ?? '');
  final parsedDay = int.tryParse(day ?? '');
  final parsedHour = int.tryParse(hour ?? '');
  final parsedMinute = int.tryParse(minute ?? '');
  final parsedSecond = int.tryParse(second ?? '');
  if (parsedYear == null ||
      parsedDay == null ||
      parsedHour == null ||
      parsedMinute == null ||
      parsedSecond == null) {
    return null;
  }

  return DateTime.utc(
    parsedYear,
    month,
    parsedDay,
    parsedHour,
    parsedMinute,
    parsedSecond,
  ).subtract(timeZoneOffset).toLocal();
}

Duration? _timeZoneOffset(String? source) {
  if (source == null || source == 'GMT' || source == 'UTC') {
    return Duration.zero;
  }

  final match = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(source);
  if (match == null) return null;

  final hours = int.tryParse(match.group(2)!);
  final minutes = int.tryParse(match.group(3)!);
  final offset = Duration(hours: hours ?? 0, minutes: minutes ?? 0);
  return match.group(1) == '-' ? -offset : offset;
}

const _monthByName = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};
