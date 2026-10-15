import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Loading placeholders matching the avatar, description and follow button.
class FollowListSkeleton extends StatelessWidget {
  const FollowListSkeleton({
    required this.semanticLabel,
    this.itemCount = 8,
    this.shrinkWrap = false,
    this.actionCount = 1,
    this.actionWidth = 80,
    super.key,
  });

  final String semanticLabel;
  final int itemCount;
  final bool shrinkWrap;

  /// Number of action placeholders shown at the trailing edge.
  final int actionCount;

  /// Width of each action placeholder.
  final double actionWidth;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      semanticLabel: semanticLabel,
      child: ListView.separated(
        primary: false,
        shrinkWrap: shrinkWrap,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const Divider(height: 0.5, thickness: 0.5),
        itemBuilder: (context, index) => ListTile(
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
          horizontalTitleGap: AppSpacing.sm,
          leading: const _Placeholder(width: 40, height: 40, radius: 20),
          title: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: _Placeholder(height: 14),
            ),
          ),
          subtitle: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: _Placeholder(height: 12),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var actionIndex = 0;
                actionIndex < actionCount;
                actionIndex++
              ) ...[
                if (actionIndex > 0) const SizedBox(width: AppSpacing.space10),
                _Placeholder(
                  width: actionWidth,
                  height: 34,
                  radius: AppLayout.buttonRadius,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height, this.width, this.radius = 4});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
