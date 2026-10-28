import 'dart:async';
import 'dart:convert';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/app.dart';
import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/app_colors.dart';
import 'package:dan/app/theme/app_style.dart';
import 'package:dan/app/view/app_shell.dart';
import 'package:dan/app/view/app_shell_app_bar.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/browse/browse.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:dan/favorites/favorites.dart';
import 'package:dan/home/home.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/login/login.dart';
import 'package:dan/mentions/mentions.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/profile/profile.dart';
import 'package:dan/search/search.dart';
import 'package:dan/settings/settings.dart';
import 'package:dan/status/status.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/user_photos/user_photos.dart';
import 'package:dan/user_statuses/user_statuses.dart';
import 'package:direct_message_repository/direct_message_repository.dart'
    as direct_message_repository;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_view/photo_view.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart' as status_repository;
import 'package:user_repository/user_repository.dart';

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

class _MockAppearanceCubit extends MockCubit<AppearanceState>
    implements AppearanceCubit {}

class _MockNotificationCountsCubit extends MockCubit<NotificationCountsState>
    implements NotificationCountsCubit {}

class _MockAppearanceRepository extends Mock implements AppearanceRepository {}

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class _MockOAuthAuthorizationService extends Mock
    implements OAuthAuthorizationService {}

class _MockStatusImageActionsService extends Mock
    implements StatusImageActionsService {}

class _MockStatusDraftRepository extends Mock
    implements status_repository.StatusDraftRepository {}

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

class _MockDirectMessageRepository extends Mock
    implements direct_message_repository.DirectMessageRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockStatusPhotoPicker extends Mock implements StatusPhotoPicker {}

