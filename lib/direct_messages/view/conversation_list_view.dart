import 'dart:async';

import 'package:dan/app/navigation/direct_message_navigation.dart';
import 'package:dan/app/navigation/user_profile_navigation.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/bloc/conversation_list_bloc.dart';
import 'package:dan/direct_messages/widgets/conversation_list_item.dart';
import 'package:dan/direct_messages/widgets/conversation_list_skeleton.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Displays a refreshable, paginated list of direct message conversations.
class ConversationListView extends StatefulWidget {
  /// Creates the conversation list view.
  const ConversationListView({super.key});

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  static const _minimumRefreshIndicatorDuration = Duration(milliseconds: 1000);

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() => _requestMoreIfNearEnd();

  void _requestMoreIfNearEnd({bool retryAfterFailure = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    if (context.read<ConversationListBloc>().state.loadMoreStatus ==
            ConversationLoadMoreStatus.failure &&
        !retryAfterFailure) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter <= position.viewportDimension * 0.5) {
      context.read<ConversationListBloc>().add(
        const ConversationListLoadMoreRequested(),
      );
    }
  }

  void _scheduleLoadMoreIfNeeded(ConversationListState state) {
    if (state.status != ConversationListStatus.success ||
        state.loadMoreStatus != ConversationLoadMoreStatus.idle ||
        !state.hasMore) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestMoreIfNearEnd();
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<ConversationListBloc>();
    final minimumDisplayElapsed = Future<void>.delayed(
      _minimumRefreshIndicatorDuration,
    );
    final refreshCompleted = bloc.stream
        .skipWhile(
          (state) =>
              state.refreshStatus != ConversationRefreshStatus.inProgress,
        )
        .firstWhere(
          (state) =>
              state.refreshStatus != ConversationRefreshStatus.inProgress,
        );
    bloc.add(const ConversationListRefreshRequested());
    await Future.wait<Object?>([minimumDisplayElapsed, refreshCompleted]);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final userScroll =
            notification is ScrollUpdateNotification &&
                notification.dragDetails != null &&
                (notification.scrollDelta ?? 0) > 0 ||
            notification is OverscrollNotification &&
                notification.dragDetails != null &&
                notification.overscroll > 0;
        if (notification.depth == 0 &&
            userScroll &&
            context.read<ConversationListBloc>().state.loadMoreStatus ==
                ConversationLoadMoreStatus.failure) {
          _requestMoreIfNearEnd(retryAfterFailure: true);
        }
        return false;
      },
      child: BlocConsumer<ConversationListBloc, ConversationListState>(
        listenWhen: (previous, current) =>
            (previous.refreshStatus != current.refreshStatus &&
                current.refreshStatus == ConversationRefreshStatus.failure) ||
            (previous.loadMoreStatus != current.loadMoreStatus &&
                current.loadMoreStatus == ConversationLoadMoreStatus.failure),
        listener: (context, state) =>
            showAppFailureSnackBar(context, message: state.failureMessage),
        builder: (context, state) {
          _scheduleLoadMoreIfNeeded(state);
          return switch (state.status) {
            ConversationListStatus.initial ||
            ConversationListStatus.loading => ConversationListSkeleton(
              semanticLabel: context.l10n.directMessagesLoadingLabel,
            ),
            ConversationListStatus.empty => _RefreshableConversationListMessage(
              scrollController: _scrollController,
              onRefresh: _refresh,
              child: AppEmptyView(
                semanticLabel: context.l10n.directMessagesEmptyLabel,
              ),
            ),
            ConversationListStatus.failure =>
              _RefreshableConversationListMessage(
                scrollController: _scrollController,
                onRefresh: _refresh,
                child: _ConversationListFailure(
                  onRetry: () => context.read<ConversationListBloc>().add(
                    const ConversationListInitialLoadRequested(),
                  ),
                ),
              ),
            ConversationListStatus.success => _ConversationListView(
              scrollController: _scrollController,
              conversations: state.conversations,
              loadMoreStatus: state.loadMoreStatus,
              onRefresh: _refresh,
            ),
          };
        },
      ),
    );
  }
}

class _ConversationListView extends StatelessWidget {
  const _ConversationListView({
    required this.scrollController,
    required this.conversations,
    required this.loadMoreStatus,
    required this.onRefresh,
  });

  final ScrollController scrollController;
  final List<DirectMessageConversation> conversations;
  final ConversationLoadMoreStatus loadMoreStatus;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PlatformRefreshableScrollView(
      scrollController: scrollController,
      onRefresh: onRefresh,
      slivers: [
        SliverList.separated(
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return ConversationListItem(
              key: ValueKey(conversation.otherUserId),
              conversation: conversation,
              onUserTap: () => unawaited(
                _openUserProfile(context, conversation),
              ),
              onTap: () => unawaited(
                _openConversation(context, conversation),
              ),
            );
          },
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemCount: conversations.length,
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverToBoxAdapter(
          child: _ConversationListFooter(
            status: loadMoreStatus,
          ),
        ),
      ],
    );
  }
}

Future<void> _openConversation(
  BuildContext context,
  DirectMessageConversation conversation,
) async {
  context.read<ConversationListBloc>().add(
    ConversationListConversationOpened(userId: conversation.otherUserId),
  );
  await openDirectMessageConversationRoute(
    context,
    userId: conversation.otherUserId,
    conversation: conversation,
  );
}

Future<void> _openUserProfile(
  BuildContext context,
  DirectMessageConversation conversation,
) async {
  final user = conversation.otherUser;
  context.read<UserRepository>().cacheUser(
    UserProfile(
      id: conversation.otherUserId,
      name: user?.name ?? '',
      screenName: user?.screenName ?? conversation.otherUserScreenName ?? '',
      avatarUrl: user?.avatarUrl ?? conversation.otherUserAvatarUrl,
      description: user?.description,
      location: user?.location,
      url: user?.url,
      protected: user?.protected,
      following: user?.following,
      followersCount: user?.followersCount,
      friendsCount: user?.friendsCount,
      favoritesCount: user?.favoritesCount,
      statusesCount: user?.statusesCount,
      gender: user?.gender,
      photoCount: user?.photoCount,
      createdAt: user?.createdAt,
      birthday: user?.birthday,
    ),
  );
  await openUserProfileRoute(context, userId: conversation.otherUserId);
}

class _RefreshableConversationListMessage extends StatelessWidget {
  const _RefreshableConversationListMessage({
    required this.scrollController,
    required this.onRefresh,
    required this.child,
  });

  final ScrollController scrollController;
  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PlatformRefreshableScrollView(
      scrollController: scrollController,
      onRefresh: onRefresh,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }
}

class _PlatformRefreshableScrollView extends StatelessWidget {
  const _PlatformRefreshableScrollView({
    required this.scrollController,
    required this.onRefresh,
    required this.slivers,
  });

  final ScrollController scrollController;
  final RefreshCallback onRefresh;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
      ],
    );

    return scrollView;
  }
}

class _ConversationListFailure extends StatelessWidget {
  const _ConversationListFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppRetryView(onRetry: onRetry);
}

class _ConversationListFooter extends StatelessWidget {
  const _ConversationListFooter({
    required this.status,
  });

  final ConversationLoadMoreStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ConversationLoadMoreStatus.idle => const SizedBox.shrink(),
      ConversationLoadMoreStatus.inProgress => ConversationListSkeleton(
        semanticLabel: context.l10n.directMessagesLoadingMoreLabel,
        itemCount: 1,
        shrinkWrap: true,
      ),
      ConversationLoadMoreStatus.failure => const SizedBox.shrink(),
    };
  }
}
