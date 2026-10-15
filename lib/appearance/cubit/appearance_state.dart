part of 'appearance_cubit.dart';

/// Persistence status for global appearance preferences.
enum AppearanceStatus {
  /// Settings are being loaded from storage.
  loading,

  /// A settings update is being persisted.
  saving,

  /// Settings are available and persisted.
  success,

  /// Loading or persistence failed.
  failure,
}

/// State emitted by [AppearanceCubit].
final class AppearanceState extends Equatable {
  /// Creates appearance state.
  const AppearanceState({
    required this.status,
    required this.settings,
  });

  /// Current loading or persistence status.
  final AppearanceStatus status;

  /// Appearance settings currently applied to the application.
  final AppearanceSettings settings;

  /// Creates a copy with selected fields replaced.
  AppearanceState copyWith({
    AppearanceStatus? status,
    AppearanceSettings? settings,
  }) {
    return AppearanceState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object> get props => [status, settings];
}
