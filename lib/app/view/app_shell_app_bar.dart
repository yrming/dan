import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// App bar used by the authenticated shell.
class AppShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a shell app bar for [selectedTab].
  const AppShellAppBar({
    required this.selectedTab,
    this.toolbarHeight = AppLayout.appBarToolbarHeight,
    this.directMessagesCount,
    this.onMineSettingsPressed,
    this.onMineSearchPressed,
    this.onBrowseSearchPressed,
    this.onMineAccountManagementPressed,
    super.key,
  });

  /// Currently selected shell tab.
  final AppShellTab selectedTab;

  /// Toolbar height derived from the active appearance scale.
  final double toolbarHeight;

  /// Unread direct-message count shown on the mail action.
  final int? directMessagesCount;

  /// Opens settings from the active account tab.
  final VoidCallback? onMineSettingsPressed;

  /// Opens search from the active account tab.
  final VoidCallback? onMineSearchPressed;

  /// Opens public status search from the browse tab.
  final VoidCallback? onBrowseSearchPressed;

  /// Opens account management from the active account tab.
  final VoidCallback? onMineAccountManagementPressed;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return DoubleTapListener(
      onDoubleTap: () =>
          ScrollToTopScope.maybeOf(context)?.scrollToTop(selectedTab),
      child: AppBar(
        toolbarHeight: toolbarHeight,
        automaticallyImplyLeading: false,
        centerTitle: true,
        shape: selectedTab == AppShellTab.mine ? const Border() : null,
        leading: selectedTab == AppShellTab.mine
            ? IconButton(
                tooltip: context.l10n.userProfileSettingsLabel,
                icon: Icon(
                  RemixIcons.menu_2_line,
                  color: context.appColors.textBase,
                ),
                onPressed: onMineSettingsPressed,
              )
            : null,
        title: _titleFor(context, selectedTab),
        actionsPadding:
            selectedTab == AppShellTab.mine || selectedTab == AppShellTab.browse
            ? const EdgeInsetsDirectional.only(end: AppSpacing.xxs)
            : null,
        actions: selectedTab == AppShellTab.mine
            ? [
                IconButton(
                  tooltip: context.l10n.userProfileSearchLabel,
                  icon: Icon(
                    RemixIcons.search_line,
                    color: context.appColors.textBase,
                  ),
                  onPressed: onMineSearchPressed,
                ),
                IconButton(
                  tooltip: context.l10n.directMessagesPageTitle,
                  icon: _mailIcon(context),
                  onPressed: onMineAccountManagementPressed,
                ),
              ]
            : selectedTab == AppShellTab.browse
            ? [
                IconButton(
                  tooltip: context.l10n.searchPageTitle,
                  icon: Icon(
                    RemixIcons.search_line,
                    color: context.appColors.textBase,
                  ),
                  onPressed: onBrowseSearchPressed,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _mailIcon(BuildContext context) {
    final icon = Icon(
      RemixIcons.mail_line,
      color: context.appColors.textBase,
    );
    final unreadCount = directMessagesCount ?? 0;
    if (unreadCount <= 0) return icon;

    return Badge.count(
      count: unreadCount,
      offset: const Offset(8, -4),
      child: icon,
    );
  }

  Widget? _titleFor(
    BuildContext context,
    AppShellTab selectedTab,
  ) {
    return switch (selectedTab) {
      AppShellTab.home => Text(context.l10n.homePageTitle),
      AppShellTab.mentions => Text(context.l10n.mentionsPageTitle),
      AppShellTab.browse => Text(context.l10n.browsePageTitle),
      AppShellTab.mine => null,
    };
  }
}
