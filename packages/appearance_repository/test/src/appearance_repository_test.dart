import 'package:appearance_repository/appearance_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockAppearanceSettingsStorage extends Mock
    implements AppearanceSettingsStorage {}

void main() {
  group(AppearanceRepository, () {
    late AppearanceSettingsStorage storage;
    late AppearanceRepository subject;

    setUpAll(() {
      registerFallbackValue(const AppearanceSettings());
    });

    setUp(() {
      storage = _MockAppearanceSettingsStorage();
      subject = AppearanceRepository(storage: storage);
    });

    group('load', () {
      test('defaults to large photos when storage is empty', () async {
        when(storage.read).thenAnswer((_) async => null);

        final settings = await subject.load();

        expect(settings.statusPhotoStyle, StatusPhotoStyle.x);
        verify(storage.read).called(1);
      });

      test('preserves stored small-photo $AppearanceSettings', () async {
        const settings = AppearanceSettings(
          fontSize: 18,
          themeMode: AppThemeMode.dark,
          statusPhotoStyle: StatusPhotoStyle.wechat,
        );
        when(storage.read).thenAnswer((_) async => settings);

        expect(await subject.load(), settings);
      });
    });

    group('save', () {
      test('writes the complete $AppearanceSettings', () async {
        const settings = AppearanceSettings(
          themeMode: AppThemeMode.light,
        );
        when(() => storage.write(settings)).thenAnswer((_) async {});

        await subject.save(settings);

        verify(() => storage.write(settings)).called(1);
      });
    });

    group('reset', () {
      test('writes and returns the default settings', () async {
        when(() => storage.write(any())).thenAnswer((_) async {});

        final result = await subject.reset();

        expect(result, const AppearanceSettings());
        verify(() => storage.write(const AppearanceSettings())).called(1);
      });
    });
  });
}
