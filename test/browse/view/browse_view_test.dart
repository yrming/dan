import 'package:bloc_test/bloc_test.dart';
import 'package:dan/browse/browse.dart';
import 'package:dan/status/status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

class _MockStatusListBloc extends MockBloc<StatusListEvent, StatusListState>
    implements StatusListBloc {}

void main() {
  group(BrowseView, () {
    late StatusListBloc statusListBloc;

    setUp(() {
      statusListBloc = _MockStatusListBloc();
      whenListen(
        statusListBloc,
        const Stream<StatusListState>.empty(),
        initialState: StatusListState(status: StatusListStatus.loading),
      );
    });

    testWidgets('renders the shared status list', (tester) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: statusListBloc,
          child: const BrowseView(),
        ),
      );

      expect(find.byType(StatusList), findsOneWidget);
    });
  });
}
