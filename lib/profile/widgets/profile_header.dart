import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external profile URL.
typedef ProfileExternalLinkLauncher = Future<bool> Function(Uri uri);

/// WeChat-inspired account header shared by current and other users.
class ProfileHeader extends StatelessWidget {
  /// Creates a profile header.
  const ProfileHeader({
    required this.id,
    required this.name,
    required this.screenName,
    this.gender,
    this.description,
    this.location,
    this.registeredAt,
    this.url,
    this.friendsCount,
    this.followersCount,
    this.friendRequestCount,
    this.avatarUrl,
    this.avatarKey,
    this.followActionLabel,
    this.followActionIcon,
    this.followActionLoading = false,
    this.showFollowActionSkeleton = false,
    this.onFollowActionPressed,
    this.onMessagePressed,
    this.externalLinkLauncher = _launchExternalLink,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onFollowRequestsTap,
    super.key,
  });

  /// Stable Fanfou user identifier.
  final String id;

  /// Display name.
  final String name;

  /// Fanfou screen name.
  final String screenName;

  /// User-provided gender used for the identity icon.
  final String? gender;

  /// User biography displayed below the identity row.
  final String? description;

  /// User-provided location displayed below the profile URL.
  final String? location;

  /// Raw Fanfou registration timestamp displayed next to [location].
  final String? registeredAt;

  /// User-provided website displayed below the biography.
  final String? url;

  /// Number of followed accounts.
  final int? friendsCount;

  /// Number of followers.
  final int? followersCount;

  /// Pending follow requests for the active account, when available.
  final int? friendRequestCount;

  /// Preferred avatar URL.
  final String? avatarUrl;

  /// Optional key for the avatar widget.
  final Key? avatarKey;

  /// Follow relationship action shown beside the counts, when available.
  final String? followActionLabel;

  /// Icon preceding the follow action label.
  final IconData? followActionIcon;

  /// Whether the follow relationship is currently being updated.
  final bool followActionLoading;

  /// Whether the initial relationship lookup needs a loading placeholder.
  final bool showFollowActionSkeleton;

  /// Updates the relationship with the displayed user.
  final VoidCallback? onFollowActionPressed;

  /// Opens a direct message conversation with the displayed user.
  final VoidCallback? onMessagePressed;

  /// Opens validated HTTP and HTTPS profile URLs.
  final ProfileExternalLinkLauncher externalLinkLauncher;

  /// Opens the list of accounts followed by this user.
  final VoidCallback? onFollowingTap;

  /// Opens the list of accounts following this user.
  final VoidCallback? onFollowersTap;

