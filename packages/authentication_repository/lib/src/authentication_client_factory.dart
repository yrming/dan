import 'package:authentication_repository/src/models/models.dart';
import 'package:fanfou/fanfou.dart' as fanfou;

/// Creates an unauthenticated client, or a client configured with [session].
///
/// The function must use the official Fanfou endpoints and return a fresh
/// client for every call so OAuth credentials cannot leak between accounts.
typedef AuthenticationClientFactory =
    fanfou.FanfouClient Function({
      AuthenticationSession? session,
    });
