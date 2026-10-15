import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Minimum width and height of an X-style single status image.
const xStatusPhotoMinExtent = 100.0;

/// Widest uncropped X-style image ratio: 16:9.
const double xStatusPhotoMaxAspectRatio = 16 / 9;

/// Tallest uncropped X-style image ratio: 3:4.
const double xStatusPhotoMinAspectRatio = 3 / 4;

/// Corner radius of an X-style single status image.
const xStatusPhotoBorderRadius = 16.0;

/// Builds the X-style width-filling single-image status photo presentation.
class XStatusPhoto extends StatelessWidget {
  /// Creates an X-style status photo presentation.
  const XStatusPhoto({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = _xStatusPhotoLayout(
          imageSize: sourceImageSize,
          availableWidth: availableWidth,
        );
        final image = imageBuilder(
          layout.displaySize,
          layout.fit,
          layout.alignment,
        );

        return Align(
          alignment: Alignment.topLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            width: layout.displaySize.width,
            height: layout.displaySize.height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(xStatusPhotoBorderRadius),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: context.appColors.divider,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(xStatusPhotoBorderRadius),
            ),
            child: SizedBox.expand(child: image),
          ),
        );
      },
    );
  }
}

({Size displaySize, BoxFit fit, Alignment alignment}) _xStatusPhotoLayout({
  required Size imageSize,
  required double availableWidth,
}) {
  final sourceAspectRatio =
      imageSize.width > 0 &&
          imageSize.height > 0 &&
          imageSize.width.isFinite &&
          imageSize.height.isFinite
      ? imageSize.width / imageSize.height
      : 4 / 3;
  final boundedAspectRatio = sourceAspectRatio.clamp(
    xStatusPhotoMinAspectRatio,
    xStatusPhotoMaxAspectRatio,
  );
  final displayWidth = availableWidth > 0 && availableWidth.isFinite
      ? availableWidth
      : xStatusPhotoMinExtent;
  final proportionalHeight = displayWidth / boundedAspectRatio;
  final displayHeight = proportionalHeight < xStatusPhotoMinExtent
      ? xStatusPhotoMinExtent
      : proportionalHeight;
  final displaySize = Size(displayWidth, displayHeight);
  final preservesSourceRatio =
      sourceAspectRatio >= xStatusPhotoMinAspectRatio &&
      sourceAspectRatio <= xStatusPhotoMaxAspectRatio &&
      (displaySize.aspectRatio - sourceAspectRatio).abs() < 0.000001;

  return (
    displaySize: displaySize,
    fit: preservesSourceRatio ? BoxFit.fitWidth : BoxFit.cover,
    alignment: sourceAspectRatio < xStatusPhotoMinAspectRatio
        ? Alignment.topCenter
        : Alignment.center,
  );
}
