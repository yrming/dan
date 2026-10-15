import 'package:html/parser.dart' as html_parser;

/// Parses the visible text and entities in an API-formatted status.
List<StatusTextPart> parseStatusHtml(String source) {
  final parts = <StatusTextPart>[];
  var offset = 0;

  while (offset < source.length) {
    final entity = _nextStatusEntity(source, offset);
    if (entity == null) {
      _addPlainPart(parts, source.substring(offset));
      break;
    }
    if (entity.match.start > offset) {
      _addPlainPart(parts, source.substring(offset, entity.match.start));
    }

    final part = switch (entity.kind) {
      StatusTextPartKind.hashtag => StatusTextPart(
        text: '#${_decodeHtmlText(entity.match.namedGroup('tag')!)}#',
        kind: entity.kind,
      ),
      StatusTextPartKind.mention => StatusTextPart(
        text: '@${_decodeHtmlText(entity.match.namedGroup('at')!)}',
        kind: entity.kind,
        userId: _decodeHtmlText(entity.match.namedGroup('id')!),
      ),
      StatusTextPartKind.link => StatusTextPart(
        text: _decodeHtmlText(entity.match.namedGroup('text')!),
        kind: entity.kind,
        link: _decodeHtmlText(entity.match.namedGroup('link')!),
      ),
      StatusTextPartKind.plain => throw StateError(
        'Plain text is not an HTML entity.',
      ),
    };
    parts.add(part);
    offset = entity.match.end;
  }

  return List.unmodifiable(parts);
}

_StatusTextEntity? _nextStatusEntity(String source, int offset) {
  final entities = <_StatusTextEntity>[
    if (_firstMatchFrom(_tagPattern, source, offset) case final match?)
      _StatusTextEntity(
        match: match,
        kind: StatusTextPartKind.hashtag,
        priority: 0,
      ),
    if (_firstMatchFrom(_atPattern, source, offset) case final match?)
      _StatusTextEntity(
        match: match,
        kind: StatusTextPartKind.mention,
        priority: 1,
      ),
    if (_firstMatchFrom(_linkPattern, source, offset) case final match?)
      _StatusTextEntity(
        match: match,
        kind: StatusTextPartKind.link,
        priority: 2,
      ),
  ];
  if (entities.isEmpty) return null;
  entities.sort((first, second) {
    final byPosition = first.match.start.compareTo(second.match.start);
    return byPosition != 0
        ? byPosition
        : first.priority.compareTo(second.priority);
  });
  return entities.first;
}

RegExpMatch? _firstMatchFrom(RegExp pattern, String source, int offset) {
  final matches = pattern.allMatches(source, offset);
  return matches.isEmpty ? null : matches.first;
}

void _addPlainPart(List<StatusTextPart> parts, String source) {
  final text = _decodeHtmlText(source);
  if (text.isEmpty) return;
  parts.add(StatusTextPart(text: text));
}

String _decodeHtmlText(String source) {
  return html_parser.parseFragment(source).text ?? '';
}

/// Semantic entity types supported by status text.
enum StatusTextPartKind {
  /// Ordinary text.
  plain,

  /// A user mention.
  mention,

  /// A topic.
  hashtag,

  /// A web link.
  link,
}

/// One visible segment of a status, shared by display and editing.
class StatusTextPart {
  /// Creates a status text segment.
  const StatusTextPart({
    required this.text,
    this.kind = StatusTextPartKind.plain,
    this.userId,
    this.link,
  });

  /// Decoded visible text.
  final String text;

  /// Entity type used for highlighting.
  final StatusTextPartKind kind;

  /// Mentioned user's identifier, if available.
  final String? userId;

  /// Decoded destination of a link, if available.
  final String? link;
}

class _StatusTextEntity {
  const _StatusTextEntity({
    required this.match,
    required this.kind,
    required this.priority,
  });

  final RegExpMatch match;
  final StatusTextPartKind kind;
  final int priority;
}

final _tagPattern = RegExp(
  r'#<a href="/q/(?<link>.*?)".?>(?<tag>[\s\S]*?)</a>#',
  caseSensitive: false,
);

final _atPattern = RegExp(
  r'@<a href="(?:http|https)://[\d\-.a-z]*fanfou.com/(?<id>[^"]*)"[^>]*>(?<at>.*?)</a>',
  caseSensitive: false,
);

final _linkPattern = RegExp(
  '<a href="(?<link>[^"]*)"[^>]*>(?<text>.*?)</a>',
  caseSensitive: false,
);