  /// Opens incoming follow requests for the active account.
  final VoidCallback? onFollowRequestsTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final displayName = name.isEmpty ? screenName : name;
    final displayDescription = description?.trim();
    final hasDescription = displayDescription?.isNotEmpty ?? false;
    final displayUrl = url?.trim();
    final displayUrlUri = displayUrl == null
        ? null
        : _parseExternalUrl(displayUrl);
    final displayLocation = location?.trim();
    final hasLocation = displayLocation?.isNotEmpty ?? false;
    final displayRegisteredAt = registeredAt?.trim();
    final hasRegisteredAt = displayRegisteredAt?.isNotEmpty ?? false;
    final hasTags = hasLocation || hasRegisteredAt;
    final normalizedGender = gender?.trim();
    final genderIcon = switch (normalizedGender) {
      '男' => Icons.man,
      '女' => Icons.woman,
      _ => null,
    };
    final genderColor = switch (normalizedGender) {
      '男' => const Color(0xFF14AEFF),
      '女' => const Color(0xFFC84040),
      _ => null,
    };
    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: sizing.scaled(AppSpacing.md),
        top: sizing.scaled(AppSpacing.sm),
        end: sizing.scaled(AppSpacing.md),
        bottom: sizing.scaled(AppSpacing.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: context.appTypography.accountName,
                        ),
                        if (genderIcon != null) ...[
                          SizedBox(width: sizing.scaled(AppSpacing.xxs)),
                          Icon(
                            key: const Key('user-profile-gender-icon'),
                            genderIcon,
                            size: sizing.scaled(22),
                            color: genderColor,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: sizing.scaled(AppSpacing.xs)),
                    Text(
                      context.l10n.userProfileAccountHandle(id),
                      style: context.appTypography.accountHandle,
                    ),
                  ],
                ),
              ),
              UserAvatar(
                key: avatarKey,
                imageUrl: avatarUrl,
                semanticLabel: displayName,
                size: sizing.scaled(64),
                borderColor: context.appColors.divider,
                borderWidth: 0.5,
              ),
            ],
          ),
          if (hasDescription) ...[
            SizedBox(height: sizing.scaled(AppSpacing.md)),
            Text(
              displayDescription!,
              key: const Key('user-profile-description'),
              style: context.appTypography.accountDescription,
            ),
          ],
          if (displayUrlUri != null) ...[
            SizedBox(
              height: sizing.scaled(
                hasDescription ? AppSpacing.sm : AppSpacing.md,
              ),
            ),
            _ProfileUrl(
              url: displayUrl!,
              uri: displayUrlUri,
              externalLinkLauncher: externalLinkLauncher,
              style: context.appTypography.accountDescription.copyWith(
                color: context.appColors.wechatLinkText,
              ),
            ),
          ],
          if (hasTags) ...[
            SizedBox(
              height: sizing.scaled(
                displayUrlUri != null || hasDescription
                    ? AppSpacing.sm
                    : AppSpacing.md,
              ),
            ),
            Wrap(
              spacing: sizing.scaled(AppSpacing.sm),
              children: [
                if (hasRegisteredAt)
                  _ProfileRegistrationTag(
                    registeredAt: displayRegisteredAt!,
                  ),
                if (hasLocation)
                  _ProfileTag(
                    tagKey: const Key('user-profile-location'),
                    label: displayLocation!,
                  ),
              ],
            ),
          ],
          SizedBox(
            height: sizing.scaled(
              hasTags || displayUrlUri != null || hasDescription
                  ? AppSpacing.sm
                  : AppSpacing.md,
            ),
          ),
          ConstrainedBox(
            key: const Key('user-profile-follow-row'),
            constraints: BoxConstraints(minHeight: sizing.scaled(32)),
            child: Semantics(
              container: true,
              label: context.l10n.userProfileFollowSummary(
                friendsCount ?? 0,
                followersCount ?? 0,
              ),
              child: Wrap(
                key: const Key('user-profile-follow-summary'),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FollowCount(
                    label: context.l10n.userProfileFollowingLabel,
                    value: friendsCount ?? 0,
                    onTap: onFollowingTap,
                  ),
                  Text(
                    ' · ',
                    style: context.appTypography.accountDescription.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  _FollowCount(
                    label: context.l10n.userProfileFollowersLabel,
                    value: followersCount ?? 0,
                    onTap: onFollowersTap,
                  ),
                  if (friendRequestCount case final count? when count > 0) ...[
                    Text(
                      ' · ',
                      style: context.appTypography.accountDescription.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    InkWell(
                      onTap: onFollowRequestsTap,
                      child: Text(
                        context.l10n.userProfileFollowRequestsCount(
                          count,
                        ),
                        style: context.appTypography.accountDescription
                            .copyWith(color: context.appColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showFollowActionSkeleton ||
              followActionLabel != null ||
              onMessagePressed != null) ...[
            SizedBox(height: sizing.scaled(AppSpacing.sm)),
            Row(
              key: const Key('user-profile-action-row'),
              children: [
                if (showFollowActionSkeleton)
                  Expanded(
                    child: AppShimmer(
                      key: const Key('user-profile-follow-skeleton'),
                      semanticLabel: context.l10n.followActionLoading,
                      child: Container(
                        height: sizing.scaled(_followActionHeight),
                        decoration: ShapeDecoration(
                          color: context.appColors.skeletonBase,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppLayout.buttonRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (followActionLabel != null)
                  Expanded(
                    child: _ProfileFollowAction(
                      label: followActionLabel!,
                      icon: followActionIcon,
                      loading: followActionLoading,
                      onPressed: onFollowActionPressed,
                    ),
                  ),
                if (onMessagePressed != null) ...[
                  SizedBox(width: sizing.scaled(AppSpacing.space10)),
                  Expanded(
                    child: _ProfileMessageAction(onPressed: onMessagePressed!),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          top: -MediaQuery.sizeOf(context).height,
          start: 0,
          end: 0,
          bottom: 0,
          child: ColoredBox(
            key: const Key('user-profile-overscroll-surface'),
            color: surfaceColor,
          ),
        ),
        Material(
          color: surfaceColor,
          child: content,
        ),
      ],
    );
  }
}

const _followActionHeight = 34.0;

class _ProfileFollowAction extends StatelessWidget {
  const _ProfileFollowAction({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return FilledButton(
      key: const Key('user-profile-follow-action'),
      style: FilledButton.styleFrom(
        foregroundColor: AppColors.wechatGreenForeground,
        disabledForegroundColor: AppColors.wechatGreenForeground,
        textStyle: context.appTypography.accountDescription.copyWith(
          color: AppColors.wechatGreenForeground,
        ),
        minimumSize: Size(0, sizing.scaled(_followActionHeight)),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: sizing.scaled(AppSpacing.sm),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: sizing.scaled(16),
              height: sizing.scaled(16),
              child: CircularProgressIndicator(
                color: AppColors.wechatGreenForeground,
                semanticsLabel: context.l10n.followActionLoading,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: sizing.scaled(16)),
                  SizedBox(width: sizing.scaled(AppSpacing.xs)),
                ],
                Text(label),
              ],
            ),
    );
  }
}

class _ProfileMessageAction extends StatelessWidget {
  const _ProfileMessageAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return FilledButton(
      key: const Key('user-profile-message-action'),
      style: FilledButton.styleFrom(
        backgroundColor: context.appColors.bgBase,
        disabledBackgroundColor: context.appColors.bgBase,
        foregroundColor: context.appColors.textBase,
        disabledForegroundColor: context.appColors.textBase,
        textStyle: context.appTypography.accountDescription,
        minimumSize: Size(0, sizing.scaled(_followActionHeight)),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: sizing.scaled(AppSpacing.sm),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(
          color: context.appColors.divider,
          width: 0.5,
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(RemixIcons.send_ins_line, size: sizing.scaled(16)),
          SizedBox(width: sizing.scaled(AppSpacing.xs)),
          Text(context.l10n.userProfileSendMessageLabel),
        ],
      ),
    );
  }
}

class _FollowCount extends StatelessWidget {
  const _FollowCount({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '$value $label',
      style: context.appTypography.accountDescription.copyWith(
        color: context.appColors.textSecondary,
      ),
    );
    return InkWell(
      key: ValueKey('user-profile-$label'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: text,
      ),
    );
  }
}

class _ProfileUrl extends StatelessWidget {
  const _ProfileUrl({
    required this.url,
    required this.uri,
    required this.externalLinkLauncher,
    required this.style,
  });

  final String url;
  final Uri uri;
  final ProfileExternalLinkLauncher externalLinkLauncher;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      url,
      key: const Key('user-profile-url'),
      style: style,
    );
    final minimumTargetSize = context.appSizing.scaled(
      AppSpacing.lg,
      minimum: AppSpacing.lg,
    );
    return Semantics(
      link: true,
      child: InkWell(
        key: const Key('user-profile-url-link'),
        onTap: () => unawaited(externalLinkLauncher(uri)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minimumTargetSize,
            minHeight: minimumTargetSize,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: text,
          ),
        ),
      ),
    );
  }
}

class _ProfileRegistrationTag extends StatelessWidget {
  const _ProfileRegistrationTag({required this.registeredAt});

  final String registeredAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tag = _ProfileTag(
      tagKey: const Key('user-profile-registered-at'),
      label: l10n.userProfileRegisteredAt(
        formatFanfouCalendarDate(registeredAt),
      ),
    );
    final date = tryParseFanfouCreatedAt(registeredAt);
    if (date == null) return tag;

    final elapsed = DateTime.now().difference(date);
    final days = elapsed.isNegative ? 0 : elapsed.inDays;
    final tooltipTextStyle = TooltipTheme.of(context).textStyle;
    final tooltipTextColor =
        tooltipTextStyle?.foreground?.color ??
        tooltipTextStyle?.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white);
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: context.appSizing.scaled(AppSpacing.sm),
        vertical: context.appSizing.scaled(6),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.grey[700]!.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(context.appSizing.scaled(45)),
      ),
      positionDelegate: (position) => positionDependentBox(
        size: position.overlaySize,
        childSize: position.tooltipSize,
        target: Offset(
          position.target.dx +
              (position.tooltipSize.width - position.targetSize.width) / 2,
          position.target.dy,
        ),
        verticalOffset: position.targetSize.height / 2 + 8,
        preferBelow: position.preferBelow,
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(text: l10n.userProfileRegistrationElapsedPrefix),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(l10n.userProfileRegistrationElapsedJoke),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  child: IgnorePointer(
                    child: ColoredBox(
                      key: const Key('profile-registration-strikethrough'),
                      color: tooltipTextColor,
                      child: const SizedBox(height: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextSpan(text: ' ${l10n.userProfileRegistrationElapsedDays(days)}'),
        ],
      ),
      child: tag,
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.tagKey, required this.label});

  final Key tagKey;

  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Container(
      key: tagKey,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: sizing.scaled(AppSpacing.sm),
        vertical: sizing.scaled(6),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(sizing.scaled(45)),
        border: Border.all(color: context.appColors.divider, width: 0.5),
      ),
      child: Text(
        label,
        style: context.appTypography.accountDescription.copyWith(
          fontSize: sizing.scaled(13),
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

Uri? _parseExternalUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      !_hasValidExternalHost(uri.host)) {
    return null;
  }
  return uri;
}

bool _hasValidExternalHost(String host) {
  if (host.contains(':')) return true;

  final ipv4Parts = host.split('.');
  final isIpv4 =
      ipv4Parts.length == 4 &&
      ipv4Parts.every((part) {
        final value = int.tryParse(part);
        return value != null && value >= 0 && value <= 255;
      });
  if (isIpv4) return true;

  final labels = host.split('.');
  if (labels.length < 2) return false;
  final labelPattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
    caseSensitive: false,
  );
  return labels.every(labelPattern.hasMatch) &&
      RegExp(r'^[a-z]{2,63}$', caseSensitive: false).hasMatch(labels.last);
}

Future<bool> _launchExternalLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
