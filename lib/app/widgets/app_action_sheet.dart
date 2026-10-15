import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Opens a grouped modal action sheet using the application visual language.
Future<void> showAppActionSheet(
  BuildContext context, {
  required List<AppActionSheetGroup> groups,
  Key? sheetKey,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.appColors.actionSheetBackground,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: Column(
          key: sheetKey,
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: groups,
        ),
      ),
    ),
  );
}

/// A rounded group of action-sheet items separated by hairline dividers.
class AppActionSheetGroup extends StatelessWidget {
  /// Creates an action-sheet group.
  const AppActionSheetGroup({
    required this.children,
    this.dividerKeys = const [],
    super.key,
  }) : assert(
         dividerKeys.length == 0 || dividerKeys.length == children.length - 1,
         'Provide one divider key for each gap between action-sheet items.',
       );

  /// Actions displayed in this group.
  final List<AppActionSheetItem> children;

  /// Optional keys applied to the dividers in item order.
  final List<Key> dividerKeys;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.bgBase,
      borderRadius: BorderRadius.circular(AppLayout.actionSheetGroupRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              SizedBox(
                key: dividerKeys.isEmpty ? null : dividerKeys[index],
                width: double.infinity,
                height: AppLayout.actionSheetDividerThickness,
                child: ColoredBox(color: context.appColors.divider),
              ),
          ],
        ],
      ),
    );
  }
}

/// One tappable row within an [AppActionSheetGroup].
class AppActionSheetItem extends StatelessWidget {
  /// Creates an action-sheet item.
  const AppActionSheetItem({
    required this.label,
    this.icon,
    this.foregroundColor,
    this.iconColor,
    this.onPressed,
    super.key,
  });

  /// Localized action label.
  final String label;

  /// Icon displayed at the trailing edge.
  final IconData? icon;

  /// Optional foreground color applied to both the label and icon.
  final Color? foregroundColor;

  /// Optional color applied only to the icon.
  final Color? iconColor;

  /// Optional callback invoked after the sheet closes.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = this.foregroundColor ?? context.appColors.textBase;
    return InkWell(
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      onTap: () {
        Navigator.of(context).pop();
        onPressed?.call();
      },
      child: SizedBox(
        height: AppLayout.actionSheetItemHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: context.appTypography.actionSheetItem.copyWith(
                  color: foregroundColor,
                ),
              ),
              if (icon case final icon?)
                Icon(
                  icon,
                  color: iconColor ?? foregroundColor,
                  size: AppLayout.actionSheetIconSize,
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
