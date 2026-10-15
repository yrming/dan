import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A locally selected photo and its preview bytes.
final class StatusComposerPhoto extends Equatable {
  /// Copies [bytes] so the selected photo remains immutable.
  StatusComposerPhoto({required this.path, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  /// Local file passed to the upload endpoint.
  final String path;

  /// Bytes used to render the preview without widget-level file access.
  final Uint8List bytes;

  @override
  List<Object> get props => [path, bytes];
}
