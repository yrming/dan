import 'package:equatable/equatable.dart';
import 'package:status_repository/src/models/status.dart';

/// Account-scoped status mutation published by the status repository.
sealed class StatusChange extends Equatable {
  /// Creates a status change.
  const StatusChange({required this.accountId});

  /// Account whose data changed.
  final String accountId;

  /// Stable identifier of the changed status.
  String get statusId;

  @override
  List<Object?> get props => [accountId];
}

/// A status was created successfully.
final class StatusCreated extends StatusChange {
  /// Creates a status creation change.
  const StatusCreated({required super.accountId, required this.status});

  /// Newly created domain value returned by Fanfou.
  final Status status;

  @override
  String get statusId => status.id;

  @override
  List<Object?> get props => [...super.props, status];
}

/// A status was deleted successfully.
final class StatusDeleted extends StatusChange {
  /// Creates a deletion change.
  const StatusDeleted({required super.accountId, required this.statusId});

  @override
  final String statusId;

  @override
  List<Object?> get props => [...super.props, statusId];
}

/// A status was updated successfully.
final class StatusUpdated extends StatusChange {
  /// Creates an update change.
  const StatusUpdated({required super.accountId, required this.status});

  /// Latest domain value returned by Fanfou.
  final Status status;

  @override
  String get statusId => status.id;

  @override
  List<Object?> get props => [...super.props, status];
}
