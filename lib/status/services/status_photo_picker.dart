import 'package:dan/status/models/status_composer_photo.dart';

/// Selects a single local photo through the platform picker.
// Kept as an interface to inject and mock this platform boundary.
abstract interface class StatusPhotoPicker {
  /// Returns null if the user cancels.
  Future<StatusComposerPhoto?> pickPhoto();
}

/// A sanitized platform or file-read failure.
final class StatusPhotoPickFailure implements Exception {
  /// Creates a photo selection failure.
  const new();
}
