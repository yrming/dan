import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// App bar used by sub-pages pushed above the authenticated shell.
///
/// Shares the shell app bar's visual style — a centered title and the active
/// appearance scale's toolbar height — while allowing tab roots to suppress
/// the implicit back button that pushed routes provide.
class AppSubpageAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a sub-page app bar with an optional [title].
  const AppSubpageAppBar({
    required this.title,
    this.toolbarHeight = AppLayout.appBarToolbarHeight,
    this.showBottomDivider = true,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.actions,
    this.actionsPadding,
    this.backgroundColor,
    super.key,
  });

  /// Title text displayed in the center, or `null` for no title.
  final String? title;

  /// Toolbar height derived from the active appearance scale.
  final double toolbarHeight;

  /// Whether the themed hairline divider is shown below the app bar.
  final bool showBottomDivider;

  /// Whether Flutter should add an implicit leading navigation control.
  final bool automaticallyImplyLeading;

  /// Widget displayed at the leading edge of the app bar.
  final Widget? leading;

  /// Widgets displayed after the title, typically navigation actions.
  final List<Widget>? actions;

  /// Padding around the trailing [actions].
  final EdgeInsetsGeometry? actionsPadding;

  /// Optional background override; otherwise uses the application bar theme.
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return DoubleTapListener(
      onDoubleTap: () => ScrollToTopScope.maybeOf(context)?.scrollToTop(),
      child: AppBar(
        backgroundColor: backgroundColor,
        toolbarHeight: toolbarHeight,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
        centerTitle: true,
        shape: showBottomDivider ? null : const Border(),
        title: title == null ? null : Text(title!),
        actions: actions,
        actionsPadding: actionsPadding,
      ),
    );
  }
}
