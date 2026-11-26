import 'package:dan/app/theme/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Non-interactive grouped profile information.
class ProfileSection extends StatelessWidget {
  /// Creates a grouped profile section.
  const new({required this.children, super.key});

  /// Rows displayed by the section.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: context.appSizing.scaled(AppSpacing.md),
                ),
                child: const Divider(height: 0),
              ),
          ],
        ],
      ),
    );
  }
}
