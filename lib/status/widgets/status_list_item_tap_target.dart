import 'package:material_ui/material_ui.dart';

/// Makes status list item content an accessible tap target.
class StatusListItemTapTarget extends StatelessWidget {
  /// Creates a status list item tap target.
  const new({required this.onTap, required this.child, super.key});

  /// Called when the content is tapped, or null when it is not interactive.
  final VoidCallback? onTap;

  /// Content displayed inside the tap target.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: child,
      ),
    );
  }
}
