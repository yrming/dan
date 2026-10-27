import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/models/status_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user_repository/user_repository.dart';

/// Opens an external status link.
typedef StatusExternalLinkLauncher = Future<bool> Function(Uri uri);

/// Displays API-formatted status HTML with supported links highlighted.
class StatusBodyText extends StatefulWidget {
  /// Creates highlighted status body text.
  const StatusBodyText({
    required this.text,
    required this.linkColor,
    this.leadingText,
    this.leadingColor,
    this.onLeadingTap,
    this.onHashtagTap,
    this.maxLines,
    this.externalLinkLauncher = _launchExternalLink,
    super.key,
  });

  /// Status body HTML returned by the API with `format: html`.
  final String text;

  /// Color applied to mentions, hashtags, and links.
  final Color linkColor;

  /// Optional linked prefix, such as a conversation reply's author name.
  final String? leadingText;

  /// Color of the linked prefix, defaulting to [linkColor].
  final Color? leadingColor;

  /// Called when the prefix is tapped.
  final VoidCallback? onLeadingTap;

  /// Called when a topic is tapped.
  final ValueChanged<String>? onHashtagTap;

  /// Maximum number of lines in a compact status preview.
  final int? maxLines;

  /// Opens validated HTTP and HTTPS links.
  final StatusExternalLinkLauncher externalLinkLauncher;

  @override
  State<StatusBodyText> createState() => _StatusBodyTextState();
}

class _StatusBodyTextState extends State<StatusBodyText> {
  late List<StatusTextPart> _parts;
  final _recognizers = <StatusTextPart, TapGestureRecognizer>{};
  final _leadingRecognizer = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _configureParts();
  }

  @override
  void didUpdateWidget(covariant StatusBodyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.externalLinkLauncher != oldWidget.externalLinkLauncher) {
      _configureParts();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _leadingRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = context.appTypography.statusBody;
    _leadingRecognizer.onTap = widget.onLeadingTap;
    return GestureDetector(
      onLongPress: _showCopyActionSheet,
      child: Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            if (widget.leadingText case final text?) ...[
              TextSpan(
                text: text,
                style: bodyStyle.copyWith(
                  color: widget.leadingColor ?? widget.linkColor,
                  fontWeight: FontWeight.w500,
                ),
                recognizer: widget.onLeadingTap == null
                    ? null
                    : _leadingRecognizer,
              ),
              const TextSpan(text: ': '),
            ],
            for (final part in _parts)
              TextSpan(
                text: part.text,
                style: part.kind == StatusTextPartKind.plain
                    ? null
                    : bodyStyle.copyWith(color: widget.linkColor),
                recognizer: _recognizers[part],
              ),
          ],
        ),
        maxLines: widget.maxLines,
        overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  /// Shows the long-press actions for copying this status text.
  Future<void> _showCopyActionSheet() async {
    final plainText = statusHtmlToPlainText(widget.text);
    if (plainText.isEmpty) return;
    final copiedMessage = context.l10n.statusTextCopied;
    await showAppActionSheet(
      context,
      sheetKey: const Key('status-text-copy-sheet'),
      groups: [
        AppActionSheetGroup(
          key: const Key('status-text-copy-group'),
          children: [
            AppActionSheetItem(
              key: const Key('status-text-copy-action'),
              label: context.l10n.statusCopyTextLabel,
              icon: RemixIcons.file_copy_line,
              onPressed: () {
                unawaited(
                  Clipboard.setData(ClipboardData(text: plainText)),
                );
                showAppToast(context, copiedMessage);
              },
            ),
          ],
        ),
      ],
    );
  }

  void _configureParts() {
    _disposeRecognizers();
    _parts = parseStatusHtml(widget.text);
    for (final part in _parts) {
      final onTap = switch (part.kind) {
        StatusTextPartKind.mention => () => _openUserProfile(
          part.userId!,
          part.text.substring(1),
        ),
        StatusTextPartKind.link => () => _openLink(part.link!),
        StatusTextPartKind.hashtag =>
          widget.onHashtagTap == null
              ? null
              : () => widget.onHashtagTap!(part.text),
        StatusTextPartKind.plain => null,
      };
      if (onTap != null) {
        _recognizers[part] = TapGestureRecognizer()..onTap = onTap;
      }
    }
  }

  void _openUserProfile(String userId, String screenName) {
    context.read<UserRepository>().cacheUser(
      UserProfile(id: userId, name: '', screenName: screenName),
    );
    unawaited(openUserProfileRoute(context, userId: userId));
  }

  void _openLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    unawaited(widget.externalLinkLauncher(uri));
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

/// Converts status HTML into the plain text presented to accessibility tools.
String statusHtmlToPlainText(String source) {
  return parseStatusHtml(source).map((part) => part.text).join();
}

Future<bool> _launchExternalLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
