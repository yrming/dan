import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external direct-message link.
typedef DirectMessageExternalLinkLauncher = Future<bool> Function(Uri uri);

/// One direct-message bubble aligned by its sender.
class DirectMessageBubble extends StatelessWidget {
  /// Creates a direct message bubble row.
  const DirectMessageBubble({
    required this.message,
    required this.isSentByActiveAccount,
    this.avatarUrl,
    this.avatarSemanticLabel,
    this.onAvatarTap,
    this.externalLinkLauncher = _launchExternalLink,
    super.key,
  });

  /// Message to display.
  final DirectMessage message;

  /// Whether the active account sent [message].
  final bool isSentByActiveAccount;

  /// Avatar URL retained for API compatibility; avatars are not shown in chat.
  final String? avatarUrl;

  /// Semantic label retained for API compatibility; avatars are not shown.
  final String? avatarSemanticLabel;

  /// Tap callback retained for API compatibility; avatars are not shown.
  final VoidCallback? onAvatarTap;

  /// Opens a URL when the message consists of an HTTP or HTTPS link.
  final DirectMessageExternalLinkLauncher externalLinkLauncher;

  static const double _borderRadius = 10;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isSentByActiveAccount
        ? colorScheme.primary
        : colors.directMessageIncomingBubble;
    final textColor = colors.textBase;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubble = Flexible(
      child: _MessageBubble(
        color: bubbleColor,
        textColor: textColor,
        linkColor: colors.directMessageLinkText,
        externalLinkLauncher: externalLinkLauncher,
        maxWidth: screenWidth * 0.72,
        text: message.text,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isSentByActiveAccount
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [bubble],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.color,
    required this.textColor,
    required this.linkColor,
    required this.externalLinkLauncher,
    required this.maxWidth,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final Color linkColor;
  final DirectMessageExternalLinkLauncher externalLinkLauncher;
  final double maxWidth;
  final String text;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.symmetric(
        horizontal: sizing.scaled(AppSpacing.sm),
        vertical: sizing.scaled(AppSpacing.xs),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(
          sizing.scaled(DirectMessageBubble._borderRadius),
        ),
      ),
      child: _DirectMessageText(
        text: text,
        textColor: textColor,
        linkColor: linkColor,
        externalLinkLauncher: externalLinkLauncher,
      ),
    );
  }
}

class _DirectMessageText extends StatefulWidget {
  const _DirectMessageText({
    required this.text,
    required this.textColor,
    required this.linkColor,
    required this.externalLinkLauncher,
  });

  final String text;
  final Color textColor;
  final Color linkColor;
  final DirectMessageExternalLinkLauncher externalLinkLauncher;

  @override
  State<_DirectMessageText> createState() => _DirectMessageTextState();
}

class _DirectMessageTextState extends State<_DirectMessageText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    final style = context.appTypography.statusBody.copyWith(
      color: widget.textColor,
    );
    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      final uri = _parseHttpUrl(match.group(0)!);
      if (uri == null) continue;
      if (match.start > offset) {
        spans.add(TextSpan(text: widget.text.substring(offset, match.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => unawaited(widget.externalLinkLauncher(uri));
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style.copyWith(color: widget.linkColor),
          recognizer: recognizer,
        ),
      );
      offset = match.end;
    }
    if (offset < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(offset)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: widget.text));

    return Text.rich(TextSpan(style: style, children: spans));
  }
}

final _urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

Uri? _parseHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

Future<bool> _launchExternalLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
