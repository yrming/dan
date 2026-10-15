import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/models/status_text.dart';
import 'package:flutter/material.dart';

/// Highlights status entities while preserving normal text editing and IME use.
class StatusComposerTextController extends TextEditingController {
  /// Creates a controller with optional entity metadata from the source status.
  StatusComposerTextController({
    required String text,
    List<StatusTextPart> parts = const [],
    bool cursorAtStart = false,
  }) : super.fromValue(
         TextEditingValue(
           text: text,
           selection: TextSelection.collapsed(
             offset: cursorAtStart ? 0 : text.length,
           ),
         ),
       ) {
    var offset = 0;
    for (final part in parts) {
      if (part.kind != StatusTextPartKind.plain && part.text.isNotEmpty) {
        _sourceRanges.add(
          TextRange(start: offset, end: offset + part.text.length),
        );
      }
      offset += part.text.length;
    }
  }

  List<TextRange> _sourceRanges = [];

  /// The mention token at the caret, excluding active IME composition.
  TextRange? get activeMention {
    if (!selection.isValid ||
        !selection.isCollapsed ||
        selection.end > text.length ||
        (value.composing.isValid && !value.composing.isCollapsed)) {
      return null;
    }
    final before = text.substring(0, selection.end);
    final match = RegExp(r'@[^\s@#，。！？；：、（）【】「」『』<>]*$').firstMatch(before);
    if (match == null) return null;
    var end = selection.end;
    final suffix = RegExp(
      r'^[^\s@#，。！？；：、（）【】「」『』<>]*',
    ).firstMatch(text.substring(end));
    end += suffix?.end ?? 0;
    return TextRange(start: match.start, end: end);
  }

  /// Starts a mention at the current selection without completing it.
  void startMention() {
    if (activeMention != null) return;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : start;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])
        ? ' '
        : '';
    final inserted = '$prefix@';
    final suffix = end < text.length ? ' ' : '';
    value = TextEditingValue(
      text: text.replaceRange(start, end, '$inserted$suffix'),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
  }

  /// Inserts an empty hashtag pair and places the caret between the hashes.
  void startHashtag() {
    final start = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length)
        : start;
    const inserted = '##';
    value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  /// Inserts a mention at the saved selection and preserves its highlight.
  void insertMention(String name, {required TextSelection selection}) {
    final start = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length)
        : start;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])
        ? ' '
        : '';
    final mention = '@$name';
    final trailing = end < text.length && text[end] == ' ' ? '' : ' ';
    final inserted = '$prefix$mention$trailing';
    value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(
        offset: start + inserted.length + (trailing.isEmpty ? 1 : 0),
      ),
    );
    _sourceRanges.add(
      TextRange(
        start: start + prefix.length,
        end: start + prefix.length + mention.length,
      ),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    final previous = value.text;
    final next = newValue.text;
    if (previous != next) {
      var start = 0;
      while (start < previous.length &&
          start < next.length &&
          previous.codeUnitAt(start) == next.codeUnitAt(start)) {
        start++;
      }
      var oldEnd = previous.length;
      var newEnd = next.length;
      while (oldEnd > start &&
          newEnd > start &&
          previous.codeUnitAt(oldEnd - 1) == next.codeUnitAt(newEnd - 1)) {
        oldEnd--;
        newEnd--;
      }
      final delta = next.length - previous.length;
      // Keep source entities outside the edit, including shortened link labels
      // and nicknames with spaces. Edited entities use live syntax detection.
      _sourceRanges = [
        for (final range in _sourceRanges)
          if (range.end <= start)
            range
          else if (range.start >= oldEnd)
            TextRange(start: range.start + delta, end: range.end + delta),
      ];
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final ranges = [
      ..._sourceRanges,
      for (final match in _entityPattern.allMatches(text))
        TextRange(start: match.start, end: match.end),
    ];
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final boundaries = <int>{
      0,
      text.length,
      for (final range in ranges) ...[range.start, range.end],
      if (composing.isValid) ...[composing.start, composing.end],
    }.toList()..sort();
    return TextSpan(
      style: style,
      children: [
        for (var index = 0; index < boundaries.length - 1; index++)
          TextSpan(
            text: text.substring(boundaries[index], boundaries[index + 1]),
            style: TextStyle(
              color:
                  ranges.any(
                    (range) =>
                        range.start <= boundaries[index] &&
                        range.end >= boundaries[index + 1],
                  )
                  ? context.appColors.wechatLinkText
                  : null,
              decoration:
                  composing.isValid &&
                      composing.start <= boundaries[index] &&
                      composing.end >= boundaries[index + 1]
                  ? TextDecoration.underline
                  : null,
            ),
          ),
      ],
    );
  }
}

final _entityPattern = RegExp(
  r'https?://[^\s<>，。！？；、）】」』]+|#[^#\r\n]+#|@[^\s@#，。！？；：、（）【】「」『』<>]+',
  caseSensitive: false,
);
