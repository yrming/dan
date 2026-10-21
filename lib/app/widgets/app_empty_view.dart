import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays the shared illustration used for empty content.
class AppEmptyView extends StatelessWidget {
  /// Creates an empty view with an optional accessible description.
  const AppEmptyView({this.semanticLabel, super.key});

  /// Description announced by screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.appSizing.scaled(AppSpacing.lg)),
        child: Semantics(
          image: true,
          label: semanticLabel,
          child: ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/icons/empty.svg',
              width: context.appSizing.scaled(48),
              height: context.appSizing.scaled(48),
              colorFilter: ColorFilter.mode(
                context.appColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
