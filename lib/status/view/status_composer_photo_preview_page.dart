import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/models/status_composer_photo.dart';
import 'package:dan/status/view/status_image_viewer_page.dart';
import 'package:flutter/material.dart';

/// Full-screen preview of a photo selected for a draft.
class StatusComposerPhotoPreviewPage extends StatelessWidget {
  const StatusComposerPhotoPreviewPage({
    required this.photo,
    required this.heroTag,
    super.key,
  });

  final StatusComposerPhoto photo;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return StatusImageViewerView.local(
      key: const Key('status-composer-photo-fullscreen'),
      imageProvider: MemoryImage(photo.bytes),
      heroTag: heroTag,
      semanticLabel: context.l10n.statusComposerPreviewPhotoLabel,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
