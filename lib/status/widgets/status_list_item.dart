import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/models/status_composer_mode.dart';
import 'package:dan/status/models/status_list_layout.dart';
import 'package:dan/status/widgets/moments_status_list_item.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_context_reply.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:dan/status/widgets/wechat_status_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart' as status_repository;
import 'package:user_repository/user_repository.dart';

/// Displays one status using the application status layout.
class StatusListItem extends StatelessWidget {
  /// Creates a style-aware status list item.
  const StatusListItem({
    required this.status,
    this.enableStatusDetailNavigation = true,
    this.showSource = false,
    this.showMetadata = true,
    this.showAbsoluteTimestamp = false,
    this.photoHeroScope,
    this.onStatusActionTap,
    this.onStatusDelete,
    this.onStatusDeleted,
    this.onStatusFavoriteToggle,
    this.isContextReply = false,
    this.layout = StatusListLayout.timeline,
    this.previousCreatedAt,
    super.key,
  });

  /// Status displayed by this item.
  final status_repository.Status status;

  /// Presentation used for this status.
  final StatusListLayout layout;

  /// Preceding timestamp used to group personal album dates.
  final String? previousCreatedAt;

  /// Whether to render a compact comment in a detail conversation.
  final bool isContextReply;

  /// Whether tapping status content opens its detail page.
  final bool enableStatusDetailNavigation;

  /// Whether the meta line appends the status source after the timestamp.
  final bool showSource;

  /// Whether to display the timestamp and status actions.
  final bool showMetadata;

  /// Whether to display the full calendar date and clock time.
  final bool showAbsoluteTimestamp;

  /// Optional Hero scope used for an attached photo.
  final String? photoHeroScope;

  /// Called when the WeChat status action button is tapped.
  final VoidCallback? onStatusActionTap;

  /// Called after the user confirms deleting this status.
  final FutureOr<void> Function()? onStatusDelete;

  /// Called after deletion succeeds and the confirmation dialog closes.
  final VoidCallback? onStatusDeleted;

  /// Called when the favorite action is selected.
  final VoidCallback? onStatusFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final authorName = _authorName(context, status);
    final photo = status.photo;
    final heroScope = photo == null
        ? null
        : _normalizeStatusPhotoHeroScope(
            photoHeroScope ?? GoRouterState.of(context).matchedLocation,
          );
    final photoHeroTag = photo == null
        ? null
        : _statusPhotoHeroTag(
            scope: heroScope!,
            status: status,
            imageUrl: photo.viewerUrl,
          );
    Future<void> onStatusTap() async {
      await _openStatusDetail(context, status);
    }

    Future<void> onAuthorTap() async {
      await _openUserProfile(context, status.author);
    }

    Future<void> onPhotoTap() async {
      if (photo == null || heroScope == null) return;
      await _openStatusImageViewer(
        context,
        status: status,
        imageUrl: photo.viewerUrl,
        heroScope: heroScope,
      );
    }

    Future<void> onActionTap() async {
      onStatusActionTap?.call();
      await _showStatusActions(
        context,
        status,
        onDelete: onStatusDelete,
        onDeleted: onStatusDeleted,
        onFavoriteToggle: onStatusFavoriteToggle,
      );
    }

    if (isContextReply) {
      return StatusContextReply(
        status: status,
        authorName: authorName,
        onAuthorTap: status.author.id.isEmpty ? null : onAuthorTap,
        onTap: onActionTap,
        onPhotoTap: photo == null ? null : onPhotoTap,
        photoHeroTag: photoHeroTag,
        onHashtagTap: (topic) => _openTopicSearch(context, topic),
      );
    }

    if (layout == StatusListLayout.moments) {
      return MomentsStatusListItem(
        status: status,
        previousCreatedAt: previousCreatedAt,
        photoHeroTag: photoHeroTag,
        onStatusTap: enableStatusDetailNavigation ? onStatusTap : null,
        onPhotoTap: photo == null ? null : onPhotoTap,
        onHashtagTap: (topic) => _openTopicSearch(context, topic),
      );
    }

    return WeChatStatusListItem(
      status: status,
      authorName: authorName,
      photoStyle: context.appStatusPhotoStyle,
      photoHeroTag: photoHeroTag,
      showSource: showSource,
      showMetadata: showMetadata,
      showAbsoluteTimestamp: showAbsoluteTimestamp,
      onAuthorTap: status.author.id.isEmpty ? null : onAuthorTap,
      onStatusTap: enableStatusDetailNavigation ? onStatusTap : null,
      onPhotoTap: photo == null ? null : onPhotoTap,
      onActionTap: onActionTap,
      onHashtagTap: (topic) => _openTopicSearch(context, topic),
    );
  }
}

Future<void> _openTopicSearch(BuildContext context, String topic) async {
  final query = topic
      .replaceFirst(RegExp('^#'), '')
      .replaceFirst(RegExp(r'#$'), '');
  if (query.trim().isEmpty) return;
  await context.pushNamed<void>(
    AppRouteName.search,
    queryParameters: {'query': query},
  );
}