void main() {
  group(AppView, () {
    late AuthenticationBloc authenticationBloc;
    late AppearanceCubit appearanceCubit;
    late NotificationCountsCubit notificationCountsCubit;
    late AppearanceRepository appearanceRepository;
    late AuthenticationRepository authenticationRepository;
    late OAuthAuthorizationService oauthAuthorizationService;
    late StatusImageActionsService statusImageActionsService;
    late StatusPhotoPicker statusPhotoPicker;
    late status_repository.StatusRepository statusRepository;
    late status_repository.StatusDraftRepository draftRepository;
    late direct_message_repository.DirectMessageRepository
    directMessageRepository;
    late UserRepository userRepository;

    setUpAll(() {
      registerFallbackValue(status_repository.StatusDraft(content: ''));
    });

    setUp(() {
      authenticationBloc = _MockAuthenticationBloc();
      appearanceCubit = _MockAppearanceCubit();
      notificationCountsCubit = _MockNotificationCountsCubit();
      appearanceRepository = _MockAppearanceRepository();
      authenticationRepository = _MockAuthenticationRepository();
      oauthAuthorizationService = _MockOAuthAuthorizationService();
      statusImageActionsService = _MockStatusImageActionsService();
      statusPhotoPicker = _MockStatusPhotoPicker();
      statusRepository = _MockStatusRepository();
      draftRepository = _MockStatusDraftRepository();
      when(() => draftRepository.load(any())).thenAnswer((_) async => null);
      when(() => draftRepository.clear(any())).thenAnswer((_) async {});
      directMessageRepository = _MockDirectMessageRepository();
      when(() => directMessageRepository.messageChanges).thenAnswer(
        (_) => const Stream.empty(),
      );
      userRepository = _MockUserRepository();
      when(
        () => userRepository.getCachedUser(any()),
      ).thenReturn(null);
      when(
        () => directMessageRepository.getConversationList(limit: 20, page: 1),
      ).thenAnswer(
        (_) async =>
            const direct_message_repository.DirectMessageConversationPage(
              conversations: [],
              hasMore: false,
              nextPage: null,
            ),
      );
      when(
        () => userRepository.getUser(_author.id),
      ).thenAnswer((_) async => _authorProfile);
      when(
        () => userRepository.getUser(_account.id),
      ).thenAnswer((_) async => _accountProfile);
      when(
        () => userRepository.getUser(_mentionedProfile.id),
      ).thenAnswer((_) async => _mentionedProfile);
      when(
        () => userRepository.getNotificationCounts(),
      ).thenAnswer((_) async => _notificationCounts);
      when(
        () => statusRepository.statusChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(() => appearanceCubit.state).thenReturn(
        const AppearanceState(
          status: AppearanceStatus.success,
          settings: AppearanceSettings(),
        ),
      );
      when(() => notificationCountsCubit.state).thenReturn(
        const NotificationCountsInitial(),
      );
      when(
        () => notificationCountsCubit.accountChanged(any()),
      ).thenAnswer((_) async {});
      when(() => notificationCountsCubit.reset()).thenReturn(null);
      when(
        () => notificationCountsCubit.refresh(),
      ).thenAnswer((_) async {});
      when(
        () => statusRepository.getHomeTimeline(),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_homeStatus],
          hasMore: false,
        ),
      );
      when(
        () => statusRepository.getMentions(
          sinceId: any(named: 'sinceId'),
          maxId: any(named: 'maxId'),
        ),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_mentionStatus],
          hasMore: false,
        ),
      );
      when(
        () => statusRepository.getFavorites(userId: _account.id),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_favoriteStatus],
          hasMore: false,
        ),
      );
      when(
        () => statusRepository.getStatus(_homeStatus.id),
      ).thenAnswer((_) async => _homeStatus);
    });

    Future<void> pumpAppView(
      WidgetTester tester,
      AuthenticationState state,
    ) async {
      when(() => authenticationBloc.state).thenReturn(state);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: appearanceRepository),
            RepositoryProvider.value(value: authenticationRepository),
            RepositoryProvider.value(value: oauthAuthorizationService),
            RepositoryProvider.value(value: statusImageActionsService),
            RepositoryProvider.value(value: statusPhotoPicker),
            RepositoryProvider.value(value: statusRepository),
            RepositoryProvider.value(value: draftRepository),
            RepositoryProvider.value(value: directMessageRepository),
            RepositoryProvider.value(value: userRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: appearanceCubit),
              BlocProvider.value(value: authenticationBloc),
              BlocProvider.value(value: notificationCountsCubit),
            ],
            child: const AppView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> pumpNavigation(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(Durations.extralong4);
    }

    testWidgets('renders loading page for the initial state', (tester) async {
      await pumpAppView(tester, const AuthenticationInitial());

      expect(find.byType(AuthenticationLoadingPage), findsOneWidget);
    });

    testWidgets('renders loading page while restoration is in progress', (
      tester,
    ) async {
      await pumpAppView(tester, const AuthenticationLoadInProgress());

      expect(find.byType(AuthenticationLoadingPage), findsOneWidget);
    });

    testWidgets('renders login page when unauthenticated', (
      tester,
    ) async {
      await pumpAppView(
        tester,
        AuthenticationUnauthenticated(
          AuthenticationSnapshot.unauthenticated(),
        ),
      );

      expect(find.byType(LoginPage), findsOneWidget);
    });

    group('login legal documents', () {
      // Cached asset futures must not cross widget test async scopes.
      setUp(rootBundle.clear);

      for (final isAddingAccount in [false, true]) {
        testWidgets(
          'reads agreements in app and returns to login '
          'when adding an account=$isAddingAccount',
          (tester) async {
            await pumpAppView(
              tester,
              isAddingAccount
                  ? _authenticatedState
                  : AuthenticationUnauthenticated(
                      AuthenticationSnapshot.unauthenticated(),
                    ),
            );
            if (isAddingAccount) {
              final context = tester.element(find.byType(AppShell));
              unawaited(
                context.pushNamed<void>(
                  AppRouteName.addAccount,
                  pathParameters: {'userId': _account.id},
                ),
              );
              await pumpNavigation(tester);
            }
            final context = tester.element(find.byType(LoginView));

            for (final document in [
              (
                label: context.l10n.settingsUserAgreementLabel,
                content: '一、协议范围与服务性质',
                path: AppRoutePath.publicUserAgreement,
              ),
              (
                label: context.l10n.settingsPrivacyPolicyLabel,
                content: '一、适用范围',
                path: AppRoutePath.publicPrivacyPolicy,
              ),
            ]) {
              await tester.tapOnText(
                find.textRange.ofSubstring(document.label),
              );
              await pumpNavigation(tester);
              await tester.pumpAndSettle();

              expect(find.byType(LegalDocumentPage), findsOneWidget);
              expect(find.byType(MarkdownBody), findsOneWidget);
              expect(find.text(document.content), findsOneWidget);
              expect(
                GoRouter.of(
                  tester.element(find.byType(LegalDocumentPage)),
                ).state.uri.path,
                document.path,
              );

              await tester.tap(find.byType(BackButton));
              await pumpNavigation(tester);
              expect(find.byType(LoginView), findsOneWidget);
              expect(
                find.byType(isAddingAccount ? AddAccountPage : LoginPage),
                findsOneWidget,
              );
            }
          },
        );
      }
    });

    testWidgets('renders the authenticated home shell', (tester) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(AppShellAppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppShellAppBar),
          matching: find.text(context.l10n.homePageTitle),
        ),
        findsOneWidget,
      );
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(StatusList), findsOneWidget);
      expect(find.text(_homeStatus.text), findsOneWidget);
      expect(find.byIcon(RemixIcons.home_5_line), findsNothing);
      expect(find.byIcon(RemixIcons.at_line), findsNothing);
      expect(
        find.byKey(
          const Key('app-bottom-navigation-create-status-visual'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(RemixIcons.compass_3_line), findsNothing);
      expect(find.byIcon(RemixIcons.user_6_line), findsNothing);
      expect(find.text(context.l10n.homePageTitle), findsNWidgets(2));
      expect(find.text(context.l10n.mentionsPageTitle), findsOneWidget);
      expect(find.text(context.l10n.browsePageTitle), findsOneWidget);
      expect(find.text(context.l10n.userProfileTabLabel), findsOneWidget);
      expect(find.text(context.l10n.userProfilePageTitle), findsNothing);
    });

    testWidgets('shows unread mentions from the global notification state', (
      tester,
    ) async {
      when(() => notificationCountsCubit.state).thenReturn(
        const NotificationCountsLoadSuccess(counts: _notificationCounts),
      );

      await pumpAppView(tester, _authenticatedState);

      expect(
        find.byKey(const Key('app-bottom-navigation-mentions-badge')),
        findsOneWidget,
      );
      expect(find.text('${_notificationCounts.mentions}'), findsOneWidget);
    });

    testWidgets('shows unread direct messages on the mine tab mail action', (
      tester,
    ) async {
      when(() => notificationCountsCubit.state).thenReturn(
        const NotificationCountsLoadSuccess(counts: _notificationCounts),
      );
      await pumpAppView(tester, _authenticatedState);
      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-mine')),
      );
      await pumpNavigation(tester);

      expect(
        find.ancestor(
          of: find.byIcon(RemixIcons.mail_line),
          matching: find.byType(Badge),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('app-bottom-navigation-mine-badge')),
        findsOneWidget,
      );
      // The unread count shows on the mail action and the mine tab badge.
      expect(
        find.text('${_notificationCounts.directMessages}'),
        findsNWidgets(2),
      );
    });

    testWidgets('hides the direct messages badge without unread messages', (
      tester,
    ) async {
      await pumpAppView(tester, _authenticatedState);
      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-mine')),
      );
      await pumpNavigation(tester);

      expect(
        find.ancestor(
          of: find.byIcon(RemixIcons.mail_line),
          matching: find.byType(Badge),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('app-bottom-navigation-mine-badge')),
        findsNothing,
      );
    });

    testWidgets('loads notification counts after account verification', (
      tester,
    ) async {
      final authenticationStates = StreamController<AuthenticationState>();
      addTearDown(authenticationStates.close);
      whenListen(
        authenticationBloc,
        authenticationStates.stream,
        initialState: const AuthenticationLoadInProgress(),
      );

      await pumpAppView(tester, const AuthenticationLoadInProgress());
      authenticationStates.add(_authenticatedState);
      await tester.pump();

      verify(
        () => notificationCountsCubit.accountChanged(_account.id),
      ).called(1);
    });

    testWidgets('resets the authenticated shell when the account changes', (
      tester,
    ) async {
      final authenticationStates = StreamController<AuthenticationState>();
      addTearDown(authenticationStates.close);
      var currentAuthenticationState = _authenticatedState;
      whenListen(
        authenticationBloc,
        authenticationStates.stream,
        initialState: currentAuthenticationState,
      );

      await pumpAppView(tester, _authenticatedState);
      when(
        () => authenticationBloc.state,
      ).thenAnswer((_) => currentAuthenticationState);
      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-mentions')),
      );
      await pumpNavigation(tester);
      expect(find.byType(MentionsPage), findsOneWidget);
      clearInteractions(statusRepository);

      currentAuthenticationState = _authenticatedStateFor(_secondAccount);
      authenticationStates.add(currentAuthenticationState);
      await pumpNavigation(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(MentionsPage, skipOffstage: false), findsNothing);
      verify(() => statusRepository.getHomeTimeline()).called(1);
      expect(
        GoRouter.of(tester.element(find.byType(AppShell))).state.uri.path,
        AppRoutePath.home,
      );
    });

    testWidgets('refreshes notification counts when the app resumes', (
      tester,
    ) async {
      await pumpAppView(tester, _authenticatedState);
      clearInteractions(notificationCountsCubit);

      // Walk the legal lifecycle path for backgrounding and resuming.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => notificationCountsCubit.refresh()).called(1);
    });

    testWidgets('uses iOS navigation and tab bar heights', (tester) async {
      expect(AppShell.appBarToolbarHeight, 44);
      expect(AppShell.bottomNavigationBarHeight, 50);
    });

    testWidgets('applies the persisted theme mode and photo style', (
      tester,
    ) async {
      when(() => appearanceCubit.state).thenReturn(
        const AppearanceState(
          status: AppearanceStatus.success,
          settings: AppearanceSettings(
            themeMode: AppThemeMode.dark,
            statusPhotoStyle: StatusPhotoStyle.wechat,
          ),
        ),
      );

      await pumpAppView(tester, const AuthenticationInitial());
      final context = tester.element(find.byType(AuthenticationLoadingPage));

      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).colorScheme.primary,
        AppColors.danDark.wechatGreen,
      );
      expect(context.appStatusPhotoStyle, StatusPhotoStyle.wechat);
    });

    test('defines status detail as an independent resource route', () {
      expect(AppRoutePath.statusDetail, '/:userId/status/:statusId');
    });

    test('defines user profile as an independent resource route', () {
      expect(AppRoutePath.userProfile, '/:userId');
    });

    test('defines the active account as a shell tab route', () {
      expect(AppRoutePath.mine, '/mine');
    });

    test('defines user status collections as independent routes', () {
      expect(AppRoutePath.userStatuses, '/statuses/:userId');
      expect(AppRoutePath.userPhotos, '/photos/:userId');
    });

    test('defines status image viewer as an independent route', () {
      expect(AppRoutePath.statusImageViewer, '/status-image');
    });

    test('defines status composer as an independent route', () {
      expect(AppRoutePath.statusComposer, '/status/compose');
    });

    testWidgets('opens the status composer as a full-screen Cupertino dialog', (
      tester,
    ) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-create-status')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final composer = find.byKey(const Key('status-composer-page'));
      final initialTop = tester.getTopLeft(composer).dy;
      final route = ModalRoute.of(
        tester.element(find.byType(StatusComposerPage)),
      );
      final page = route!.settings as CupertinoPage<void>;
      expect(find.byType(StatusComposerPage), findsOneWidget);
      final avatar = tester.widget<UserAvatar>(
        find.byKey(const Key('status-composer-avatar')),
      );
      expect(avatar.imageUrl, _account.avatarUrl);
      expect(avatar.semanticLabel, _account.name);
      expect(page.fullscreenDialog, isTrue);
      expect(GoRouter.of(context).state.uri.path, AppRoutePath.statusComposer);
      expect(initialTop, greaterThan(0));

      await tester.pump(route.transitionDuration ~/ 2);
      final middleTop = tester.getTopLeft(composer).dy;
      expect(middleTop, greaterThan(0));
      expect(middleTop, lessThan(initialTop));

      await tester.pump(route.transitionDuration);
      expect(tester.getTopLeft(composer).dy, closeTo(0, 0.001));
      expect(
        tester.getSize(composer),
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );

      await tester.tap(
        find.byKey(const Key('status-composer-close')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatusComposerPage), findsNothing);
      expect(GoRouter.of(context).state.uri.path, AppRoutePath.home);
    });

    group('original status drafts', () {
      testWidgets('prompts for a photo-only draft and restores its preview', (
        tester,
      ) async {
        final photo = StatusComposerPhoto(
          path: '/photo.png',
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
          ),
        );
        status_repository.StatusDraft? saved;
        when(
          () => statusPhotoPicker.pickPhoto(),
        ).thenAnswer((_) async => photo);
        when(() => draftRepository.load(any())).thenAnswer((_) async => saved);
        when(() => draftRepository.save(any(), any())).thenAnswer((call) async {
          saved = call.positionalArguments[1] as status_repository.StatusDraft;
        });
        await pumpAppView(tester, _authenticatedState);
        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-create-status')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('status-composer-add-photo')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('status-composer-close')));
        await tester.pumpAndSettle();
        expect(find.text('保留当前内容？'), findsOneWidget);
        await tester.tap(find.text('保留'));
        await tester.pumpAndSettle();
        expect(saved!.photoBytes, photo.bytes);
        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-create-status')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('status-composer-photo-preview')),
          findsOneWidget,
        );
      });

      for (final keep in [true, false]) {
        testWidgets('closes and restores only when keep=$keep', (tester) async {
          status_repository.StatusDraft? saved;
          when(
            () => draftRepository.load(any()),
          ).thenAnswer((_) async => saved);
          when(() => draftRepository.save(any(), any())).thenAnswer((
            call,
          ) async {
            saved =
                call.positionalArguments[1] as status_repository.StatusDraft;
          });
          when(() => draftRepository.clear(any())).thenAnswer((_) async {
            saved = null;
          });
          await pumpAppView(tester, _authenticatedState);
          await tester.tap(
            find.byKey(const Key('app-bottom-navigation-create-status')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '  未完成的消息\n第二行');
          await tester.tap(find.byKey(const Key('status-composer-close')));
          await tester.pumpAndSettle();
          expect(find.text('保留当前内容？'), findsOneWidget);
          await tester.tap(find.text(keep ? '保留' : '不保留'));
          await tester.pumpAndSettle();
          expect(find.byType(StatusComposerPage), findsNothing);
          await tester.tap(
            find.byKey(const Key('app-bottom-navigation-create-status')),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            keep ? '  未完成的消息\n第二行' : '',
          );
        });
      }

      testWidgets('retains the editor and dialog when saving fails', (
        tester,
      ) async {
        when(
          () => draftRepository.save(any(), any()),
        ).thenThrow(Exception('disk full'));
        await pumpAppView(tester, _authenticatedState);
        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-create-status')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '不能丢失');
        await tester.tap(find.byKey(const Key('status-composer-close')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保留'));
        await tester.pumpAndSettle();
        expect(find.text('无法保存草稿更改，请重试。'), findsOneWidget);
        expect(find.byType(StatusComposerPage), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '不能丢失',
        );
      });

      testWidgets('system back asks before discarding content', (tester) async {
        await pumpAppView(tester, _authenticatedState);
        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-create-status')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '系统返回草稿');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('保留当前内容？'), findsOneWidget);
      });
    });

    testWidgets('selects a photo and publishes it through the photo endpoint', (
      tester,
    ) async {
      final photo = StatusComposerPhoto(
        path: '/photo.png',
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
        ),
      );
      when(() => statusPhotoPicker.pickPhoto()).thenAnswer((_) async => photo);
      when(
        () => statusRepository.createPhotoStatus(
          photoPath: photo.path,
          text: '配图文字',
        ),
      ).thenAnswer((_) async => _homeStatusWithPhoto);
      await pumpAppView(tester, _authenticatedState);
      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-create-status')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '配图文字');
      await tester.tap(find.byKey(const Key('status-composer-add-photo')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('status-composer-photo-preview')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '配图文字',
      );
      await tester.tap(find.byKey(const Key('status-composer-publish')));
      await tester.pumpAndSettle();

      verify(() => statusPhotoPicker.pickPhoto()).called(1);
      verify(
        () => statusRepository.createPhotoStatus(
          photoPath: photo.path,
          text: '配图文字',
        ),
      ).called(1);
      verifyNever(() => statusRepository.createStatus(any()));
      expect(find.byType(StatusComposerPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    group('reply and repost', () {
      for (final fromDetail in [false, true]) {
        for (final reply in [true, false]) {
          for (final withPhoto in [false, true]) {
            testWidgets(
              'opens a prefilled composer for reply=$reply '
              'fromDetail=$fromDetail withPhoto=$withPhoto '
              'and publishes with its source identifiers',
              (tester) async {
                const source =
                    '正文 &amp; '
                    '@<a href="https://fanfou.com/user-b">饭友 B</a> '
                    '<a href="https://example.com/?a=1&amp;b=2">网页</a> '
                    '#<a href="/q/topic">话题</a>#';
                final status = _homeStatus.copyWith(
                  text: source,
                  photo: withPhoto ? _homeStatusWithPhoto.photo : null,
                );
                when(() => statusRepository.getHomeTimeline()).thenAnswer(
                  (_) async => status_repository.StatusPage(
                    statuses: [status],
                    hasMore: false,
                  ),
                );
                when(
                  () => statusRepository.getStatus(status.id),
                ).thenAnswer((_) async => status);
                await pumpAppView(tester, _authenticatedState);
                final router = GoRouter.of(
                  tester.element(find.byType(AppShell)),
                );
                if (fromDetail) {
                  unawaited(
                    router.pushNamed<void>(
                      AppRouteName.statusDetail,
                      pathParameters: {
                        'userId': status.author.id,
                        'statusId': status.id,
                      },
                    ),
                  );
                  await pumpNavigation(tester);
                }
                final sourceLocation = router.state.uri;
                await tester.ensureVisible(
                  find.byType(StatusActionButton),
                );
                await tester.pump();
                await tester.tap(
                  find.byKey(const Key('wechat-status-action-hit-target')),
                );
                await pumpNavigation(tester);
                await tester.tap(
                  find.byKey(
                    Key(
                      reply ? 'status-reply-action' : 'status-repost-action',
                    ),
                  ),
                );
                await pumpNavigation(tester);

                expect(find.byType(StatusComposerPage), findsOneWidget);
                expect(router.state.uri.queryParameters, {
                  'mode': reply ? 'reply' : 'repost',
                  'sourceStatusId': status.id,
                  'sourceAuthor': status.author.name,
                  'sourceText': source,
                  if (!reply && withPhoto)
                    'sourcePhotoUrl': status.photo!.viewerUrl,
                });
                expect(
                  find.byKey(const Key('status-action-sheet')),
                  findsNothing,
                );
                final sourcePhoto = find.byKey(
                  const Key('status-composer-source-photo'),
                );
                expect(
                  sourcePhoto,
                  !reply && withPhoto ? findsOneWidget : findsNothing,
                );
                expect(
                  find.byKey(const Key('status-composer-remove-photo')),
                  findsNothing,
                );
                expect(
                  find.byKey(const Key('status-composer-add-photo')),
                  findsNothing,
                );
                final context = tester.element(find.byType(TextField));
                expect(
                  find.bySemanticsLabel(
                    context.l10n.statusComposerAddPhotoLabel,
                  ),
                  findsNothing,
                );
                expect(
                  tester
                      .widget<AppSubpageAppBar>(find.byType(AppSubpageAppBar))
                      .title,
                  reply
                      ? context.l10n.statusActionReplyLabel
                      : context.l10n.statusActionRepostLabel,
                );
                final field = tester.widget<TextField>(find.byType(TextField));
                final controller = field.controller!;
                final expected = reply
                    ? '@${status.author.name} '
                    : '转@${status.author.name} 正文 & @饭友 B 网页 #话题#';
                expect(controller.text, expected);
                expect(
                  controller.selection,
                  TextSelection.collapsed(offset: reply ? expected.length : 0),
                );
                expect(
                  tester
                      .widget<EditableText>(find.byType(EditableText))
                      .focusNode
                      .hasFocus,
                  isTrue,
                );
                expect(
                  context.read<StatusComposerCubit>().state.content,
                  expected,
                );
                final spans = controller
                    .buildTextSpan(
                      context: context,
                      withComposing: false,
                    )
                    .children!
                    .cast<TextSpan>();
                expect(
                  spans
                      .where(
                        (span) =>
                            span.style?.color ==
                            Theme.of(
                              context,
                            ).extension<AppColors>()!.wechatLinkText,
                      )
                      .map((span) => span.text)
                      .join(),
                  reply
                      ? '@${status.author.name}'
                      : '@${status.author.name}@饭友 B网页#话题#',
                );
                expect(
                  tester
                      .widget<FilledButton>(
                        find.byKey(const Key('status-composer-publish')),
                      )
                      .onPressed,
                  isNotNull,
                );

                if (!reply && withPhoto) {
                  final thumbnail = tester.widget<StatusPhoto>(sourcePhoto);
                  expect(thumbnail.imageUrl, status.photo!.viewerUrl);
                  expect(thumbnail.style, StatusPhotoStyle.x);
                  expect(
                    tester.getSize(sourcePhoto).width,
                    tester.getSize(find.byType(TextField)).width,
                  );
                  expect(
                    context.read<StatusComposerCubit>().state.photo,
                    isNull,
                  );
                  final composerLocation = router.state.uri;
                  await tester.ensureVisible(sourcePhoto);
                  await tester.tap(sourcePhoto);
                  await pumpNavigation(tester);
                  final viewer = tester.widget<StatusImageViewerPage>(
                    find.byType(StatusImageViewerPage),
                  );
                  expect(viewer.imageUrl, status.photo!.viewerUrl);
                  expect(viewer.heroTag, thumbnail.heroTag);
                  router.pop();
                  await pumpNavigation(tester);
                  expect(router.state.uri, composerLocation);
                  expect(sourcePhoto, findsOneWidget);
                }

                await tester.enterText(find.byType(TextField), '$expected新内容');
                await tester.pump();
                expect(
                  context.read<StatusComposerCubit>().state.content,
                  '$expected新内容',
                );
                final submittedText = '$expected新内容'.trim();
                when(
                  () => statusRepository.createStatus(
                    submittedText,
                    inReplyToStatusId: reply ? status.id : null,
                    repostStatusId: reply ? null : status.id,
                  ),
                ).thenAnswer((_) async => status);
                await tester.tap(
                  find.byKey(const Key('status-composer-publish')),
                );
                await pumpNavigation(tester);
                verify(
                  () => statusRepository.createStatus(
                    submittedText,
                    inReplyToStatusId: reply ? status.id : null,
                    repostStatusId: reply ? null : status.id,
                  ),
                ).called(1);
                verifyNever(
                  () => statusRepository.createPhotoStatus(
                    photoPath: any(named: 'photoPath'),
                    text: any(named: 'text'),
                  ),
                );
                expect(router.state.uri, sourceLocation);
                expect(find.byType(StatusComposerPage), findsNothing);
              },
            );
          }
        }
      }
    });

    testWidgets('opens search from browse and returns to the same tab', (
      tester,
    ) async {
      when(() => statusRepository.getPublicTimeline()).thenAnswer(
        (_) async =>
            status_repository.StatusPage(statuses: const [], hasMore: false),
      );
      await pumpAppView(tester, _authenticatedState);
      await tester.tap(find.byKey(const Key('app-bottom-navigation-browse')));
      await pumpNavigation(tester);
      final browse = tester.element(find.byType(BrowsePage));
      await tester.tap(find.byIcon(RemixIcons.search_line));
      await pumpNavigation(tester);
      expect(find.byType(SearchPage), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(SearchPage))).state.uri.path,
        AppRoutePath.search,
      );
      expect(find.byType(AppBottomNavigationBar), findsNothing);
      expect(find.text('输入关键词搜索全站消息'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await pumpNavigation(tester);
      expect(find.byType(SearchPage), findsNothing);
      expect(tester.element(find.byType(BrowsePage)), same(browse));
      verify(() => statusRepository.getPublicTimeline()).called(1);
    });

    testWidgets('switches between lazily routed tabs', (tester) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(MentionsPage, skipOffstage: false), findsNothing);
      expect(find.byType(BrowsePage, skipOffstage: false), findsNothing);
      expect(find.byType(MinePage, skipOffstage: false), findsNothing);

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-mentions')),
      );
      await pumpNavigation(tester);
      expect(find.byType(MentionsPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
      // Entering the mentions tab refreshes the notification counters.
      verify(() => notificationCountsCubit.refresh()).called(1);

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-browse')),
      );
      await pumpNavigation(tester);
      expect(find.byType(BrowsePage), findsOneWidget);
      expect(find.byType(MentionsPage), findsNothing);
      expect(find.byType(MentionsPage, skipOffstage: false), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-mine')),
      );
      await tester.pump();
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).shape,
        const Border(),
      );
      await pumpNavigation(tester);
      expect(find.byType(MinePage), findsOneWidget);
      expect(find.byType(UserProfilePage), findsNothing);
      expect(find.byType(UserProfileView), findsOneWidget);
      expect(GoRouter.of(context).state.uri.path, AppRoutePath.mine);
      expect(find.byType(AppShellAppBar), findsOneWidget);
      expect(find.byType(AppSubpageAppBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(RemixIcons.menu_2_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.mail_line), findsOneWidget);
      // Entering the mine tab triggers a second refresh.
      verify(() => notificationCountsCubit.refresh()).called(1);
      expect(find.byType(BrowsePage), findsNothing);
      expect(find.byType(BrowsePage, skipOffstage: false), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-home')),
      );
      await pumpNavigation(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(BrowsePage, skipOffstage: false), findsOneWidget);
    });

    for (final tab in ['home', 'mentions', 'browse']) {
      testWidgets('refreshes profile counts when returning from $tab', (
        tester,
      ) async {
        await pumpAppView(tester, _authenticatedState);
        await tester.tap(find.byKey(const Key('app-bottom-navigation-mine')));
        await pumpNavigation(tester);
        verify(() => userRepository.getUser(_account.id)).called(1);

        await tester.tap(find.byKey(Key('app-bottom-navigation-$tab')));
        await pumpNavigation(tester);
        when(() => userRepository.getUser(_account.id)).thenAnswer(
          (_) async => const UserProfile(
            id: 'account-id',
            name: 'Account',
            screenName: 'account',
            favoritesCount: 17,
            statusesCount: 23,
            photoCount: 5,
          ),
        );
        verifyNever(() => userRepository.getUser(_account.id));

        await tester.tap(find.byKey(const Key('app-bottom-navigation-mine')));
        await pumpNavigation(tester);

        verify(() => userRepository.getUser(_account.id)).called(1);
        expect(find.text('17'), findsOneWidget);
        expect(find.text('23'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        await tester.pump();
        verifyNever(() => userRepository.getUser(_account.id));
      });
    }

    for (final pushedProfile in [false, true]) {
      testWidgets(
        'refreshes the visible current profile after a root route pop '
        'for pushedProfile=$pushedProfile',
        (tester) async {
          await pumpAppView(tester, _authenticatedState);
          final router = GoRouter.of(tester.element(find.byType(AppShell)));
          await tester.tap(find.byKey(const Key('app-bottom-navigation-mine')));
          await pumpNavigation(tester);
          verify(() => userRepository.getUser(_account.id)).called(1);

          if (pushedProfile) {
            unawaited(
              router.pushNamed<void>(
                AppRouteName.userProfile,
                pathParameters: {'userId': _account.id},
                queryParameters: const {'presentation': 'pushed'},
              ),
            );
            await pumpNavigation(tester);
            verify(() => userRepository.getUser(_account.id)).called(1);
          }

          unawaited(
            router.pushNamed<void>(
              AppRouteName.statusDetail,
              pathParameters: {
                'userId': _author.id,
                'statusId': _homeStatus.id,
              },
            ),
          );
          await pumpNavigation(tester);
          verifyNever(() => userRepository.getUser(_account.id));

          router.pop();
          await pumpNavigation(tester);
          verify(() => userRepository.getUser(_account.id)).called(1);
          expect(find.byType(UserProfileView), findsOneWidget);

          if (pushedProfile) {
            router.pop();
            await pumpNavigation(tester);
            verify(() => userRepository.getUser(_account.id)).called(1);
            expect(find.byType(MinePage), findsOneWidget);
          }
        },
      );
    }

    testWidgets('opens favorites and settings from the profile tab', (
      tester,
    ) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));
      final favoritesLabel = context.l10n.userProfileFavoritesLabel;
      final profileLabel = context.l10n.userProfilePageTitle;
      final settingsPageTitle = context.l10n.settingsPageTitle;

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-mine')),
      );
      await pumpNavigation(tester);

      await tester.tap(find.text(favoritesLabel));
      await pumpNavigation(tester);
      expect(find.byType(FavoritesPage), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(FavoritesPage))).state.uri.path,
        '/favorites/${_account.id}',
      );
      verify(
        () => statusRepository.getFavorites(userId: _account.id),
      ).called(1);
      expect(find.text(profileLabel), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(FavoritesPage),
          matching: find.byType(BackButton),
        ),
      );
      await pumpNavigation(tester);
      await tester.tap(find.byIcon(RemixIcons.menu_2_line));
      await pumpNavigation(tester);

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text(settingsPageTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-font-size-row')));
      await pumpNavigation(tester);
      expect(find.byType(FontSizePage), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(FontSizePage))).state.uri.path,
        '/${_account.id}/settings/font-size',
      );
      expect(find.byType(Slider), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await pumpNavigation(tester);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(FontSizePage), findsNothing);

      expect(find.text(profileLabel), findsNothing);
    });

    for (final pushedProfile in [false, true]) {
      testWidgets(
        'refreshes notification counts after leaving the direct message list '
        'for pushedProfile=$pushedProfile',
        (tester) async {
          await pumpAppView(tester, _authenticatedState);
          await tester.tap(find.byKey(const Key('app-bottom-navigation-mine')));
          await pumpNavigation(tester);
          verify(() => notificationCountsCubit.refresh()).called(1);
          final router = GoRouter.of(tester.element(find.byType(AppShell)));
          if (pushedProfile) {
            unawaited(
              router.pushNamed<void>(
                AppRouteName.userProfile,
                pathParameters: {'userId': _account.id},
                queryParameters: const {'presentation': 'pushed'},
              ),
            );
            await pumpNavigation(tester);
          }
          final profileLocation = router.state.uri;
          await tester.tap(find.byIcon(RemixIcons.mail_line));
          await pumpNavigation(tester);

          expect(find.byType(ConversationListPage), findsOneWidget);
          expect(router.state.uri.path, AppRoutePath.directMessageList);
          verify(
            () =>
                directMessageRepository.getConversationList(limit: 20, page: 1),
          ).called(1);
          verifyNever(() => notificationCountsCubit.refresh());

          await tester.tap(
            find.descendant(
              of: find.byType(ConversationListPage),
              matching: find.byType(BackButton),
            ),
          );
          await pumpNavigation(tester);

          expect(router.state.uri, profileLocation);
          expect(find.byType(UserProfileView), findsOneWidget);
          expect(find.byType(ConversationListPage), findsNothing);
          verify(() => notificationCountsCubit.refresh()).called(1);
        },
      );
    }

    testWidgets(
      'preserves timeline data after changing appearance in settings',
      (tester) async {
        final appearanceStates = StreamController<AppearanceState>();
        addTearDown(appearanceStates.close);
        const initialAppearanceState = AppearanceState(
          status: AppearanceStatus.success,
          settings: AppearanceSettings(),
        );
        whenListen(
          appearanceCubit,
          appearanceStates.stream,
          initialState: initialAppearanceState,
        );

        await pumpAppView(tester, _authenticatedState);

        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-mentions')),
        );
        await pumpNavigation(tester);
        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-mine')),
        );
        await pumpNavigation(tester);
        await tester.tap(find.byIcon(RemixIcons.menu_2_line));
        await pumpNavigation(tester);

        appearanceStates.add(
          const AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(themeMode: AppThemeMode.dark),
          ),
        );
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(BackButton),
          ),
        );
        await pumpNavigation(tester);
        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-home')),
        );
        await pumpNavigation(tester);

        expect(find.text(_homeStatus.text), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('app-bottom-navigation-mentions')),
        );
        await pumpNavigation(tester);

        expect(find.text(_mentionStatus.text), findsOneWidget);
        verify(() => statusRepository.getHomeTimeline()).called(1);
        // Re-entering the mentions tab reloads the timeline.
        verify(
          () => statusRepository.getMentions(
            sinceId: any(named: 'sinceId'),
            maxId: any(named: 'maxId'),
          ),
        ).called(2);
      },
    );

    testWidgets('opens another user at the shared user route', (tester) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      await tester.tap(find.text(_author.name));
      await pumpNavigation(tester);

      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(find.byType(UserProfileView), findsOneWidget);
      expect(GoRouter.of(context).state.uri.path, '/${_author.id}');
      expect(find.text(context.l10n.userProfilePageTitle), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    group('profile list empty states', () {
      for (final entry in [
        (label: '消息', route: AppRouteName.userStatuses),
        (label: '照片', route: AppRouteName.userPhotos),
        (label: '收藏', route: AppRouteName.favorites),
      ]) {
        for (final count in [null, 0, 42]) {
          testWidgets(
            'shows the matching empty state for '
            '$entry with profile count=$count',
            (tester) async {
              when(() => userRepository.getUser(_author.id)).thenAnswer(
                (_) async => UserProfile(
                  id: _author.id,
                  name: _author.name,
                  screenName: _author.screenName,
                  statusesCount: count,
                  photoCount: count,
                  favoritesCount: count,
                ),
              );
              final emptyPage = status_repository.StatusPage(
                statuses: const [],
                hasMore: false,
              );
              when(
                () => statusRepository.getUserTimeline(userId: _author.id),
              ).thenAnswer((_) async => emptyPage);
              when(
                () => statusRepository.getPhotoTimeline(userId: _author.id),
              ).thenAnswer((_) async => emptyPage);
              when(
                () => statusRepository.getFavorites(userId: _author.id),
              ).thenAnswer((_) async => emptyPage);
              await pumpAppView(tester, _authenticatedState);
              final context = tester.element(find.byType(AppShell));

              await tester.tap(find.text(_author.name));
              await pumpNavigation(tester);
              await tester.tap(find.text(entry.label));
              await pumpNavigation(tester);

              expect(
                find.text(context.l10n.statusListEmptyLabel),
                (count ?? 0) > 0 ? findsOneWidget : findsNothing,
              );
              expect(
                find.byType(AppEmptyView),
                (count ?? 0) > 0 ? findsNothing : findsOneWidget,
              );
            },
          );
        }

        testWidgets(
          'shows the illustration when opening $entry without a profile count',
          (tester) async {
            final emptyPage = status_repository.StatusPage(
              statuses: const [],
              hasMore: false,
            );
            when(
              () => statusRepository.getUserTimeline(userId: _author.id),
            ).thenAnswer((_) async => emptyPage);
            when(
              () => statusRepository.getPhotoTimeline(userId: _author.id),
            ).thenAnswer((_) async => emptyPage);
            when(
              () => statusRepository.getFavorites(userId: _author.id),
            ).thenAnswer((_) async => emptyPage);
            await pumpAppView(tester, _authenticatedState);
            final context = tester.element(find.byType(AppShell));

            unawaited(
              context.pushNamed<void>(
                entry.route,
                pathParameters: {'userId': _author.id},
              ),
            );
            await pumpNavigation(tester);

            expect(find.byType(AppEmptyView), findsOneWidget);
            expect(
              find.text(context.l10n.statusListEmptyLabel),
              findsNothing,
            );
          },
        );
      }
    });

    testWidgets('opens another user favorites from their profile', (
      tester,
    ) async {
      when(
        () => statusRepository.getFavorites(userId: _author.id),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_favoriteStatus],
          hasMore: false,
        ),
      );
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      await tester.tap(find.text(_author.name));
      await pumpNavigation(tester);
      await tester.tap(find.text(context.l10n.userProfileFavoritesLabel));
      await pumpNavigation(tester);

      expect(find.byType(FavoritesPage), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(FavoritesPage))).state.uri.path,
        '/favorites/${_author.id}',
      );
      verify(
        () => statusRepository.getFavorites(userId: _author.id),
      ).called(1);
    });

    testWidgets('opens another user messages and photos from their profile', (
      tester,
    ) async {
      when(
        () => statusRepository.getUserTimeline(userId: _author.id),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_homeStatus],
          hasMore: false,
        ),
      );
      when(
        () => statusRepository.getPhotoTimeline(userId: _author.id),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_homeStatusWithPhoto],
          hasMore: false,
        ),
      );
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      await tester.tap(find.text(_author.name));
      await pumpNavigation(tester);
      await tester.tap(find.text(context.l10n.userProfileMessagesLabel));
      await pumpNavigation(tester);

      expect(find.byType(UserStatusesPage), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(UserStatusesPage)),
        ).state.uri.path,
        '/statuses/${_author.id}',
      );
      expect(find.text(_homeStatus.text), findsOneWidget);
      verify(
        () => statusRepository.getUserTimeline(userId: _author.id),
      ).called(1);

      await tester.tap(
        find.descendant(
          of: find.byType(UserStatusesPage),
          matching: find.byType(BackButton),
        ),
      );
      await pumpNavigation(tester);
      await tester.tap(find.text(context.l10n.userProfilePhotosLabel));
      await pumpNavigation(tester);

      expect(find.byType(UserPhotosPage), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(UserPhotosPage)),
        ).state.uri.path,
        '/photos/${_author.id}',
      );
      final albumPhoto = find.descendant(
        of: find.byType(UserPhotosPage),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CachedNetworkImage &&
              widget.imageUrl == _homeStatusWithPhoto.photo!.displayUrl,
        ),
      );
      expect(albumPhoto, findsOneWidget);
      verify(
        () => statusRepository.getPhotoTimeline(userId: _author.id),
      ).called(1);

      await tester.tap(albumPhoto);
      await pumpNavigation(tester);
      expect(find.byType(StatusImageViewerPage), findsOneWidget);
      expect(find.byType(StatusDetailPage), findsNothing);
      final preview = tester.widget<StatusImageViewerPage>(
        find.byType(StatusImageViewerPage),
      );
      expect(preview.imageUrl, _homeStatusWithPhoto.photo!.viewerUrl);
      expect(preview.userId, _homeStatusWithPhoto.author.id);
      expect(preview.statusId, _homeStatusWithPhoto.id);
      expect(preview.initialStatus, same(_homeStatusWithPhoto));

      await tester.tap(
        find.text(context.l10n.statusImageViewerViewStatusLabel),
      );
      await pumpNavigation(tester);
      expect(find.byType(StatusDetailPage), findsOneWidget);
      expect(
        tester
            .widget<StatusDetailPage>(find.byType(StatusDetailPage))
            .initialStatus,
        same(_homeStatusWithPhoto),
      );
      verifyNever(() => statusRepository.getStatus(_homeStatusWithPhoto.id));
    });

    testWidgets(
      'pushes the active account profile as an independent page from a status',
      (tester) async {
        when(
          () => statusRepository.getHomeTimeline(),
        ).thenAnswer(
          (_) async => status_repository.StatusPage(
            statuses: const [_currentAccountStatus],
            hasMore: false,
          ),
        );
        await pumpAppView(tester, _authenticatedState);

        await tester.tap(find.text(_account.name));
        await pumpNavigation(tester);

        final profileContext = tester.element(find.byType(UserProfilePage));
        final router = GoRouter.of(profileContext);
        expect(find.byType(UserProfilePage), findsOneWidget);
        expect(find.byType(AppSubpageAppBar), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byType(AppBottomNavigationBar), findsNothing);
        expect(router.state.uri.path, '/${_account.id}');
        expect(
          router.state.uri.queryParameters,
          const {'presentation': 'pushed'},
        );
      },
    );

    testWidgets('opens a status detail page from a status list item', (
      tester,
    ) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));
      final title = context.l10n.statusDetailPageTitle;
      final profileLabel = context.l10n.userProfilePageTitle;

      await tester.tap(find.text(_homeStatus.text));
      await pumpNavigation(tester);

      expect(find.byType(StatusDetailPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text(title), findsOneWidget);
      expect(find.text(_homeStatus.text), findsOneWidget);
      expect(find.text(profileLabel), findsNothing);
      verifyNever(() => statusRepository.getStatus(_homeStatus.id));
    });

    group('iOS back navigation', () {
      testWidgets('uses a Cupertino route for the tab root', (tester) async {
        await pumpAppView(tester, _authenticatedState);
        final route = ModalRoute.of(tester.element(find.byType(AppShell)))!;

        expect(route.settings, isA<CupertinoPage<void>>());
        expect(route.delegatedTransition, isNotNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      for (final completesSwipe in [false, true]) {
        testWidgets(
          completesSwipe
              ? 'returns to the home timeline after an edge swipe'
              : 'keeps status detail open after an incomplete edge swipe',
          (tester) async {
            await pumpAppView(tester, _authenticatedState);
            await tester.tap(find.text(_homeStatus.text));
            await pumpNavigation(tester);

            final detail = find.byType(StatusDetailPage);
            final bounds = tester.getRect(detail);
            final gesture = await tester.startGesture(
              Offset(bounds.left + 1, bounds.center.dy),
            );
            await gesture.moveBy(const Offset(20, 0));
            await gesture.moveBy(
              Offset(bounds.width * (completesSwipe ? 0.8 : 0.2), 0),
              timeStamp: const Duration(seconds: 1),
            );
            await tester.pump();

            expect(tester.getTopLeft(detail).dx, greaterThan(bounds.left));

            await gesture.up(timeStamp: const Duration(seconds: 2));
            await pumpNavigation(tester);

            expect(
              detail,
              completesSwipe ? findsNothing : findsOneWidget,
            );
            expect(
              find.byType(AppShell),
              completesSwipe ? findsOneWidget : findsNothing,
            );
            expect(find.text(_homeStatus.text), findsOneWidget);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    });

    testWidgets('opens the author profile from status detail', (tester) async {
      await pumpAppView(tester, _authenticatedState);

      await tester.tap(find.text(_homeStatus.text));
      await pumpNavigation(tester);
      await tester.tap(find.text(_author.name));
      await pumpNavigation(tester);

      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(UserProfilePage)),
        ).state.uri.path,
        '/${_author.id}',
      );
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        find.byType(StatusDetailPage, skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await pumpNavigation(tester);

      expect(find.byType(StatusDetailPage), findsOneWidget);
      expect(find.text(_homeStatus.text), findsOneWidget);
    });

    testWidgets('opens a mentioned user profile from status detail', (
      tester,
    ) async {
      when(
        () => statusRepository.getHomeTimeline(),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_homeStatusWithMention],
          hasMore: false,
        ),
      );
      await pumpAppView(tester, _authenticatedState);

      await tester.tap(find.textContaining('7月28日'));
      await pumpNavigation(tester);
      _tapStatusBodySpan(tester, '@${_mentionedProfile.screenName}');
      await pumpNavigation(tester);

      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(UserProfilePage)),
        ).state.uri.path,
        '/${_mentionedProfile.id}',
      );
      expect(
        find.byType(StatusDetailPage, skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await pumpNavigation(tester);

      expect(find.byType(StatusDetailPage), findsOneWidget);
      expect(
        find.textContaining('@${_mentionedProfile.screenName}'),
        findsOneWidget,
      );
    });

    testWidgets('loads status detail when navigation has no initial status', (
      tester,
    ) async {
      await pumpAppView(tester, _authenticatedState);
      final context = tester.element(find.byType(AppShell));

      unawaited(
        context.pushNamed<void>(
          AppRouteName.statusDetail,
          pathParameters: {
            'userId': _homeStatus.author.id,
            'statusId': _homeStatus.id,
          },
        ),
      );
      await pumpNavigation(tester);

      expect(find.byType(StatusDetailPage), findsOneWidget);
      expect(find.text(_homeStatus.text), findsOneWidget);
      verify(() => statusRepository.getStatus(_homeStatus.id)).called(1);
    });

    testWidgets('opens a full-screen image viewer from a status photo', (
      tester,
    ) async {
      when(
        () => statusRepository.getHomeTimeline(),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [_homeStatusWithPhoto],
          hasMore: false,
        ),
      );
      await pumpAppView(tester, _authenticatedState);

      await tester.tap(find.byType(StatusPhoto));
      await pumpNavigation(tester);
      final image = tester.widget<PhotoView>(
        find.descendant(
          of: find.byType(StatusImageViewerPage),
          matching: find.byType(PhotoView),
        ),
      );

      expect(find.byType(StatusImageViewerPage), findsOneWidget);
      expect(image.initialScale, PhotoViewComputedScale.contained);
      expect(image.basePosition, Alignment.center);
      expect(
        find.byKey(const Key('status-image-viewer-gesture-layer')),
        findsOneWidget,
      );
      expect(find.byType(StatusDetailPage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets(
      'does not slide the status detail page when opening its image viewer',
      (tester) async {
        when(
          () => statusRepository.getHomeTimeline(),
        ).thenAnswer(
          (_) async => status_repository.StatusPage(
            statuses: const [_homeStatusWithPhoto],
            hasMore: false,
          ),
        );
        await pumpAppView(tester, _authenticatedState);

        await tester.tap(find.text(_homeStatusWithPhoto.text));
        await pumpNavigation(tester);
        final detailPage = find.byType(StatusDetailPage);
        final detailPageLeftBeforePush = tester.getTopLeft(detailPage).dx;

        await tester.tap(find.byType(StatusPhoto));
        await tester.pump();
        await tester.pump(Durations.short4);

        expect(find.byType(StatusImageViewerPage), findsOneWidget);
        expect(
          tester.getTopLeft(detailPage).dx,
          detailPageLeftBeforePush,
        );
      },
    );

    testWidgets('renders failure page and dispatches retry request', (
      tester,
    ) async {
      await pumpAppView(tester, const AuthenticationRestoreFailure());

      expect(find.byType(AuthenticationFailurePage), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verify(
        () => authenticationBloc.add(
          const AuthenticationSubscriptionRequested(),
        ),
      ).called(1);
    });
  });
}

final _authenticatedState = AuthenticationAuthenticated(
  AuthenticationSnapshot.authenticated(
    accounts: const [_account],
    activeAccount: _account,
  ),
);

AuthenticationAuthenticated _authenticatedStateFor(
  AuthenticatedAccount account,
) {
  return AuthenticationAuthenticated(
    AuthenticationSnapshot.authenticated(
      accounts: [account],
      activeAccount: account,
    ),
  );
}

const _account = AuthenticatedAccount(
  id: 'account-id',
  name: 'Account',
  screenName: 'account',
  avatarUrl: 'https://example.com/avatar.png',
);

const _secondAccount = AuthenticatedAccount(
  id: 'second-account-id',
  name: 'Second Account',
  screenName: 'second-account',
);

const _author = status_repository.StatusAuthor(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
);

const _authorProfile = UserProfile(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
);

const _mentionedProfile = UserProfile(
  id: 'user-b',
  name: '饭友 B',
  screenName: 'fanfou_b',
);

const _accountProfile = UserProfile(
  id: 'account-id',
  name: 'Account',
  screenName: 'account',
  avatarUrl: 'https://example.com/avatar.png',
);

const _notificationCounts = UserNotificationCounts(
  mentions: 2,
  directMessages: 3,
  friendRequests: 4,
);

const _homeStatus = status_repository.Status(
  id: 'home-status-a',
  text: '真实首页时间线动态',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: _author,
);

const _currentAccountStatus = status_repository.Status(
  id: 'current-account-status',
  text: '当前账号的动态',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'account-id',
    name: 'Account',
    screenName: 'account',
  ),
);

const _homeStatusWithPhoto = status_repository.Status(
  id: 'home-status-with-photo',
  text: '带图片的首页动态',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: _author,
  photo: status_repository.StatusPhotoUrls(
    thumbnailUrl: 'https://example.com/home-status-photo-thumb.png',
    imageUrl: 'https://example.com/home-status-photo.png',
    largeUrl: 'https://example.com/home-status-photo-large.png',
  ),
);

const _homeStatusWithMention = status_repository.Status(
  id: 'home-status-with-mention',
  text: '提到 @<a href="https://fanfou.com/user-b">fanfou_b</a>',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: _author,
);

const _mentionStatus = status_repository.Status(
  id: 'mention-status-a',
  text: '真实提到我的动态',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: _author,
);

const _favoriteStatus = status_repository.Status(
  id: 'favorite-status-a',
  text: '真实收藏动态',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: _author,
);

void _tapStatusBodySpan(WidgetTester tester, String text) {
  final body = tester.widget<Text>(
    find.descendant(
      of: find.byType(StatusBodyText),
      matching: find.byType(Text),
    ),
  );
  final root = body.textSpan! as TextSpan;
  final span = root.children!.cast<TextSpan>().singleWhere(
    (span) => span.text == text,
  );

  expect(span.recognizer, isA<TapGestureRecognizer>());
  (span.recognizer! as TapGestureRecognizer).onTap!();
}
