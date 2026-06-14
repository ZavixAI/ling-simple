import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class PrivateAssetCacheStore {
  Future<int> sizeBytes();
  Future<void> clear();
}

class DefaultPrivateAssetCacheStore implements PrivateAssetCacheStore {
  const DefaultPrivateAssetCacheStore();

  static const String _defaultCacheManagerKey = 'libCachedImageData';

  @override
  Future<int> sizeBytes() async {
    final directory = await _defaultCacheDirectory();
    return _directorySizeBytes(directory);
  }

  @override
  Future<void> clear() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await DefaultCacheManager().emptyCache();
    await _deleteDefaultCacheDirectory();
  }

  Future<Directory> _defaultCacheDirectory() async {
    final directory = await getTemporaryDirectory();
    return Directory('${directory.path}/$_defaultCacheManagerKey');
  }

  Future<int> _directorySizeBytes(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // File may disappear while the cache manager is trimming entries.
        }
      }
    }
    return total;
  }

  Future<void> _deleteDefaultCacheDirectory() async {
    final directory = await _defaultCacheDirectory();
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      if (await directory.exists()) {
        rethrow;
      }
    }
  }
}
