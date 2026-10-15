import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/profile/cubit/follow_list_cubit.dart';
import 'package:dan/profile/view/follow_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Displays a user's following or followers list.
class FollowListPage extends StatelessWidget {
  /// Creates a follow list page.
  const FollowListPage({
    required this.userId,
    required this.followers,
    super.key,
  });

  final String userId;
  final bool followers;

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
    final title = followers
        ? context.l10n.userProfileFollowersLabel
        : context.l10n.userProfileFollowingLabel;
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: title,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: BlocProvider(
        key: ValueKey((accountId, userId, followers)),
        create: (context) {
          final cubit = FollowListCubit(
            repository: context.read<UserRepository>(),
            userId: userId,
            followers: followers,
            accountId: accountId,
          );
          unawaited(cubit.load());
          return cubit;
        },
        child: FollowListView(
          followers: followers,
          personal: userId == accountId,
        ),
      ),
    );
  }
}
