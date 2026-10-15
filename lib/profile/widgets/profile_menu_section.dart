import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Group of profile menu rows matching the profile page visual language.
class ProfileMenuSection extends StatelessWidget {
  /// Creates a profile menu section.
  const ProfileMenuSection({required this.children, super.key});

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
            if (index != children.length - 1) const Divider(height: 0),
          ],
        ],
      ),
    );
  }
}

/// One action or count-bearing row in a [ProfileMenuSection].
class ProfileTile extends StatelessWidget {
  /// Creates a profile menu row.
  const ProfileTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.value,
    this.showChevron,
    this.onTap,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Leading icon color.
  final Color iconColor;

  /// Row label.
  final String title;

  /// Optional number shown at the trailing edge.
  final int? value;

  /// Whether to display the trailing navigation indicator.
  ///
  /// Defaults to whether the row has an [onTap] action.
  final bool? showChevron;

  /// Optional action for the row.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: sizing.scaled(60, minimum: 60)),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: sizing.scaled(AppSpacing.md),
          end: sizing.scaled(AppSpacing.sm),
          top: sizing.scaled(AppSpacing.sm),
          bottom: sizing.scaled(AppSpacing.sm),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: sizing.scaled(26),
            ),
            SizedBox(width: sizing.scaled(AppSpacing.md)),
            Expanded(
              child: Text(title, style: context.appTypography.menuTitle),
            ),
            if (value != null) ...[
              Text('$value', style: context.appTypography.menuSubtitle),
              SizedBox(width: sizing.scaled(AppSpacing.xxs)),
            ],
            if (showChevron ?? onTap != null)
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );

    return onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            hoverColor: AppColors.transparent,
            child: row,
          );
  }
}
