import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Shows request failure feedback without an action button.
void showAppFailureSnackBar(BuildContext context, {String? message}) {
  final serverMessage = message?.trim();
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          serverMessage == null || serverMessage.isEmpty
              ? context.l10n.retryPageMessage
              : serverMessage,
        ),
      ),
    );
}
