import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockFollowRequestsCubit extends MockCubit<FollowRequestsState>
    implements FollowRequestsCubit {}

void main() {
  group(FollowRequestsView, () {
    late FollowRequestsCubit cubit;

    setUp(() {
      cubit = _MockFollowRequestsCubit();
    });

    group('empty message', () {
      testWidgets('shows the personal message when there are no requests', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          FollowRequestsState(loading: false, hasMore: false),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: FollowRequestsView()),
          ),
        );

        expect(
          find.text('你似季候风\n抵挡计划全也无用\n然后是场空'),
          findsOneWidget,
        );
      });
    });

    group('request list items', () {
      testWidgets('does not show a splash when the item is tapped', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          FollowRequestsState(
            users: const [
              UserProfile(id: 'user', name: 'Name', screenName: 'screen'),
            ],
            loading: false,
            hasMore: false,
          ),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: FollowRequestsView()),
          ),
        );

        final tile = tester.widget<ListTile>(find.byType(ListTile));

        expect(
          tile.splashColor ??
              Theme.of(tester.element(find.byType(ListTile))).splashColor,
          AppColors.transparent,
        );
      });
    });
  });
}
