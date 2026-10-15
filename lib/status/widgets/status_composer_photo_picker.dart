import 'package:dan/app/theme/theme.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/models/status_composer_photo.dart';
import 'package:dan/status/view/status_composer_photo_preview_page.dart';
import 'package:dan/status/widgets/x_status_photo.dart';
import 'package:flutter/material.dart';

/// A selected attachment with preview and removal actions.
class StatusComposerPhotoPicker extends StatefulWidget {
  const StatusComposerPhotoPicker({
    required this.photo,
    required this.isBusy,
    required this.onRemove,
    super.key,
  });

  final StatusComposerPhoto photo;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  State<StatusComposerPhotoPicker> createState() =>
      _StatusComposerPhotoPickerState();
}

class _StatusComposerPhotoPickerState extends State<StatusComposerPhotoPicker> {
  final String _heroTag = 'status-composer-photo-${UniqueKey()}';
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant StatusComposerPhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.photo.bytes, widget.photo.bytes)) {
      _imageSize = null;
      _resolveImage();
    }
  }

  void _resolveImage() {
    _removeImageListener();
    final stream = MemoryImage(
      widget.photo.bytes,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        info.dispose();
        if (!mounted || _imageSize == size) return;
        setState(() => _imageSize = size);
      },
      // Image.memory below renders the failure state.
      onError: (_, _) {},
    );
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final listener = _imageListener;
    if (listener != null) _imageStream?.removeListener(listener);
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return XStatusPhoto(
      sourceImageSize: _imageSize ?? const Size(4, 3),
      backgroundColor: context.appColors.groupedBackground,
      imageBuilder: (displaySize, fit, alignment) => Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: context.appColors.groupedBackground,
            child: Semantics(
              label: context.l10n.statusComposerPreviewPhotoLabel,
              button: true,
              enabled: !widget.isBusy,
              child: InkWell(
                key: const Key('status-composer-photo-attachment'),
                onTap: widget.isBusy
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            opaque: false,
                            pageBuilder: (_, _, _) =>
                                StatusComposerPhotoPreviewPage(
                                  photo: photo,
                                  heroTag: _heroTag,
                                ),
                            transitionsBuilder: (_, animation, _, child) =>
                                FadeTransition(
                                  opacity: animation.drive(
                                    CurveTween(curve: Easing.standard),
                                  ),
                                  child: child,
                                ),
                          ),
                        );
                      },
                child: Hero(
                  tag: _heroTag,
                  placeholderBuilder: (_, _, child) => child,
                  child: Image.memory(
                    photo.bytes,
                    key: const Key('status-composer-photo-preview'),
                    width: displaySize.width,
                    height: displaySize.height,
                    fit: fit,
                    alignment: alignment,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IconButton.filled(
              key: const Key('status-composer-remove-photo'),
              tooltip: context.l10n.statusComposerRemovePhotoLabel,
              onPressed: widget.isBusy ? null : widget.onRemove,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black26,
                disabledForegroundColor: Colors.white54,
              ),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
