import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Maximum width of a WeChat-style single status image.
const wechatStatusPhotoMaxWidth = 200.0;

/// Maximum height of a WeChat-style single status image.
const wechatStatusPhotoMaxHeight = 200.0;

/// Minimum width and height of a WeChat-style single status image.
const wechatStatusPhotoMinExtent = 70.0;

/// Corner radius of a WeChat-style single status image.
const wechatStatusPhotoBorderRadius = 8.0;

/// Builds the WeChat-style bounded single-image status photo presentation.
class WeChatStatusPhoto extends StatelessWidget {
  /// Creates a WeChat-style status photo presentation.
  const WeChatStatusPhoto({
    required this.sourceImageSize,
    required this.backgroundColor,
    required this.imageBuilder,
    super.key,
  });

  /// Resolved source image dimensions.
  final Size sourceImageSize;

  /// Color shown while the image is loading or unavailable.
  final Color backgroundColor;

  /// Builds the shared cached image for the requested presentation.
  final Widget Function(Size displaySize, BoxFit fit, Alignment alignment)
  imageBuilder;

  @override
  Widget build(BuildContext context) {
    final displaySize = wechatStatusPhotoDisplaySize(
      imageSize: sourceImageSize,
    );
    final image = imageBuilder(
      displaySize,
      BoxFit.cover,
      Alignment.center,
    );

    return Container(
      width: displaySize.width,
      height: displaySize.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(wechatStatusPhotoBorderRadius),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: context.appColors.divider,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(wechatStatusPhotoBorderRadius),
      ),
      child: SizedBox.expand(child: image),
    );
  }
}

/// Returns the bounded display size for a WeChat-style single status image.
///
/// Images with ratios outside 1:3 through 3:1 use the nearest limit. The
/// rendered image uses [BoxFit.cover], so extreme ratios and the minimum short
/// edge can center-crop the source. The short edge is kept at least 70 logical
/// pixels.
@visibleForTesting
Size wechatStatusPhotoDisplaySize({required Size imageSize}) {
  final sourceAspectRatio =
      imageSize.width > 0 &&
          imageSize.height > 0 &&
          imageSize.width.isFinite &&
          imageSize.height.isFinite
      ? imageSize.width / imageSize.height
      : 4 / 3;
  final boundedAspectRatio = sourceAspectRatio.clamp(1 / 3, 3).toDouble();

  final widthFromMaxHeight = wechatStatusPhotoMaxHeight * boundedAspectRatio;
  final size = widthFromMaxHeight <= wechatStatusPhotoMaxWidth
      ? Size(widthFromMaxHeight, wechatStatusPhotoMaxHeight)
      : Size(
          wechatStatusPhotoMaxWidth,
          wechatStatusPhotoMaxWidth / boundedAspectRatio,
        );

  return Size(
    size.width.clamp(
      wechatStatusPhotoMinExtent,
      wechatStatusPhotoMaxWidth,
    ),
    size.height.clamp(
      wechatStatusPhotoMinExtent,
      wechatStatusPhotoMaxHeight,
    ),
  );
}
