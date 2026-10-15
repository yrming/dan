import 'package:equatable/equatable.dart';

/// Photo URLs attached to a Fanfou status.
///
/// Fanfou exposes three different sizes for a status photo. The repository
/// keeps all of them so presentation can choose the best URL for each context
/// without depending on the external API field names.
final class StatusPhotoUrls extends Equatable {
  /// Creates status photo URLs.
  const StatusPhotoUrls({
    this.thumbnailUrl,
    this.imageUrl,
    this.largeUrl,
  }) : assert(
         thumbnailUrl != null || imageUrl != null || largeUrl != null,
         'At least one photo URL must be provided.',
       );

  /// Thumbnail URL, usually best for compact list previews.
  final String? thumbnailUrl;

  /// Regular image URL, usually best for inline detail display.
  final String? imageUrl;

  /// Largest image URL, usually best for full-screen image viewing.
  final String? largeUrl;

  /// Best URL for compact previews.
  String get previewUrl => _requireUrl(thumbnailUrl ?? imageUrl ?? largeUrl);

  /// Best URL for inline display.
  String get displayUrl => _requireUrl(imageUrl ?? largeUrl ?? thumbnailUrl);

  /// Best URL for full-screen viewing.
  String get viewerUrl => _requireUrl(largeUrl ?? imageUrl ?? thumbnailUrl);

  @override
  List<Object?> get props => [thumbnailUrl, imageUrl, largeUrl];
}

String _requireUrl(String? url) {
  if (url == null) {
    throw StateError('At least one photo URL must be provided.');
  }
  return url;
}
