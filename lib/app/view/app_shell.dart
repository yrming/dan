import 'dart:async';

import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/app/navigation/app_shell_tab_scope.dart';
import 'package:dan/app/navigation/direct_message_navigation.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_shell_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Main authenticated application shell.
class AppShell extends StatefulWidget {
  /// Creates an authenticated shell around [navigationShell].
  const AppShell({
    required this.navigationShell,
    required this.showBottomNavigationBar,
    required this.activeUserId,
    super.key,
  });

  /// Stateful tab navigation shell.
  final StatefulNavigationShell navigationShell;

  /// Whether the shell is displaying one of its four tab roots.
  final bool showBottomNavigationBar;

  /// Identifier used to open settings for the active account.
  final String activeUserId;

  static const double appBarToolbarHeight = AppLayout.appBarToolbarHeight;
  static const double bottomNavigationBarHeight =
      AppLayout.bottomNavigationBarHeight;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scrollToTopController = ScrollToTopController();
  late AppShellTab _selectedTab = AppShellTab.fromIndex(
    widget.navigationShell.currentIndex,
  );

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedTab = AppShellTab.fromIndex(
      widget.navigationShell.currentIndex,
    );
    if (selectedTab == _selectedTab) return;
    _selectedTab = selectedTab;
    // The mentions tab reloads its timeline first and refreshes the
    // notification counters afterwards; refreshing here would race with the
    // timeline request and keep stale unread counts.
    if (selectedTab == AppShellTab.mine) {
      unawaited(context.read<NotificationCountsCubit>().refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = _selectedTab;
    final sizing = context.appSizing;

    return ScrollToTopScope(
      controller: _scrollToTopController,
      child: Scaffold(
        appBar: !widget.showBottomNavigationBar
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(sizing.appBarToolbarHeight),
                child:
                    BlocSelector<
                      NotificationCountsCubit,
                      NotificationCountsState,
                      int?
                    >(
                      selector: (state) => state.directMessages,
                      builder: (context, directMessagesCount) => AppShellAppBar(
                        key: ValueKey(selectedTab),
                        selectedTab: selectedTab,
                        toolbarHeight: sizing.appBarToolbarHeight,
                        directMessagesCount: directMessagesCount,
                        onMineSettingsPressed: () => unawaited(
                          context.pushNamed<void>(
                            AppRouteName.settings,
                            pathParameters: {'userId': widget.activeUserId},
                          ),
                        ),
                        onMineSearchPressed: () => unawaited(
                          context.pushNamed<void>(
                            AppRouteName.search,
                            queryParameters: {'scope': 'mine'},
                          ),
                        ),
                        onBrowseSearchPressed: () => unawaited(
                          context.pushNamed<void>(AppRouteName.search),
                        ),
                        onMineAccountManagementPressed: () => unawaited(
                          openDirectMessageListRoute(context),
                        ),
                      ),
                    ),
              ),
        body: AppShellTabScope(
          selectedTab: selectedTab,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: widget.showBottomNavigationBar
            ? BlocSelector<
                NotificationCountsCubit,
                NotificationCountsState,
                (int?, int?)
              >(
                selector: (state) => (state.mentions, state.directMessages),
                builder: (context, counts) => AppBottomNavigationBar(
                  selectedTab: selectedTab,
                  mentionsBadgeCount: counts.$1,
                  mineBadgeCount: counts.$2,
                  onTabSelected: (tab) =>
                      widget.navigationShell.goBranch(tab.index),
                  onCreateStatusPressed: () => unawaited(
                    context.pushNamed<void>(AppRouteName.statusComposer),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
