import 'package:authentication_repository/src/models/models.dart';
import 'package:fanfou/fanfou.dart' as fanfou;

/// Creates isolated clients using Fanfou's official HTTPS endpoints.
///
/// Consumer credentials are supplied by the application composition root and
/// are never retained in account sessions. Every invocation returns a fresh
/// client so OAuth credentials cannot cross account boundaries.
///
/// This factory does not accept configurable endpoints, preventing credentials
/// from being redirected to an arbitrary host.
final class FanfouAuthenticationClientFactory {
  /// Creates a Fanfou authentication client factory.
  factory FanfouAuthenticationClientFactory({
    required String consumerKey,
    required String consumerSecret,
  }) {
    if (consumerKey.isEmpty || consumerSecret.isEmpty) {
      throw ArgumentError('Fanfou consumer credentials must not be empty.');
    }
    return FanfouAuthenticationClientFactory._(consumerKey, consumerSecret);
  }

  const FanfouAuthenticationClientFactory._(
    this._consumerKey,
    this._consumerSecret,
  );

  static const _apiBaseUrl = 'https://api.fanfou.com';
  static const _oauthBaseUrl = 'https://fanfou.com';

  final String _consumerKey;
  final String _consumerSecret;

  /// Creates an unauthenticated client or one scoped to [session].
  fanfou.FanfouClient call({AuthenticationSession? session}) {
    return fanfou.FanfouClient(
      consumerKey: _consumerKey,
      consumerSecret: _consumerSecret,
      oauthToken: session?.token,
      oauthTokenSecret: session?.tokenSecret,
      // Keep the official hosts explicit so an SDK default change cannot
      // redirect authentication traffic.
      // ignore: avoid_redundant_argument_values
      baseUrl: _apiBaseUrl,
      // Pin the OAuth host for the same reason as the API host above.
      // ignore: avoid_redundant_argument_values
      oauthBaseUrl: _oauthBaseUrl,
    );
  }
}
