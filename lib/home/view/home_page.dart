import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Home timeline page.
class HomePage extends StatelessWidget {
  /// Creates a home page.
  const HomePage({super.key});

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
      key: ValueKey((StatusFeed.home, accountId)),
      create: (context) => StatusListBloc(
        statusRepository: context.read<StatusRepository>(),
        feed: StatusFeed.home,
        accountId: accountId,
      )..add(const StatusListInitialLoadRequested()),
      child: const StatusList(scrollToTopKey: AppShellTab.home),
    );
  }
}
