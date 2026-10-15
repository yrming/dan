import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Displays a circular user avatar with persistent network image caching.
class UserAvatar extends StatelessWidget {
  /// Creates a user avatar.
  const UserAvatar({
    required this.imageUrl,
    required this.size,
    this.semanticLabel,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1,
    super.key,
  }) : assert(size > 0, 'Avatar size must be greater than zero.'),
       assert(borderWidth >= 0, 'Avatar border width cannot be negative.');

  /// URL of the avatar image, or `null` when no image is available.
  final String? imageUrl;

  /// Logical width and height of the avatar.
  final double size;

  /// Accessible name for a meaningful avatar.
  ///
  /// When omitted or empty, the avatar is treated as decorative.
  final String? semanticLabel;

  /// Optional rounded-rectangle radius. When omitted, the avatar is circular.
  final BorderRadius? borderRadius;

  /// Optional avatar border color.
  final Color? borderColor;

  /// Avatar border width. A value of zero renders a device-pixel hairline.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl?.trim();
    final hasImage =
        normalizedImageUrl != null && normalizedImageUrl.isNotEmpty;
    final cacheDimension = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final normalizedSemanticLabel = semanticLabel?.trim();

    const fallback = SizedBox.expand();
    final image = hasImage
        ? CachedNetworkImage(
            imageUrl: normalizedImageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: cacheDimension,
            memCacheHeight: cacheDimension,
            maxWidthDiskCache: cacheDimension,
            maxHeightDiskCache: cacheDimension,
            fadeInDuration: disableAnimations
                ? Duration.zero
                : Durations.short2,
            fadeOutDuration: disableAnimations
                ? Duration.zero
                : Durations.short2,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          )
        : fallback;
    final imageBackground = ColoredBox(
      color: context.appColors.groupedBackground,
      child: image,
    );
    final clippedImage = borderRadius == null
        ? ClipOval(child: imageBackground)
        : ClipRRect(borderRadius: borderRadius!, child: imageBackground);
    final borderedImage = borderColor == null
        ? clippedImage
        : Container(
            foregroundDecoration: BoxDecoration(
              shape: borderRadius == null
                  ? BoxShape.circle
                  : BoxShape.rectangle,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor!, width: borderWidth),
            ),
            child: clippedImage,
          );
    final avatar = SizedBox.square(
      dimension: size,
      child: borderedImage,
    );

    if (normalizedSemanticLabel == null || normalizedSemanticLabel.isEmpty) {
      return ExcludeSemantics(child: avatar);
    }

    return Semantics(
      image: true,
      label: normalizedSemanticLabel,
      excludeSemantics: true,
      child: avatar,
    );
  }
}
