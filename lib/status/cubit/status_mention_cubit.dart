import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:status_repository/status_repository.dart';

/// Immutable results for the mention picker.
final class StatusMentionState extends Equatable {
  StatusMentionState({
    this.query = '',
    List<StatusAuthor> users = const [],
    this.loading = false,
    this.failed = false,
  }) : users = List.unmodifiable(users);

  final String query;
  final List<StatusAuthor> users;
  final bool loading;
  final bool failed;

  @override
  List<Object> get props => [query, users, loading, failed];
}

/// Suggests distinct authors from the latest messages mentioning this account.
class StatusMentionCubit extends Cubit<StatusMentionState> {
  StatusMentionCubit({required StatusRepository statusRepository})
    : _repository = statusRepository,
      super(StatusMentionState());

  final StatusRepository _repository;
  List<StatusAuthor> _authors = const [];

  Future<void> load() async {
    if (state.loading) return;
    _emit(loading: true);
    try {
      final page = await _repository.getMentions(limit: 60);
      if (isClosed) return;
      final authors = <String, StatusAuthor>{};
      for (final status in page.statuses) {
        if (!status.isSelf) {
          authors.putIfAbsent(status.author.id, () => status.author);
        }
      }
      _authors = List.unmodifiable(authors.values);
      _emit();
    } on Object {
      if (!isClosed) _emit(failed: true);
    }
  }

  void queryChanged(String query) {
    if (query == state.query) return;
    _emit(query: query, loading: state.loading, failed: state.failed);
  }

  void _emit({String? query, bool loading = false, bool failed = false}) {
    final currentQuery = query ?? state.query;
    final keyword = currentQuery.toLowerCase();
    emit(
      StatusMentionState(
        query: currentQuery,
        users: _authors
            .where(
              (user) =>
                  user.name.toLowerCase().contains(keyword) ||
                  user.screenName.toLowerCase().contains(keyword) ||
                  user.id.toLowerCase().contains(keyword),
            )
            .toList(),
        loading: loading,
        failed: failed,
      ),
    );
  }
}
