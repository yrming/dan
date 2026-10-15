import 'package:bloc/bloc.dart';
import 'package:dan/status/services/status_image_actions_service.dart';
import 'package:equatable/equatable.dart';

part 'status_image_viewer_state.dart';

/// Performs share and gallery-save actions for the viewed status image.
class StatusImageViewerCubit extends Cubit<StatusImageViewerState> {
  /// Creates a status image viewer cubit.
  StatusImageViewerCubit({required this._imageActionsService})
    : super(const StatusImageViewerState());

  final StatusImageActionsService _imageActionsService;

  /// Shares the viewed image through the system share sheet.
  Future<void> shareRequested(String imageUrl) async {
    if (_shouldIgnoreRequest(imageUrl)) return;

    try {
      await _imageActionsService.share(imageUrl);
    } on Object {
      emit(
        state.copyWith(
          action: StatusImageViewerAction.share,
          status: StatusImageViewerActionStatus.failure,
        ),
      );
    }
  }

  /// Saves the viewed image into the device photo gallery.
  Future<void> saveToGalleryRequested(String imageUrl) async {
    if (_shouldIgnoreRequest(imageUrl)) return;

    emit(
      state.copyWith(
        action: StatusImageViewerAction.save,
        status: StatusImageViewerActionStatus.inProgress,
      ),
    );
    try {
      await _imageActionsService.saveToGallery(imageUrl);
      emit(
        state.copyWith(
          action: StatusImageViewerAction.save,
          status: StatusImageViewerActionStatus.success,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          action: StatusImageViewerAction.save,
          status: StatusImageViewerActionStatus.failure,
        ),
      );
    }
  }

  /// Ignores blank URLs and requests while another action is still running.
  bool _shouldIgnoreRequest(String imageUrl) {
    return imageUrl.trim().isEmpty || state.isBusy;
  }
}
