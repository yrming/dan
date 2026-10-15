import 'dart:async';

import 'package:dan/app/configuration/app_links.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/view/account_switcher_sheet.dart';
import 'package:dan/settings/view/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Opens an external link from settings.
typedef SettingsExternalLinkLauncher = Future<bool> Function(Uri uri);

/// Route boundary for application settings.
class SettingsPage extends StatelessWidget {
  /// Creates a settings page.
  const SettingsPage({
    this.externalLinkLauncher = AppLinks.openExternal,
    super.key,
  });

  /// Opens a legal document when its settings row is tapped.
  final SettingsExternalLinkLauncher externalLinkLauncher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.groupedBackground,
      appBar: AppSubpageAppBar(
        showBottomDivider: false,
        backgroundColor: context.appColors.groupedBackground,
        title: context.l10n.settingsPageTitle,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: SettingsView(
        onFontSizePressed: () => context.pushNamed<void>(
          AppRouteName.fontSize,
          pathParameters: {
            'userId': GoRouterState.of(context).pathParameters['userId']!,
          },
        ),
        onBlacklistPressed: () => context.pushNamed<void>(
          AppRouteName.blacklist,
        ),
        onAboutPressed: () => showAboutDialog(
          context: context,
          applicationName: context.l10n.loginBrandLogoLabel,
        ),
        onUserAgreementPressed: () => unawaited(
          externalLinkLauncher(AppLinks.userAgreement),
        ),
        onPrivacyPolicyPressed: () => unawaited(
          externalLinkLauncher(AppLinks.privacyPolicy),
        ),
        onSwitchAccountPressed: () => showAccountSwitcherSheet(
          context,
          onAddAccountPressed: () => context.pushNamed<void>(
            AppRouteName.addAccount,
            pathParameters: {
              'userId': GoRouterState.of(context).pathParameters['userId']!,
            },
          ),
        ),
        onSignOutPressed: () => unawaited(_showSignOutDialog(context)),
      ),
    );
  }

  Future<void> _showSignOutDialog(BuildContext context) {
    final accountName = switch (context.read<AuthenticationBloc>().state) {
      AuthenticationAuthenticated(:final snapshot) =>
        snapshot.activeAccount?.name ?? '',
      _ => '',
    };
    return showAppAlertDialog(
      context,
      title: context.l10n.signOutDialogTitle(accountName),
      content: context.l10n.confirmationDialogContent,
      cancelAction: AppDialogAction(
        label: context.l10n.signOutDialogCancelLabel,
        color: context.appColors.textBase,
        onPressed: () {},
      ),
      confirmAction: AppDialogAction(
        label: context.l10n.signOutDialogConfirmLabel,
        color: context.appColors.destructiveAction,
        onPressed: () => context.read<AuthenticationBloc>().add(
          const AuthenticationSignOutRequested(),
        ),
      ),
    );
  }
}
