import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/profile/cubit/user_profile_cubit.dart';
import 'package:dan/profile/cubit/user_profile_state.dart';
import 'package:dan/profile/widgets/profile_header.dart';
import 'package:dan/profile/widgets/profile_menu_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:user_repository/user_repository.dart';

const _showProfileFollowAction = true;

/// Displays any user using the shared grouped account layout.
class UserProfileView extends StatefulWidget {
  /// Creates a user profile view.
  const UserProfileView({
    required this.userId,
    this.isCurrentUser = false,
    this.friendRequestCount,
    super.key,
  });

  /// Identifier of the displayed user.
  final String userId;

  /// Whether [userId] belongs to the active account.
  final bool isCurrentUser;

  /// Pending follow requests for the active account, when available.
  final int? friendRequestCount;

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  GoRouterDelegate? _routerDelegate;
  ValueKey<String>? _pageKey;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // A cached or synchronously failed request can finish before the listener
    // subscribes. Show its feedback once the scaffold is ready.
    if (context.read<UserProfileCubit>().state is UserProfileLoadFailure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            context.read<UserProfileCubit>().state is UserProfileLoadFailure) {
          _showLoadFailure(context);
        }
      });
    }
  }

  void _showLoadFailure(BuildContext context) =>
      showAppFailureSnackBar(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    final delegate = widget.isCurrentUser ? router?.routerDelegate : null;
    if (delegate == _routerDelegate) return;
    _routerDelegate?.removeListener(_onRouteChanged);
    _routerDelegate = delegate;
    _pageKey = delegate == null ? null : GoRouterState.of(context).pageKey;
    _isVisible = _isCurrentRoute;
    delegate?.addListener(_onRouteChanged);
  }

  bool get _isCurrentRoute =>
      _pageKey != null &&
      _routerDelegate?.currentConfiguration.lastOrNull?.pageKey == _pageKey;

  void _onRouteChanged() {
    final isVisible = _isCurrentRoute;
    final becameVisible = isVisible && !_isVisible;
    _isVisible = isVisible;
    if (!becameVisible) return;
    // Shell branches stay mounted while hidden. Refresh only when this exact
    // profile route becomes the top page again, including root navigator pops.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isVisible) {
        unawaited(context.read<UserProfileCubit>().load());
      }
    });
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserProfileCubit, UserProfileState>(
      listenWhen: (previous, current) =>
          previous is! UserProfileLoadFailure &&
          current is UserProfileLoadFailure,
      listener: (context, state) => _showLoadFailure(context),
      builder: (context, state) {
        final profile =
            state.profile ??
            UserProfile(id: widget.userId, name: '', screenName: widget.userId);
        return _ProfileContent(
          profile: profile,
          state: state,
          isCurrentUser: widget.isCurrentUser,
          friendRequestCount: widget.friendRequestCount,
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.state,
    required this.isCurrentUser,
    required this.friendRequestCount,
  });

  final UserProfile profile;
  final UserProfileState state;
  final bool isCurrentUser;
  final int? friendRequestCount;
  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    // A protected account the active account does not follow hides its
    // content, so its entries explain the limitation instead of navigating.
    final isLocked =
        !isCurrentUser &&
        profile.protected == true &&
        profile.following == false;
    final success = state is UserProfileLoadSuccess
        ? state as UserProfileLoadSuccess
        : null;
    final followActionLabel =
        !_showProfileFollowAction || isCurrentUser || success == null
        ? null
        : profile.following != true
        ? context.l10n.followActionFollow
        : success.followedBy == true
        ? context.l10n.followActionMutual
        : context.l10n.followActionFollowing;
    final followActionIcon = profile.following != true
        ? RemixIcons.add_line
        : success?.followedBy == true
        ? RemixIcons.arrow_left_right_line
        : RemixIcons.check_line;
    return ColoredBox(
      color: context.appColors.groupedBackground,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            ProfileHeader(
              id: profile.id,
              name: profile.name,
              screenName: profile.screenName,
              gender: profile.gender,
              description: profile.description,
              location: profile.location,
              registeredAt: profile.createdAt,
              url: profile.url,
              friendsCount: profile.friendsCount,
              followersCount: profile.followersCount,
              friendRequestCount: friendRequestCount,
              avatarUrl: profile.avatarUrl,
              avatarKey: const Key('user-profile-avatar'),
              followActionLabel: followActionLabel,
              followActionIcon: followActionIcon,
              showFollowActionSkeleton:
                  _showProfileFollowAction &&
                  !isCurrentUser &&
                  (state is UserProfileInitial ||
                      state is UserProfileLoadInProgress),
              followActionLoading: success?.isFollowingUpdating ?? false,
              onFollowActionPressed: followActionLabel == null
                  ? null
                  : context.read<UserProfileCubit>().toggleFollowing,
              onMessagePressed: isCurrentUser
                  ? null
                  : () => unawaited(
                      openDirectMessageConversationRoute(
                        context,
                        userId: profile.id,
                        peerScreenName: profile.screenName,
                      ),
                    ),
              onFollowingTap: () => _openEntry(
                context,
                isLocked,
                () => unawaited(
                  _openProfileList(
                    context,
                    routeName: AppRouteName.following,
                    userId: profile.id,
                  ),
                ),
              ),
              onFollowersTap: () => _openEntry(
                context,
                isLocked,
                () => unawaited(
                  _openProfileList(
                    context,
                    routeName: AppRouteName.followers,
                    userId: profile.id,
                  ),
                ),
              ),
              onFollowRequestsTap: isCurrentUser
                  ? () => unawaited(
                      _openFollowRequests(context),
                    )
                  : null,
            ),
            if (state is UserProfileLoadInProgress && state.profile == null)
              LinearProgressIndicator(
                minHeight: sizing.scaled(AppSpacing.xxs),
                semanticsLabel: context.l10n.userProfileLoadingLabel,
              ),
            if (state.profile != null) ...[
              SizedBox(height: sizing.scaled(AppSpacing.xs)),
              ProfileMenuSection(
                children: [
                  ProfileTile(
                    icon: RemixIcons.message_line,
                    iconColor: context.appColors.textBase,
                    title: context.l10n.userProfileMessagesLabel,
                    value: profile.statusesCount ?? 0,
                    showChevron: !isLocked,
                    onTap: () => _openEntry(context, isLocked, () {
                      unawaited(
                        _openProfileList(
                          context,
                          routeName: AppRouteName.userStatuses,
                          userId: profile.id,
                        ),
                      );
                    }),
                  ),
                  ProfileTile(
                    icon: RemixIcons.multi_image_line,
                    iconColor: context.appColors.textBase,
                    title: context.l10n.userProfilePhotosLabel,
                    value: profile.photoCount ?? 0,
                    showChevron: !isLocked,
                    onTap: () => _openEntry(context, isLocked, () {
                      unawaited(
                        _openProfileList(
                          context,
                          routeName: AppRouteName.userPhotos,
                          userId: profile.id,
                        ),
                      );
                    }),
                  ),
                  ProfileTile(
                    icon: RemixIcons.star_line,
                    iconColor: context.appColors.textBase,
                    title: context.l10n.userProfileFavoritesLabel,
                    value: profile.favoritesCount ?? 0,
                    showChevron: !isLocked,
                    onTap: () => _openEntry(context, isLocked, () {
                      unawaited(
                        _openProfileList(
                          context,
                          routeName: AppRouteName.favorites,
                          userId: profile.id,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
            SizedBox(height: sizing.scaled(AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  void _openEntry(BuildContext context, bool isLocked, VoidCallback navigate) {
    if (isLocked) {
      _showProtectedContentDialog(context);
      return;
    }
    navigate();
  }

  Future<void> _openProfileList(
    BuildContext context, {
    required String routeName,
    required String userId,
  }) async {
    await context.pushNamed<void>(
      routeName,
      pathParameters: {'userId': userId},
    );
  }

  Future<void> _openFollowRequests(BuildContext context) async {
    await context.pushNamed<void>(AppRouteName.followRequests);
  }

  void _showProtectedContentDialog(BuildContext context) {
    final followLabel = switch (profile.gender?.trim()) {
      '男' => context.l10n.userProfileProtectedDialogFollowMaleLabel,
      '女' => context.l10n.userProfileProtectedDialogFollowFemaleLabel,
      _ => context.l10n.userProfileProtectedDialogFollowUnknownLabel,
    };
    unawaited(
      showAppAlertDialog(
        context,
        title: context.l10n.userProfileProtectedDialogTitle,
        content: context.l10n.userProfileProtectedDialogContent,
        cancelAction: AppDialogAction(
          label: context.l10n.userProfileProtectedDialogCancelLabel,
          color: context.appColors.textBase,
          onPressed: () {},
        ),
        confirmAction: AppDialogAction(
          label: followLabel,
          color: context.appColors.wechatLinkText!,
          onPressed: () {},
        ),
      ),
    );
  }
}
