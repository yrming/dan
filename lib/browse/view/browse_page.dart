import 'package:dan/authentication/authentication.dart';
import 'package:dan/browse/view/browse_view.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Route boundary for the browse tab.
class BrowsePage extends StatelessWidget {
  /// Creates a browse page.
  const BrowsePage({super.key});

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
      key: ValueKey((StatusFeed.public, accountId)),
      create: (context) => StatusListBloc(
        statusRepository: context.read<StatusRepository>(),
        feed: StatusFeed.public,
        accountId: accountId,
      )..add(const StatusListInitialLoadRequested()),
      child: const BrowseView(),
    );
  }
}
