/// Build-time Fanfou consumer configuration.
///
/// Values are compiled into the application and can be extracted from the
/// binary. This keeps real values out of source control but does not make them
/// secret on an end-user device.
final class FanfouConfiguration {
  /// Reads consumer configuration from Dart build-time environment values.
  factory FanfouConfiguration.fromEnvironment({
    String consumerKey = const String.fromEnvironment(
      'FANFOU_CONSUMER_KEY',
    ),
    String consumerSecret = const String.fromEnvironment(
      'FANFOU_CONSUMER_SECRET',
    ),
  }) {
    if (consumerKey.trim().isEmpty || consumerSecret.trim().isEmpty) {
      throw const FanfouConfigurationException();
    }
    return FanfouConfiguration._(
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
    );
  }

  const FanfouConfiguration._({
    required this.consumerKey,
    required this.consumerSecret,
  });

  /// OAuth consumer key embedded at build time.
  final String consumerKey;

  /// OAuth consumer secret embedded at build time.
  final String consumerSecret;

  @override
  String toString() => 'FanfouConfiguration(<redacted>)';
}

/// Thrown when required Fanfou build-time values are missing.
final class FanfouConfigurationException implements Exception {
  /// Creates a sanitized configuration exception.
  const FanfouConfigurationException();

  @override
  String toString() =>
      'FanfouConfigurationException: FANFOU_CONSUMER_KEY and '
      'FANFOU_CONSUMER_SECRET are required.';
}
