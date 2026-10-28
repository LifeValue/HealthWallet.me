import 'dart:io';

import 'package:flutter/services.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';

/// Keeps access to folders the user chose outside the app's own storage.
///
/// The macOS app is sandboxed: it may use a folder the user picked only for
/// the rest of that run. A security-scoped bookmark, saved when the folder is
/// chosen and resolved after a restart, gives the access back. Other
/// platforms have no sandbox, so there every call is a no-op.
@lazySingleton
class FolderAccessService {
  FolderAccessService({
    @ignoreParam MethodChannel? channel,
    @ignoreParam bool? usesBookmarks,
  }) : _channel =
           channel ?? const MethodChannel('dev.lifevalue.healthwallet/fs'),
       _usesBookmarks = usesBookmarks ?? Platform.isMacOS;

  final MethodChannel _channel;
  final bool _usesBookmarks;

  /// A bookmark for [path], to save next to it, or null when the platform
  /// needs none or it could not be made.
  Future<String?> bookmarkFor(String path) async {
    if (!_usesBookmarks) return null;
    try {
      return await _channel.invokeMethod<String>('createBookmark', {
        'path': path,
      });
    } on PlatformException catch (e) {
      logger.w('No bookmark for the chosen folder', e);
      return null;
    } on MissingPluginException catch (e) {
      logger.w('No bookmark for the chosen folder', e);
      return null;
    }
  }

  /// Opens the folder saved as [bookmark] for this run. Returns the bookmark to
  /// keep from now on: a refreshed one when macOS marked it stale, otherwise
  /// [bookmark]. Returns null when the access could not be restored.
  Future<String?> restore(String bookmark) async {
    if (!_usesBookmarks) return bookmark;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'resolveBookmark',
        {'bookmark': bookmark},
      );
      if (result == null || result['granted'] != true) return null;
      return result['bookmark'] as String? ?? bookmark;
    } on PlatformException catch (e) {
      logger.w('Access to the saved folder could not be restored', e);
      return null;
    } on MissingPluginException catch (e) {
      logger.w('Access to the saved folder could not be restored', e);
      return null;
    }
  }
}
