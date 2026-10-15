import 'package:bloc_test/bloc_test.dart';
import 'package:dan/blacklist/cubit/blacklist_cubit.dart';
import 'package:dan/blacklist/view/blacklist_view.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockBlacklistCubit extends MockCubit<BlacklistState>
    implements BlacklistCubit {}

void main() {
  group(BlacklistView, () {
    late BlacklistCubit cubit;

    setUp(() {
      cubit = _MockBlacklistCubit();
      when(() => cubit.state).thenReturn(
        const BlacklistState(
          status: BlacklistStatus.success,
          users: [_user],
          hasMore: false,
        ),
      );
      when(() => cubit.remove(_user.id)).thenAnswer((_) async {});
    });

    testWidgets('confirms before removing a user from the blacklist', (
      tester,
    ) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: BlacklistView()),
        ),
      );

      await tester.tap(find.text('移出'));
      await tester.pump();

      expect(find.text('移出黑名单？'), findsOneWidget);
      final context = tester.element(find.byType(BlacklistView));
      expect(
        find.text(
          context.l10n.confirmationDialogContent,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('移出').last);
      await tester.pump();

      verify(() => cubit.remove(_user.id)).called(1);
    });

    testWidgets('shows the empty blacklist message when no users are blocked', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const BlacklistState(status: BlacklistStatus.success, hasMore: false),
      );

      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: BlacklistView()),
        ),
      );

      expect(
        find.text(
          '如果白痴都会飞\n我简直活在机场周围\n你是否也看到他们就会感觉反胃',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.text(
                '如果白痴都会飞\n我简直活在机场周围\n你是否也看到他们就会感觉反胃',
              ),
            )
            .textAlign,
        TextAlign.center,
      );
    });
  });
}

const _user = UserProfile(
  id: 'blocked-user',
  name: 'Blocked User',
  screenName: 'blocked',
);
