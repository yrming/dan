import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'appearance_state.dart';

/// Controls global appearance preferences and persists user changes.
class AppearanceCubit extends Cubit<AppearanceState> {
  /// Creates an appearance cubit.
  factory AppearanceCubit({
    required AppearanceRepository appearanceRepository,
    AppearanceSettings initialSettings = const AppearanceSettings(),
  }) {
    return AppearanceCubit._(appearanceRepository, initialSettings);
  }

  AppearanceCubit._(
    this._appearanceRepository,
    AppearanceSettings initialSettings,
  ) : _persistedSettings = initialSettings,
      super(
        AppearanceState(
          status: AppearanceStatus.success,
          settings: initialSettings,
        ),
      );

  final AppearanceRepository _appearanceRepository;
  AppearanceSettings _persistedSettings;
  Future<void> _saveQueue = Future<void>.value();
  int _saveRevision = 0;

  /// Reloads the appearance settings from storage.
  Future<void> load() async {
    emit(state.copyWith(status: AppearanceStatus.loading));
    try {
      final settings = await _appearanceRepository.load();
      _persistedSettings = settings;
      emit(
        AppearanceState(
          status: AppearanceStatus.success,
          settings: settings,
        ),
      );
    } on Object {
      emit(state.copyWith(status: AppearanceStatus.failure));
    }
  }

  /// Updates the base font size, constrained to the supported range.
  Future<void> updateFontSize(double fontSize) async {
    final normalizedFontSize = fontSize.clamp(
      AppearanceSettings.minimumFontSize,
      AppearanceSettings.maximumFontSize,
    );
    await _save(state.settings.copyWith(fontSize: normalizedFontSize));
  }

  /// Updates the light, dark, or system theme mode.
  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    await _save(state.settings.copyWith(themeMode: themeMode));
  }

  /// Updates the status photo layout.
  Future<void> updateStatusPhotoStyle(StatusPhotoStyle style) async {
    await _save(state.settings.copyWith(statusPhotoStyle: style));
  }

  /// Restores the default appearance settings.
  Future<void> reset() => _save(const AppearanceSettings());

  Future<void> _save(AppearanceSettings settings) async {
    if (settings == state.settings) {
      return;
    }

    final revision = ++_saveRevision;
    emit(
      AppearanceState(
        status: AppearanceStatus.saving,
        settings: settings,
      ),
    );
    final operation = _saveQueue.then(
      (_) => _appearanceRepository.save(settings),
    );
    _saveQueue = operation.catchError((Object _) {});

    try {
      await operation;
      _persistedSettings = settings;
      if (revision != _saveRevision) {
        return;
      }
      emit(
        AppearanceState(
          status: AppearanceStatus.success,
          settings: settings,
        ),
      );
    } on Object {
      if (revision != _saveRevision) {
        return;
      }
      emit(
        AppearanceState(
          status: AppearanceStatus.failure,
          settings: _persistedSettings,
        ),
      );
    }
  }
}
