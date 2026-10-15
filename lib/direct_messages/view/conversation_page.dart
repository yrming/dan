import 'dart:async';

import 'package:dan/direct_messages/cubit/cubit.dart';
import 'package:dan/direct_messages/view/conversation_view.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Route boundary for the conversation with one peer account.
class ConversationPage extends StatelessWidget {
  /// Creates the conversation page.
  const ConversationPage({
    required this.userId,
    this.activeAccountId,
    this.activeAccountAvatarUrl,
    this.initialPeerScreenName,
    this.conversation,
    super.key,
  });

  /// Identifier of the peer account.
  final String userId;

  /// Identifier of the active account, when authenticated.
  final String? activeAccountId;

  /// Active account avatar URL retained for API compatibility.
  final String? activeAccountAvatarUrl;

  /// Peer screen name supplied by the source screen for the header.
  final String? initialPeerScreenName;

  /// Conversation summary supplied by the source screen for the header.
  final DirectMessageConversation? conversation;

  @override
  Widget build(BuildContext context) {
    final peerAvatarUrl =
        conversation?.otherUserAvatarUrl ??
        context.read<UserRepository>().getCachedUser(userId)?.avatarUrl;
    return BlocProvider(
      create: (context) {
        final cubit = ConversationCubit(
          directMessageRepository: context.read<DirectMessageRepository>(),
          userId: userId,
          activeAccountId: activeAccountId,
          initialPeerScreenName:
              conversation?.otherUserScreenName ?? initialPeerScreenName,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: ConversationView(
        activeAccountId: activeAccountId,
        peerAvatarUrl: peerAvatarUrl,
        activeAccountAvatarUrl: activeAccountAvatarUrl,
      ),
    );
  }
}
