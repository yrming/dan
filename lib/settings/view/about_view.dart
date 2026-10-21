import 'package:dan/app/configuration/configuration.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
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
      body: ColoredBox(
        color: colors.groupedBackground,
        child: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: sizing.scaled(AppSpacing.md),
                        vertical: sizing.scaled(AppSpacing.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              SizedBox(height: sizing.scaled(AppSpacing.xxl)),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  sizing.scaled(
                                    AppLayout.actionSheetGroupRadius,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/icons/logo.png',
                                  width: sizing.scaled(80),
                                  height: sizing.scaled(80),
                                  excludeFromSemantics: true,
                                ),
                              ),
                              SizedBox(height: sizing.scaled(AppSpacing.lg)),
                              Text(
                                l10n.loginBrandLogoLabel,
                                style: typography.brandTagline,
                                textAlign: TextAlign.center,
                              ),
                              if (buildInfo.version.isNotEmpty) ...[
                                SizedBox(height: sizing.scaled(AppSpacing.sm)),
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
                              SizedBox(height: sizing.scaled(AppSpacing.xxl)),
                              Card(
                                elevation: 0,
                                color: Theme.of(context).colorScheme.surface,
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
                            child: Column(
                              children: [
                                Text(
                                  l10n.aboutCopyright,
                                  style: typography.statusHandle,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
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
