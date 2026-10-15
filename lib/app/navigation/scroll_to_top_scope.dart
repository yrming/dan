import 'package:flutter/material.dart';

class DoubleTapListener extends StatefulWidget {
  const DoubleTapListener({
    required this.onDoubleTap,
    required this.child,
    super.key,
  });

  final VoidCallback onDoubleTap;
  final Widget child;

  @override
  State<DoubleTapListener> createState() => _DoubleTapListenerState();
}

class _DoubleTapListenerState extends State<DoubleTapListener> {
  static const Duration _doubleTapWindow = Durations.short4;
  DateTime? _lastTap;

  void _handlePointerDown(PointerDownEvent event) {
    final now = DateTime.now();
    final lastTap = _lastTap;
    _lastTap = now;
    if (lastTap != null && now.difference(lastTap) <= _doubleTapWindow) {
      widget.onDoubleTap();
      _lastTap = null;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _handlePointerDown,
    child: widget.child,
  );
}

/// Coordinates the scroll controller belonging to the visible status list.
class ScrollToTopController {
  final Map<Object?, VoidCallback> _callbacks = <Object?, VoidCallback>{};

  VoidCallback register(Object? key, VoidCallback callback) {
    _callbacks[key] = callback;
    return () {
      if (identical(_callbacks[key], callback)) _callbacks.remove(key);
    };
  }

  void scrollToTop([Object? key]) => _callbacks[key]?.call();
}

/// Makes the current status list available to an app bar.
class ScrollToTopScope extends InheritedWidget {
  const ScrollToTopScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final ScrollToTopController controller;

  static ScrollToTopController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ScrollToTopScope>()
      ?.controller;

  @override
  bool updateShouldNotify(ScrollToTopScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}
