import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/profile/cubit/follow_list_cubit.dart';
import 'package:dan/profile/widgets/follow_list_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renders following or followers with incremental loading.
class FollowListView extends StatelessWidget {
  const FollowListView({
    required this.followers,
    this.personal = false,
    super.key,
  });

  final bool followers;
  final bool personal;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FollowListCubit, FollowListState>(
          listenWhen: (previous, current) =>
              previous.actionFailureCount != current.actionFailureCount,
          listener: (context, state) => _showFeedback(
            context,
            state.actionFailureMessage ?? context.l10n.followActionFailure,
          ),
        ),
        BlocListener<FollowListCubit, FollowListState>(
          listenWhen: (previous, current) =>
              previous.requestSentCount != current.requestSentCount,
          listener: (context, state) => _showFeedback(
            context,
            context.l10n.followActionRequestSent,
          ),
        ),
      ],
      child: BlocBuilder<FollowListCubit, FollowListState>(
        builder: (context, state) {
          final l10n = context.l10n;
          if (state.loading) {
            return FollowListSkeleton(
              semanticLabel: l10n.followListLoadingLabel,
            );
          }
          if (state.error) {
            return AppRetryView(
              onRetry: () => unawaited(context.read<FollowListCubit>().load()),
            );
          }
          if (state.users.isEmpty) {
            return Center(
              child: Text(
                l10n.statusListEmptyLabel,
                textAlign: TextAlign.center,
                style: context.appTypography.statusBody.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final cubit = context.read<FollowListCubit>();
              final current = cubit.state;
              final scrollingDown =
                  notification is ScrollUpdateNotification &&
                      (notification.scrollDelta ?? 0) > 0 ||
                  notification is OverscrollNotification &&
                      notification.overscroll > 0;
              if (notification.depth == 0 &&
                  scrollingDown &&
                  notification.metrics.extentAfter < 200 &&
                  !current.loadMoreError &&
                  !current.loadingMore &&
                  current.hasMore) {
                unawaited(cubit.loadMore());
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverList.separated(
                  itemCount: state.users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    final name = user.name.isEmpty
                        ? user.screenName
                        : user.name;
                    return ListTile(
                      key: ValueKey(user.id),
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      horizontalTitleGap: AppSpacing.sm,
                      onTap: () => unawaited(
                        openUserProfileRoute(context, userId: user.id),
                      ),
                      leading: UserAvatar(
                        imageUrl: user.avatarUrl,
                        semanticLabel: name,
                        size: 40,
                        borderColor: context.appColors.divider,
                        borderWidth: 0.5,
                      ),
                      trailing: state.actions[user.id] == null
                          ? null
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: Size(
                                  context.appSizing.scaled(
                                    _followListButtonWidth,
                                  ),
                                  context.appSizing.scaled(
                                    _followListButtonHeight,
                                  ),
                                ),
                                maximumSize: Size(
                                  context.appSizing.scaled(
                                    _followListButtonWidth,
                                  ),
                                  context.appSizing.scaled(
                                    _followListButtonHeight,
                                  ),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: state.updatingIds.contains(user.id)
                                  ? null
                                  : () => unawaited(
                                      context
                                          .read<FollowListCubit>()
                                          .toggleFollowing(user.id),
                                    ),
                              child: state.updatingIds.contains(user.id)
                                  ? SizedBox.square(
                                      dimension: context.appSizing.scaled(
                                        AppSpacing.md,
                                      ),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        semanticsLabel:
                                            l10n.followActionLoading,
                                      ),
                                    )
                                  : Text(switch (state.actions[user.id]!) {
                                      FollowListAction.follow =>
                                        l10n.followActionFollow,
                                      FollowListAction.unfollow =>
                                        l10n.followActionUnfollow,
                                      FollowListAction.followBack =>
                                        l10n.followActionFollowBack,
                                    }),
                            ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        user.description?.trim() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(
                  child: Divider(height: 1),
                ),
                if (state.loadingMore || state.loadMoreError || state.hasMore)
                  SliverToBoxAdapter(
                    child: state.loadingMore
                        ? FollowListSkeleton(
                            semanticLabel: l10n.followListLoadingMoreLabel,
                            itemCount: 1,
                            shrinkWrap: true,
                          )
                        : state.loadMoreError
                        ? AppRetryView(
                            revealOnDisplay: true,
                            message: l10n.retryLoadMoreMessage,
                            onRetry: () => unawaited(
                              context.read<FollowListCubit>().loadMore(),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsetsDirectional.all(16),
                            child: Center(
                              child: Text(
                                l10n.followListPullUpLabel,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}

const _followListButtonWidth = 80.0;
const _followListButtonHeight = 34.0;
