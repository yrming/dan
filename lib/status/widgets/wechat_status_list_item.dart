import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_list_item_tap_target.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/material.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// Displays a status using the WeChat-inspired list item layout.
class WeChatStatusListItem extends StatelessWidget {
  /// Creates a WeChat-inspired status list item.
  const WeChatStatusListItem({
    required this.status,
    required this.authorName,
    required this.onAuthorTap,
    required this.onStatusTap,
    this.photoStyle = StatusPhotoStyle.wechat,
    this.photoHeroTag,
    this.showSource = false,
    this.showMetadata = true,
    this.showAbsoluteTimestamp = false,
    this.onPhotoTap,
    this.onActionTap,
    this.onHashtagTap,
    super.key,
  });

  /// Status displayed by this item.
  final status_repository.Status status;

  /// Localized author name displayed by this item.
  final String authorName;

  /// Called when the status author avatar or name is tapped.
  final VoidCallback? onAuthorTap;

  /// Called when status content is tapped, or null when it is not interactive.
  final VoidCallback? onStatusTap;

  /// Layout used to display an attached photo.
  final StatusPhotoStyle photoStyle;

  /// Hero tag used by an attached photo.
  final String? photoHeroTag;

  /// Whether the meta line appends the status source after the timestamp.
  final bool showSource;

  /// Whether to display the timestamp and status actions.
  final bool showMetadata;

  /// Whether to display the full calendar date and clock time.
  final bool showAbsoluteTimestamp;

  /// Called when an attached photo is tapped.
  final VoidCallback? onPhotoTap;

  /// Called when the status action button is tapped.
  final VoidCallback? onActionTap;

  /// Called when a topic in the status body is tapped.
  final ValueChanged<String>? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final colors = context.appColors;
    return Material(
      color: colors.bgBase,
      child: StatusListItemTapTarget(
        onTap: onStatusTap,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            sizing.scaled(AppSpacing.md),
            sizing.scaled(AppSpacing.sm),
            AppSpacing.md,
            sizing.scaled(AppSpacing.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusListItemTapTarget(
                onTap: onAuthorTap,
                child: UserAvatar(
                  imageUrl: status.author.avatarUrl,
                  semanticLabel: authorName,
                  size: sizing.statusAvatarSize,
                  borderColor: colors.divider,
                  borderWidth: 0.5,
                ),
              ),
              SizedBox(width: sizing.scaled(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusListItemTapTarget(
                          onTap: onAuthorTap,
                          child: Text(
                            authorName,
                            style: context.appTypography.statusAuthor,
                          ),
                        ),
                        if (status.text.isNotEmpty) ...[
                          SizedBox(height: sizing.scaled(6)),
                          StatusBodyText(
                            text: status.text,
                            linkColor: colors.wechatLinkText!,
                            onHashtagTap: onHashtagTap,
                          ),
                          SizedBox(height: sizing.scaled(6)),
                        ] else
                          SizedBox(height: sizing.scaled(10)),
                      ],
                    ),
                    if (status.photo case final photo?) ...[
                      _StatusPhoto(
                        style: photoStyle,
                        imageUrl: photo.viewerUrl,
                        semanticLabel: statusHtmlToPlainText(status.text),
                        heroTag: photoHeroTag ?? '',
                        onTap: onPhotoTap,
                      ),
                      SizedBox(height: sizing.scaled(10)),
                    ],
                    if (showMetadata)
                      _WeChatStatusMeta(
                        status: status,
                        showSource: showSource,
                        showAbsoluteTimestamp: showAbsoluteTimestamp,
                        onActionTap: onActionTap,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPhoto extends StatelessWidget {
  const _StatusPhoto({
    required this.style,
    required this.imageUrl,
    required this.semanticLabel,
    required this.heroTag,
    required this.onTap,
  });

  final StatusPhotoStyle style;
  final String imageUrl;
  final String semanticLabel;
  final String heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      StatusPhotoStyle.wechat => StatusPhoto.wechat(
        imageUrl: imageUrl,
        semanticLabel: semanticLabel,
        heroTag: heroTag,
        onTap: onTap,
      ),
      StatusPhotoStyle.x => StatusPhoto.x(
        imageUrl: imageUrl,
        semanticLabel: semanticLabel,
        heroTag: heroTag,
        onTap: onTap,
      ),
    };
  }
}

class _WeChatStatusMeta extends StatelessWidget {
  const _WeChatStatusMeta({
    required this.status,
    required this.showSource,
    required this.showAbsoluteTimestamp,
    required this.onActionTap,
  });

  final status_repository.Status status;
  final bool showSource;
  final bool showAbsoluteTimestamp;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final timestamp = showAbsoluteTimestamp
        ? formatFanfouDateTime(status.createdAt)
        : formatFanfouTimestamp(
            status.createdAt,
            compactCalendarDate: true,
          );
    final source = showSource ? status.source : null;
    return Row(
      children: [
        Expanded(
          child: Text(
            source == null ? timestamp : '$timestamp · $source',
            style: context.appTypography.statusHandle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: sizing.scaled(AppSpacing.xs)),
        StatusActionButton(onPressed: onActionTap),
      ],
    );
  }
}
