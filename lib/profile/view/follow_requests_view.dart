import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/profile/cubit/follow_requests_cubit.dart';
import 'package:dan/profile/widgets/follow_list_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

class FollowRequestsView extends StatelessWidget {
  const FollowRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FollowRequestsCubit, FollowRequestsState>(
          listenWhen: (previous, current) =>
              !previous.loadMoreError && current.loadMoreError,
          listener: (context, state) => showAppFailureToast(
            context,
            message: state.requestFailureMessage,
          ),
        ),
        BlocListener<FollowRequestsCubit, FollowRequestsState>(
          listenWhen: (previous, current) =>
              previous.actionFailureCount != current.actionFailureCount,
          listener: (context, state) => showAppToast(
            context,
            state.actionFailureMessage ?? context.l10n.followActionFailure,
          ),
        ),
        BlocListener<FollowRequestsCubit, FollowRequestsState>(
          listenWhen: (previous, current) =>
              previous.actionSuccessCount != current.actionSuccessCount,
          listener: (context, state) => unawaited(
            context.read<NotificationCountsCubit>().refresh(),
          ),
        ),
      ],
      child: BlocBuilder<FollowRequestsCubit, FollowRequestsState>(
        builder: (context, state) {
          final l10n = context.l10n;
          if (state.loading) {
            return FollowListSkeleton(
              semanticLabel: l10n.followListLoadingLabel,
              actionCount: 2,
              actionWidth: _followRequestButtonWidth,
            );
          }
          if (state.error) {
            return AppRetryView(
              onRetry: () => unawaited(
                context.read<FollowRequestsCubit>().load(),
              ),
            );
          }
          if (state.users.isEmpty) {
            return AppEmptyView(
              semanticLabel: l10n.followRequestsEmpty,
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final cubit = context.read<FollowRequestsCubit>();
              final scrollingDown =
                  notification is ScrollUpdateNotification &&
                      (notification.scrollDelta ?? 0) > 0 ||
                  notification is OverscrollNotification &&
                      notification.overscroll > 0;
              if (notification.depth == 0 &&
                  scrollingDown &&
                  notification.metrics.extentAfter < 200 &&
                  (!state.loadMoreError ||
                      notification is ScrollUpdateNotification &&
                          notification.dragDetails != null ||
                      notification is OverscrollNotification &&
                          notification.dragDetails != null) &&
                  !state.loadingMore &&
                  state.hasMore) {
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
                    final updating = state.updatingIds.contains(user.id);
                    final updatingAction = state.updatingActions[user.id];
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton(
                            style: _followRequestButtonStyle(context),
                            onPressed: updating
                                ? null
                                : () => unawaited(
                                    context.read<FollowRequestsCubit>().accept(
                                      user.id,
                                    ),
                                  ),
                            child: updatingAction == FollowRequestAction.accept
                                ? _followRequestLoadingIndicator(
                                    l10n.followActionLoading,
                                  )
                                : Tooltip(
                                    message: l10n.followRequestAccept,
                                    child: const Icon(
                                      RemixIcons.check_line,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.space10),
                          FilledButton(
                            style: _followRequestIgnoreButtonStyle(context),
                            onPressed: updating
                                ? null
                                : () => unawaited(
                                    context.read<FollowRequestsCubit>().ignore(
                                      user.id,
                                    ),
                                  ),
                            child: updatingAction == FollowRequestAction.ignore
                                ? _followRequestLoadingIndicator(
                                    l10n.followActionLoading,
                                  )
                                : Tooltip(
                                    message: l10n.followRequestIgnore,
                                    child: const Icon(
                                      RemixIcons.close_line,
                                    ),
                                  ),
                          ),
                        ],
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
                            actionCount: 2,
                            actionWidth: _followRequestButtonWidth,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Center(
                              child: Text(l10n.followListPullUpLabel),
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
}

Widget _followRequestLoadingIndicator(String semanticsLabel) {
  return SizedBox.square(
    dimension: AppSpacing.md,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      semanticsLabel: semanticsLabel,
    ),
  );
}

ButtonStyle _followRequestButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: Size(
      context.appSizing.scaled(_followRequestButtonWidth),
      context.appSizing.scaled(_followListButtonHeight),
    ),
    maximumSize: Size(
      context.appSizing.scaled(_followRequestButtonWidth),
      context.appSizing.scaled(_followListButtonHeight),
    ),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

ButtonStyle _followRequestIgnoreButtonStyle(BuildContext context) {
  return _followRequestButtonStyle(context).copyWith(
    backgroundColor: WidgetStatePropertyAll(context.appColors.bgBase),
    foregroundColor: WidgetStatePropertyAll(context.appColors.textBase),
    side: WidgetStatePropertyAll(
      BorderSide(color: context.appColors.divider, width: 0.5),
    ),
  );
}

const _followRequestButtonWidth = 40.0;
const _followListButtonHeight = 34.0;
