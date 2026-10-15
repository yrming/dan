import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_list_item_tap_target.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// Lazily builds a personal photo album grouped by calendar month.
class MonthlyStatusPhotos extends StatelessWidget {
  const MonthlyStatusPhotos({required this.statuses, super.key});

  final List<status_repository.Status> statuses;

  @override
  Widget build(BuildContext context) {
    // Group all loaded photos so page boundaries never split a month.
    final groups = <(int?, int?), List<status_repository.Status>>{};
    for (final status in statuses) {
      if (status.photo == null) continue;
      final date = tryParseFanfouCreatedAt(status.createdAt);
      groups.putIfAbsent((date?.year, date?.month), () => []).add(status);
    }
    final rows = <Widget>[];
    int? previousYear;
    for (final entry in groups.entries) {
      final (year, month) = entry.key;
      final photos = entry.value;
      for (var offset = 0; offset < photos.length; offset += 3) {
        rows.add(
          MonthlyPhotoRow(
            key: ValueKey(photos[offset].id),
            monthLabel: offset == 0
                ? month == null
                      ? '—'
                      : '${month.toString().padLeft(2, '0')}月'
                : null,
            yearLabel:
                offset == 0 &&
                    year != null &&
                    year != (previousYear ?? DateTime.now().year)
                ? '$year年'
                : null,
            startsMonth: offset == 0,
            endsMonth: offset + 3 >= photos.length,
            children: [
              for (final status in photos.skip(offset).take(3))
                _Photo(status: status),
            ],
          ),
        );
      }
      previousYear = year;
    }
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

/// Shared geometry for album rows and their loading placeholders.
class MonthlyPhotoRow extends StatelessWidget {
  const MonthlyPhotoRow({
    required this.children,
    this.monthLabel,
    this.yearLabel,
    this.startsMonth = false,
    this.endsMonth = false,
    this.loading = false,
    super.key,
  });

  final List<Widget> children;
  final String? monthLabel;
  final String? yearLabel;
  final bool startsMonth;
  final bool endsMonth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final gap = sizing.scaled(AppSpacing.xxs);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: sizing.scaled(AppSpacing.md),
        end: sizing.scaled(AppSpacing.md),
        top: startsMonth ? sizing.scaled(AppSpacing.md) : gap,
        bottom: endsMonth ? sizing.scaled(AppSpacing.md) : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (yearLabel != null) ...[
            Text(
              yearLabel!,
              style: context.appTypography.statusBody.copyWith(
                fontSize: context.appSizing.scaled(18),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: sizing.scaled(AppSpacing.lg)),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: sizing.scaled(AppLayout.momentsDateColumnWidth),
                child: loading && startsMonth
                    ? Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(sizing.scaled(8)),
                          child: ColoredBox(
                            color: context.appColors.skeletonBase,
                            child: SizedBox(
                              width: sizing.scaled(32),
                              height: sizing.scaled(16),
                            ),
                          ),
                        ),
                      )
                    : monthLabel == null
                    ? null
                    : Text(
                        monthLabel!,
                        style: context.appTypography.statusBody,
                      ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < 3; index++) ...[
                      if (index > 0) SizedBox(width: gap),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: index < children.length
                              ? children[index]
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.status});

  final status_repository.Status status;

  @override
  Widget build(BuildContext context) {
    final label = statusHtmlToPlainText(status.text);
    final heroTag = statusPhotoHeroTag(
      scope: 'monthly-photos',
      statusId: status.id,
      imageUrl: status.photo!.viewerUrl,
    );
    return Material(
      color: context.appColors.groupedBackground,
      borderRadius: BorderRadius.circular(AppLayout.albumPhotoRadius),
      clipBehavior: Clip.antiAlias,
      child: StatusListItemTapTarget(
        onTap: () => unawaited(
          context.pushNamed<void>(
            AppRouteName.statusImageViewer,
            queryParameters: {
              'url': status.photo!.viewerUrl,
              'semanticLabel': label,
              'heroTag': heroTag,
              'userId': status.author.id.isEmpty ? 'unknown' : status.author.id,
              'statusId': status.id,
            },
            extra: status,
          ),
        ),
        child: Semantics(
          image: true,
          label: label.isEmpty
              ? formatFanfouCalendarDate(status.createdAt)
              : label,
          child: Hero(
            tag: heroTag,
            transitionOnUserGestures: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppLayout.albumPhotoRadius),
              child: CachedNetworkImage(
                imageUrl: status.photo!.displayUrl,
                fit: BoxFit.cover,
                memCacheHeight: (200 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                placeholder: (context, url) => AppShimmer(
                  semanticLabel: '',
                  child: ColoredBox(color: context.appColors.skeletonBase),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
