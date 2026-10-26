import 'package:dan/app/configuration/configuration.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:remixicon/remixicon.dart';

/// Displays the app identity, its story, and legal document links.
class AboutView extends StatelessWidget {
  /// Creates the about view.
  const AboutView({
    required this.buildInfo,
    required this.onStoryPressed,
    required this.onUserAgreementPressed,
    required this.onPrivacyPolicyPressed,
    super.key,
  });

  /// Installed application version and build number.
  final AppBuildInfo buildInfo;

  /// Opens the story behind the application.
  final VoidCallback onStoryPressed;

  /// Opens the user agreement.
  final VoidCallback onUserAgreementPressed;

  /// Opens the privacy policy.
  final VoidCallback onPrivacyPolicyPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final typography = context.appTypography;
    final colors = context.appColors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.groupedBackground,
      appBar: AppSubpageAppBar(
        title: l10n.settingsAboutLabel,
        showBottomDivider: false,
        backgroundColor: colors.groupedBackground,
        toolbarHeight: sizing.appBarToolbarHeight,
      ),
      body: SafeArea(
        // bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _AboutPullReveal(
              imageExtent: constraints.maxWidth,
              viewportHeight: constraints.maxHeight,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: sizing.scaled(AppSpacing.md),
                        vertical: sizing.scaled(AppSpacing.md),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              SizedBox(
                                height: sizing.scaled(AppSpacing.xxl),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  sizing.scaled(
                                    AppLayout.actionSheetGroupRadius,
                                  ),
                                ),
                                child: SvgPicture.asset(
                                  'assets/icons/logo.svg',
                                  width: sizing.scaled(80),
                                  height: sizing.scaled(80),
                                  excludeFromSemantics: true,
                                ),
                              ),
                              SizedBox(
                                height: sizing.scaled(AppSpacing.lg),
                              ),
                              Text(
                                l10n.loginBrandLogoLabel,
                                style: typography.brandTagline,
                                textAlign: TextAlign.center,
                              ),
                              if (buildInfo.version.isNotEmpty) ...[
                                SizedBox(
                                  height: sizing.scaled(AppSpacing.sm),
                                ),
                                Text(
                                  buildInfo.buildNumber.isEmpty
                                      ? l10n.aboutVersion(buildInfo.version)
                                      : l10n.aboutVersionWithBuild(
                                          buildInfo.version,
                                          buildInfo.buildNumber,
                                        ),
                                  style: typography.statusHandle,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              SizedBox(
                                height: sizing.scaled(AppSpacing.xxl),
                              ),
                              Card(
                                elevation: 0,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    _AboutRow(
                                      key: const Key('about-why-row'),
                                      title: l10n.aboutWhyLabel,
                                      icon: RemixIcons.question_line,
                                      onTap: onStoryPressed,
                                    ),
                                    const Divider(height: 1),
                                    _AboutRow(
                                      key: const Key(
                                        'about-user-agreement-row',
                                      ),
                                      title: l10n.settingsUserAgreementLabel,
                                      icon: RemixIcons.file_text_line,
                                      onTap: onUserAgreementPressed,
                                    ),
                                    const Divider(height: 1),
                                    _AboutRow(
                                      key: const Key(
                                        'about-privacy-policy-row',
                                      ),
                                      title: l10n.settingsPrivacyPolicyLabel,
                                      icon: RemixIcons.file_lock_line,
                                      onTap: onPrivacyPolicyPressed,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              top: sizing.scaled(AppSpacing.xxl),
                            ),
                            child: Text(
                              l10n.aboutCopyright,
                              style: typography.statusHandle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AboutPullReveal extends StatefulWidget {
  const _AboutPullReveal({
    required this.imageExtent,
    required this.viewportHeight,
    required this.child,
  });

  final double imageExtent;
  final double viewportHeight;
  final Widget child;

  @override
  State<_AboutPullReveal> createState() => _AboutPullRevealState();
}

class _AboutPullRevealState extends State<_AboutPullReveal> {
  static const _settleDuration = Duration(milliseconds: 240);
  static const double _imageInset = AppSpacing.md;

  double get _revealExtent => _imageExtent + _imageInset * 2;

  double get _imageExtent =>
      (widget.imageExtent - _imageInset * 2).clamp(0, widget.imageExtent);

  double _pullExtent = 0;
  bool _isDragging = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.metrics.extentAfter == 0 &&
        notification.overscroll > 0) {
      setState(() {
        _isDragging = true;
        _pullExtent = (_pullExtent + notification.overscroll.abs()).clamp(
          0,
          _revealExtent,
        );
      });
    } else if (notification is ScrollEndNotification && _pullExtent > 0) {
      setState(() {
        _isDragging = false;
        _pullExtent = 0;
      });
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.extentAfter > 0 &&
        _pullExtent > 0) {
      setState(() {
        _isDragging = true;
        _pullExtent = 0;
      });
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: -_pullExtent),
              duration: _isDragging ? Duration.zero : _settleDuration,
              curve: Curves.easeOut,
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: widget.child,
            ),
          ),
          AnimatedPositioned(
            duration: _isDragging ? Duration.zero : _settleDuration,
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: widget.viewportHeight - _pullExtent,
            child: IgnorePointer(
              child: ColoredBox(
                color: context.appColors.bgBase,
                child: Padding(
                  padding: const EdgeInsets.all(_imageInset),
                  child: Image.asset(
                    key: const Key('about-bottom-image'),
                    'assets/images/dan.jpg',
                    width: _imageExtent,
                    height: _imageExtent,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.title,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return ListTile(
      textColor: context.appColors.textBase,
      iconColor: context.appColors.textBase,
      contentPadding: EdgeInsetsDirectional.only(
        start: sizing.scaled(AppSpacing.md),
        end: sizing.scaled(AppSpacing.sm),
      ),
      title: Text(title),
      leading: Icon(icon, size: sizing.scaled(AppSpacing.lg)),
      trailing: Icon(
        Icons.chevron_right,
        color: context.appColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
