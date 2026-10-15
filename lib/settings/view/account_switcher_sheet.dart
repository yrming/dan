import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

/// Shows the stored-account switcher using the application action-sheet style.
Future<void> showAccountSwitcherSheet(
  BuildContext context, {
  VoidCallback? onAddAccountPressed,
}) {
  final authenticationBloc = context.read<AuthenticationBloc>();
  final accounts = switch (authenticationBloc.state) {
    AuthenticationAuthenticated(:final snapshot) => snapshot.accounts,
    AuthenticationUnauthenticated(:final snapshot) => snapshot.accounts,
    _ => const <AuthenticatedAccount>[],
  };
  final activeAccountId = switch (authenticationBloc.state) {
    AuthenticationAuthenticated(:final snapshot) => snapshot.activeAccount?.id,
    _ => null,
  };

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.appColors.actionSheetBackground,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: _AccountSwitcherSheet(
          accounts: accounts,
          activeAccountId: activeAccountId,
          onAccountSelected: (accountId) {
            Navigator.of(sheetContext).pop();
            if (accountId != activeAccountId) {
              authenticationBloc.add(
                AuthenticationAccountSwitchRequested(accountId),
              );
            }
          },
          onAddAccountPressed: () {
            Navigator.of(sheetContext).pop();
            onAddAccountPressed?.call();
          },
        ),
      ),
    ),
  );
}

class _AccountSwitcherSheet extends StatelessWidget {
  const _AccountSwitcherSheet({
    required this.accounts,
    required this.activeAccountId,
    required this.onAccountSelected,
    required this.onAddAccountPressed,
  });

  final List<AuthenticatedAccount> accounts;
  final String? activeAccountId;
  final ValueChanged<String> onAccountSelected;
  final VoidCallback onAddAccountPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.md,
      children: [
        _AccountSwitcherGroup(
          children: [
            for (final account in accounts)
              _AccountSwitcherAccountItem(
                account: account,
                selected: account.id == activeAccountId,
                onPressed: () => onAccountSelected(account.id),
              ),
            _AccountSwitcherAddItem(onPressed: onAddAccountPressed),
          ],
        ),
      ],
    );
  }
}

class _AccountSwitcherGroup extends StatelessWidget {
  const _AccountSwitcherGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.bgBase,
      borderRadius: BorderRadius.circular(AppLayout.actionSheetGroupRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              SizedBox(
                width: double.infinity,
                height: AppLayout.actionSheetDividerThickness,
                child: ColoredBox(color: context.appColors.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _AccountSwitcherAccountItem extends StatelessWidget {
  const _AccountSwitcherAccountItem({
    required this.account,
    required this.selected,
    required this.onPressed,
  });

  final AuthenticatedAccount account;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final displayName = account.name.isEmpty
        ? account.screenName
        : account.name;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onPressed,
      child: SizedBox(
        height: sizing.scaled(64),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: sizing.scaled(AppSpacing.md),
          ),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: account.avatarUrl,
                size: sizing.scaled(40),
                semanticLabel: displayName,
                borderColor: context.appColors.divider,
                borderWidth: 0.5,
              ),
              SizedBox(width: sizing.scaled(AppSpacing.sm)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      account.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                SizedBox(width: sizing.scaled(AppSpacing.sm)),
                Icon(
                  RemixIcons.check_line,
                  size: sizing.scaled(AppLayout.actionSheetIconSize),
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSwitcherAddItem extends StatelessWidget {
  const _AccountSwitcherAddItem({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return SizedBox(
      height: sizing.scaled(64),
      child: ListTile(
        minTileHeight: sizing.scaled(64),
        titleAlignment: ListTileTitleAlignment.center,
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: sizing.scaled(AppSpacing.md),
        ),
        horizontalTitleGap: sizing.scaled(AppSpacing.sm),
        onTap: onPressed,
        leading: Container(
          width: sizing.scaled(40),
          height: sizing.scaled(40),
          decoration: BoxDecoration(
            color: context.appColors.groupedBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.appColors.divider,
              width: 0.5,
            ),
          ),
          child: Icon(
            RemixIcons.add_line,
            size: sizing.scaled(AppLayout.actionSheetIconSize),
            color: context.appColors.textSecondary,
          ),
        ),
        title: Text(
          context.l10n.addAccountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
