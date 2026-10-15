import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// One tappable action of an [AppAlertDialog].
final class AppDialogAction {
  /// Creates a dialog action.
  const AppDialogAction({
    required this.label,
    required this.color,
    required this.onPressed,
    this.onSubmit,
    this.failureLabel,
  });

  /// Label rendered centered inside the action button.
  final String label;

  /// Label color, for example a destructive color for a confirm action.
  final Color color;

  /// Invoked after the dialog has been dismissed.
  final VoidCallback onPressed;

  /// Optional operation completed before dismissal and [onPressed].
  final Future<void> Function()? onSubmit;

  /// Message displayed when [onSubmit] fails.
  final String? failureLabel;
}

/// Opens a centered alert dialog with a content block and two actions.
///
/// The dialog is modal: tapping the barrier does not dismiss it, and both
/// actions pop the dialog before their callback runs. Asynchronous submissions
/// keep the dialog open and disable its actions until the request completes.
Future<void> showAppAlertDialog(
  BuildContext context, {
  required String title,
  required String content,
  required AppDialogAction cancelAction,
  required AppDialogAction confirmAction,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppAlertDialog(
      title: title,
      content: content,
      cancelAction: cancelAction,
      confirmAction: confirmAction,
    ),
  );
}

/// Centered alert dialog matching the shared application dialog style.
class AppAlertDialog extends StatefulWidget {
  /// Creates an alert dialog.
  const AppAlertDialog({
    required this.title,
    required this.content,
    required this.cancelAction,
    required this.confirmAction,
    super.key,
  });

  /// Primary question rendered above the content.
  final String title;

  /// Explanatory body text rendered below the title.
  final String content;

  /// Left action, expected to decline the question.
  final AppDialogAction cancelAction;

  /// Right action, expected to accept the question.
  final AppDialogAction confirmAction;

  @override
  State<AppAlertDialog> createState() => _AppAlertDialogState();
}

class _AppAlertDialogState extends State<AppAlertDialog> {
  AppDialogAction? _submittingAction;
  String? _failureLabel;

  Future<void> _activate(AppDialogAction action) async {
    if (_submittingAction != null) return;
    if (action.onSubmit case final submit?) {
      setState(() {
        _submittingAction = action;
        _failureLabel = null;
      });
      try {
        await submit();
      } on Object catch (_) {
        if (!mounted) return;
        setState(() {
          _submittingAction = null;
          _failureLabel = action.failureLabel;
        });
        return;
      }
      if (!mounted) return;
    }
    Navigator.of(context).pop();
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final typography = context.appTypography;
    final actionHeight = sizing.scaled(
      AppLayout.alertDialogActionHeight,
      minimum: AppLayout.alertDialogActionHeight,
    );
    return PopScope(
      canPop: _submittingAction == null,
      child: Align(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            sizing.scaled(
              AppLayout.alertDialogRadius,
              minimum: AppLayout.alertDialogRadius,
            ),
          ),
          child: Material(
            color: context.appColors.dialogBackground,
            child: SizedBox(
              width: sizing.scaled(
                AppLayout.alertDialogWidth,
                minimum: AppLayout.alertDialogWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.all(
                      sizing.scaled(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.title,
                          style: typography.dialogTitle,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sizing.scaled(AppSpacing.sm)),
                        Text(
                          _failureLabel ?? widget.content,
                          style: typography.dialogContent,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  SizedBox(
                    height: actionHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AppDialogActionButton(
                          action: widget.cancelAction,
                          isLoading: _submittingAction == widget.cancelAction,
                          onTap: _submittingAction == null
                              ? () => unawaited(_activate(widget.cancelAction))
                              : null,
                        ),
                        SizedBox(
                          width: 0.5,
                          child: ColoredBox(color: context.appColors.divider),
                        ),
                        _AppDialogActionButton(
                          action: widget.confirmAction,
                          isLoading: _submittingAction == widget.confirmAction,
                          onTap: _submittingAction == null
                              ? () => unawaited(_activate(widget.confirmAction))
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppDialogActionButton extends StatelessWidget {
  const _AppDialogActionButton({
    required this.action,
    required this.isLoading,
    required this.onTap,
  });

  final AppDialogAction action;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.transparent,
        child: Center(
          child: isLoading
              ? SizedBox.square(
                  dimension: context.appSizing.scaled(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: action.color,
                    semanticsLabel: action.label,
                  ),
                )
              : Text(
                  action.label,
                  style: context.appTypography.dialogAction.copyWith(
                    color: action.color,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}
