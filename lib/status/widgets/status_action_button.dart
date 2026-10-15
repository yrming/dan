import 'package:dan/app/theme/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Minimum interactive size of the status action button.
const statusActionButtonHitTargetSize = 40.0;

/// Displays the status action button.
class StatusActionButton extends StatefulWidget {
  /// Creates a status action button.
  const StatusActionButton({required this.onPressed, super.key});

  /// Called when the button is activated, or null when no action is available.
  final VoidCallback? onPressed;

  @override
  State<StatusActionButton> createState() => _StatusActionButtonState();
}

class _StatusActionButtonState extends State<StatusActionButton> {
  final _overlayController = OverlayPortalController();
  Drag? _scrollDrag;

  @override
  void initState() {
    super.initState();
    _overlayController.show();
  }

  @override
  void dispose() {
    _scrollDrag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;
    final colors = context.appColors;
    final foregroundColor = colors.textSecondary;
    final tooltip = MaterialLocalizations.of(context).moreButtonTooltip;
    final scrollable = Scrollable.maybeOf(context);
    // An overlay keeps the centered target tappable beyond the item's bounds
    // without making the dots or metadata row occupy additional layout space.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayChildBuilder: (overlayContext, info) {
        final buttonRect = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        final targetRect = Rect.fromCenter(
          center: buttonRect.center,
          width: statusActionButtonHitTargetSize,
          height: statusActionButtonHitTargetSize,
        );
        var visibleRect = Offset.zero & info.overlaySize;
        // Keep hot areas inside the feed viewport as their buttons scroll.
        final renderObject = context.findRenderObject();
        final viewport = renderObject == null
            ? null
            : RenderAbstractViewport.maybeOf(renderObject);
        if (viewport case final RenderBox viewportBox) {
          final overlay = Overlay.of(overlayContext).context.findRenderObject();
          visibleRect = visibleRect.intersect(
            MatrixUtils.transformRect(
              viewportBox.getTransformTo(overlay),
              Offset.zero & viewportBox.size,
            ),
          );
        }
        final hitRect = targetRect.intersect(visibleRect);
        if (hitRect.isEmpty || !buttonRect.overlaps(visibleRect)) {
          return const SizedBox.shrink();
        }
        return Positioned.fromRect(
          rect: hitRect,
          child: ExcludeSemantics(
            child: IgnorePointer(
              ignoring: widget.onPressed == null,
              child: GestureDetector(
                key: const Key('wechat-status-action-hit-target'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPressed,
                // Overlay gestures must forward drags to the underlying feed.
                onVerticalDragStart: scrollable == null
                    ? null
                    : (details) {
                        _scrollDrag = scrollable.position.drag(
                          details,
                          () => _scrollDrag = null,
                        );
                      },
                onVerticalDragUpdate: scrollable == null
                    ? null
                    : (details) => _scrollDrag?.update(details),
                onVerticalDragEnd: scrollable == null
                    ? null
                    : (details) => _scrollDrag?.end(details),
                onVerticalDragCancel: scrollable == null
                    ? null
                    : () => _scrollDrag?.cancel(),
              ),
            ),
          ),
        );
      },
      child: Semantics(
        button: true,
        enabled: widget.onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(sizing.scaled(4)),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionDot(color: foregroundColor),
                SizedBox(width: sizing.scaled(4)),
                _ActionDot(color: foregroundColor),
                SizedBox(width: sizing.scaled(4)),
                _ActionDot(color: foregroundColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionDot extends StatelessWidget {
  const _ActionDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final dimension = context.appSizing.scaled(3);
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
