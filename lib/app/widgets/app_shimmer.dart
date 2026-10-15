import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Applies the application's loading shimmer to a placeholder subtree.
class AppShimmer extends StatefulWidget {
  /// Creates an application shimmer.
  const AppShimmer({
    required this.semanticLabel,
    required this.child,
    super.key,
  });

  /// Accessibility label announced while the content is loading.
  final String semanticLabel;

  /// Placeholder subtree painted by the shimmer.
  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  static const Duration _shimmerDuration = Durations.extralong4;

  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _shimmerDuration,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_animationsDisabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final shimmer = _animationsDisabled
        ? widget.child
        : AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) {
              final position = (_controller.value * 3) - 1.5;
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(position - 1, -0.3),
                  end: Alignment(position + 1, 0.3),
                  colors: [
                    colors.skeletonBase,
                    colors.skeletonHighlight,
                    colors.skeletonBase,
                  ],
                  stops: const [0.2, 0.5, 0.8],
                ).createShader(bounds),
                child: child,
              );
            },
          );

    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: RepaintBoundary(child: shimmer),
      ),
    );
  }
}
