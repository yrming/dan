/// Shares or saves status images through platform integrations.
abstract interface class StatusImageActionsService {
  /// Opens the system share sheet for the image at [imageUrl].
  Future<void> share(String imageUrl);

  /// Saves the image at [imageUrl] into the device photo gallery.
  Future<void> saveToGallery(String imageUrl);
}

/// Base type for sanitized status image action failures.
sealed class StatusImageActionFailure implements Exception {
  const StatusImageActionFailure();
}

/// Thrown when the status image cannot be shared.
final class StatusImageShareFailure extends StatusImageActionFailure {
  /// Creates a sanitized share failure.
  const StatusImageShareFailure();
}

/// Thrown when the status image cannot be saved to the gallery.
final class StatusImageGallerySaveFailure extends StatusImageActionFailure {
  /// Creates a sanitized gallery save failure.
  const StatusImageGallerySaveFailure();
}
