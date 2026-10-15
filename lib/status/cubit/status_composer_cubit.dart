import 'package:bloc/bloc.dart';
import 'package:characters/characters.dart';
import 'package:dan/status/models/status_composer_photo.dart';
import 'package:dan/status/services/status_photo_picker.dart';
import 'package:equatable/equatable.dart';
import 'package:status_repository/status_repository.dart';

part 'status_composer_state.dart';

/// Coordinates composing and publishing a new status.
class StatusComposerCubit extends Cubit<StatusComposerState> {
  /// Creates a status composer cubit.
  factory StatusComposerCubit({
    required StatusRepository statusRepository,
    required StatusPhotoPicker photoPicker,
    String initialContent = '',
    StatusDraftRepository? draftRepository,
    String? accountId,
    String? inReplyToStatusId,
    String? repostStatusId,
  }) {
    return StatusComposerCubit._(
      statusRepository,
      photoPicker,
      initialContent,
      inReplyToStatusId,
      repostStatusId,
      draftRepository,
      accountId,
    );
  }

  StatusComposerCubit._(
    this._statusRepository,
    this._photoPicker,
    String initialContent,
    this._inReplyToStatusId,
    this._repostStatusId,
    this._draftRepository,
    this._accountId,
  ) : super(StatusComposerState(content: initialContent));

  final StatusRepository _statusRepository;
  final StatusPhotoPicker _photoPicker;
  final String? _inReplyToStatusId;
  final String? _repostStatusId;
  final StatusDraftRepository? _draftRepository;
  final String? _accountId;
  bool _draftLoadFailed = false;

  bool get _supportsDraft =>
      _draftRepository != null &&
      _accountId != null &&
      _inReplyToStatusId == null &&
      _repostStatusId == null;

  /// Restores an original status before the form becomes editable.
  Future<void> restoreDraft() async {
    if (!_supportsDraft || state.isBusy) return;
    emit(state.copyWith(draftStatus: StatusDraftStatus.loading));
    try {
      final draft = await _draftRepository!.load(_accountId!);
      _draftLoadFailed = false;
      if (isClosed) return;
      emit(
        state.copyWith(
          content: draft?.content,
          photo: draft?.photoBytes == null
              ? null
              : StatusComposerPhoto(
                  path: draft!.photoPath!,
                  bytes: draft.photoBytes!,
                ),
          draftStatus: StatusDraftStatus.restored,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      _draftLoadFailed = true;
      emit(state.copyWith(draftStatus: StatusDraftStatus.failure));
    }
  }

  /// Persists or discards the original draft before leaving the composer.
  Future<void> finishDraft({required bool keep}) async {
    if (!_supportsDraft || (_draftLoadFailed && !state.hasContent)) return;
    if (state.isBusy) throw StateError('The composer is busy.');
    emit(state.copyWith(draftStatus: StatusDraftStatus.saving));
    try {
      if (keep && state.hasContent) {
        await _draftRepository!.save(
          _accountId!,
          StatusDraft(
            content: state.content,
            photoPath: state.photo?.path,
            photoBytes: state.photo?.bytes,
          ),
        );
      } else {
        await _draftRepository!.clear(_accountId!);
      }
      if (!isClosed) emit(state.copyWith(draftStatus: StatusDraftStatus.idle));
    } on Object catch (error, stackTrace) {
      if (!isClosed) {
        addError(error, stackTrace);
        emit(state.copyWith(draftStatus: StatusDraftStatus.idle));
      }
      rethrow;
    }
  }

  /// Updates the draft text.
  void contentChanged(String content) {
    if (state.submissionStatus == StatusComposerSubmissionStatus.inProgress ||
        state.draftStatus == StatusDraftStatus.loading ||
        state.draftStatus == StatusDraftStatus.saving) {
      return;
    }
    emit(
      state.copyWith(
        content: content,
        submissionStatus: StatusComposerSubmissionStatus.initial,
        photoSelectionStatus:
            state.photoSelectionStatus == StatusPhotoSelectionStatus.failure ||
                state.photoSelectionStatus ==
                    StatusPhotoSelectionStatus.unsupportedFormat
            ? StatusPhotoSelectionStatus.idle
            : state.photoSelectionStatus,
      ),
    );
  }

  /// Selects one photo while preserving the text and any previous selection.
  Future<void> pickPhoto() async {
    if (_inReplyToStatusId != null || _repostStatusId != null || state.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        photoSelectionStatus: StatusPhotoSelectionStatus.picking,
        submissionStatus: StatusComposerSubmissionStatus.initial,
      ),
    );
    try {
      final photo = await _photoPicker.pickPhoto();
      if (isClosed) return;
      emit(
        state.copyWith(
          photo: photo,
          photoSelectionStatus: StatusPhotoSelectionStatus.idle,
          submissionStatus: StatusComposerSubmissionStatus.initial,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          photoSelectionStatus: error is StatusRepositoryPhotoFormatFailure
              ? StatusPhotoSelectionStatus.unsupportedFormat
              : StatusPhotoSelectionStatus.failure,
        ),
      );
    }
  }

  /// Removes the attachment without discarding the draft text.
  void removePhoto() {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        clearPhoto: true,
        photoSelectionStatus: StatusPhotoSelectionStatus.idle,
        submissionStatus: StatusComposerSubmissionStatus.initial,
      ),
    );
  }

  /// Publishes the current draft when it contains text or a photo.
  Future<void> publish() async {
    if (!state.canPublish) return;
    final content = state.content.trim();
    emit(
      state.copyWith(
        submissionStatus: StatusComposerSubmissionStatus.inProgress,
        photoSelectionStatus: StatusPhotoSelectionStatus.idle,
      ),
    );
    try {
      if (state.photo case final photo?) {
        await _statusRepository.createPhotoStatus(
          photoPath: photo.path,
          text: content,
        );
      } else {
        await _statusRepository.createStatus(
          content,
          inReplyToStatusId: _inReplyToStatusId,
          repostStatusId: _repostStatusId,
        );
      }
      if (_supportsDraft) {
        try {
          await _draftRepository!.clear(_accountId!);
        } on Object catch (error, stackTrace) {
          // The server accepted the post; never invite a duplicate submission.
          addError(error, stackTrace);
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          submissionStatus: StatusComposerSubmissionStatus.success,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          submissionStatus: error is StatusRepositoryPhotoFormatFailure
              ? StatusComposerSubmissionStatus.unsupportedPhotoFormat
              : StatusComposerSubmissionStatus.failure,
          failureMessage: error is StatusRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }
}
