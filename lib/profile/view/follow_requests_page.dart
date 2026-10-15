import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/profile/cubit/follow_requests_cubit.dart';
import 'package:dan/profile/view/follow_requests_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

class FollowRequestsPage extends StatelessWidget {
  const FollowRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: context.l10n.userProfileFollowRequestsLabel,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: BlocProvider(
        create: (context) {
          final cubit = FollowRequestsCubit(
            repository: context.read<UserRepository>(),
          );
          unawaited(cubit.load());
          return cubit;
        },
        child: const FollowRequestsView(),
      ),
    );
  }
}
