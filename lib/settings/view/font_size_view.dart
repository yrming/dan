import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/widgets/font_size_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Previews and immediately saves changes to the application font size.
class FontSizeView extends StatelessWidget {
  /// Creates the font-size adjustment view.
  const FontSizeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppearanceCubit, AppearanceState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AppearanceStatus.failure) {
          showAppToast(context, context.l10n.appearanceSaveFailure);
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        return Theme(
          data: _sizedTheme(theme, state.settings),
          child: Builder(
            builder: (context) => ColoredBox(
              color: context.appColors.groupedBackground,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                      children: [
                        Text(
                          context.l10n.appearanceFontPreviewTitle,
                          style: context.appTypography.statusHandle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const FontSizePreview(),
                      ],
                    ),
                  ),
                  _FontSizeControl(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  const _FontSizeControl({required this.state});

  final AppearanceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fontSize = state.settings.fontSize;
    String sizeLabel(double value) => l10n.appearanceFontSizeValue(value);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: AppSpacing.xl,
                      child: Text(
                        'Aa',
                        textAlign: TextAlign.end,
                        style: context.appTypography.settingsValue.copyWith(
                          fontSize: AppearanceSettings.minimumFontSize,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: l10n.appearanceFontSizeTitle,
                      child: Slider(
                        value: fontSize,
                        min: AppearanceSettings.minimumFontSize,
                        max: AppearanceSettings.maximumFontSize,
                        divisions:
                            (AppearanceSettings.maximumFontSize -
                                    AppearanceSettings.minimumFontSize)
                                .round(),
                        semanticFormatterCallback: sizeLabel,
                        onChanged: state.status == AppearanceStatus.loading
                            ? null
                            : (value) {
                                if (value == fontSize) return;
                                unawaited(HapticFeedback.selectionClick());
                                unawaited(
                                  context
                                      .read<AppearanceCubit>()
                                      .updateFontSize(
                                        value,
                                      ),
                                );
                              },
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: AppSpacing.xl,
                      child: Text(
                        'Aa',
                        textAlign: TextAlign.start,
                        style: context.appTypography.settingsValue.copyWith(
                          fontSize: AppearanceSettings.maximumFontSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.appearanceFontSizeHint,
                textAlign: TextAlign.center,
                style: context.appTypography.statusHandle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _sizedTheme(ThemeData theme, AppearanceSettings settings) {
  final sizing = AppSizing(scale: settings.scale);
  return theme.copyWith(
    extensions: [
      ...theme.extensions.values,
      sizing,
      AppTypography.fromTheme(
        sizing: sizing,
        colorScheme: theme.colorScheme,
        colors: theme.extension<AppColors>()!,
      ),
      AppStyle(statusPhotoStyle: settings.statusPhotoStyle),
    ],
  );
}
