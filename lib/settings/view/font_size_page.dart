import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/view/font_size_view.dart';
import 'package:flutter/material.dart';

/// Route boundary using the application-wide appearance cubit.
class FontSizePage extends StatelessWidget {
  /// Creates the font-size adjustment page.
  const FontSizePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.groupedBackground,
      appBar: AppSubpageAppBar(
        showBottomDivider: false,
        backgroundColor: context.appColors.groupedBackground,
        title: context.l10n.appearanceFontSizeTitle,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      body: const FontSizeView(),
    );
  }
}
