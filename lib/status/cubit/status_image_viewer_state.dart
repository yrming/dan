part of 'status_image_viewer_cubit.dart';

/// The image action a viewer state refers to.
enum StatusImageViewerAction { share, save }

/// The lifecycle of the latest viewer image action.
enum StatusImageViewerActionStatus { idle, inProgress, success, failure }

/// Holds the outcome of the latest share or gallery-save action.
class StatusImageViewerState extends Equatable {
  /// Creates a status image viewer state.
  const StatusImageViewerState({
    this.action,
    this.status = StatusImageViewerActionStatus.idle,
  });

  /// The action this state refers to, or null while [status] is idle.
  final StatusImageViewerAction? action;

  /// The lifecycle of the latest action.
  final StatusImageViewerActionStatus status;

  /// Whether another gallery save or share is still running.
  bool get isBusy => status == StatusImageViewerActionStatus.inProgress;

  /// Returns a copy of this state with the given fields replaced.
  StatusImageViewerState copyWith({
    StatusImageViewerAction? action,
    StatusImageViewerActionStatus? status,
  }) {
    return StatusImageViewerState(
      action: action ?? this.action,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [action, status];
}
