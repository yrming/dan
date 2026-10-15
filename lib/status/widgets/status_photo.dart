import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/wechat_status_photo.dart';
import 'package:dan/status/widgets/x_status_photo.dart';
import 'package:flutter/material.dart';

export 'package:appearance_repository/appearance_repository.dart'
    show StatusPhotoStyle;

export 'package:dan/status/widgets/wechat_status_photo.dart'
    show
        wechatStatusPhotoBorderRadius,
        wechatStatusPhotoDisplaySize,
        wechatStatusPhotoMaxHeight,
        wechatStatusPhotoMaxWidth,
        wechatStatusPhotoMinExtent;
export 'package:dan/status/widgets/x_status_photo.dart'
    show
        xStatusPhotoBorderRadius,
        xStatusPhotoMaxAspectRatio,
        xStatusPhotoMinAspectRatio,
        xStatusPhotoMinExtent;

/// Returns the corner radius used by a status photo style.
double statusPhotoBorderRadiusFor(StatusPhotoStyle style) {
  return switch (style) {
    StatusPhotoStyle.wechat => wechatStatusPhotoBorderRadius,
    StatusPhotoStyle.x => xStatusPhotoBorderRadius,
  };
}

/// Displays a cached status photo thumbnail.
class StatusPhoto extends StatefulWidget {
  /// Creates an X-style width-filling status photo thumbnail.
  const StatusPhoto.x({
    required this.imageUrl,
    required this.semanticLabel,
    required this.heroTag,
    this.onTap,
    super.key,
  }) : _cacheHeight = null,
       _isMomentsPreview = false,
       style = StatusPhotoStyle.x;

  /// Creates a WeChat-style bounded single-image thumbnail.
  const StatusPhoto.wechat({
    required this.imageUrl,
    required this.semanticLabel,
    required this.heroTag,
    this.onTap,
    super.key,
  }) : _cacheHeight = wechatStatusPhotoMaxHeight,
       _isMomentsPreview = false,
       style = StatusPhotoStyle.wechat;

  /// Creates a square thumbnail for a personal Moments album.
  const StatusPhoto.moments({
    required this.imageUrl,
    required this.semanticLabel,
    required this.heroTag,
    this.onTap,
    super.key,
  }) : _cacheHeight = wechatStatusPhotoMaxHeight,
       _isMomentsPreview = true,
       style = StatusPhotoStyle.wechat;

  /// Image URL to display.
  final String imageUrl;

  /// Accessible description for the image.
  final String semanticLabel;

  /// Hero tag shared with the full-screen image viewer.
  final String heroTag;

  /// Called when the photo is tapped.
  final VoidCallback? onTap;

  /// Layout and decoration applied to the thumbnail.
  final StatusPhotoStyle style;

  final double? _cacheHeight;
  final bool _isMomentsPreview;

  @override
  State<StatusPhoto> createState() => _StatusPhotoState();
}

