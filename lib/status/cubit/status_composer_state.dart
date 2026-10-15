part of 'status_composer_cubit.dart';

/// Lifecycle of the system photo picker.
enum StatusPhotoSelectionStatus { idle, picking, failure, unsupportedFormat }

/// Lifecycle of local draft operations.
enum StatusDraftStatus { idle, loading, restored, saving, failure }

/// Status composer submission status.
enum StatusComposerSubmissionStatus {
  /// No submission has been requested.
  initial,

  /// A submission is in progress.
  inProgress,

  /// The status was published successfully.
  success,

  /// The status could not be published.
  failure,

  /// The attachment is not a supported photo format.
  unsupportedPhotoFormat,
}

/// Immutable state for the status composer.
final class StatusComposerState extends Equatable {
  /// Creates a status composer state.
  const StatusComposerState({
    this.content = '',
    this.draftStatus = StatusDraftStatus.idle,
    this.submissionStatus = StatusComposerSubmissionStatus.initial,
    this.photo,
    this.photoSelectionStatus = StatusPhotoSelectionStatus.idle,
    this.failureMessage,
  });

  /// Current draft text.
  final String content;

  /// Current local draft operation.
  final StatusDraftStatus draftStatus;

  /// Whether there is text or an attachment to preserve.
  bool get hasContent => content.trim().isNotEmpty || photo != null;

  /// Maximum number of user-perceived characters in a status.
  static const maximumCharacterCount = 140;

  /// Remaining characters, negative when the draft exceeds the limit.
  int get remainingCharacters =>
      maximumCharacterCount - content.characters.length;

  /// Current submission lifecycle status.
  final StatusComposerSubmissionStatus submissionStatus;

  /// Optional attachment for a new status.
  final StatusComposerPhoto? photo;

  /// Whether selection is running or has failed.
  final StatusPhotoSelectionStatus photoSelectionStatus;

  final String? failureMessage;

  /// Blocks competing selection, removal, or submission operations.
  bool get isBusy =>
      draftStatus == StatusDraftStatus.loading ||
      draftStatus == StatusDraftStatus.saving ||
      photoSelectionStatus == StatusPhotoSelectionStatus.picking ||
      submissionStatus == StatusComposerSubmissionStatus.inProgress;

  /// Whether the draft can be submitted now.
  bool get canPublish =>
      (content.trim().isNotEmpty || photo != null) &&
      remainingCharacters >= 0 &&
      !isBusy;

  /// Returns a copy with updated fields.
  StatusComposerState copyWith({
    String? content,
    StatusDraftStatus? draftStatus,
    StatusComposerSubmissionStatus? submissionStatus,
    StatusComposerPhoto? photo,
    bool clearPhoto = false,
    StatusPhotoSelectionStatus? photoSelectionStatus,
    Object? failureMessage = _unset,
  }) {
    return StatusComposerState(
      content: content ?? this.content,
      draftStatus: draftStatus ?? this.draftStatus,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      photo: clearPhoto ? null : photo ?? this.photo,
      photoSelectionStatus: photoSelectionStatus ?? this.photoSelectionStatus,
      failureMessage: failureMessage == _unset
          ? this.failureMessage
          : failureMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    content,
    draftStatus,
    submissionStatus,
    photo,
    photoSelectionStatus,
    failureMessage,
  ];
}

const _unset = Object();
