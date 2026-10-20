import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/cubit/status_image_viewer_cubit.dart';
import 'package:dan/status/models/status_image_gallery.dart';
import 'package:dan/status/services/status_image_actions_service.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

const _dismissThreshold = 0.22;
const _dismissFlingVelocity = 1000.0;
const _minimumFlingDistance = 24.0;
const _maximumDismissScaleReduction = 0.15;
const _zoomComparisonTolerance = 0.01;

/// Shows a status image in an immersive viewer.
class StatusImageViewerPage extends StatelessWidget {
  /// Creates a status image viewer page.
  const StatusImageViewerPage({
    required this.imageUrl,
    required this.heroTag,
    this.semanticLabel,
    this.imageProvider,
    this.userId,
    this.statusId,
    this.initialStatus,
    this.gallery,
    super.key,
  });

  /// Full-size image URL to display.
  final String imageUrl;

  /// Accessible description for the image.
  final String? semanticLabel;

  /// Hero tag shared with the source thumbnail.
  final String heroTag;

  /// Author of the status linked from an album preview.
  final String? userId;

  /// Status linked from an album preview; absent for other image previews.
  final String? statusId;

  /// Existing status passed through to detail without fetching it again.
  final status_repository.Status? initialStatus;

  /// Loaded album photos available for horizontal paging.
  final StatusImageGallery? gallery;

  /// Overrides the network image provider in tests.
  @visibleForTesting
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final photos = gallery?.statuses;
    final initialIndex = photos?.indexWhere((status) => status.id == statusId);
    final selectedStatus = gallery?.statusFor(statusId) ?? initialStatus;
    return BlocProvider(
      create: (context) => StatusImageViewerCubit(
        imageActionsService: context.read<StatusImageActionsService>(),
      ),
      child:
          photos != null &&
              photos.length > 1 &&
              initialIndex != null &&
              initialIndex >= 0
          ? _StatusImageGalleryView(
              photos: photos,
              initialIndex: initialIndex,
              imageProvider: imageProvider,
            )
          : StatusImageViewerView(
              imageUrl: imageUrl,
              heroTag: heroTag,
              semanticLabel: semanticLabel,
              imageProvider: imageProvider,
              previewImageUrl: initialStatus?.photo?.displayUrl,
              createdAt: gallery == null ? null : selectedStatus?.createdAt,
              onViewStatus:
                  userId != null &&
                      userId!.trim().isNotEmpty &&
                      statusId != null &&
                      statusId!.trim().isNotEmpty
                  ? () => unawaited(
                      context.pushNamed<void>(
                        AppRouteName.statusDetail,
                        pathParameters: {
                          'userId': userId!,
                          'statusId': statusId!,
                        },
                        extra: initialStatus,
                      ),
                    )
                  : null,
            ),
    );
  }
}

class _StatusImageGalleryView extends StatefulWidget {
  const _StatusImageGalleryView({
    required this.photos,
    required this.initialIndex,
    this.imageProvider,
  });

  final List<status_repository.Status> photos;
  final int initialIndex;
  final ImageProvider<Object>? imageProvider;

  @override
  State<_StatusImageGalleryView> createState() =>
      _StatusImageGalleryViewState();
}

