import 'package:dan/app/navigation/routes.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Pushes the active account's conversation list onto the navigation stack.
/// Refreshes unread counters when the user returns to the source page.
Future<void> openDirectMessageListRoute(BuildContext context) async {
  await context.pushNamed<void>(AppRouteName.directMessageList);
  if (!context.mounted) return;
  await context.read<NotificationCountsCubit>().refresh();
}

/// Pushes the conversation with [userId] onto the navigation stack.
///
/// [conversation] optionally carries a summary from the source screen so the
/// header can render immediately. [peerScreenName] optionally names the peer
/// for the header when no summary is available.
Future<void> openDirectMessageConversationRoute(
  BuildContext context, {
  required String userId,
  DirectMessageConversation? conversation,
  String? peerScreenName,
}) async {
  await context.pushNamed<void>(
    AppRouteName.directMessageConversation,
    pathParameters: {'userId': userId},
    queryParameters: peerScreenName == null
        ? const {}
        : {'screenName': peerScreenName},
    extra: conversation,
  );
}
