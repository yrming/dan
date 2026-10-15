import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/login/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Full-screen page for adding another authenticated account.
class AddAccountPage extends StatelessWidget {
  /// Creates an add-account page.
  const AddAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(
        authenticationRepository: context.read<AuthenticationRepository>(),
        oauthAuthorizationService: context.read<OAuthAuthorizationService>(),
      ),
      child: BlocListener<LoginBloc, LoginState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == LoginSubmissionStatus.success,
        listener: (context, state) => context.go(AppRoutePath.home),
        child: LoginView(onClose: () => Navigator.of(context).maybePop()),
      ),
    );
  }
}
