import 'package:bloc/bloc.dart';
import 'package:dan/notifications/cubit/notification_counts_state.dart';
import 'package:user_repository/user_repository.dart';

/// Loads unread notification counters for the active account.
class NotificationCountsCubit extends Cubit<NotificationCountsState> {
  /// Creates a notification counter cubit.
  NotificationCountsCubit({required this._userRepository})
    : super(const NotificationCountsInitial());

  final UserRepository _userRepository;
  String? _activeAccountId;
  var _requestVersion = 0;

  /// Loads counters when the authenticated account changes.
  Future<void> accountChanged(String accountId) async {
    if (_activeAccountId == accountId) return;
    _activeAccountId = accountId;
    final requestVersion = ++_requestVersion;
    emit(const NotificationCountsLoadInProgress());
    try {
      final counts = await _userRepository.getNotificationCounts();
      if (requestVersion != _requestVersion) return;
      emit(NotificationCountsLoadSuccess(counts: counts));
    } on Object {
      if (requestVersion != _requestVersion) return;
      emit(const NotificationCountsLoadFailure());
    }
  }

  /// Refreshes counters for the current authenticated account.
  Future<void> refresh() async {
    if (_activeAccountId == null) return;
    final requestVersion = ++_requestVersion;
    final currentCounts = state.counts;
    emit(NotificationCountsLoadInProgress(counts: currentCounts));
    try {
      final counts = await _userRepository.getNotificationCounts();
      if (requestVersion != _requestVersion) return;
      emit(NotificationCountsLoadSuccess(counts: counts));
    } on Object {
      if (requestVersion != _requestVersion) return;
      emit(NotificationCountsLoadFailure(counts: currentCounts));
    }
  }

  /// Clears counters when there is no authenticated account.
  void reset() {
    _activeAccountId = null;
    _requestVersion++;
    emit(const NotificationCountsInitial());
  }
}
