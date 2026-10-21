import 'dart:async';

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

/// Route boundary for application settings.
class SettingsPage extends StatelessWidget {
  /// Creates a settings page.
  const SettingsPage({super.key});

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
        onAboutPressed: () => _openDocument(
          context,
          AppRouteName.about,
        ),
        onUserAgreementPressed: () => _openDocument(
          context,
          AppRouteName.userAgreement,
        ),
        onPrivacyPolicyPressed: () => _openDocument(
          context,
          AppRouteName.privacyPolicy,
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

  void _openDocument(BuildContext context, String routeName) {
    unawaited(
      context.pushNamed<void>(
        routeName,
        pathParameters: {
          'userId': GoRouterState.of(context).pathParameters['userId']!,
        },
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
