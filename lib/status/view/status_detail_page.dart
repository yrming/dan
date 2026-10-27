import 'dart:async';

import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/cubit/status_detail_cubit.dart';
import 'package:dan/status/widgets/status_detail_skeleton.dart';
import 'package:dan/status/widgets/status_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:status_repository/status_repository.dart' as status_repository;
import 'package:user_repository/user_repository.dart';

/// Shows a single status.
class StatusDetailPage extends StatelessWidget {
  /// Creates a status detail page.
  const StatusDetailPage({
    required this.userId,
    required this.statusId,
    this.initialStatus,
    super.key,
  });

  /// User id from the route path.
  final String userId;

  /// Status id from the route path.
  final String statusId;

  /// Status supplied by an in-app list navigation, when available.
  final status_repository.Status? initialStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: context.l10n.statusDetailPageTitle,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: BlocProvider(
        create: (context) {
          final cubit = StatusDetailCubit(
            userRepository: context.read<UserRepository>(),
            statusRepository: context
                .read<status_repository.StatusRepository>(),
            statusId: statusId,
            initialStatus: initialStatus,
          );
          unawaited(cubit.load());
          return cubit;
        },
        child: StatusDetailView(
          userId: userId,
          statusId: statusId,
        ),
      ),
    );
  }
}

/// Renders one status detail.
class StatusDetailView extends StatelessWidget {
  /// Creates a status detail view.
  const StatusDetailView({
    required this.userId,
    required this.statusId,
    super.key,
  });

  /// User id from the route path.
  final String userId;

  /// Status id from the route path.
  final String statusId;

  @override
  Widget build(BuildContext context) {
    return BlocListener<StatusDetailCubit, StatusDetailState>(
      listenWhen: (previous, current) =>
          previous.favoriteActionStatus != current.favoriteActionStatus &&
          current.favoriteActionStatus != StatusFavoriteActionStatus.initial,
      listener: (context, state) {
        final message = switch (state.favoriteActionStatus) {
          StatusFavoriteActionStatus.favorited =>
            context.l10n.statusFavoriteSuccess,
          StatusFavoriteActionStatus.unfavorited =>
            context.l10n.statusUnfavoriteSuccess,
          _ =>
            state.favoriteActionMessage ?? context.l10n.statusFavoriteFailure,
        };
        showAppToast(context, message);
      },
      child: BlocBuilder<StatusDetailCubit, StatusDetailState>(
        builder: (context, state) {
          if (state.isResolvingReply) {
            return StatusDetailSkeleton(
              semanticLabel: context.l10n.statusDetailLoadingLabel,
              contextSemanticLabel: context.l10n.statusContextLoadingLabel,
            );
          }
          return switch (state.status) {
            StatusDetailStatus.initial || StatusDetailStatus.loading => Center(
              child: Text(context.l10n.statusDetailLoadingLabel),
            ),
            StatusDetailStatus.failure => _StatusDetailFailure(
              onRetry: () => context.read<StatusDetailCubit>().retry(),
            ),
            StatusDetailStatus.success => _StatusDetailContent(
              state: state,
            ),
          };
        },
      ),
    );
  }
}

class _StatusDetailContent extends StatelessWidget {
  const _StatusDetailContent({required this.state});

  final StatusDetailState state;

  @override
  Widget build(BuildContext context) {
    final status = state.statusDetail;
    if (status == null) {
      return const SizedBox.shrink();
    }

    final sizing = context.appSizing;
    return ListView(
      key: const Key('status-detail-content'),
      children: [
        if (state.originUnavailable)
          StatusListItem(
            status: status.copyWith(
              text: context.l10n.statusOriginUnavailableLabel,
            ),
            enableStatusDetailNavigation: false,
            showMetadata: false,
            photoHeroScope: AppRouteName.statusDetail,
          )
        else
          StatusListItem(
            status: status,
            enableStatusDetailNavigation: false,
            showSource: true,
            showAbsoluteTimestamp: true,
            onStatusFavoriteToggle: () =>
                context.read<StatusDetailCubit>().toggleFavorite(),
            photoHeroScope: AppRouteName.statusDetail,
            onStatusDelete: () => context.read<StatusDetailCubit>().delete(),
            onStatusDeleted: () {
              if (context.mounted) context.pop();
            },
          ),
        if (state.replies.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start:
                  sizing.scaled(AppSpacing.md) +
                  sizing.statusAvatarSize +
                  sizing.scaled(10),
              end: sizing.scaled(AppSpacing.md),
              bottom: sizing.scaled(AppSpacing.md),
            ),
            child: Material(
              color:
                  context.appColors.wechatStatusActionBackground ??
                  Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(
                sizing.scaled(AppLayout.statusContextRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: sizing.scaled(AppSpacing.xs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: sizing.scaled(AppSpacing.xxs),
                  children: [
                    for (final reply in state.replies)
                      StatusListItem(
                        key: ValueKey(reply.id),
                        status: reply,
                        isContextReply: true,
                        photoHeroScope: AppRouteName.statusDetail,
                        onStatusDelete: () => context
                            .read<StatusDetailCubit>()
                            .deleteReply(reply.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (state.contextStatus == StatusDetailStatus.failure)
          AppRetryView(
            message: context.l10n.statusContextFailureLabel,
            onRetry: () => context.read<StatusDetailCubit>().retry(),
          ),
      ],
    );
  }
}

class _StatusDetailFailure extends StatelessWidget {
  const _StatusDetailFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppRetryView(onRetry: onRetry);
}
