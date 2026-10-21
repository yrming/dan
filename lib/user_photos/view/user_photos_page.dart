import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Photo statuses posted by one user.
class UserPhotosPage extends StatelessWidget {
  /// Creates a user photos page.
  const UserPhotosPage({
    required this.userId,
    this.profileItemCount,
    super.key,
  });

  /// Identifier of the user whose photo statuses are displayed.
  final String userId;

  /// Count shown on the profile entry used to open this list.
  final int? profileItemCount;

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
          title: context.l10n.userProfilePhotosLabel,
          toolbarHeight: context.appSizing.appBarToolbarHeight,
        ),
        body: BlocProvider(
          key: ValueKey((StatusFeed.photos, accountId, userId)),
          create: (context) => StatusListBloc(
            statusRepository: context.read<StatusRepository>(),
            feed: StatusFeed.photos,
            accountId: accountId,
            userId: userId,
            profileItemCount: profileItemCount,
          )..add(const StatusListInitialLoadRequested()),
          child: const StatusList(
            layout: StatusListLayout.monthlyPhotos,
          ),
        ),
      ),
    );
  }
}
