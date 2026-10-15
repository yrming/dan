import 'dart:async';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/navigation/direct_message_navigation.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/app_action_sheet.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/profile/cubit/user_profile_cubit.dart';
import 'package:dan/profile/cubit/user_profile_state.dart';
import 'package:dan/profile/view/user_profile_view.dart';
import 'package:dan/search/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:user_repository/user_repository.dart';

/// Shell route boundary for the active account profile.
class MinePage extends StatelessWidget {
  /// Creates the active account profile page.
  const MinePage({required this.activeAccount, super.key});

  /// Currently authenticated account.
  final AuthenticatedAccount activeAccount;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<UserRepository>();
    return BlocProvider(
      create: (_) {
        final cubit = UserProfileCubit(
          userRepository: repository,
          userId: activeAccount.id,
          initialProfile:
              repository.getCachedUser(activeAccount.id) ??
              _profileFromAccount(activeAccount),
          activeAccountId: activeAccount.id,
          authenticationRepository: context.read<AuthenticationRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _UserProfileContent(
        userId: activeAccount.id,
        isCurrentUser: true,
      ),
    );
  }
}

/// Independent route boundary for any user's profile.
class UserProfilePage extends StatelessWidget {
  /// Creates a user profile page.
  const UserProfilePage({
    required this.userId,
    this.activeAccount,
    this.initialProfile,
    super.key,
  });

  /// Identifier of the displayed user.
  final String userId;

  /// Currently authenticated account, when available.
  final AuthenticatedAccount? activeAccount;

  /// Summary supplied by the source screen for immediate rendering.
  final UserProfile? initialProfile;

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = activeAccount?.id == userId;
    final userRepository = context.read<UserRepository>();
    final resolvedInitialProfile =
        initialProfile ??
        userRepository.getCachedUser(userId) ??
        (isCurrentUser ? _profileFromAccount(activeAccount!) : null);

    return BlocProvider(
      create: (_) {
        final cubit = UserProfileCubit(
          userRepository: userRepository,
          userId: userId,
          initialProfile: resolvedInitialProfile,
          activeAccountId: activeAccount?.id,
          authenticationRepository: isCurrentUser
              ? context.read<AuthenticationRepository>()
              : null,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: Scaffold(
        appBar: _UserProfileAppBar(
          isCurrentUser: isCurrentUser,
          userId: userId,
          toolbarHeight: context.appSizing.appBarToolbarHeight,
        ),
        body: _UserProfileContent(
          userId: userId,
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
  }
}

class _UserProfileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _UserProfileAppBar({
    required this.isCurrentUser,
    required this.userId,
    required this.toolbarHeight,
  });

  final bool isCurrentUser;
  final String userId;
  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final gender = context.select<UserProfileCubit, String?>(
      (cubit) => cubit.state.profile?.gender,
    );
    final scope = isCurrentUser
        ? SearchScope.mine
        : searchScopeForGender(gender);
    return AppSubpageAppBar(
      title: null,
      toolbarHeight: toolbarHeight,
      showBottomDivider: false,
      actionsPadding: const EdgeInsetsDirectional.only(
        end: AppSpacing.xxs,
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.userProfileSearchLabel,
          icon: Icon(
            RemixIcons.search_line,
            color: context.appColors.textBase,
          ),
          onPressed: () => unawaited(
            context.pushNamed<void>(
              AppRouteName.search,
              queryParameters: {
                'scope': searchScopeQueryValue(scope),
                if (!isCurrentUser) 'userId': userId,
              },
            ),
          ),
        ),
        if (isCurrentUser) ...[
          IconButton(
            tooltip: context.l10n.directMessagesPageTitle,
            icon: Icon(
              RemixIcons.mail_line,
              color: context.appColors.textBase,
            ),
            onPressed: () => unawaited(openDirectMessageListRoute(context)),
          ),
        ] else ...[
          IconButton(
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            icon: Icon(
              RemixIcons.more_line,
              color: context.appColors.textBase,
            ),
            onPressed: () => unawaited(_showUserActions(context)),
          ),
        ],
      ],
    );
  }
}

Future<void> _showUserActions(BuildContext context) async {
  final cubit = context.read<UserProfileCubit>();
  await cubit.loadBlocked();
  if (!context.mounted) return;
  final state = cubit.state;
  if (state is! UserProfileLoadSuccess || state.isBlocked == null) return;
  final isBlocked = state.isBlocked!;
  final l10n = context.l10n;
  final color = context.appColors.destructiveAction;
  await showAppActionSheet(
    context,
    sheetKey: const Key('user-profile-action-sheet'),
    groups: [
      AppActionSheetGroup(
        key: const Key('user-profile-action-group'),
        children: [
          AppActionSheetItem(
            key: const Key('user-profile-block-action'),
            label: isBlocked
                ? l10n.userProfileUnblockLabel
                : l10n.userProfileBlockLabel,
            icon: isBlocked ? RemixIcons.forbid_fill : RemixIcons.forbid_line,
            foregroundColor: color,
            onPressed: () => unawaited(cubit.toggleBlocked()),
          ),
        ],
      ),
    ],
  );
}

class _UserProfileContent extends StatelessWidget {
  const _UserProfileContent({
    required this.userId,
    required this.isCurrentUser,
  });

  final String userId;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserProfileCubit, UserProfileState>(
      listenWhen: (previous, current) =>
          previous is UserProfileLoadSuccess &&
          current is UserProfileLoadSuccess &&
          previous.actionFailureCount != current.actionFailureCount,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (state as UserProfileLoadSuccess).actionFailureMessage ??
                  context.l10n.followActionFailure,
            ),
          ),
        );
      },
      child: BlocListener<UserProfileCubit, UserProfileState>(
        listenWhen: (previous, current) =>
            previous is UserProfileLoadSuccess &&
            current is UserProfileLoadSuccess &&
            (previous.blockActionCount != current.blockActionCount ||
                previous.blockActionFailureCount !=
                    current.blockActionFailureCount),
        listener: (context, state) {
          final success = state as UserProfileLoadSuccess;
          final message =
              success.blockActionMessage ??
              (success.blockActionFailed
                  ? context.l10n.userProfileBlockFailure
                  : success.isBlocked == true
                  ? context.l10n.userProfileBlockSuccess
                  : context.l10n.userProfileUnblockSuccess);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        child: BlocListener<UserProfileCubit, UserProfileState>(
          listenWhen: (previous, current) =>
              previous is UserProfileLoadSuccess &&
              current is UserProfileLoadSuccess &&
              previous.requestSentCount != current.requestSentCount,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.followActionRequestSent),
              ),
            );
          },
          child:
              BlocSelector<
                NotificationCountsCubit,
                NotificationCountsState,
                int?
              >(
                selector: (state) =>
                    isCurrentUser ? state.friendRequests : null,
                builder: (context, friendRequestCount) => UserProfileView(
                  userId: userId,
                  isCurrentUser: isCurrentUser,
                  friendRequestCount: friendRequestCount,
                ),
              ),
        ),
      ),
    );
  }
}

UserProfile _profileFromAccount(AuthenticatedAccount account) {
  return UserProfile(
    id: account.id,
    name: account.name,
    screenName: account.screenName,
    avatarUrl: account.avatarUrl,
    description: account.description,
    location: account.location,
    url: account.url,
    protected: account.protected,
    following: account.following,
    followersCount: account.followersCount,
    friendsCount: account.friendsCount,
    favoritesCount: account.favoritesCount,
    statusesCount: account.statusesCount,
    gender: account.gender,
    photoCount: account.photoCount,
    createdAt: account.createdAt,
    birthday: account.birthday,
  );
}