Future<void> _showStatusActions(
  BuildContext context,
  status_repository.Status status, {
  FutureOr<void> Function()? onDelete,
  VoidCallback? onDeleted,
  VoidCallback? onFavoriteToggle,
}) {
  final l10n = context.l10n;
  void openComposer(StatusComposerMode mode) {
    unawaited(
      context.pushNamed<void>(
        AppRouteName.statusComposer,
        queryParameters: {
          'mode': mode.name,
          'sourceStatusId': status.id,
          'sourceAuthor': _authorName(context, status),
          'sourceText': status.text,
          if (mode == StatusComposerMode.repost && status.photo != null)
            'sourcePhotoUrl': status.photo!.viewerUrl,
        },
      ),
    );
  }

  return showAppActionSheet(
    context,
    sheetKey: const Key('status-action-sheet'),
    groups: [
      AppActionSheetGroup(
        key: const Key('status-action-group'),
        dividerKeys: status.isSelf
            ? const [Key('status-action-divider-0')]
            : const [
                Key('status-action-divider-0'),
                Key('status-action-divider-1'),
              ],
        children: [
          if (!status.isSelf)
            AppActionSheetItem(
              key: const Key('status-reply-action'),
              label: l10n.statusActionReplyLabel,
              icon: RemixIcons.message_2_line,
              onPressed: () => openComposer(StatusComposerMode.reply),
            ),
          AppActionSheetItem(
            key: const Key('status-repost-action'),
            label: l10n.statusActionRepostLabel,
            icon: RemixIcons.repeat_line,
            onPressed: () => openComposer(StatusComposerMode.repost),
          ),
          AppActionSheetItem(
            key: const Key('status-favorite-action'),
            label: l10n.statusActionFavoriteLabel,
            icon: status.isFavorited
                ? RemixIcons.star_fill
                : RemixIcons.star_line,
            iconColor: status.isFavorited ? const Color(0xFFFFDD33) : null,
            onPressed: onFavoriteToggle,
          ),
        ],
      ),
      if (status.isSelf)
        AppActionSheetGroup(
          key: const Key('status-delete-group'),
          children: [
            AppActionSheetItem(
              key: const Key('status-delete-action'),
              label: l10n.statusActionDeleteLabel,
              icon: RemixIcons.delete_bin_7_line,
              foregroundColor: context.appColors.destructiveAction,
              onPressed: () {
                unawaited(
                  showAppAlertDialog(
                    context,
                    title: l10n.statusDeleteDialogTitle,
                    content: l10n.statusDeleteDialogContent,
                    cancelAction: AppDialogAction(
                      label: l10n.statusDeleteDialogCancelLabel,
                      color: context.appColors.textBase,
                      onPressed: () {},
                    ),
                    confirmAction: AppDialogAction(
                      label: l10n.statusDeleteDialogConfirmLabel,
                      color: context.appColors.destructiveAction,
                      onSubmit: () async => onDelete?.call(),
                      failureLabel: l10n.statusDeleteFailure,
                      onPressed: onDeleted ?? () {},
                    ),
                  ),
                );
              },
            ),
          ],
        ),
    ],
  );
}

String _authorName(BuildContext context, status_repository.Status status) {
  return status.author.name.isEmpty
      ? context.l10n.statusUnknownAuthor
      : status.author.name;
}

String _normalizeStatusPhotoHeroScope(String scope) {
  final routeScope = Uri.tryParse(scope.trim())?.pathSegments.join('-') ?? '';
  if (routeScope.isEmpty) return 'status-list';
  return routeScope;
}

Future<void> _openUserProfile(
  BuildContext context,
  status_repository.StatusAuthor author,
) async {
  context.read<UserRepository>().cacheUser(
    UserProfile(
      id: author.id,
      name: author.name,
      screenName: author.screenName,
      gender: author.gender,
      avatarUrl: author.avatarUrl,
      description: author.description,
      url: author.url,
      location: author.location,
      createdAt: author.createdAt,
      protected: author.protected,
      following: author.following,
      followersCount: author.followersCount,
      friendsCount: author.friendsCount,
      favoritesCount: author.favoritesCount,
      statusesCount: author.statusesCount,
      photoCount: author.photoCount,
    ),
  );
  await openUserProfileRoute(
    context,
    userId: author.id,
  );
}

Future<void> _openStatusDetail(
  BuildContext context,
  status_repository.Status status,
) async {
  await context.pushNamed<void>(
    AppRouteName.statusDetail,
    pathParameters: {
      'userId': status.author.id.isEmpty ? 'unknown' : status.author.id,
      'statusId': status.id,
    },
    extra: status,
  );
}

Future<void> _openStatusImageViewer(
  BuildContext context, {
  required status_repository.Status status,
  required String imageUrl,
  required String heroScope,
}) async {
  final heroTag = _statusPhotoHeroTag(
    scope: heroScope,
    status: status,
    imageUrl: imageUrl,
  );
  await context.pushNamed<void>(
    AppRouteName.statusImageViewer,
    queryParameters: {
      'url': imageUrl,
      'semanticLabel': statusHtmlToPlainText(status.text),
      'heroTag': heroTag,
    },
  );
}

String _statusPhotoHeroTag({
  required String scope,
  required status_repository.Status status,
  required String imageUrl,
}) {
  return statusPhotoHeroTag(
    scope: _normalizeStatusPhotoHeroScope(scope),
    statusId: status.id,
    imageUrl: imageUrl,
  );
}
