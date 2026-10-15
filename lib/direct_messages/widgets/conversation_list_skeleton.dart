import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Displays animated placeholders matching direct-message conversations.
class ConversationListSkeleton extends StatelessWidget {
  /// Creates a conversation-list skeleton.
  const ConversationListSkeleton({
    required this.semanticLabel,
    this.itemCount = 8,
    this.shrinkWrap = false,
    super.key,
  });

  /// Accessibility label announced while conversations are loading.
  final String semanticLabel;

  /// Number of placeholder conversation items to display.
  final int itemCount;

  /// Whether the list should size itself to its contents.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppShimmer(
      semanticLabel: semanticLabel,
      child: ListView.separated(
        primary: false,
        shrinkWrap: shrinkWrap,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => _ConversationListSkeletonItem(
          color: colors.skeletonBase,
        ),
        separatorBuilder: (context, index) => const Divider(height: 1),
      ),
    );
  }
}

abstract final class _ConversationSkeletonLayout {
  static const nameWidth = 112.0;
  static const timeWidth = 52.0;
  static const primaryLineHeight = 14.0;
  static const secondaryLineHeight = 14.0;
  static const messageWidthFactor = 0.76;
}

class _ConversationListSkeletonItem extends StatelessWidget {
  const _ConversationListSkeletonItem({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
      ),
      horizontalTitleGap: AppSpacing.sm,
      leading: _SkeletonShape.circle(color: color, diameter: 40),
      title: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SkeletonShape.rounded(
                color: color,
                width: sizing.scaled(_ConversationSkeletonLayout.nameWidth),
                height: sizing.scaled(
                  _ConversationSkeletonLayout.primaryLineHeight,
                ),
              ),
            ),
          ),
          SizedBox(width: sizing.scaled(AppSpacing.xs)),
          _SkeletonShape.rounded(
            color: color,
            width: sizing.scaled(_ConversationSkeletonLayout.timeWidth),
            height: sizing.scaled(
              _ConversationSkeletonLayout.secondaryLineHeight,
            ),
          ),
        ],
      ),
      subtitle: FractionallySizedBox(
        widthFactor: _ConversationSkeletonLayout.messageWidthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: _SkeletonShape.rounded(
          color: color,
          width: double.infinity,
          height: sizing.scaled(
            _ConversationSkeletonLayout.secondaryLineHeight,
          ),
        ),
      ),
    );
  }
}

class _SkeletonShape extends StatelessWidget {
  const _SkeletonShape._({
    required this.color,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  factory _SkeletonShape.circle({
    required Color color,
    required double diameter,
  }) {
    return _SkeletonShape._(
      color: color,
      width: diameter,
      height: diameter,
      borderRadius: BorderRadius.circular(diameter / 2),
    );
  }

  factory _SkeletonShape.rounded({
    required Color color,
    required double width,
    required double height,
  }) {
    return _SkeletonShape._(
      color: color,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }

  final Color color;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: color,
        child: SizedBox(width: width, height: height),
      ),
    );
  }
}
