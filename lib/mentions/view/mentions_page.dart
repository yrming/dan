import 'dart:async';

import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/app/navigation/app_shell_tab_scope.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Mentions timeline page.
class MentionsPage extends StatelessWidget {
  /// Creates a mentions page.
  const MentionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final accountId = context.select<AuthenticationBloc, String?>(
      (bloc) => switch (bloc.state) {
        AuthenticationAuthenticated(:final snapshot) =>
          snapshot.activeAccount?.id,
        _ => null,
      },
    );
    if (accountId == null) return const SizedBox.shrink();

    return BlocProvider(
      key: ValueKey((StatusFeed.mentions, accountId)),
      create: (context) => StatusListBloc(
        statusRepository: context.read<StatusRepository>(),
        feed: StatusFeed.mentions,
        accountId: accountId,
      )..add(const StatusListInitialLoadRequested()),
      child: const _MentionsRefreshCoordinator(
        child: StatusList(scrollToTopKey: AppShellTab.mentions),
      ),
    );
  }
}

/// Reloads the mentions timeline on tab activation and refreshes the
/// notification counters afterwards.
///
/// Fanfou clears the unread-mention counter only when
/// `account/notification.json` follows a mentions-timeline request, so the
/// counters are refreshed here instead of on tab activation itself.
class _MentionsRefreshCoordinator extends StatefulWidget {
  const _MentionsRefreshCoordinator({required this.child});

  final Widget child;

  @override
  State<_MentionsRefreshCoordinator> createState() =>
      _MentionsRefreshCoordinatorState();
}

class _MentionsRefreshCoordinatorState
    extends State<_MentionsRefreshCoordinator> {
  AppShellTab? _visibleTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedTab = AppShellTabScope.of(context);
    final previousTab = _visibleTab;
    _visibleTab = selectedTab;
    // The first activation is covered by the initial load.
    if (previousTab == null || selectedTab == previousTab) return;
    if (selectedTab == AppShellTab.mentions) {
      context.read<StatusListBloc>().add(const StatusListRefreshRequested());
    }
  }

  bool _isFetching(StatusListState state) {
    return state.status == StatusListStatus.loading ||
        state.refreshStatus == StatusRefreshStatus.inProgress ||
        state.loadMoreStatus == StatusLoadMoreStatus.inProgress;
  }

  bool _hasFetchFailure(StatusListState state) {
    return state.status == StatusListStatus.failure ||
        state.refreshStatus == StatusRefreshStatus.failure ||
        state.loadMoreStatus == StatusLoadMoreStatus.failure;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StatusListBloc, StatusListState>(
      listenWhen: (previous, current) =>
          _isFetching(previous) &&
          !_isFetching(current) &&
          !_hasFetchFailure(current),
      listener: (context, state) {
        unawaited(context.read<NotificationCountsCubit>().refresh());
      },
      child: widget.child,
    );
  }
}
