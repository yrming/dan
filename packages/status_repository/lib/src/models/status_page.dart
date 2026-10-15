import 'package:equatable/equatable.dart';
import 'package:status_repository/src/models/status.dart';

/// One immutable page of statuses returned by the repository.
final class StatusPage extends Equatable {
  /// Creates a status page.
  StatusPage({
    required Iterable<Status> statuses,
    required this.hasMore,
    this.nextCursor,
  }) : statuses = List<Status>.unmodifiable(statuses);

  /// Statuses in API order.
  final List<Status> statuses;

  /// Whether another page may be available.
  final bool hasMore;

  /// Opaque cursor to return to the same repository method.
  final String? nextCursor;

  @override
  List<Object?> get props => [statuses, hasMore, nextCursor];
}
