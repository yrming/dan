import 'package:dan/app/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockPackageInfoLoader extends Mock {
  Future<PackageInfo> call();
}

void main() {
  group(AppBuildInfo, () {
    late _MockPackageInfoLoader loader;

    setUp(() {
      loader = _MockPackageInfoLoader();
    });

    group('load', () {
      test('reads the installed package through the default loader', () async {
        PackageInfo.setMockInitialValues(
          appName: '旦',
          packageName: 'dev.yrm.dan',
          version: '3.2.1',
          buildNumber: '789',
          buildSignature: '',
        );

        final info = await AppBuildInfo.load();

        expect(info.version, '3.2.1');
        expect(info.buildNumber, '789');
      });

      test('keeps the version and build returned by the loader', () async {
        when(loader.call).thenAnswer(
          (_) async => PackageInfo(
            appName: '旦',
            packageName: 'dev.yrm.dan',
            version: '2.3.4',
            buildNumber: '56',
          ),
        );

        final info = await AppBuildInfo.load(loader: loader.call);

        expect(info.version, '2.3.4');
        expect(info.buildNumber, '56');
        verify(loader.call).called(1);
      });

      test('preserves unavailable metadata as empty values', () async {
        when(loader.call).thenAnswer(
          (_) async => PackageInfo(
            appName: '',
            packageName: '',
            version: '',
            buildNumber: '',
          ),
        );

        final info = await AppBuildInfo.load(loader: loader.call);

        expect(info.version, isEmpty);
        expect(info.buildNumber, isEmpty);
        verify(loader.call).called(1);
      });

      test('allows startup to continue when the platform read fails', () async {
        when(loader.call).thenThrow(PlatformException(code: 'unavailable'));

        final info = await AppBuildInfo.load(loader: loader.call);

        expect(info.version, isEmpty);
        expect(info.buildNumber, isEmpty);
        verify(loader.call).called(1);
      });
    });
  });
}
