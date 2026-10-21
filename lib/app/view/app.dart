import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/configuration/configuration.dart';
import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/gen/app_localizations.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/status/status.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:status_repository/status_repository.dart';
import 'package:user_repository/user_repository.dart';

class App extends StatelessWidget {
  const App({
    required this.appearanceRepository,
    required this.authenticationRepository,
    required this.initialAppearanceSettings,
    required this.oauthAuthorizationService,
    required this.statusImageActionsService,
    required this.statusPhotoPicker,
    required this.statusRepository,
    required this.statusDraftRepository,
    required this.directMessageRepository,
    required this.userRepository,
    this.appBuildInfo = const AppBuildInfo(),
    super.key,
  });

  final AppearanceRepository appearanceRepository;
  final AuthenticationRepository authenticationRepository;
  final AppearanceSettings initialAppearanceSettings;
  final OAuthAuthorizationService oauthAuthorizationService;
  final StatusImageActionsService statusImageActionsService;
  final StatusPhotoPicker statusPhotoPicker;
  final StatusRepository statusRepository;
  final StatusDraftRepository statusDraftRepository;
  final DirectMessageRepository directMessageRepository;
  final UserRepository userRepository;
  final AppBuildInfo appBuildInfo;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: appBuildInfo),
        RepositoryProvider.value(value: appearanceRepository),
        RepositoryProvider.value(value: authenticationRepository),
        RepositoryProvider.value(value: oauthAuthorizationService),
        RepositoryProvider.value(value: statusImageActionsService),
        RepositoryProvider.value(value: statusPhotoPicker),
        RepositoryProvider.value(value: statusRepository),
        RepositoryProvider.value(value: statusDraftRepository),
        RepositoryProvider.value(value: directMessageRepository),
        RepositoryProvider.value(value: userRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppearanceCubit(
              appearanceRepository: appearanceRepository,
              initialSettings: initialAppearanceSettings,
            ),
          ),
          BlocProvider(
            create: (_) => AuthenticationBloc(
              authenticationRepository: authenticationRepository,
            )..add(const AuthenticationSubscriptionRequested()),
          ),
          BlocProvider(
            create: (_) => NotificationCountsCubit(
              userRepository: userRepository,
            ),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late GoRouter _router;
  late final AppLifecycleListener _lifecycleListener;
  String? _lastActiveAccountId;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(context.read<AuthenticationBloc>());
    _router.routerDelegate.addListener(_dismissSnackBars);
    _lifecycleListener = AppLifecycleListener(onResume: _handleAppResumed);
  }

  void _dismissSnackBars() {
    _scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..removeCurrentSnackBar();
  }

  void _handleAppResumed() {
    unawaited(context.read<NotificationCountsCubit>().refresh());
  }

  void _replaceRouter() {
    final authenticationBloc = context.read<AuthenticationBloc>();
    final previousRouter = _router;
    final nextRouter = createAppRouter(authenticationBloc);
    previousRouter.routerDelegate.removeListener(_dismissSnackBars);
    nextRouter.routerDelegate.addListener(_dismissSnackBars);
    _dismissSnackBars();
    setState(() {
      _router = nextRouter;
    });
    previousRouter.dispose();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _router.routerDelegate.removeListener(_dismissSnackBars);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listenWhen: (previous, current) =>
          _activeAccountId(previous) != _activeAccountId(current),
      listener: (context, state) {
        final notificationCountsCubit = context.read<NotificationCountsCubit>();
        final accountId = _activeAccountId(state);
        final previousAccountId = _lastActiveAccountId;
        _lastActiveAccountId = accountId;
        if (accountId == null) {
          notificationCountsCubit.reset();
        } else {
          unawaited(notificationCountsCubit.accountChanged(accountId));
        }
        if (accountId != null && accountId != previousAccountId) {
          _replaceRouter();
          _router.go(AppRoutePath.home);
        }
      },
      child: BlocBuilder<AppearanceCubit, AppearanceState>(
        builder: (context, state) {
          final settings = state.settings;
          return MaterialApp.router(
            scaffoldMessengerKey: _scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(appearance: settings),
            darkTheme: AppTheme.dark(appearance: settings),
            themeMode: _themeMode(settings.themeMode),
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: Theme.of(context).appBarTheme.systemOverlayStyle!,
              child: child ?? const SizedBox.shrink(),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

String? _activeAccountId(AuthenticationState state) {
  return switch (state) {
    AuthenticationAuthenticated(:final snapshot) => snapshot.activeAccount?.id,
    _ => null,
  };
}

ThemeMode _themeMode(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
