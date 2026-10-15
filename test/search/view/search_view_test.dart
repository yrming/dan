import 'dart:async';

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/search/search.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart' as repository;

import '../../helpers/helpers.dart';

class _MockStatusRepository extends Mock
    implements repository.StatusRepository {}

void main() {
  group(SearchView, () {
    late repository.StatusRepository statusRepository;
    late StatusListBloc bloc;

    setUp(() {
      statusRepository = _MockStatusRepository();
      when(
        () => statusRepository.statusChanges,
      ).thenAnswer((_) => const Stream.empty());
    });

    Future<void> pumpSearch(WidgetTester tester, {String? initialQuery}) async {
      bloc = StatusListBloc(
        statusRepository: statusRepository,
        feed: StatusFeed.search,
        accountId: 'account',
      );
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(
            path: '/search',
            builder: (_, _) => BlocProvider(
              create: (_) => bloc,
              child: SearchView(initialQuery: initialQuery),
            ),
          ),
          GoRoute(
            name: AppRouteName.statusDetail,
            path: AppRoutePath.statusDetail,
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('detail: ${(state.extra! as repository.Status).id}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpRouterApp(router);
      await tester.pump();
    }

    testWidgets('does not autofocus when opened from a topic', (tester) async {
      when(
        () => statusRepository.searchStatuses(query: 'flutter'),
      ).thenAnswer(
        (_) async => repository.StatusPage(
          statuses: const [],
          hasMore: false,
        ),
      );
      await pumpSearch(tester, initialQuery: 'flutter');
      expect(
        tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
        isFalse,
      );
      verify(() => statusRepository.searchStatuses(query: 'flutter')).called(1);
    });

    testWidgets('puts input in the app bar and waits for a keyword', (
      tester,
    ) async {
      await pumpSearch(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
      expect(find.text('输入关键词搜索全站消息'), findsNothing);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('输入关键词搜索全站消息'), findsNothing);
      verifyNever(
        () => statusRepository.searchStatuses(query: any(named: 'query')),
      );
    });

    testWidgets('offers only all and mine scopes and updates the hint', (
      tester,
    ) async {
      await pumpSearch(tester);
      expect(find.text('搜索全站消息'), findsOneWidget);
      await tester.tap(find.text('全站'));
      await tester.pumpTransition();
      expect(
        tester
            .widgetList<AppActionSheetItem>(find.byType(AppActionSheetItem))
            .map((item) => item.label),
        ['全站', '我的'],
      );
      expect(find.text('用户'), findsNothing);
      await tester.tap(find.text('我的'));
      await tester.pumpTransition();
      expect(find.text('搜索我的消息'), findsOneWidget);
      await tester.tap(find.text('我的'));
      await tester.pumpTransition();
      await tester.tap(find.text('全站'));
      await tester.pumpTransition();
      expect(find.text('搜索全站消息'), findsOneWidget);
    });

    testWidgets('disables search for empty input and enables it for keywords', (
      tester,
    ) async {
      await pumpSearch(tester);
      final action = find.ancestor(
        of: find.text('搜索'),
        matching: find.byType(InkWell),
      );
      expect(action, findsNothing);
      expect(find.byKey(const ValueKey('search-action-divider')), findsNothing);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(find.text('搜索'), findsNothing);
      expect(find.byKey(const ValueKey('search-action-divider')), findsNothing);
      verifyNever(
        () => statusRepository.searchStatuses(query: any(named: 'query')),
      );

      await tester.enterText(find.byType(TextField), '猫');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('search-action-divider')),
        findsOneWidget,
      );
      final clearIconRect = tester.getRect(find.byIcon(RemixIcons.close_line));
      final dividerRect = tester.getRect(
        find.byKey(const ValueKey('search-action-divider')),
      );
      final searchTextRect = tester.getRect(find.text('搜索'));
      final clearToDivider = dividerRect.left - clearIconRect.right;
      final dividerToSearch = searchTextRect.left - dividerRect.right;
      expect(clearToDivider, closeTo(10, 0.001));
      expect(dividerToSearch, closeTo(12, 0.001));
      expect(tester.widget<InkWell>(action).onTap, isNotNull);

      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(action, findsNothing);
    });

    testWidgets('keeps input geometry when typing, clearing and losing focus', (
      tester,
    ) async {
      await pumpSearch(tester);
      final input = find.byType(InputDecorator);
      final initialRect = tester.getRect(input);
      expect(
        initialRect.right,
        closeTo(
          tester.view.physicalSize.width / tester.view.devicePixelRatio -
              AppSpacing.md,
          0.001,
        ),
      );
      final initialDecoration = tester.widget<InputDecorator>(input).decoration;
      final border = initialDecoration.focusedBorder! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(16));
      expect(initialDecoration.enabledBorder, border);

      await tester.enterText(find.byType(TextField), '搜索内容');
      await tester.pump();
      expect(find.byTooltip('清空搜索'), findsOneWidget);
      expect(find.byIcon(RemixIcons.close_line), findsOneWidget);
      expect(
        tester.getSize(find.byType(IconButton)),
        const Size(40, 40),
      );
      expect(tester.getRect(input), initialRect);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(input), initialRect);
      expect(tester.widget<InputDecorator>(input).isFocused, isFalse);
      expect(find.text('搜索'), findsNothing);
      expect(find.byKey(const ValueKey('search-action-divider')), findsNothing);

      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(find.byTooltip('清空搜索'), findsNothing);
      expect(tester.getRect(input), initialRect);

      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<InputDecorator>(input).isFocused, isTrue);
      expect(find.text('搜索'), findsNothing);
      expect(
        find.byKey(const ValueKey('search-action-divider')),
        findsNothing,
      );
      expect(tester.getRect(input), initialRect);
    });

    testWidgets('submits, shows loading and opens a result then returns', (
      tester,
    ) async {
      final response = Completer<repository.StatusPage>();
      when(
        () => statusRepository.searchStatuses(query: '猫'),
      ).thenAnswer((_) => response.future);
      await pumpSearch(tester);
      await tester.enterText(find.byType(TextField), ' 猫 ');
      await tester.pump();
      final action = find.ancestor(
        of: find.text('搜索'),
        matching: find.byType(InkWell),
      );
      await tester.tap(action);
      await tester.pump();
      expect(bloc.state.status, StatusListStatus.loading);
      expect(
        tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
        isFalse,
      );
      expect(find.text('搜索'), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(StatusListSkeleton), findsOneWidget);
      response.complete(
        repository.StatusPage(statuses: const [_status], hasMore: false),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('猫在晒太阳'), findsOneWidget);
      expect(find.text('搜索'), findsNothing);
      expect(find.byType(CupertinoSliverRefreshControl), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      verify(() => statusRepository.searchStatuses(query: '猫')).called(1);
      await tester.tap(find.text('猫在晒太阳'));
      await tester.pumpTransition();
      expect(find.text('detail: result'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpTransition();
      expect(find.text('猫在晒太阳'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        ' 猫 ',
      );
      verifyNever(() => statusRepository.searchStatuses(query: '猫'));
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(find.text('输入关键词搜索全站消息'), findsNothing);
      expect(find.text('猫在晒太阳'), findsNothing);
    });

    testWidgets('retries failures and displays the no-results message', (
      tester,
    ) async {
      var calls = 0;
      when(() => statusRepository.searchStatuses(query: '猫')).thenAnswer((
        _,
      ) async {
        if (calls++ == 0) {
          throw const repository.StatusRepositoryUnknownFailure();
        }
        return repository.StatusPage(statuses: const [], hasMore: false);
      });
      await pumpSearch(tester);
      await tester.enterText(find.byType(TextField), '猫');
      await tester.pump();
      await tester.tap(find.text('搜索'));
      await tester.pump();
      await tester.pump();
      expect(bloc.state.status, StatusListStatus.failure);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('重试'), findsOneWidget);
      expect(find.byType(CupertinoSliverRefreshControl), findsNothing);
      expect(find.text('搜索'), findsNothing);
      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump();
      expect(find.text('没有找到相关消息'), findsOneWidget);
      expect(find.byType(CupertinoSliverRefreshControl), findsNothing);
      verify(() => statusRepository.searchStatuses(query: '猫')).called(2);
    });
  });
}

const _status = repository.Status(
  id: 'result',
  text: '猫在晒太阳',
  createdAt: '2026-09-29T01:00:00Z',
  author: repository.StatusAuthor(
    id: 'author',
    name: '作者',
    screenName: 'author',
  ),
);
