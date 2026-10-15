import 'package:dan/status/models/status_composer_photo.dart';
import 'package:dan/status/services/status_photo_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:status_repository/status_repository.dart';

/// Opens the system gallery without requesting full photo metadata.
class DefaultStatusPhotoPicker implements StatusPhotoPicker {
  /// Creates a picker with an injectable platform implementation.
  DefaultStatusPhotoPicker(this._imagePicker);

  final ImagePicker _imagePicker;

  @override
  Future<StatusComposerPhoto?> pickPhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw const StatusPhotoPickFailure();
      StatusPhotoFormat.detect(file.path, bytes);
      return StatusComposerPhoto(path: file.path, bytes: bytes);
    } on StatusRepositoryPhotoFormatFailure {
      rethrow;
    } on Object {
      throw const StatusPhotoPickFailure();
    }
  }
}
