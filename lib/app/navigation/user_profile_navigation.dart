import 'package:dan/app/navigation/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Pushes [userId] onto the current navigation stack.
Future<void> openUserProfileRoute(
  BuildContext context, {
  required String userId,
}) async {
  await context.pushNamed<void>(
    AppRouteName.userProfile,
    pathParameters: {'userId': userId},
    queryParameters: const {'presentation': 'pushed'},
  );
}
