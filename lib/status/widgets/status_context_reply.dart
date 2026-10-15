import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/material.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// A compact, tappable conversation comment with inline author and content.
class StatusContextReply extends StatelessWidget {
  /// Creates a conversation comment.
  const StatusContextReply({
    required this.status,
    required this.authorName,
    required this.onAuthorTap,
    required this.onTap,
    this.onPhotoTap,
    this.photoHeroTag,
    this.onHashtagTap,
    super.key,
  });

  /// Reply displayed by this comment.
  final status_repository.Status status;

  /// Display name of the reply author.
  final String authorName;

  /// Opens the author's profile.
  final VoidCallback? onAuthorTap;

  /// Opens actions for this reply.
  final VoidCallback onTap;

  /// Opens an attached photo.
  final VoidCallback? onPhotoTap;

  /// Photo transition identifier.
  final String? photoHeroTag;

  /// Called when a topic in the reply is tapped.
  final ValueChanged<String>? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: InkRipple.splashFactory,
      splashColor: Theme.of(context).colorScheme.onSurface.withValues(
        alpha: 0.12,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: context.appSizing.scaled(AppSpacing.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusBodyText(
              text: status.text,
              leadingText: authorName,
              leadingColor: context.appColors.textBase,
              onLeadingTap: onAuthorTap,
              onHashtagTap: onHashtagTap,
              linkColor: context.appColors.wechatLinkText!,
            ),
            if (status.photo case final photo?) ...[
              SizedBox(height: context.appSizing.scaled(AppSpacing.xs)),
              StatusPhoto.wechat(
                imageUrl: photo.viewerUrl,
                semanticLabel: statusHtmlToPlainText(status.text),
                heroTag: photoHeroTag ?? '',
                onTap: onPhotoTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
