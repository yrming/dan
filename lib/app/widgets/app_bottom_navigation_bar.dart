import 'dart:async';

import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Four-tab application navigation bar owned by the authenticated shell.
class AppBottomNavigationBar extends StatelessWidget {
  /// Creates the application navigation bar.
  const AppBottomNavigationBar({
    required this.selectedTab,
    required this.onTabSelected,
    this.mentionsBadgeCount,
    this.mineBadgeCount,
    this.onCreateStatusPressed,
    this.isCreateStatusSelected = false,
    super.key,
  });

  /// Currently selected tab.
  final AppShellTab selectedTab;

  /// Called when an unselected tab is tapped.
  final ValueChanged<AppShellTab> onTabSelected;

  /// Number of unread mentions shown above the mentions tab.
  final int? mentionsBadgeCount;

  /// Number of unread direct messages shown above the mine tab.
  final int? mineBadgeCount;

  /// Called when the central create-status action is tapped.
  final VoidCallback? onCreateStatusPressed;

  /// Whether the central create-status action is selected.
  final bool isCreateStatusSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizing = context.appSizing;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sizing.bottomNavigationBarHeight,
          child: Row(
            children: [
              _BottomNavigationItem(
                label: context.l10n.homePageTitle,
                semanticLabel: context.l10n.homePageTitle,
                tab: AppShellTab.home,
                selectedTab: selectedTab,
                onTap: onTabSelected,
              ),
              _BottomNavigationItem(
                label: context.l10n.mentionsPageTitle,
                semanticLabel: (mentionsBadgeCount ?? 0) > 0
                    ? context.l10n.mentionsNavigationLabelWithUnreadCount(
                        mentionsBadgeCount!,
                      )
                    : context.l10n.mentionsPageTitle,
                tab: AppShellTab.mentions,
                selectedTab: selectedTab,
                onTap: onTabSelected,
                badgeCount: mentionsBadgeCount,
              ),
              _BottomNavigationAction(
                semanticLabel: context.l10n.createStatusLabel,
                onTap: onCreateStatusPressed,
                selected: isCreateStatusSelected,
              ),
              _BottomNavigationItem(
                label: context.l10n.browsePageTitle,
                semanticLabel: context.l10n.browsePageTitle,
                tab: AppShellTab.browse,
                selectedTab: selectedTab,
                onTap: onTabSelected,
              ),
              _BottomNavigationItem(
                label: context.l10n.userProfileTabLabel,
                semanticLabel: context.l10n.userProfilePageTitle,
                tab: AppShellTab.mine,
                selectedTab: selectedTab,
                onTap: onTabSelected,
                badgeCount: mineBadgeCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationAction extends StatelessWidget {
  const _BottomNavigationAction({
    required this.semanticLabel,
    required this.onTap,
    required this.selected,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sizing = context.appSizing;
    final foregroundColor = colors.textBase;
    final strokeWidth = sizing.createStatusButtonStrokeWidth;
    final plusSize = sizing.createStatusButtonPlusSize;
    final visual = DecoratedBox(
      key: const Key('app-bottom-navigation-create-status-visual'),
      decoration: BoxDecoration(
        border: Border.all(
          color: foregroundColor,
          width: strokeWidth,
        ),
        borderRadius: BorderRadius.circular(
          AppLayout.buttonRadius,
        ),
      ),
      child: SizedBox(
        width: sizing.createStatusButtonWidth,
        height: sizing.createStatusButtonHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: plusSize,
              height: strokeWidth,
              child: ColoredBox(
                key: const Key(
                  'app-bottom-navigation-create-status-plus-horizontal',
                ),
                color: foregroundColor,
              ),
            ),
            SizedBox(
              width: strokeWidth,
              height: plusSize,
              child: ColoredBox(
                key: const Key(
                  'app-bottom-navigation-create-status-plus-vertical',
                ),
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );

    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: true,
        child: InkWell(
          key: const Key('app-bottom-navigation-create-status'),
          onTap: onTap == null
              ? null
              : () {
                  unawaited(HapticFeedback.lightImpact());
                  onTap!();
                },
          child: Center(child: visual),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.semanticLabel,
    required this.tab,
    required this.selectedTab,
    required this.onTap,
    required this.label,
    this.badgeCount,
  });

  final String label;
  final String semanticLabel;
  final AppShellTab tab;
  final AppShellTab selectedTab;
  final ValueChanged<AppShellTab> onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final selected = tab == selectedTab;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: selected
          ? context.appTypography.selectedNavigationLabel
          : context.appTypography.navigationLabel,
    );
    final visual = (badgeCount ?? 0) > 0
        ? Badge.count(
            key: Key('app-bottom-navigation-${tab.name}-badge'),
            count: badgeCount!,
            offset: const Offset(8, -4),
            child: labelText,
          )
        : labelText;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: true,
        child: InkWell(
          key: Key('app-bottom-navigation-${tab.name}'),
          onTap: selected ? null : () => onTap(tab),
          child: Center(child: visual),
        ),
      ),
    );
  }
}
