import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:status_repository/src/exceptions/exceptions.dart';
import 'package:status_repository/src/status_photo_format.dart';

/// Prepares an upload without changing the original photo.
class StatusPhotoUploadPreparer {
  /// Uses Fanfou's 4 MiB photo limit and 3 MiB GIF limit by default.
  const StatusPhotoUploadPreparer({
    this.maxBytes = 4194304,
    this.maxGifBytes = 3145728,
  }) : assert(maxBytes > 0, 'The upload limit must be positive.'),
       assert(maxGifBytes > 0, 'The GIF upload limit must be positive.');

  /// Maximum number of bytes sent to the photo endpoint.
  final int maxBytes;

  /// Maximum encoded GIF size, in bytes.
  final int maxGifBytes;

  /// Keeps small files intact and compresses larger files off the main isolate.
  Future<PreparedStatusPhoto> prepare(File source) async {
    Directory? temporaryDirectory;
    try {
      final length = await source.length();
      if (length == 0) throw const StatusRepositoryPhotoPreparationFailure();
      final handle = await source.open();
      final StatusPhotoFormat format;
      try {
        format = StatusPhotoFormat.detect(source.path, await handle.read(12));
      } finally {
        await handle.close();
      }
      final limit = format == StatusPhotoFormat.gif ? maxGifBytes : maxBytes;
      if (length <= limit) return PreparedStatusPhoto(file: source);

      final path = source.path;
      final bytes = await Isolate.run(() => _compress(path, limit, format));
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'dan-status-photo-',
      );
      final extension = format == StatusPhotoFormat.gif ? 'gif' : 'jpg';
      final file = File('${temporaryDirectory.path}/upload.$extension');
      await file.writeAsBytes(bytes, flush: true);
      return PreparedStatusPhoto(
        file: file,
        temporaryDirectory: temporaryDirectory,
      );
    } on StatusRepositoryPhotoFormatFailure {
      rethrow;
    } on Object {
      if (temporaryDirectory != null) {
        await _removeTemporaryDirectory(temporaryDirectory);
      }
      throw const StatusRepositoryPhotoPreparationFailure();
    }
  }
}

/// An upload file and the temporary resources it owns, if any.
class PreparedStatusPhoto {
  /// Creates a prepared photo. Original files do not own temporary resources.
  const PreparedStatusPhoto({required this.file, this.temporaryDirectory});

  /// File ready to upload.
  final File file;

  /// Directory owned by this upload, never the original photo directory.
  final Directory? temporaryDirectory;

  /// Removes only the temporary upload copy.
  Future<void> dispose() async {
    if (temporaryDirectory case final directory?) {
      await _removeTemporaryDirectory(directory);
    }
  }
}

Future<void> _removeTemporaryDirectory(Directory directory) async {
  try {
    await directory.delete(recursive: true);
  } on FileSystemException {
    // Cache cleanup must not turn a successful upload into a failed submission.
  }
}

Future<Uint8List> _compress(
  String path,
  int maxBytes,
  StatusPhotoFormat format,
) async {
  final decoded = image.decodeImage(await File(path).readAsBytes());
  if (decoded == null) throw const StatusRepositoryPhotoPreparationFailure();
  if (format == StatusPhotoFormat.gif) {
    var animation = decoded;
    while (true) {
      final bytes = image.encodeGif(animation);
      if (bytes.length <= maxBytes) return bytes;
      if (animation.width == 1 && animation.height == 1) {
        throw const StatusRepositoryPhotoPreparationFailure();
      }
      animation = _shrink(animation);
    }
  }
  final oriented = image.bakeOrientation(decoded);
  // Flatten transparency onto white and omit metadata from the upload copy.
  var photo = image.Image(width: oriented.width, height: oriented.height);
  image.fill(photo, color: image.ColorRgb8(255, 255, 255));
  image.compositeImage(photo, oriented);

  while (true) {
    for (final quality in [90, 80, 70, 60]) {
      final bytes = image.encodeJpg(photo, quality: quality);
      if (bytes.length <= maxBytes) return bytes;
    }
    if (photo.width == 1 && photo.height == 1) {
      throw const StatusRepositoryPhotoPreparationFailure();
    }
    photo = _shrink(photo);
  }
}

image.Image _shrink(image.Image photo) => image.copyResize(
  photo,
  width: math.max(1, (photo.width * 0.8).floor()),
  height: math.max(1, (photo.height * 0.8).floor()),
  interpolation: image.Interpolation.average,
);
