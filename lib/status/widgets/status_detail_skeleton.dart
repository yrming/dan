import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/status_list_skeleton.dart';
import 'package:flutter/material.dart';

/// Loading placeholders for an original status and its reply context.
class StatusDetailSkeleton extends StatelessWidget {
  /// Creates a status-detail skeleton.
  const StatusDetailSkeleton({
    required this.semanticLabel,
    required this.contextSemanticLabel,
    super.key,
  });

  /// Accessibility label for the original status being loaded.
  final String semanticLabel;

  /// Accessibility label for the reply context being loaded.
  final String contextSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        StatusListSkeleton(
          semanticLabel: semanticLabel,
          itemCount: 1,
          shrinkWrap: true,
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start:
                sizing.scaled(AppSpacing.md) +
                sizing.statusAvatarSize +
                sizing.scaled(AppSpacing.space10),
            end: sizing.scaled(AppSpacing.md),
            bottom: sizing.scaled(AppSpacing.md),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              vertical: sizing.scaled(AppSpacing.xs),
            ),
            child: AppShimmer(
              semanticLabel: contextSemanticLabel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: sizing.scaled(AppSpacing.xxs),
                children: const [
                  _ReplySkeletonLine(widthFactor: 0.85),
                  _ReplySkeletonLine(widthFactor: 1),
                  _ReplySkeletonLine(widthFactor: 0.65),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplySkeletonLine extends StatelessWidget {
  const _ReplySkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final height = context.appSizing.scaled(14);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.appColors.skeletonBase,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
