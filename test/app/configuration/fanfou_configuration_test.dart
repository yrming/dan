import 'package:dan/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(FanfouConfiguration, () {
    group('fromEnvironment', () {
      test('returns configuration when both values are provided', () {
        final configuration = FanfouConfiguration.fromEnvironment(
          consumerKey: 'consumer-key',
          consumerSecret: 'consumer-secret',
        );

        expect(configuration.consumerKey, 'consumer-key');
        expect(configuration.consumerSecret, 'consumer-secret');
      });

      test('throws when either required value is missing', () {
        expect(
          () => FanfouConfiguration.fromEnvironment(
            consumerKey: ' ',
            consumerSecret: 'consumer-secret',
          ),
          throwsA(isA<FanfouConfigurationException>()),
        );
        expect(
          () => FanfouConfiguration.fromEnvironment(
            consumerKey: 'consumer-key',
            consumerSecret: ' ',
          ),
          throwsA(isA<FanfouConfigurationException>()),
        );
      });
    });

    test('redacts consumer values from its string representation', () {
      final configuration = FanfouConfiguration.fromEnvironment(
        consumerKey: 'consumer-key',
        consumerSecret: 'consumer-secret',
      );

      expect(configuration.toString(), isNot(contains('consumer-key')));
      expect(configuration.toString(), isNot(contains('consumer-secret')));
    });
  });
}
