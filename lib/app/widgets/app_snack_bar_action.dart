import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// A primary-colored snackbar action using the application's 16px text size.
class AppSnackBarAction extends SnackBarAction {
  /// Creates an action with the standard callback and dismissal behavior.
  const AppSnackBarAction({
    required super.label,
    required super.onPressed,
    super.key,
  });

  @override
  State<SnackBarAction> createState() => _AppSnackBarActionState();
}

class _AppSnackBarActionState extends State<AppSnackBarAction> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonTheme = TextButtonTheme.of(context);
    return TextButtonTheme(
      data: TextButtonThemeData(
        style: (buttonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            theme.textTheme.labelLarge?.copyWith(
              fontSize: context.appSizing.scaled(16),
            ),
          ),
        ),
      ),
      child: SnackBarAction(
        label: widget.label,
        textColor: theme.colorScheme.primary,
        onPressed: widget.onPressed,
      ),
    );
  }
}
