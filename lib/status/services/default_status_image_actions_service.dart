import 'package:dan/status/services/status_image_actions_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Default [StatusImageActionsService] backed by the system share sheet and
/// the device photo gallery.
///
/// Images are resolved through [CacheManager], so an image already loaded by
/// the viewer is shared or saved without being downloaded again.
class DefaultStatusImageActionsService implements StatusImageActionsService {
  /// Creates a status image actions service.
  ///
  /// Pass a custom [cacheManager] in tests; defaults to
  /// [DefaultCacheManager], which is also what the viewer's image provider
  /// uses.
  DefaultStatusImageActionsService({CacheManager? cacheManager})
    : _cacheManager = cacheManager ?? DefaultCacheManager();

  final CacheManager _cacheManager;

  @override
  Future<void> share(String imageUrl) async {
    try {
      final file = await _cacheManager.getSingleFile(imageUrl);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } on Object {
      throw const StatusImageShareFailure();
    }
  }

  @override
  Future<void> saveToGallery(String imageUrl) async {
    try {
      final file = await _cacheManager.getSingleFile(imageUrl);
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) throw const StatusImageGallerySaveFailure();
      }
      await Gal.putImage(file.path);
    } on StatusImageActionFailure {
      rethrow;
    } on Object {
      throw const StatusImageGallerySaveFailure();
    }
  }
}
