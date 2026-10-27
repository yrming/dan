import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

/// Renders appearance and display settings.
class SettingsView extends StatelessWidget {
  /// Creates the settings view.
  const SettingsView({
    this.onFontSizePressed,
    this.onBlacklistPressed,
    this.onAboutPressed,
    this.onSwitchAccountPressed,
    this.onSignOutPressed,
    super.key,
  });

  /// Opens the font-size adjustment page.
  final VoidCallback? onFontSizePressed;

  /// Opens the active account's blacklist.
  final VoidCallback? onBlacklistPressed;

  /// Opens application information.
  final VoidCallback? onAboutPressed;

  /// Called when the switch-account action is pressed.
  final VoidCallback? onSwitchAccountPressed;

  /// Called when the sign-out action is pressed.
  final VoidCallback? onSignOutPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;

    return BlocConsumer<AppearanceCubit, AppearanceState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AppearanceStatus.failure &&
            ModalRoute.of(context)?.isCurrent != false) {
          showAppToast(context, context.l10n.appearanceSaveFailure);
        }
      },
      builder: (context, state) {
        final settings = state.settings;
        final enabled = state.status != AppearanceStatus.loading;

        return ColoredBox(
          color: context.appColors.groupedBackground,
          child: ListView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsRow(
                      key: const Key('settings-font-size-row'),
                      title: context.l10n.appearanceFontSizeTitle,
                      icon: RemixIcons.font_size,
                      enabled: enabled,
                      onTap: onFontSizePressed,
                    ),
                    const Divider(height: 1),
                    _AppearanceSettingRow<AppThemeMode>(
                      key: const Key('settings-theme-mode-row'),
                      title: context.l10n.appearanceThemeModeTitle,
                      icon: RemixIcons.moon_line,
                      selected: settings.themeMode,
                      options: {
                        AppThemeMode.system:
                            context.l10n.appearanceThemeModeSystem,
                        AppThemeMode.light:
                            context.l10n.appearanceThemeModeLight,
                        AppThemeMode.dark: context.l10n.appearanceThemeModeDark,
                      },
                      enabled: enabled,
                      onSelected: context
                          .read<AppearanceCubit>()
                          .updateThemeMode,
                    ),
                    const Divider(height: 1),
                    _AppearanceSettingRow<StatusPhotoStyle>(
                      key: const Key('settings-photo-style-row'),
                      title: context.l10n.appearanceStatusPhotoStyleTitle,
                      icon: RemixIcons.image_2_line,
                      selected: settings.statusPhotoStyle,
                      options: {
                        StatusPhotoStyle.wechat:
                            context.l10n.appearanceStatusPhotoStyleWeChat,
                        StatusPhotoStyle.x:
                            context.l10n.appearanceStatusPhotoStyleFullWidth,
                      },
                      enabled: enabled,
                      onSelected: context
                          .read<AppearanceCubit>()
                          .updateStatusPhotoStyle,
                    ),
                  ],
                ),
              ),
              SizedBox(height: sizing.scaled(AppSpacing.md)),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: _SettingsRow(
                  key: const Key('settings-blacklist-row'),
                  title: context.l10n.userProfileBlacklistLabel,
                  icon: RemixIcons.forbid_line,
                  enabled: enabled,
                  onTap: onBlacklistPressed,
                ),
              ),
              SizedBox(height: sizing.scaled(AppSpacing.md)),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: _SettingsRow(
                  key: const Key('settings-about-row'),
                  title: context.l10n.settingsAboutLabel,
                  icon: RemixIcons.information_line,
                  enabled: true,
                  onTap: onAboutPressed,
                ),
              ),
              SizedBox(height: sizing.scaled(AppSpacing.md)),
              _SettingsActionsSection(
                onSwitchAccountPressed: onSwitchAccountPressed,
                onSignOutPressed: onSignOutPressed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppearanceSettingRow<T> extends StatelessWidget {
  const _AppearanceSettingRow({
    required this.title,
    required this.icon,
    required this.selected,
    required this.options,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final String title;
  final IconData icon;
  final T selected;
  final Map<T, String> options;
  final bool enabled;
  final Future<void> Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      title: title,
      icon: icon,
      value: options[selected],
      enabled: enabled,
      onTap: () => unawaited(
        showAppActionSheet(
          context,
          groups: [
            AppActionSheetGroup(
              children: [
                for (final option in options.entries)
                  AppActionSheetItem(
                    key: ValueKey('settings-option-${option.key}'),
                    label: option.value,
                    icon: Icons.check,
                    iconColor: option.key == selected
                        ? context.appColors.wechatGreen
                        : AppColors.transparent,
                    onPressed: () {
                      if (option.key != selected) {
                        unawaited(onSelected(option.key));
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionsSection extends StatelessWidget {
  const _SettingsActionsSection({
    required this.onSwitchAccountPressed,
    required this.onSignOutPressed,
  });

  final VoidCallback? onSwitchAccountPressed;
  final VoidCallback? onSignOutPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SettingsRow(
            title: context.l10n.accountSwitcherPageTitle,
            icon: RemixIcons.arrow_left_right_line,
            enabled: true,
            onTap: onSwitchAccountPressed,
          ),
          const Divider(height: 1),
          _SettingsRow(
            title: context.l10n.signOutLabel,
            icon: RemixIcons.logout_box_r_line,
            enabled: true,
            onTap: onSignOutPressed,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.value,
    super.key,
  });

  final String title;
  final IconData icon;
  final String? value;
  final bool enabled;
  final VoidCallback? onTap;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value case final value?) ...[
            Text(
              value,
              style: context.appTypography.settingsValue.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            SizedBox(width: sizing.scaled(AppSpacing.xxs)),
          ],
          Icon(Icons.chevron_right, color: context.appColors.textSecondary),
        ],
      ),
      enabled: enabled,
      onTap: onTap,
    );
  }
}
