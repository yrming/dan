import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/authentication/bloc/authentication_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Error boundary shown when stored authentication cannot be restored.
class AuthenticationFailurePage extends StatelessWidget {
  /// Creates an authentication failure page.
  const AuthenticationFailurePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppRetryView(
        onRetry: () => context.read<AuthenticationBloc>().add(
          const AuthenticationSubscriptionRequested(),
        ),
      ),
    );
  }
}