class _StatusImageGalleryViewState extends State<_StatusImageGalleryView> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _isDismissing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoViewGestureDetectorScope(
      axis: Axis.horizontal,
      child: PageView.builder(
        controller: _controller,
        physics: _isDismissing ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final status = widget.photos[index];
          return HeroMode(
            enabled: index == _index,
            child: StatusImageViewerView(
              key: ValueKey(status.id),
              imageUrl: status.photo!.viewerUrl,
              imageProvider: widget.imageProvider,
              isActive: index == _index,
              onDismissGestureChanged: (isDismissing) {
                if (_isDismissing == isDismissing) return;
                setState(() => _isDismissing = isDismissing);
              },
              heroTag: statusPhotoHeroTag(
                scope: 'monthly-photos',
                statusId: status.id,
                imageUrl: status.photo!.viewerUrl,
              ),
              semanticLabel: statusHtmlToPlainText(status.text),
              previewImageUrl: status.photo!.displayUrl,
              createdAt: status.createdAt,
              onViewStatus: () => unawaited(
                context.pushNamed<void>(
                  AppRouteName.statusDetail,
                  pathParameters: {
                    'userId': status.author.id.isEmpty
                        ? 'unknown'
                        : status.author.id,
                    'statusId': status.id,
                  },
                  extra: status,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Renders the immersive viewer state and dispatches image actions.
class StatusImageViewerView extends StatefulWidget {
  const StatusImageViewerView({
    required this.imageUrl,
    required this.heroTag,
    this.semanticLabel,
    this.imageProvider,
    this.onViewStatus,
    this.previewImageUrl,
    this.createdAt,
    this.isActive = true,
    this.onDismissGestureChanged,
    super.key,
  }) : onClose = null;

  /// Uses the status viewer interactions for a local, unpublished image.
  const StatusImageViewerView.local({
    required this.imageProvider,
    required this.onClose,
    required this.heroTag,
    this.semanticLabel,
    super.key,
  }) : imageUrl = '',
       previewImageUrl = null,
       createdAt = null,
       isActive = true,
       onDismissGestureChanged = null,
       onViewStatus = null;

  /// Full-size image URL to display.
  final String imageUrl;

  /// Accessible description for the image.
  final String? semanticLabel;

  /// Hero tag shared with the source thumbnail.
  final String heroTag;

  /// Image source for a local preview, or a test override for a status.
  final ImageProvider<Object>? imageProvider;

  /// Closes a local image preview without navigating to a status route.
  final VoidCallback? onClose;

  /// Opens the status associated with an album photo.
  final VoidCallback? onViewStatus;

  /// Album thumbnail used for the Hero flight while the full image loads.
  final String? previewImageUrl;

  /// Posting time shown over a photo opened from the album.
  final String? createdAt;

  /// Whether this photo is currently visible and should show action feedback.
  final bool isActive;

  /// Prevents gallery paging while this photo is dragged out or returning.
  final ValueChanged<bool>? onDismissGestureChanged;

  @override
  State<StatusImageViewerView> createState() => _StatusImageViewerViewState();
}

class _StatusImageViewerViewState extends State<StatusImageViewerView> {
  late final PhotoViewController _photoViewController;
  late final PhotoViewScaleStateController _scaleStateController;
  late final StreamSubscription<PhotoViewControllerValue>
  _photoViewSubscription;

  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  Size? _imageSize;
  Size? _viewportSize;
  String? _resolvedImageUrl;
  ImageProvider<Object>? _resolvedImageProvider;
  double? _initialScale;
  double _dismissProgress = 0;
  double _slideOffset = 0;
  bool _canSlideOut = true;
  bool _isSlidingOut = false;
  bool _isSlideResetAnimating = false;
  bool _isClosing = false;
  int _reloadCount = 0;
  Offset _photoPosition = Offset.zero;
  final _activePointers = <int>{};
  Animation<double>? _openingPreviewAnimation;
  bool _keepOpeningPreview = false;
  int? _slidePointer;
  Offset? _slideStartPosition;
  Offset? _lastSlidePointerPosition;
  VelocityTracker? _slideVelocityTracker;

  @override
  void initState() {
    super.initState();
    _photoViewController = PhotoViewController();
    _scaleStateController = PhotoViewScaleStateController();
    _photoViewSubscription = _photoViewController.outputStateStream.listen(
      _handlePhotoViewValue,
    );
  }

  @override
  void didUpdateWidget(covariant StatusImageViewerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl ||
        widget.imageProvider != oldWidget.imageProvider) {
      _resolveImageSizeIfNeeded();
      _initialScale = null;
      _canSlideOut = true;
      _reloadCount = 0;
      _resetPhotoView();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageSizeIfNeeded();
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    // Hero measures the destination offstage with a completed proxy animation
    // before the real entrance animation starts. Include that first frame.
    if (_openingPreviewAnimation == null &&
        _imageSize == null &&
        widget.previewImageUrl != null &&
        widget.heroTag.isNotEmpty &&
        animation != null &&
        (route!.offstage ||
            animation.status == AnimationStatus.forward ||
            animation.status == AnimationStatus.dismissed)) {
      _openingPreviewAnimation = animation;
      _keepOpeningPreview = true;
      animation.addStatusListener(_handleOpeningPreviewStatus);
    }
  }

  void _handleOpeningPreviewStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _openingPreviewAnimation?.removeStatusListener(_handleOpeningPreviewStatus);
    setState(() => _keepOpeningPreview = false);
  }

  @override
  void dispose() {
    _openingPreviewAnimation?.removeStatusListener(_handleOpeningPreviewStatus);
    _removeImageStreamListener();
    unawaited(_photoViewSubscription.cancel());
    _photoViewController.dispose();
    _scaleStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrl.trim();
    final semanticLabel = widget.semanticLabel?.trim();
    final resolvedSemanticLabel = semanticLabel == null || semanticLabel.isEmpty
        ? imageUrl
        : semanticLabel;
    final heroTag = widget.heroTag.trim();
    final backgroundOpacity = 1 - _dismissProgress;
    final imageScale = 1 - (_dismissProgress * _maximumDismissScaleReduction);
    final statusPhotoBorderRadius = widget.onClose == null
        ? statusPhotoBorderRadiusFor(context.appStatusPhotoStyle)
        : xStatusPhotoBorderRadius;
    final isDismissing = _isClosing || _isSlidingOut;
    final slideAnimationDuration = _isSlideResetAnimating
        ? Durations.medium2
        : Duration.zero;
    final createdAt = widget.createdAt;
    final dateLabel =
        createdAt != null && tryParseFanfouCreatedAt(createdAt) != null
        ? formatFanfouCalendarDate(createdAt)
        : null;

    final viewer = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: AppColors.imageViewerBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: slideAnimationDuration,
              curve: Easing.standard,
              color: AppColors.imageViewerBackground.withValues(
                alpha: backgroundOpacity,
              ),
            ),
            if (imageUrl.isEmpty && widget.imageProvider == null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const _ImageViewerFailureIcon(),
              )
            else
              Listener(
                key: const Key('status-image-viewer-gesture-layer'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportSize = constraints.biggest;
                    final imageSize = _imageSize;
                    final imageProvider = _imageProviderFor(imageUrl);
                    _viewportSize = viewportSize;
                    final usesWidthFit =
                        imageSize != null &&
                        statusImageViewerUsesWidthFitFor(
                          imageSize: imageSize,
                          viewportSize: viewportSize,
                        );
                    final initialScale = imageSize == null
                        ? PhotoViewComputedScale.contained
                        : statusImageViewerInitialScaleFor(
                            imageSize: imageSize,
                            viewportSize: viewportSize,
                          );
                    final basePosition = usesWidthFit
                        ? Alignment.topCenter
                        : Alignment.center;
                    final imageBounds = imageSize == null
                        ? null
                        : basePosition.inscribe(
                            imageSize *
                                statusImageViewerInitialScaleFor(
                                  imageSize: imageSize,
                                  viewportSize: viewportSize,
                                ),
                            Offset.zero & viewportSize,
                          );

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPressStart: widget.onClose == null
                          ? (_) => unawaited(_showImageActions(context))
                          // Consume a draft long press without treating its
                          // release as a tap to close the preview.
                          : (_) {},
                      child: AnimatedSlide(
                        duration: slideAnimationDuration,
                        curve: Easing.standard,
                        offset: Offset(0, _dismissProgress),
                        onEnd: _handleSlideAnimationEnd,
                        child: AnimatedScale(
                          duration: slideAnimationDuration,
                          curve: Easing.standard,
                          scale: imageScale,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              end: isDismissing && imageBounds != null
                                  ? statusPhotoBorderRadius / imageScale
                                  : 0,
                            ),
                            duration: slideAnimationDuration,
                            curve: Easing.standard,
                            builder: (context, borderRadius, child) {
                              if (borderRadius <= 0 || imageBounds == null) {
                                return child!;
                              }

                              return ClipRRect(
                                key: const Key(
                                  'status-image-viewer-rounded-photo',
                                ),
                                clipper: _StatusImageViewerClipper(
                                  imageBounds: imageBounds,
                                  borderRadius: borderRadius,
                                ),
                                child: child,
                              );
                            },
                            // Keep the same Hero mounted for the entire flight.
                            // Replacing the loading Hero when decoding finishes
                            // would reveal a second image underneath it.
                            child: _keepOpeningPreview
                                ? _buildLoadingPreview(heroTag)
                                : PhotoView(
                                    key: ValueKey(
                                      'status-image-viewer-photo-$_reloadCount',
                                    ),
                                    imageProvider: imageProvider,
                                    controller: _photoViewController,
                                    scaleStateController: _scaleStateController,
                                    backgroundDecoration: const BoxDecoration(
                                      color: AppColors.transparent,
                                    ),
                                    semanticLabel: resolvedSemanticLabel,
                                    heroAttributes: heroTag.isEmpty
                                        ? null
                                        : PhotoViewHeroAttributes(
                                            tag: heroTag,
                                            transitionOnUserGestures: true,
                                            flightShuttleBuilder: isDismissing
                                                ? (
                                                    _,
                                                    _,
                                                    _,
                                                    _,
                                                    toHeroContext,
                                                  ) => _buildRoundedHeroShuttle(
                                                    toHeroContext:
                                                        toHeroContext,
                                                    borderRadius:
                                                        statusPhotoBorderRadius,
                                                  )
                                                : null,
                                          ),
                                    initialScale: initialScale,
                                    minScale: initialScale,
                                    maxScale:
                                        PhotoViewComputedScale.covered * 4,
                                    scaleStateCycle: _cycleScaleState,
                                    basePosition: basePosition,
                                    filterQuality: FilterQuality.medium,
                                    gestureDetectorBehavior:
                                        HitTestBehavior.opaque,
                                    disableGestures: isDismissing,
                                    loadingBuilder: (_, _) =>
                                        _buildLoadingPreview(heroTag),
                                    errorBuilder: (_, _, _) =>
                                        _ImageViewerFailureIcon(
                                          onTap: () => _reloadImage(imageUrl),
                                        ),
                                    onTapUp: (_, _, _) => _close(),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (dateLabel != null)
              PositionedDirectional(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                top: AppSpacing.md,
                child: IgnorePointer(
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedOpacity(
                      opacity: isDismissing ? 0 : 1,
                      duration: Durations.short2,
                      child: Text(
                        dateLabel,
                        textAlign: TextAlign.center,
                        style: context.appTypography.statusBody.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.onViewStatus != null)
              PositionedDirectional(
                end: AppSpacing.md,
                bottom: AppSpacing.lg,
                child: SafeArea(
                  top: false,
                  child: IgnorePointer(
                    ignoring: isDismissing,
                    child: AnimatedOpacity(
                      opacity: isDismissing ? 0 : 1,
                      duration: Durations.short2,
                      child: FilledButton.icon(
                        onPressed: widget.onViewStatus,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF737373).withValues(
                            alpha: 0.6,
                          ),
                          foregroundColor: Colors.white,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: context.appTypography.statusHandle,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        iconAlignment: IconAlignment.end,
                        // icon: const Icon(
                        //   RemixIcons.arrow_right_s_line,
                        //   size: 14,
                        // ),
                        label: Text(
                          context.l10n.statusImageViewerViewStatusLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.onClose != null) return viewer;
    return BlocListener<StatusImageViewerCubit, StatusImageViewerState>(
      listenWhen: (previous, current) =>
          widget.isActive &&
          previous.status != current.status &&
          current.status != StatusImageViewerActionStatus.inProgress,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                state.status == StatusImageViewerActionStatus.success
                    ? context.l10n.statusImageViewerSavedToGalleryLabel
                    : context.l10n.statusImageViewerActionFailureLabel,
              ),
            ),
          );
      },
      child: viewer,
    );
  }

  Widget _buildLoadingPreview(String heroTag) {
    final previewImageUrl = widget.previewImageUrl;
    if (previewImageUrl == null || heroTag.isEmpty) {
      return const SizedBox.expand();
    }

    // PhotoView only creates its Hero once the full image is decoded. Keep a
    // matching Hero available on the first frame using the cached album image.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Hero(
        tag: heroTag,
        transitionOnUserGestures: true,
        child: CachedNetworkImage(
          imageUrl: previewImageUrl,
          memCacheHeight: (200 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          fit: BoxFit.contain,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, _) => const SizedBox.expand(),
          errorWidget: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
  }

  /// Resets both the photo view controller and its scale state controller.
  ///
  /// Resetting only the photo view controller desynchronizes the internal
  /// scale state (PhotoView marks it as zoomed-out), which makes the first
  /// double-tap a no-op. Resetting the scale state afterwards keeps the
  /// double-tap cycle starting from the initial scale.
  void _resetPhotoView() {
    _photoViewController.reset();
    _scaleStateController.reset();
  }

  /// Returns the next scale state for a double-tap.
  ///
  /// Double-tapping toggles between the fit-to-screen state and a single
  /// zoomed-in state, instead of PhotoView's default three-step cycle
  /// (fit → covering → original size), whose covering → original size step is
  /// an imperceptible change for many images.
  PhotoViewScaleState _cycleScaleState(PhotoViewScaleState current) {
    if (current != PhotoViewScaleState.initial) {
      return PhotoViewScaleState.initial;
    }

    final imageSize = _imageSize;
    final viewportSize = _viewportSize;
    if (imageSize == null || viewportSize == null) {
      return PhotoViewScaleState.covering;
    }

    return statusImageViewerZoomScaleStateFor(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
  }

  void _handlePhotoViewValue(PhotoViewControllerValue value) {
    _photoPosition = value.position;
    final scale = value.scale;
    if (scale == null || !scale.isFinite || scale <= 0) return;

    final imageSize = _imageSize;
    final viewportSize = _viewportSize;
    final initialScale = imageSize == null || viewportSize == null
        ? _initialScale ??= scale
        : statusImageViewerInitialScaleFor(
            imageSize: imageSize,
            viewportSize: viewportSize,
          );
    final canSlideOut = scale <= initialScale + _zoomComparisonTolerance;
    if (canSlideOut == _canSlideOut || !mounted) return;

    setState(() => _canSlideOut = canSlideOut);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length != 1) {
      _cancelSlideTracking(resetSlide: _isSlidingOut);
      return;
    }

    // The reset animation targets the resting position, so a new gesture can
    // safely interrupt it and start tracking immediately.
    if (_isSlideResetAnimating) {
      setState(() => _isSlideResetAnimating = false);
      widget.onDismissGestureChanged?.call(false);
    }

    _slidePointer = event.pointer;
    _slideStartPosition = event.position;
    _lastSlidePointerPosition = event.position;
    _slideVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _slidePointer || _activePointers.length != 1) return;

    final lastPosition = _lastSlidePointerPosition;
    _lastSlidePointerPosition = event.position;
    _slideVelocityTracker?.addPosition(event.timeStamp, event.position);
    if (lastPosition == null || !_canSlideOut) return;

    final delta = event.position - lastPosition;
    if (!_isSlidingOut) {
      final startPosition = _slideStartPosition;
      final totalDelta = startPosition == null
          ? delta
          : event.position - startPosition;
      final isDraggingDown =
          totalDelta.dy > 0 && totalDelta.dy.abs() > totalDelta.dx.abs();
      final isAtTop = _photoPosition.dy >= -_zoomComparisonTolerance;
      if (!isDraggingDown || !isAtTop) return;

      // Include the movement used to establish the direction so the first
      // frame of the dismissal does not get lost to gesture jitter.
      final viewportHeight = _viewportSize?.height ?? 0;
      if (viewportHeight <= 0) return;
      final slideOffset = totalDelta.dy.clamp(0.0, viewportHeight);
      setState(() {
        _isSlidingOut = true;
        _isSlideResetAnimating = false;
        _slideOffset = slideOffset;
        _dismissProgress = slideOffset / viewportHeight;
      });
      widget.onDismissGestureChanged?.call(true);
      return;
    }

    final viewportHeight = _viewportSize?.height ?? 0;
    if (viewportHeight <= 0) return;

    final slideOffset = (_slideOffset + delta.dy).clamp(
      0.0,
      viewportHeight,
    );
    setState(() {
      _isSlidingOut = true;
      _isSlideResetAnimating = false;
      _slideOffset = slideOffset;
      _dismissProgress = slideOffset / viewportHeight;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (event.pointer != _slidePointer) return;

    _slideVelocityTracker?.addPosition(event.timeStamp, event.position);
    _finishSlide();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (event.pointer != _slidePointer) return;

    _cancelSlideTracking(resetSlide: _isSlidingOut);
  }

  void _finishSlide() {
    final velocity =
        _slideVelocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final viewportHeight = _viewportSize?.height ?? 0;
    final shouldClose = statusImageViewerShouldPopForSlide(
      distance: _slideOffset,
      viewportHeight: viewportHeight,
      velocity: velocity,
    );
    final wasSlidingOut = _isSlidingOut;
    _clearSlideTracking();

    if (wasSlidingOut && shouldClose) {
      _close();
      return;
    }
    if (wasSlidingOut) _resetSlide();
  }

  void _cancelSlideTracking({required bool resetSlide}) {
    _clearSlideTracking();
    if (resetSlide) _resetSlide();
  }

  void _clearSlideTracking() {
    _slidePointer = null;
    _slideStartPosition = null;
    _lastSlidePointerPosition = null;
    _slideVelocityTracker = null;
  }

  void _resetSlide() {
    if (!mounted) return;

    setState(() {
      _isSlidingOut = false;
      _isSlideResetAnimating = true;
      _slideOffset = 0;
      _dismissProgress = 0;
    });
  }

  void _handleSlideAnimationEnd() {
    if (!_isSlideResetAnimating || _dismissProgress != 0 || !mounted) return;
    setState(() => _isSlideResetAnimating = false);
    widget.onDismissGestureChanged?.call(false);
  }

  Future<void> _reloadImage(String imageUrl) async {
    await _imageProviderFor(imageUrl).evict();
    if (!mounted) return;

    _resolvedImageUrl = null;
    setState(() {
      _imageSize = null;
      _initialScale = null;
      _canSlideOut = true;
      _reloadCount += 1;
    });
    _resolveImageSizeIfNeeded();
  }

  void _resolveImageSizeIfNeeded() {
    final imageUrl = widget.imageUrl.trim();
    final imageProvider = _imageProviderFor(imageUrl);
    if (_resolvedImageUrl == imageUrl &&
        _resolvedImageProvider == imageProvider) {
      return;
    }

    _removeImageStreamListener();
    _resolvedImageUrl = imageUrl;
    _resolvedImageProvider = imageProvider;
    _imageSize = null;
    if (imageUrl.isEmpty && widget.imageProvider == null) return;

    final stream = imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (imageInfo, _) {
        if (!mounted) return;

        _resetPhotoView();
        setState(() {
          _imageSize = Size(
            imageInfo.image.width.toDouble(),
            imageInfo.image.height.toDouble(),
          );
          _initialScale = null;
          _canSlideOut = true;
        });
      },
      onError: (_, _) {
        if (!mounted || _imageSize == null) return;
        setState(() => _imageSize = null);
      },
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _removeImageStreamListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  ImageProvider<Object> _imageProviderFor(String imageUrl) {
    return widget.imageProvider ?? CachedNetworkImageProvider(imageUrl);
  }

  void _close() {
    if (_isClosing || !mounted) return;
    setState(() => _isClosing = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final onClose = widget.onClose;
      if (onClose != null) {
        onClose();
        return;
      }

      if (context.canPop()) {
        context.pop();
        return;
      }

      context.goNamed(AppRouteName.home);
    });
  }

  Future<void> _showImageActions(BuildContext context) {
    final l10n = context.l10n;
    return showAppActionSheet(
      context,
      sheetKey: const Key('status-image-viewer-action-sheet'),
      groups: [
        AppActionSheetGroup(
          key: const Key('status-image-viewer-action-group'),
          dividerKeys: const [Key('status-image-viewer-action-divider')],
          children: [
            AppActionSheetItem(
              key: const Key('status-image-viewer-save-action'),
              label: l10n.statusImageViewerSaveLabel,
              icon: RemixIcons.download_line,
              onPressed: () => unawaited(
                context.read<StatusImageViewerCubit>().saveToGalleryRequested(
                  widget.imageUrl,
                ),
              ),
            ),
            AppActionSheetItem(
              key: const Key('status-image-viewer-share-action'),
              label: l10n.statusImageViewerShareLabel,
              icon: RemixIcons.share_box_line,
              onPressed: () => unawaited(
                context.read<StatusImageViewerCubit>().shareRequested(
                  widget.imageUrl,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Returns whether a downward slide should close the image viewer.
@visibleForTesting
bool statusImageViewerShouldPopForSlide({
  required double distance,
  required double viewportHeight,
  required double velocity,
}) {
  if (distance <= 0 || viewportHeight <= 0) return false;

  return distance / viewportHeight >= _dismissThreshold ||
      (distance >= _minimumFlingDistance && velocity >= _dismissFlingVelocity);
}

/// Returns whether an image needs width-fit presentation to avoid appearing
/// narrower than the viewport when fully contained.
@visibleForTesting
bool statusImageViewerUsesWidthFitFor({
  required Size imageSize,
  required Size viewportSize,
}) {
  if (!_isValidSize(imageSize) || !_isValidSize(viewportSize)) return false;

  return imageSize.aspectRatio < viewportSize.aspectRatio;
}

/// Returns the initial PhotoView scale for an image and viewport.
@visibleForTesting
double statusImageViewerInitialScaleFor({
  required Size imageSize,
  required Size viewportSize,
}) {
  if (!_isValidSize(imageSize) || !_isValidSize(viewportSize)) return 1;

  final widthScale = viewportSize.width / imageSize.width;
  final heightScale = viewportSize.height / imageSize.height;

  return statusImageViewerUsesWidthFitFor(
        imageSize: imageSize,
        viewportSize: viewportSize,
      )
      ? widthScale
      : widthScale < heightScale
      ? widthScale
      : heightScale;
}

/// Returns the scale state a double-tap zooms to from the fit-to-screen state.
///
/// Regular images zoom to [PhotoViewScaleState.covering] (fill the screen).
/// Width-fitted images already fill the width at the fit scale, so covering is
/// the same as the fit scale and [PhotoViewScaleState.originalSize] is used
/// instead for a meaningful zoom.
@visibleForTesting
PhotoViewScaleState statusImageViewerZoomScaleStateFor({
  required Size imageSize,
  required Size viewportSize,
}) {
  return statusImageViewerUsesWidthFitFor(
        imageSize: imageSize,
        viewportSize: viewportSize,
      )
      ? PhotoViewScaleState.originalSize
      : PhotoViewScaleState.covering;
}

bool _isValidSize(Size size) {
  return size.width > 0 &&
      size.height > 0 &&
      size.width.isFinite &&
      size.height.isFinite;
}

Widget _buildRoundedHeroShuttle({
  required BuildContext toHeroContext,
  required double borderRadius,
}) {
  final toHero = toHeroContext.widget as Hero;
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: toHero.child,
  );
}

class _StatusImageViewerClipper extends CustomClipper<RRect> {
  const _StatusImageViewerClipper({
    required this.imageBounds,
    required this.borderRadius,
  });

  final Rect imageBounds;
  final double borderRadius;

  @override
  RRect getClip(Size size) {
    return RRect.fromRectAndRadius(
      imageBounds,
      Radius.circular(borderRadius),
    );
  }

  @override
  bool shouldReclip(_StatusImageViewerClipper oldClipper) {
    return imageBounds != oldClipper.imageBounds ||
        borderRadius != oldClipper.borderRadius;
  }
}

class _ImageViewerFailureIcon extends StatelessWidget {
  const _ImageViewerFailureIcon({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        tooltip: MaterialLocalizations.of(
          context,
        ).refreshIndicatorSemanticLabel,
        color: AppColors.imageViewerForeground,
        onPressed: onTap,
        icon: Icon(
          Icons.broken_image_outlined,
          size: context.appSizing.scaled(40),
        ),
      ),
    );
  }
}
