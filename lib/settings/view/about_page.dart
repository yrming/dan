import 'dart:async';

import 'package:dan/app/configuration/configuration.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/settings/view/about_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route boundary for application information and legal documents.
class AboutPage extends StatelessWidget {
  /// Creates the about page.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AboutView(
      buildInfo: context.read<AppBuildInfo?>() ?? const AppBuildInfo(),
      onStoryPressed: () => _openDocument(context, AppRouteName.aboutStory),
      onUserAgreementPressed: () =>
          _openDocument(context, AppRouteName.userAgreement),
      onPrivacyPolicyPressed: () =>
          _openDocument(context, AppRouteName.privacyPolicy),
    );
  }

  void _openDocument(BuildContext context, String routeName) {
    unawaited(
      context.pushNamed<void>(
        routeName,
        pathParameters: {
          'userId': GoRouterState.of(context).pathParameters['userId']!,
        },
      ),
    );
  }
}
