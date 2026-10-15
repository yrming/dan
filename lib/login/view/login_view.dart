import 'dart:async';

import 'package:dan/app/configuration/app_links.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/login/bloc/login_bloc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

/// Opens an external link from the login page.
typedef LoginExternalLinkLauncher = Future<bool> Function(Uri uri);

/// Renders the login experience and dispatches user actions.
class LoginView extends StatelessWidget {
  /// Creates a login view.
  const LoginView({this.onClose, this.externalLinkLauncher, super.key});

  /// Optional callback used by a full-screen add-account presentation.
  final VoidCallback? onClose;

  /// Opens a legal document when its link is tapped.
  final LoginExternalLinkLauncher? externalLinkLauncher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: onClose == null
          ? null
          : AppSubpageAppBar(
              title: context.l10n.addAccountPageTitle,
              toolbarHeight: context.appSizing.appBarToolbarHeight,
              showBottomDivider: false,
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: context.l10n.addAccountCloseLabel,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ),
      body: SafeArea(
        child: BlocBuilder<LoginBloc, LoginState>(
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final sizing = context.appSizing;
                final verticalInset = sizing.scaled(AppSpacing.xxl);
                final minimumHeight = constraints.maxHeight > verticalInset
                    ? constraints.maxHeight - verticalInset
                    : 0.0;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: sizing.scaled(AppSpacing.lg),
                    vertical: sizing.scaled(AppSpacing.lg),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: sizing.scaled(420),
                        minHeight: minimumHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(),
                            _Brand(
                              logoLabel: context.l10n.loginBrandLogoLabel,
                              tagline: context.l10n.loginTagline,
                            ),
                            const Spacer(),
                            _OAuthOptions(
                              state: state,
                              externalLinkLauncher:
                                  externalLinkLauncher ?? AppLinks.openExternal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.logoLabel, required this.tagline});

  final String logoLabel;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizing = context.appSizing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DanLogo(
          color: colorScheme.onSurface,
          semanticLabel: logoLabel,
          size: sizing.scaled(96),
        ),
        SizedBox(height: sizing.scaled(AppSpacing.lg)),
        Semantics(
          header: true,
          child: Text(
            tagline,
            style: context.appTypography.brandTagline,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _OAuthOptions extends StatelessWidget {
  const _OAuthOptions({
    required this.state,
    required this.externalLinkLauncher,
  });

  final LoginState state;
  final LoginExternalLinkLauncher externalLinkLauncher;

  @override
  Widget build(BuildContext context) {
    final isOAuthInProgress =
        state.status == LoginSubmissionStatus.oauthInProgress;
    final error = _submissionError(context, state);
    final sizing = context.appSizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          _SubmissionError(message: error),
          SizedBox(height: sizing.scaled(AppSpacing.md)),
        ],
        FilledButton.icon(
          onPressed: state.isInProgress
              ? null
              : () => context.read<LoginBloc>().add(
                  const LoginOAuthRequested(),
                ),
          icon: isOAuthInProgress
              ? _ProgressIndicator(
                  semanticLabel: context.l10n.loginOAuthSubmittingLabel,
                )
              : const Icon(Remix.shield_keyhole_line),
          label: Text(context.l10n.loginOAuthButtonLabel),
        ),
        SizedBox(height: sizing.scaled(AppSpacing.sm)),
        _LoginConsent(
          externalLinkLauncher: externalLinkLauncher,
        ),
      ],
    );
  }
}

class _LoginConsent extends StatefulWidget {
  const _LoginConsent({required this.externalLinkLauncher});

  final LoginExternalLinkLauncher externalLinkLauncher;

  @override
  State<_LoginConsent> createState() => _LoginConsentState();
}

class _LoginConsentState extends State<_LoginConsent> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final notice = context.l10n.loginConsentNotice;
    final agreementLabel = context.l10n.settingsUserAgreementLabel;
    final privacyLabel = context.l10n.settingsPrivacyPolicyLabel;
    final agreementStart = notice.indexOf(agreementLabel);
    final privacyStart = notice.indexOf(privacyLabel);

    if (agreementStart < 0 || privacyStart < 0) {
      return Text(
        notice,
        style: context.appTypography.loginConsent,
        textAlign: TextAlign.center,
      );
    }

    final agreementEnd = agreementStart + agreementLabel.length;
    final privacyEnd = privacyStart + privacyLabel.length;
    final consentStyle = context.appTypography.loginConsent;
    final linkStyle = consentStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: consentStyle.color,
      decorationStyle: TextDecorationStyle.solid,
    );
    final agreementRecognizer = TapGestureRecognizer()
      ..onTap = () => unawaited(
        widget.externalLinkLauncher(AppLinks.userAgreement),
      );
    final privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => unawaited(
        widget.externalLinkLauncher(AppLinks.privacyPolicy),
      );
    _recognizers
      ..add(agreementRecognizer)
      ..add(privacyRecognizer);

    return Text.rich(
      TextSpan(
        style: consentStyle,
        children: [
          TextSpan(text: notice.substring(0, agreementStart)),
          TextSpan(
            text: agreementLabel,
            style: linkStyle,
            recognizer: agreementRecognizer,
          ),
          TextSpan(text: notice.substring(agreementEnd, privacyStart)),
          TextSpan(
            text: privacyLabel,
            style: linkStyle,
            recognizer: privacyRecognizer,
          ),
          TextSpan(text: notice.substring(privacyEnd)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: sizing.scaled(16),
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.onPrimary,
          strokeWidth: sizing.scaled(2),
        ),
      ),
    );
  }
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: context.appTypography.errorMessage,
        textAlign: TextAlign.center,
      ),
    );
  }
}

String? _submissionError(BuildContext context, LoginState state) {
  final status = state.status;
  return switch (status) {
    LoginSubmissionStatus.apiFailure =>
      state.errorMessage ?? context.l10n.loginApiFailure,
    LoginSubmissionStatus.storageFailure => context.l10n.loginStorageFailure,
    LoginSubmissionStatus.oauthDenied => context.l10n.loginOAuthDenied,
    LoginSubmissionStatus.oauthFailure => context.l10n.loginOAuthFailure,
    LoginSubmissionStatus.failure => context.l10n.loginGenericFailure,
    LoginSubmissionStatus.initial ||
    LoginSubmissionStatus.oauthInProgress ||
    LoginSubmissionStatus.success => null,
  };
}
