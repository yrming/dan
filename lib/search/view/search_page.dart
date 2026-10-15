import 'dart:async';

import 'package:dan/authentication/authentication.dart';
import 'package:dan/search/models/search_scope.dart';
import 'package:dan/search/view/search_view.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:status_repository/status_repository.dart';

/// Provides account-scoped search results.
class SearchPage extends StatelessWidget {
  const SearchPage({
    this.initialQuery,
    this.initialScope = SearchScope.all,
    this.userId,
    super.key,
  });

  final String? initialQuery;
  final SearchScope initialScope;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final accountId = context.select<AuthenticationBloc, String?>(
      (bloc) => switch (bloc.state) {
        AuthenticationAuthenticated(:final snapshot) =>
          snapshot.activeAccount?.id,
        _ => null,
      },
    );
    if (accountId == null) return const SizedBox.shrink();
    return _SearchSession(
      key: ValueKey(accountId),
      accountId: accountId,
      initialQuery: initialQuery,
      initialScope: initialScope,
      userId: userId,
    );
  }
}

class _SearchSession extends StatefulWidget {
  const _SearchSession({
    required this.accountId,
    required this.initialScope,
    this.userId,
    this.initialQuery,
    super.key,
  });
  final String accountId;
  final String? initialQuery;
  final SearchScope initialScope;
  final String? userId;

  @override
  State<_SearchSession> createState() => _SearchSessionState();
}

class _SearchSessionState extends State<_SearchSession> {
  late final StatusListBloc _mineBloc;
  late final StatusListBloc? _userBloc;

  @override
  void initState() {
    super.initState();
    _mineBloc = StatusListBloc(
      statusRepository: context.read<StatusRepository>(),
      feed: StatusFeed.searchMine,
      accountId: widget.accountId,
    );
    _userBloc = widget.userId == null
        ? null
        : StatusListBloc(
            statusRepository: context.read<StatusRepository>(),
            feed: StatusFeed.searchUser,
            accountId: widget.accountId,
            userId: widget.userId,
          );
  }

  @override
  void dispose() {
    unawaited(_mineBloc.close());
    unawaited(_userBloc?.close() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => StatusListBloc(
          statusRepository: context.read<StatusRepository>(),
          feed: StatusFeed.search,
          accountId: widget.accountId,
        ),
      ),
    ],
    child: SearchView(
      initialQuery: widget.initialQuery,
      initialScope: widget.initialScope,
      mineBloc: _mineBloc,
      userBloc: _userBloc,
    ),
  );
}
