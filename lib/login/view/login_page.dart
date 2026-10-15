import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/login/bloc/login_bloc.dart';
import 'package:dan/login/view/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Route boundary that provides the login business logic.
class LoginPage extends StatelessWidget {
  /// Creates a login page.
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(
        authenticationRepository: context.read<AuthenticationRepository>(),
        oauthAuthorizationService: context.read<OAuthAuthorizationService>(),
      ),
      child: const LoginView(),
    );
  }
}
