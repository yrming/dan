import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Duration of the toast entrance fade.
const _fadeInDuration = Duration(milliseconds: 200);

/// Duration of the toast exit fade.
const _fadeOutDuration = Duration(milliseconds: 150);

/// How long the toast stays fully visible before fading out.
const _displayDuration = Duration(seconds: 2);

/// Maximum width of the toast pill.
const _maxWidth = 320.0;

/// Corner radius of the toast pill.
const _radius = 12.0;

/// Toast currently showing on each root overlay, so a new toast can replace
/// the visible one instead of queueing behind it.
final Expando<_AppToastHandle> _activeHandles = Expando<_AppToastHandle>();

/// Shows a short centered toast with [message] above all routes.
///
/// A new toast replaces the visible one with a cross-fade, never queues, and
/// does not block input. Does nothing when no root overlay is available.
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _activeHandles[overlay]?.dismiss();
  final handle = _AppToastHandle();
  _activeHandles[overlay] = handle;
  final entry = OverlayEntry(
    builder: (_) => _AppToast(message: message, handle: handle),
  );
  handle.entry = entry;
  overlay.insert(entry);
}

/// Links a showing toast with its overlay entry and dismissal callback.
class _AppToastHandle {
  OverlayEntry? entry;
  VoidCallback? onDismissRequested;

  /// Fades the toast out, or drops an entry that has not been built yet so a
  /// same-frame replacement never appears on screen.
  void dismiss() {
    final onDismiss = onDismissRequested;
    if (onDismiss != null) {
      onDismiss();
      return;
    }
    final pendingEntry = entry;
    entry = null;
    pendingEntry?.remove();
  }
}

/// A fading, self-removing toast pill rendered inside an overlay entry.
class _AppToast extends StatefulWidget {
  const _AppToast({required this.message, required this.handle});

  final String message;
  final _AppToastHandle handle;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: _fadeInDuration,
    reverseDuration: _fadeOutDuration,
    vsync: this,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();
    widget.handle.onDismissRequested = _beginDismiss;
    _controller.addStatusListener(_handleStatusChange);
    _controller.forward();
  }

  @override
  void dispose() {
    widget.handle
      ..entry = null
      ..onDismissRequested = null;
    _displayTimer?.cancel();
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleStatusChange(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.completed:
        _displayTimer = Timer(_displayDuration, _beginDismiss);
      case AnimationStatus.dismissed:
        final entry = widget.handle.entry;
        widget.handle
          ..entry = null
          ..onDismissRequested = null;
        if (entry?.mounted ?? false) {
          entry!.remove();
        }
      case AnimationStatus.forward || AnimationStatus.reverse:
        break;
    }
  }

  void _beginDismiss() {
    _displayTimer?.cancel();
    if (_controller.status == AnimationStatus.reverse ||
        _controller.isDismissed) {
      return;
    }
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IgnorePointer(
      child: Align(
        child: SafeArea(
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: FadeTransition(
                  opacity: _opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.toastBackground,
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: DefaultTextStyle(
                        style: context.appTypography.statusBody.copyWith(
                          color: colors.toastForeground,
                        ),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
