import 'package:dan/app/widgets/app_toast.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Shows request failure feedback as a toast.
void showAppFailureToast(BuildContext context, {String? message}) {
  final serverMessage = message?.trim();
  showAppToast(
    context,
    serverMessage == null || serverMessage.isEmpty
        ? context.l10n.retryPageMessage
        : serverMessage,
  );
}
