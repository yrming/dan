import 'package:status_repository/status_repository.dart';

/// Snapshot of the loaded album photos, in their displayed order.
class StatusImageGallery {
  /// Creates an immutable gallery containing only statuses with photos.
  StatusImageGallery({required Iterable<Status> statuses})
    : statuses = List.unmodifiable(
        statuses.where((status) => status.photo != null),
      );

  /// Photo statuses available when the viewer was opened.
  final List<Status> statuses;

  /// Returns a loaded status matching a route's selected photo.
  Status? statusFor(String? statusId) =>
      statuses.where((status) => status.id == statusId).firstOrNull;
}
