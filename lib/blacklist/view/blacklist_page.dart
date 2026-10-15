import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/blacklist/cubit/blacklist_cubit.dart';
import 'package:dan/blacklist/view/blacklist_view.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

class BlacklistPage extends StatelessWidget {
  const BlacklistPage({super.key});

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
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: context.l10n.userProfileBlacklistLabel,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: BlocProvider(
        key: ValueKey(accountId),
        create: (context) {
          final cubit = BlacklistCubit(
            repository: context.read<UserRepository>(),
          );
          unawaited(cubit.load());
          return cubit;
        },
        child: const BlacklistView(),
      ),
    );
  }
}
