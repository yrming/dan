import 'dart:async';
import 'dart:developer';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/view/app_shell.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/blacklist/blacklist.dart';
import 'package:dan/browse/browse.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:dan/favorites/favorites.dart';
import 'package:dan/home/home.dart';
import 'package:dan/login/login.dart';
import 'package:dan/mentions/mentions.dart';
import 'package:dan/profile/profile.dart';
import 'package:dan/search/search.dart';
import 'package:dan/settings/settings.dart';
import 'package:dan/status/status.dart';
import 'package:dan/user_photos/user_photos.dart';
import 'package:dan/user_statuses/user_statuses.dart';
import 'package:direct_message_repository/direct_message_repository.dart'
    as conversation_repository;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Durations, Easing;
import 'package:go_router/go_router.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// Creates the application router.
GoRouter createAppRouter(AuthenticationBloc authenticationBloc) {
  return GoRouter(
    initialLocation: AppRoutePath.home,
    refreshListenable: GoRouterRefreshStream(authenticationBloc.stream),
    redirect: (context, state) {
      final authenticationState = authenticationBloc.state;
      final path = state.uri.path;

      final isLoadingRoute = path == AppRoutePath.loading;
      final isLoginRoute = path == AppRoutePath.login;
      final isFailureRoute = path == AppRoutePath.authenticationFailure;

      return switch (authenticationState) {
        AuthenticationInitial() || AuthenticationLoadInProgress() =>
          isLoadingRoute ? null : AppRoutePath.loading,
        AuthenticationRestoreFailure() =>
          isFailureRoute ? null : AppRoutePath.authenticationFailure,
        AuthenticationUnauthenticated() =>
          isLoginRoute ? null : AppRoutePath.login,
        AuthenticationAuthenticated() =>
          isLoadingRoute || isLoginRoute || isFailureRoute
              ? AppRoutePath.home
              : null,
      };
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => AppRoutePath.home,
      ),
      GoRoute(
        name: AppRouteName.loading,
        path: AppRoutePath.loading,
        pageBuilder: (context, state) => _buildNoTransitionPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.loading,
            state: state,
            child: const AuthenticationLoadingPage(),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.login,
        path: AppRoutePath.login,
        pageBuilder: (context, state) => _buildNoTransitionPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.login,
            state: state,
            child: const LoginPage(),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.authenticationFailure,
        path: AppRoutePath.authenticationFailure,
        pageBuilder: (context, state) => _buildNoTransitionPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.authenticationFailure,
            state: state,
            child: const AuthenticationFailurePage(),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.statusComposer,
        path: AppRoutePath.statusComposer,
        pageBuilder: (context, state) => CupertinoPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: _buildLoggedPage(
            routeName: AppRouteName.statusComposer,
            state: state,
            child: StatusComposerPage(
              mode: switch (state.uri.queryParameters['mode']) {
                'reply' => StatusComposerMode.reply,
                'repost' => StatusComposerMode.repost,
                _ => StatusComposerMode.compose,
              },
              sourceStatusId: state.uri.queryParameters['sourceStatusId'],
              sourceAuthor: state.uri.queryParameters['sourceAuthor'],
              sourceText: state.uri.queryParameters['sourceText'],
              sourcePhotoUrl: state.uri.queryParameters['sourcePhotoUrl'],
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.statusDetail,
        path: AppRoutePath.statusDetail,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.statusDetail,
            state: state,
            child: StatusDetailPage(
              userId: state.pathParameters['userId']!,
              statusId: state.pathParameters['statusId']!,
              initialStatus: switch (state.extra) {
                final status_repository.Status status
                    when status.id == state.pathParameters['statusId'] =>
                  status,
                _ => null,
              },
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.statusImageViewer,
        path: AppRoutePath.statusImageViewer,
        pageBuilder: (context, state) => _buildImageViewerPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.statusImageViewer,
            state: state,
            child: StatusImageViewerPage(
              imageUrl: state.uri.queryParameters['url'] ?? '',
              heroTag: state.uri.queryParameters['heroTag'] ?? '',
              semanticLabel: state.uri.queryParameters['semanticLabel'],
              userId: state.uri.queryParameters['userId'],
              statusId: state.uri.queryParameters['statusId'],
              gallery: switch (state.extra) {
                final StatusImageGallery gallery => gallery,
                _ => null,
              },
              initialStatus: switch (state.extra) {
                final StatusImageGallery gallery => gallery.statusFor(
                  state.uri.queryParameters['statusId'],
                ),
                final status_repository.Status status
                    when status.id == state.uri.queryParameters['statusId'] =>
                  status,
                _ => null,
              },
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.search,
        path: AppRoutePath.search,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.search,
            state: state,
            child: SearchPage(
              initialQuery: state.uri.queryParameters['query'],
              initialScope: switch (state.uri.queryParameters['scope']) {
                'mine' => SearchScope.mine,
                'his' => SearchScope.his,
                'hers' => SearchScope.hers,
                'theirs' => SearchScope.theirs,
                _ => SearchScope.all,
              },
              userId: state.uri.queryParameters['userId'],
            ),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) {
          final activeAccountId = _activeAccount(
            authenticationBloc.state,
          )!.id;
          return NoTransitionPage<void>(
            key: ValueKey((state.pageKey, activeAccountId)),
            child: AppShell(
              key: ValueKey(activeAccountId),
              navigationShell: navigationShell,
              activeUserId: activeAccountId,
              showBottomNavigationBar: _isTabRoot(path: state.uri.path),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            initialLocation: AppRoutePath.home,
            routes: [
              GoRoute(
                name: AppRouteName.home,
                path: AppRoutePath.home,
                pageBuilder: (context, state) => _buildNoTransitionPage(
                  state,
                  _buildLoggedPage(
                    routeName: AppRouteName.home,
                    state: state,
                    child: const HomePage(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppRoutePath.mentions,
            routes: [
              GoRoute(
                name: AppRouteName.mentions,
                path: AppRoutePath.mentions,
                pageBuilder: (context, state) => _buildNoTransitionPage(
                  state,
                  _buildLoggedPage(
                    routeName: AppRouteName.mentions,
                    state: state,
                    child: const MentionsPage(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppRoutePath.browse,
            routes: [
              GoRoute(
                name: AppRouteName.browse,
                path: AppRoutePath.browse,
                pageBuilder: (context, state) => _buildNoTransitionPage(
                  state,
                  _buildLoggedPage(
                    routeName: AppRouteName.browse,
                    state: state,
                    child: const BrowsePage(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: AppRoutePath.mine,
            routes: [
              GoRoute(
                name: AppRouteName.mine,
                path: AppRoutePath.mine,
                pageBuilder: (context, state) => _buildNoTransitionPage(
                  state,
                  _buildLoggedPage(
                    routeName: AppRouteName.mine,
                    state: state,
                    child: MinePage(
                      activeAccount: _activeAccount(
                        authenticationBloc.state,
                      )!,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        name: AppRouteName.favorites,
        path: AppRoutePath.favorites,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.favorites,
            state: state,
            child: FavoritesPage(
              userId: state.pathParameters['userId']!,
              profileItemCount: int.tryParse(
                state.uri.queryParameters['profileItemCount'] ?? '',
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.userStatuses,
        path: AppRoutePath.userStatuses,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.userStatuses,
            state: state,
            child: UserStatusesPage(
              userId: state.pathParameters['userId']!,
              profileItemCount: int.tryParse(
                state.uri.queryParameters['profileItemCount'] ?? '',
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.userPhotos,
        path: AppRoutePath.userPhotos,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.userPhotos,
            state: state,
            child: UserPhotosPage(
              userId: state.pathParameters['userId']!,
              profileItemCount: int.tryParse(
                state.uri.queryParameters['profileItemCount'] ?? '',
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.following,
        path: AppRoutePath.following,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.following,
            state: state,
            child: FollowListPage(
              userId: state.pathParameters['userId']!,
              followers: false,
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.followers,
        path: AppRoutePath.followers,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.followers,
            state: state,
            child: FollowListPage(
              userId: state.pathParameters['userId']!,
              followers: true,
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.blacklist,
        path: AppRoutePath.blacklist,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.blacklist,
            state: state,
            child: const BlacklistPage(),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.followRequests,
        path: AppRoutePath.followRequests,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.followRequests,
            state: state,
            child: const FollowRequestsPage(),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.directMessageList,
        path: AppRoutePath.directMessageList,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.directMessageList,
            state: state,
            child: const ConversationListPage(),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.directMessageConversation,
        path: AppRoutePath.directMessageConversation,
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.directMessageConversation,
            state: state,
            child: ConversationPage(
              userId: state.pathParameters['userId']!,
              activeAccountId: _activeAccount(authenticationBloc.state)?.id,
              activeAccountAvatarUrl: _activeAccount(
                authenticationBloc.state,
              )?.avatarUrl,
              initialPeerScreenName: state.uri.queryParameters['screenName'],
              conversation: switch (state.extra) {
                final conversation_repository.DirectMessageConversation
                    conversation
                    when conversation.otherUserId ==
                        state.pathParameters['userId'] =>
                  conversation,
                _ => null,
              },
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRouteName.userProfile,
        path: AppRoutePath.userProfile,
        redirect: (context, state) {
          final isPushed =
              state.uri.queryParameters['presentation'] == 'pushed';
          final isActiveAccount =
              state.pathParameters['userId'] ==
              _activeAccount(authenticationBloc.state)?.id;
          final isProfileRoot = state.uri.pathSegments.length == 1;
          return isActiveAccount && !isPushed && isProfileRoot
              ? AppRoutePath.mine
              : null;
        },
        pageBuilder: (context, state) => _buildCupertinoPage(
          state,
          _buildLoggedPage(
            routeName: AppRouteName.userProfile,
            state: state,
            child: UserProfilePage(
              userId: state.pathParameters['userId']!,
              activeAccount: _activeAccount(authenticationBloc.state),
            ),
          ),
        ),
        routes: [
          GoRoute(
            name: AppRouteName.settings,
            path: AppRoutePath.settings,
            pageBuilder: (context, state) => _buildCupertinoPage(
              state,
              _buildLoggedPage(
                routeName: AppRouteName.settings,
                state: state,
                child: const SettingsPage(),
              ),
            ),
            routes: [
              GoRoute(
                name: AppRouteName.about,
                path: AppRoutePath.about,
                pageBuilder: (context, state) => _buildCupertinoPage(
                  state,
                  const AboutPage(),
                ),
              ),
              GoRoute(
                name: AppRouteName.userAgreement,
                path: AppRoutePath.userAgreement,
                pageBuilder: (context, state) => _buildCupertinoPage(
                  state,
                  const LegalDocumentPage(),
                ),
              ),
              GoRoute(
                name: AppRouteName.privacyPolicy,
                path: AppRoutePath.privacyPolicy,
                pageBuilder: (context, state) => _buildCupertinoPage(
                  state,
                  const LegalDocumentPage(privacyPolicy: true),
                ),
              ),
              GoRoute(
                name: AppRouteName.fontSize,
                path: AppRoutePath.fontSize,
                pageBuilder: (context, state) => _buildCupertinoPage(
                  state,
                  _buildLoggedPage(
                    routeName: AppRouteName.fontSize,
                    state: state,
                    child: const FontSizePage(),
                  ),
                ),
              ),
              GoRoute(
                name: AppRouteName.addAccount,
                path: AppRoutePath.addAccount,
                pageBuilder: (context, state) => CupertinoPage<void>(
                  key: state.pageKey,
                  fullscreenDialog: true,
                  child: _buildLoggedPage(
                    routeName: AppRouteName.addAccount,
                    state: state,
                    child: const AddAccountPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

AuthenticatedAccount? _activeAccount(AuthenticationState state) {
  return switch (state) {
    AuthenticationAuthenticated(:final snapshot) => snapshot.activeAccount,
    _ => null,
  };
}

bool _isTabRoot({
  required String path,
}) {
  return path == AppRoutePath.home ||
      path == AppRoutePath.mentions ||
      path == AppRoutePath.browse ||
      path == AppRoutePath.mine;
}

Widget _buildLoggedPage({
  required String routeName,
  required GoRouterState state,
  required Widget child,
}) {
  return _PageEntryLogger(
    routeName: routeName,
    location: state.uri.path,
    child: child,
  );
}

Page<void> _buildNoTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

Page<void> _buildCupertinoPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: false,
        child: child,
      );
    },
  );
}

Page<void> _buildImageViewerPage(GoRouterState state, Widget child) {
  return _ImageViewerPage(
    key: state.pageKey,
    child: child,
  );
}

class _ImageViewerPage extends Page<void> {
  const _ImageViewerPage({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return _ImageViewerPageRoute(this);
  }
}

class _ImageViewerPageRoute extends PageRoute<void> {
  _ImageViewerPageRoute(_ImageViewerPage page) : super(settings: page);

  _ImageViewerPage get _page => settings as _ImageViewerPage;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get fullscreenDialog => false;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => Durations.medium2;

  @override
  Duration get reverseTransitionDuration => Durations.medium2;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Easing.standard,
      ),
      child: child,
    );
  }
}

class _PageEntryLogger extends StatefulWidget {
  const _PageEntryLogger({
    required this.routeName,
    required this.location,
    required this.child,
  });

  final String routeName;
  final String location;
  final Widget child;

  @override
  State<_PageEntryLogger> createState() => _PageEntryLoggerState();
}

class _PageEntryLoggerState extends State<_PageEntryLogger> {
  @override
  void initState() {
    super.initState();
    log(
      'enter page: ${widget.routeName} (${widget.location})',
      name: 'navigation',
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Refreshes [GoRouter] when the authentication stream emits.
class GoRouterRefreshStream extends ChangeNotifier {
  /// Creates a router refresh notifier.
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
