import 'package:dan/app/theme/theme.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Shared loading failure message and retry action.
class AppRetryView extends StatefulWidget {
  const AppRetryView({
    required this.onRetry,
    this.message,
    this.revealOnDisplay = false,
    super.key,
  });

  final VoidCallback onRetry;
  final String? message;

  /// Reveals the entire pagination error when it is partly in the viewport.
  final bool revealOnDisplay;

  @override
  State<AppRetryView> createState() => _AppRetryViewState();
}

class _AppRetryViewState extends State<AppRetryView> {
  @override
  void initState() {
    super.initState();
    if (widget.revealOnDisplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealIfVisible());
    }
  }

  void _revealIfVisible() {
    if (!mounted) return;
    final target = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (target == null || scrollable == null) return;
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;
    final position = scrollable.position;
    final leading = viewport.getOffsetToReveal(target, 0).offset;
    // Do not pull the reader away from content elsewhere in the list.
    if (leading >= position.pixels + position.viewportDimension) return;
    Scrollable.ensureVisible(
      context,
      alignmentPolicy: axisDirectionIsReversed(position.axisDirection)
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(sizing.scaled(AppSpacing.md)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message ?? context.l10n.retryPageMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sizing.scaled(16),
                color: context.appColors.textBase,
              ),
            ),
            SizedBox(height: sizing.scaled(AppSpacing.md)),
            FilledButton(
              onPressed: widget.onRetry,
              child: Text(context.l10n.retryButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