class _StatusPhotoState extends State<StatusPhoto> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;
  Object? _imageError;
  String? _resolvedImageUrl;
  int? _resolvedCacheHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageSizeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StatusPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveImageSizeIfNeeded();
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImageSizeIfNeeded() {
    final cacheHeight = _cacheHeightFor(context, widget._cacheHeight);
    if (_resolvedImageUrl == widget.imageUrl &&
        _resolvedCacheHeight == cacheHeight) {
      return;
    }

    _removeImageListener();
    _imageSize = null;
    _imageError = null;
    _resolvedImageUrl = widget.imageUrl;
    _resolvedCacheHeight = cacheHeight;

    final provider = CachedNetworkImageProvider(
      widget.imageUrl,
      maxHeight: cacheHeight,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (imageInfo, _) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            imageInfo.image.width.toDouble(),
            imageInfo.image.height.toDouble(),
          );
          _imageError = null;
        });
        // Pre-cache the full-resolution image so the Hero animation to the
        // image viewer works on the first tap. Without this, only the
        // memCacheHeight-scaled version is in ImageCache, and the viewer
        // requests a different cache key (full-resolution), causing the
        // first Hero transition to fail.
        if (widget.heroTag.trim().isNotEmpty && widget.onTap != null) {
          unawaited(
            precacheImage(
              CachedNetworkImageProvider(widget.imageUrl),
              context,
            ),
          );
        }
      },
      onError: (error, _) {
        if (!mounted) return;
        setState(() {
          _imageError = error;
        });
      },
    );

    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageListener = null;
  }

  Future<void> _retryImage() async {
    final cacheHeight = _cacheHeightFor(context, widget._cacheHeight);
    await Future.wait([
      CachedNetworkImageProvider(
        widget.imageUrl,
        maxHeight: cacheHeight,
      ).evict(),
      CachedNetworkImageProvider(
        '${widget.imageUrl}1',
        maxHeight: cacheHeight,
      ).evict(),
    ]);
    if (!mounted) return;

    _removeImageListener();
    setState(() {
      _imageSize = null;
      _imageError = null;
      _resolvedImageUrl = null;
      _resolvedCacheHeight = null;
    });
    _resolveImageSizeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cacheHeight = _cacheHeightFor(context, widget._cacheHeight);
    final imageSize = _imageSize;
    final heroTag = widget.heroTag.trim();
    final failureIcon = IconButton(
      style: IconButton.styleFrom(
        overlayColor: AppColors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      color: colorScheme.onSurfaceVariant,
      onPressed: _retryImage,
      icon: Icon(
        Icons.broken_image_outlined,
        size: context.appSizing.scaled(40),
      ),
    );

    Widget buildImage(Size displaySize, BoxFit fit, Alignment alignment) {
      final placeholder = ExcludeSemantics(
        child: AppShimmer(
          semanticLabel: widget.semanticLabel,
          child: ColoredBox(
            color: context.appColors.skeletonBase,
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
            ),
          ),
        ),
      );
      final imageChild = _imageError != null
          ? failureIcon
          : imageSize == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: widget.imageUrl,
              width: displaySize.width,
              height: displaySize.height,
              memCacheHeight: cacheHeight,
              fit: fit,
              alignment: alignment,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => failureIcon,
            );
      return heroTag.isEmpty
          ? imageChild
          : Hero(
              tag: heroTag,
              placeholderBuilder: (_, _, child) => child,
              child: imageChild,
            );
    }

    final sourceImageSize = imageSize ?? const Size(4, 3);
    final thumbnailContent = widget._isMomentsPreview
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AppLayout.albumPhotoRadius),
            child: SizedBox.square(
              dimension: context.appSizing.scaled(100),
              child: ColoredBox(
                color: context.appColors.groupedBackground,
                child: buildImage(
                  Size.square(context.appSizing.scaled(100)),
                  BoxFit.cover,
                  Alignment.center,
                ),
              ),
            ),
          )
        : switch (widget.style) {
            StatusPhotoStyle.x => XStatusPhoto(
              sourceImageSize: sourceImageSize,
              backgroundColor: context.appColors.groupedBackground,
              imageBuilder: buildImage,
            ),
            StatusPhotoStyle.wechat => WeChatStatusPhoto(
              sourceImageSize: sourceImageSize,
              backgroundColor: context.appColors.groupedBackground,
              imageBuilder: buildImage,
            ),
          };

    return Semantics(
      image: true,
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: thumbnailContent,
      ),
    );
  }
}

int? _cacheHeightFor(BuildContext context, double? size) {
  return size == null
      ? null
      : (size * MediaQuery.devicePixelRatioOf(context)).ceil();
}

/// Returns a stable Hero tag for a status photo.
String statusPhotoHeroTag({
  required String scope,
  required String statusId,
  required String imageUrl,
}) {
  return 'status-photo-$scope-$statusId-$imageUrl';
}
