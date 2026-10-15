import 'package:status_repository/src/exceptions/exceptions.dart';

/// Formats accepted by Fanfou's photo upload endpoint.
enum StatusPhotoFormat {
  /// JPEG, with either a jpg or jpeg filename extension.
  jpeg,

  /// PNG.
  png,

  /// GIF, including animated images.
  gif;

  /// Validates the extension and file signature rather than MIME metadata.
  static StatusPhotoFormat detect(String path, List<int> header) {
    final name = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    final extension = name.split('.').last;
    bool startsWith(List<int> signature) =>
        header.length >= signature.length &&
        Iterable<int>.generate(signature.length).every(
          (index) => header[index] == signature[index],
        );

    if ((extension == 'jpg' || extension == 'jpeg') &&
        startsWith([0xff, 0xd8, 0xff])) {
      return jpeg;
    }
    if (extension == 'png' &&
        startsWith([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return png;
    }
    if (extension == 'gif' &&
        (startsWith('GIF87a'.codeUnits) || startsWith('GIF89a'.codeUnits))) {
      return gif;
    }
    throw const StatusRepositoryPhotoFormatFailure();
  }
}
