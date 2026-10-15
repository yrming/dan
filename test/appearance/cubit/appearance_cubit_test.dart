import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppearanceRepository extends Mock implements AppearanceRepository {}

void main() {
  group(AppearanceCubit, () {
    late AppearanceRepository appearanceRepository;

    setUpAll(() {
      registerFallbackValue(const AppearanceSettings());
    });

    setUp(() {
      appearanceRepository = _MockAppearanceRepository();
    });

    test('starts with the supplied settings ready to use', () {
      const settings = AppearanceSettings(fontSize: 17);

      expect(
        AppearanceCubit(
          appearanceRepository: appearanceRepository,
          initialSettings: settings,
        ).state,
        const AppearanceState(
          status: AppearanceStatus.success,
          settings: settings,
        ),
      );
    });

    group('load', () {
      const storedSettings = AppearanceSettings(
        fontSize: 18,
        themeMode: AppThemeMode.dark,
        statusPhotoStyle: StatusPhotoStyle.wechat,
      );

      blocTest<AppearanceCubit, AppearanceState>(
        'emits [loading, success] when repository loading succeeds',
        setUp: () {
          when(appearanceRepository.load).thenAnswer(
            (_) async => storedSettings,
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.loading,
            settings: AppearanceSettings(),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: storedSettings,
          ),
        ],
        verify: (_) {
          verify(appearanceRepository.load).called(1);
        },
      );

      blocTest<AppearanceCubit, AppearanceState>(
        'emits [loading, failure] and keeps current settings on failure',
        setUp: () {
          when(appearanceRepository.load).thenThrow(Exception('failed'));
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.loading,
            settings: AppearanceSettings(),
          ),
          AppearanceState(
            status: AppearanceStatus.failure,
            settings: AppearanceSettings(),
          ),
        ],
      );
    });

    group('updateFontSize', () {
      late List<AppearanceSettings> savedSettings;

      setUp(() {
        savedSettings = <AppearanceSettings>[];
      });

      blocTest<AppearanceCubit, AppearanceState>(
        'emits [saving, success] and persists the new font size',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenAnswer(
            (_) async {},
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.updateFontSize(17),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(fontSize: 17),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(fontSize: 17),
          ),
        ],
        verify: (_) {
          verify(
            () => appearanceRepository.save(
              const AppearanceSettings(fontSize: 17),
            ),
          ).called(1);
        },
      );

      blocTest<AppearanceCubit, AppearanceState>(
        'constrains a font size above the supported range',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenAnswer(
            (_) async {},
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.updateFontSize(100),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(fontSize: 20),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(fontSize: 20),
          ),
        ],
      );

      blocTest<AppearanceCubit, AppearanceState>(
        'constrains a font size below the supported range',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenAnswer(
            (_) async {},
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.updateFontSize(0),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(fontSize: 12),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(fontSize: 12),
          ),
        ],
      );

      blocTest<AppearanceCubit, AppearanceState>(
        'applies rapid changes immediately and persists them in order',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenAnswer((
            invocation,
          ) async {
            savedSettings.add(
              invocation.positionalArguments.single as AppearanceSettings,
            );
            await Future<void>.delayed(Duration.zero);
          });
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) async {
          final firstUpdate = cubit.updateFontSize(15);
          final secondUpdate = cubit.updateFontSize(17);
          await Future.wait([firstUpdate, secondUpdate]);
        },
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(fontSize: 15),
          ),
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(fontSize: 17),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(fontSize: 17),
          ),
        ],
        verify: (_) {
          expect(savedSettings, const [
            AppearanceSettings(fontSize: 15),
            AppearanceSettings(fontSize: 17),
          ]);
        },
      );
    });

    group('updateThemeMode', () {
      blocTest<AppearanceCubit, AppearanceState>(
        'persists the selected theme mode',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenAnswer(
            (_) async {},
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.updateThemeMode(AppThemeMode.dark),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(themeMode: AppThemeMode.dark),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(themeMode: AppThemeMode.dark),
          ),
        ],
      );
    });

    group('updateStatusPhotoStyle', () {
      blocTest<AppearanceCubit, AppearanceState>(
        'persists the selected status photo style',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenAnswer(
            (_) async {},
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.updateStatusPhotoStyle(StatusPhotoStyle.wechat),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(
              statusPhotoStyle: StatusPhotoStyle.wechat,
            ),
          ),
          AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(
              statusPhotoStyle: StatusPhotoStyle.wechat,
            ),
          ),
        ],
      );

      blocTest<AppearanceCubit, AppearanceState>(
        'rolls back and emits failure when persistence fails',
        setUp: () {
          when(() => appearanceRepository.save(any())).thenThrow(
            Exception('failed'),
          );
        },
        build: () => AppearanceCubit(
          appearanceRepository: appearanceRepository,
        ),
        act: (cubit) => cubit.updateStatusPhotoStyle(StatusPhotoStyle.wechat),
        expect: () => const [
          AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(
              statusPhotoStyle: StatusPhotoStyle.wechat,
            ),
          ),
          AppearanceState(
            status: AppearanceStatus.failure,
            settings: AppearanceSettings(),
          ),
        ],
      );
    });
  });
}
