import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_list_item_tap_target.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/material.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

/// Displays a message in a personal Moments album, with its date on the left.
class MomentsStatusListItem extends StatelessWidget {
  /// Creates a personal album message.
  const MomentsStatusListItem({
    required this.status,
    required this.onStatusTap,
    this.previousCreatedAt,
    this.photoHeroTag,
    this.onPhotoTap,
    this.onHashtagTap,
    this.now,
    super.key,
  });

  final status_repository.Status status;

  /// Timestamp of the preceding message, including across page boundaries.
  final String? previousCreatedAt;
  final String? photoHeroTag;
  final VoidCallback? onStatusTap;
  final VoidCallback? onPhotoTap;
  final ValueChanged<String>? onHashtagTap;

  /// Clock used to label today and yesterday. Defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final date = tryParseFanfouCreatedAt(status.createdAt);
    final previousDate = previousCreatedAt == null
        ? null
        : tryParseFanfouCreatedAt(previousCreatedAt!);
    final currentDate = now ?? DateTime.now();
    final showDate =
        date == null || previousDate == null || !_sameDay(date, previousDate);
    final showYear =
        date != null &&
        (previousDate == null
            ? date.year != currentDate.year
            : date.year != previousDate.year);
    final photo = status.photo;
    return Material(
      color: context.appColors.bgBase,
      child: StatusListItemTapTarget(
        onTap: onStatusTap,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: sizing.scaled(AppSpacing.md),
            end: sizing.scaled(AppSpacing.md),
            top: sizing.scaled(AppSpacing.md),
            bottom: sizing.scaled(AppSpacing.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showYear) ...[
                SizedBox(height: sizing.scaled(AppSpacing.md)),
                Text(
                  '${date.year}年',
                  style: context.appTypography.statusBody.copyWith(
                    fontSize: context.appSizing.scaled(18),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: sizing.scaled(AppSpacing.md)),
                SizedBox(height: sizing.scaled(AppSpacing.md)),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: sizing.scaled(AppLayout.momentsDateColumnWidth),
                    child: showDate
                        ? _MomentsDate(
                            date: date,
                            source: status.createdAt,
                            now: currentDate,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photo != null)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final thumbnail = StatusPhoto.moments(
                                imageUrl: photo.viewerUrl,
                                semanticLabel: statusHtmlToPlainText(
                                  status.text,
                                ),
                                heroTag: photoHeroTag ?? '',
                                onTap: onPhotoTap,
                              );
                              if (status.text.isEmpty) return thumbnail;
                              if (constraints.maxWidth < sizing.scaled(200)) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    thumbnail,
                                    SizedBox(
                                      height: sizing.scaled(AppSpacing.space10),
                                    ),
                                    _body(context, maxLines: 4),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  thumbnail,
                                  SizedBox(
                                    width: sizing.scaled(AppSpacing.space10),
                                  ),
                                  Expanded(child: _body(context, maxLines: 4)),
                                ],
                              );
                            },
                          )
                        else
                          _body(context, maxLines: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, {required int maxLines}) {
    return StatusBodyText(
      text: status.text,
      maxLines: maxLines,
      linkColor: context.appColors.wechatLinkText!,
      onHashtagTap: onHashtagTap,
    );
  }
}

class _MomentsDate extends StatelessWidget {
  const _MomentsDate({
    required this.date,
    required this.source,
    required this.now,
  });

  final DateTime? date;
  final String source;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    if (date == null) {
      return Text(source, style: context.appTypography.statusHandle);
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final relativeLabel = _sameDay(date, now)
        ? '今天'
        : _sameDay(date, yesterday)
        ? '昨天'
        : null;
    if (relativeLabel != null) {
      return Text(
        relativeLabel,
        style: context.appTypography.statusBody.copyWith(
          fontSize: context.appSizing.scaled(18),
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Semantics(
      label: '${date.month}月${date.day}日',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.month.toString().padLeft(2, '0')}月',
            // style: context.appTypography.statusHandle.copyWith(
            //   color: context.appColors.textBase,
            // ),
            style: context.appTypography.statusBody,
          ),
          Text(
            date.day.toString().padLeft(2, '0'),
            style: context.appTypography.statusBody.copyWith(
              fontSize: context.appSizing.scaled(18),
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
