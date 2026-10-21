import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/models/status_list_layout.dart';
import 'package:dan/status/widgets/monthly_status_photos.dart';
import 'package:flutter/material.dart';

/// Displays animated placeholders matching the status-list item layout.
class StatusListSkeleton extends StatelessWidget {
  /// Creates a status-list skeleton.
  const StatusListSkeleton({
    required this.semanticLabel,
    this.itemCount = 6,
    this.shrinkWrap = false,
    this.layout = StatusListLayout.timeline,
    super.key,
  });

  /// Accessibility label announced while the list is loading.
  final String semanticLabel;

  /// Number of placeholder status items to display.
  final int itemCount;

  /// Whether the list should size itself to its contents.
  final bool shrinkWrap;

  /// Presentation matched by the loading placeholders.
  final StatusListLayout layout;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (layout == StatusListLayout.monthlyPhotos) {
      return AppShimmer(
        semanticLabel: semanticLabel,
        child: ListView.builder(
          primary: false,
          shrinkWrap: shrinkWrap,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (context, index) => MonthlyPhotoRow(
            loading: true,
            startsMonth: index % 3 == 0,
            endsMonth: index % 3 == 2,
            children: List.generate(
              3,
              (_) => ClipRRect(
                borderRadius: BorderRadius.circular(AppLayout.albumPhotoRadius),
                child: ColoredBox(color: colors.skeletonBase),
              ),
            ),
          ),
        ),
      );
    }
    return AppShimmer(
      semanticLabel: semanticLabel,
      child: ListView.separated(
        primary: false,
        shrinkWrap: shrinkWrap,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => layout == StatusListLayout.moments
            ? _MomentsSkeletonItem(
                color: colors.skeletonBase,
                showDate: index.isEven,
                showPhoto: index % 3 == 1,
              )
            : _StatusListSkeletonItem(color: colors.skeletonBase),
        separatorBuilder: (context, index) {
          if (layout == StatusListLayout.timeline) {
            return const Divider(height: 1);
          }
          final sizing = context.appSizing;
          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: sizing.scaled(
                AppSpacing.md + AppLayout.momentsDateColumnWidth,
              ),
            ),
            child: const Divider(height: 1),
          );
        },
      ),
    );
  }
}

class _MomentsSkeletonItem extends StatelessWidget {
  const _MomentsSkeletonItem({
    required this.color,
    required this.showDate,
    required this.showPhoto,
  });

  final Color color;
  final bool showDate;
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: sizing.scaled(AppSpacing.md),
        end: sizing.scaled(AppSpacing.md),
        top: sizing.scaled(AppSpacing.md),
        bottom: sizing.scaled(AppSpacing.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: sizing.scaled(AppLayout.momentsDateColumnWidth),
            child: showDate
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonShape.rounded(
                        color: color,
                        width: sizing.scaled(32),
                        height: sizing.scaled(14),
                      ),
                      SizedBox(height: sizing.scaled(AppSpacing.xs)),
                      _SkeletonShape.rounded(
                        color: color,
                        width: sizing.scaled(28),
                        height: sizing.scaled(22),
                      ),
                    ],
                  )
                : null,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final text = _MomentsSkeletonText(color: color);
                if (!showPhoto) return text;
                final photo = ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppLayout.albumPhotoRadius,
                  ),
                  child: ColoredBox(
                    color: color,
                    child: SizedBox.square(dimension: sizing.scaled(100)),
                  ),
                );
                if (constraints.maxWidth < sizing.scaled(200)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      photo,
                      SizedBox(height: sizing.scaled(AppSpacing.space10)),
                      text,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    photo,
                    SizedBox(width: sizing.scaled(AppSpacing.space10)),
                    Expanded(child: text),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentsSkeletonText extends StatelessWidget {
  const _MomentsSkeletonText({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var line = 0; line < 3; line++) ...[
          if (line > 0) SizedBox(height: sizing.scaled(AppSpacing.xs)),
          FractionallySizedBox(
            widthFactor: line == 2 ? 0.65 : 1,
            alignment: AlignmentDirectional.centerStart,
            child: _SkeletonShape.rounded(
              color: color,
              width: double.infinity,
              height: sizing.scaled(_StatusSkeletonLayout.bodyLineHeight),
            ),
          ),
        ],
      ],
    );
  }
}

abstract final class _StatusSkeletonLayout {
  static const authorWidth = 96.0;
  static const bodyLineHeight = 14.0;
  static const bodyLineGap = 6.0;
  static const metadataWidth = 80.0;
  static const metadataHeight = 12.0;
}

class _StatusListSkeletonItem extends StatelessWidget {
  const _StatusListSkeletonItem({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: sizing.scaled(AppSpacing.md),
        top: sizing.scaled(AppSpacing.sm),
        end: AppSpacing.md,
        bottom: sizing.scaled(AppSpacing.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonShape.circle(
            color: color,
            diameter: sizing.statusAvatarSize,
          ),
          SizedBox(width: sizing.scaled(AppSpacing.space10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonShape.rounded(
                  color: color,
                  width: sizing.scaled(_StatusSkeletonLayout.authorWidth),
                  height: sizing.scaled(
                    _StatusSkeletonLayout.bodyLineHeight,
                  ),
                ),
                SizedBox(height: sizing.scaled(AppSpacing.space6)),
                _SkeletonShape.rounded(
                  color: color,
                  width: double.infinity,
                  height: sizing.scaled(
                    _StatusSkeletonLayout.bodyLineHeight,
                  ),
                ),
                SizedBox(
                  height: sizing.scaled(_StatusSkeletonLayout.bodyLineGap),
                ),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  alignment: AlignmentDirectional.centerStart,
                  child: _SkeletonShape.rounded(
                    color: color,
                    width: double.infinity,
                    height: sizing.scaled(
                      _StatusSkeletonLayout.bodyLineHeight,
                    ),
                  ),
                ),
                SizedBox(
                  height: sizing.scaled(AppSpacing.space6),
                ),
                _SkeletonShape.rounded(
                  color: color,
                  width: sizing.scaled(_StatusSkeletonLayout.metadataWidth),
                  height: sizing.scaled(_StatusSkeletonLayout.metadataHeight),
                ),
              ],
            ),
          ),
        ],
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
