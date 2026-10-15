import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';

/// One conversation entry of the direct message list.
class ConversationListItem extends StatelessWidget {
  /// Creates a conversation list item.
  const ConversationListItem({
    required this.conversation,
    required this.onTap,
    required this.onUserTap,
    super.key,
  });

  /// Conversation to display.
  final DirectMessageConversation conversation;

  /// Invoked when the user selects the conversation.
  final VoidCallback onTap;

  /// Invoked when the user selects the peer's avatar or name.
  final VoidCallback onUserTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final colors = context.appColors;
    final screenName =
        conversation.otherUserScreenName ?? conversation.otherUserId;

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
      ),
      horizontalTitleGap: AppSpacing.sm,
      onTap: onTap,
      leading: InkWell(
        onTap: onUserTap,
        child: Badge(
          isLabelVisible: conversation.hasUnread,
          alignment: Alignment.topRight,
          backgroundColor: AppColors.wechatRed,
          smallSize: sizing.scaled(AppSpacing.xs),
          child: UserAvatar(
            imageUrl: conversation.otherUserAvatarUrl,
            size: 40,
            semanticLabel: screenName,
            borderColor: colors.divider,
            borderWidth: 0.5,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkWell(
                onTap: onUserTap,
                child: Text(
                  screenName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(width: sizing.scaled(AppSpacing.xs)),
          Text(
            formatFanfouTimestamp(
              conversation.lastMessage.createdAt,
              compactCalendarDate: true,
            ),
            style: context.appTypography.statusHandle.copyWith(
              color: colors.textSecondary,
              fontSize: sizing.scaled(13),
              height: kTextHeightNone,
            ),
          ),
        ],
      ),
      subtitle: Text(
        conversation.lastMessage.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
