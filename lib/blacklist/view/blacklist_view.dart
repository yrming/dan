import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/blacklist/cubit/blacklist_cubit.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/profile/widgets/follow_list_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BlacklistView extends StatefulWidget {
  const BlacklistView({super.key});

  @override
  State<BlacklistView> createState() => _BlacklistViewState();
}

class _BlacklistViewState extends State<BlacklistView> {
  GoRouterDelegate? _routerDelegate;
  ValueKey<String>? _pageKey;
  bool _isVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    final delegate = router?.routerDelegate;
    if (delegate == _routerDelegate) return;
    _routerDelegate?.removeListener(_onRouteChanged);
    _routerDelegate = delegate;
    _pageKey = delegate == null ? null : GoRouterState.of(context).pageKey;
    _isVisible = _isCurrentRoute;
    delegate?.addListener(_onRouteChanged);
  }

  bool get _isCurrentRoute =>
      _pageKey != null &&
      _routerDelegate?.currentConfiguration.lastOrNull?.pageKey == _pageKey;

  void _onRouteChanged() {
    final isVisible = _isCurrentRoute;
    final becameVisible = isVisible && !_isVisible;
    _isVisible = isVisible;
    if (!becameVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isVisible) {
        unawaited(context.read<BlacklistCubit>().load());
      }
    });
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BlacklistCubit, BlacklistState>(
          listenWhen: (previous, current) =>
              !previous.loadMoreError && current.loadMoreError,
          listener: (context, state) => showAppFailureSnackBar(
            context,
            message: state.requestFailureMessage,
          ),
        ),
        BlocListener<BlacklistCubit, BlacklistState>(
          listenWhen: (previous, current) =>
              previous.actionFailureCount != current.actionFailureCount,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.actionFailureMessage ??
                        context.l10n.blacklistActionFailure,
                  ),
                ),
              );
          },
        ),
      ],
      child: BlocBuilder<BlacklistCubit, BlacklistState>(
        builder: (context, state) {
          final l10n = context.l10n;
          if (state.status == BlacklistStatus.loading) {
            return FollowListSkeleton(
              semanticLabel: l10n.followListLoadingLabel,
            );
          }
          if (state.status == BlacklistStatus.failure) {
            return AppRetryView(
              onRetry: () => unawaited(context.read<BlacklistCubit>().load()),
            );
          }
          if (state.users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Text(
                  l10n.blacklistEmptyLabel,
                  textAlign: TextAlign.center,
                  style: context.appTypography.statusBody.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final cubit = context.read<BlacklistCubit>();
              final scrollingDown =
                  notification is ScrollUpdateNotification &&
                      (notification.scrollDelta ?? 0) > 0 ||
                  notification is OverscrollNotification &&
                      notification.overscroll > 0;
              if (notification.depth == 0 &&
                  scrollingDown &&
                  notification.metrics.extentAfter < 200 &&
                  state.hasMore &&
                  !state.loadingMore &&
                  (!state.loadMoreError ||
                      notification is ScrollUpdateNotification &&
                          notification.dragDetails != null ||
                      notification is OverscrollNotification &&
                          notification.dragDetails != null)) {
                unawaited(cubit.loadMore());
              }
              return false;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.users.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == state.users.length) {
                  if (state.loadingMore) {
                    return FollowListSkeleton(
                      semanticLabel: l10n.followListLoadingMoreLabel,
                      itemCount: 1,
                      shrinkWrap: true,
                    );
                  }
                  if (!state.hasMore) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(child: Text(l10n.followListPullUpLabel)),
                  );
                }
                final user = state.users[index];
                final name = user.name.isEmpty ? user.screenName : user.name;
                return ListTile(
                  key: ValueKey(user.id),
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  horizontalTitleGap: AppSpacing.sm,
                  onTap: () =>
                      unawaited(openUserProfileRoute(context, userId: user.id)),
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
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: Size(
                        context.appSizing.scaled(_blacklistButtonWidth),
                        context.appSizing.scaled(_blacklistButtonHeight),
                      ),
                      maximumSize: Size(
                        context.appSizing.scaled(_blacklistButtonWidth),
                        context.appSizing.scaled(_blacklistButtonHeight),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: state.removingIds.contains(user.id)
                        ? null
                        : () => unawaited(_confirmRemove(context, user.id)),
                    child: state.removingIds.contains(user.id)
                        ? SizedBox.square(
                            dimension: context.appSizing.scaled(AppSpacing.md),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: l10n.blacklistRemoveLoadingLabel,
                            ),
                          )
                        : Text(l10n.blacklistRemoveLabel),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, String userId) {
    return showAppAlertDialog(
      context,
      title: context.l10n.blacklistRemoveDialogTitle,
      content: context.l10n.confirmationDialogContent,
      cancelAction: AppDialogAction(
        label: context.l10n.blacklistRemoveDialogCancelLabel,
        color: context.appColors.textBase,
        onPressed: () {},
      ),
      confirmAction: AppDialogAction(
        label: context.l10n.blacklistRemoveDialogConfirmLabel,
        color: context.appColors.destructiveAction,
        onSubmit: () => context.read<BlacklistCubit>().remove(userId),
        failureLabel: context.l10n.blacklistActionFailure,
        onPressed: () {},
      ),
    );
  }
}

const _blacklistButtonWidth = 80.0;
const _blacklistButtonHeight = 34.0;
