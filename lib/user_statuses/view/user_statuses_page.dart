import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Statuses posted by one user.
class UserStatusesPage extends StatelessWidget {
  /// Creates a user statuses page.
  const UserStatusesPage({required this.userId, super.key});

  /// Identifier of the user whose statuses are displayed.
  final String userId;

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

    return ScrollToTopScope(
      controller: ScrollToTopController(),
      child: Scaffold(
        appBar: AppSubpageAppBar(
          title: context.l10n.userProfileMessagesLabel,
          toolbarHeight: context.appSizing.appBarToolbarHeight,
        ),
        body: BlocProvider(
          key: ValueKey((StatusFeed.user, accountId, userId)),
          create: (context) => StatusListBloc(
            statusRepository: context.read<StatusRepository>(),
            feed: StatusFeed.user,
            accountId: accountId,
            userId: userId,
          )..add(const StatusListInitialLoadRequested()),
          child: StatusList(
            personalEmpty: userId == accountId,
            layout: StatusListLayout.moments,
          ),
        ),
      ),
    );
  }
}
