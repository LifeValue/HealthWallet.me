import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';

@lazySingleton
class ShareIntentService {
  final ExternalFilesService _externalFileService;
  final AppRouter _router;
  final PageViewNavigationController _navigationController;

  ShareIntentService(
      this._externalFileService, this._router, this._navigationController);

  StreamSubscription? _intentSub;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (sharedFiles) async {
        if (sharedFiles.isNotEmpty) {
          await _processSharedFiles(sharedFiles);
        }
      },
      onError: (err) {
        logger.e('Error receiving shared files: $err');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((sharedFiles) async {
      if (sharedFiles.isNotEmpty) {
        await _processSharedFiles(sharedFiles);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  Future<void> _processSharedFiles(List<SharedMediaFile> sharedFiles) async {
    try {
      final List<String> processedPaths = [];
      final appDocDir = await getApplicationDocumentsDirectory();
      final sharedDir = Directory(path.join(appDocDir.path, 'shared_files'));

      if (!await sharedDir.exists()) {
        await sharedDir.create(recursive: true);
      }

      for (final sharedFile in sharedFiles) {
        try {
          final sourceFile = File(sharedFile.path);
          if (!await sourceFile.exists() ||
              !_isValidFileType(sharedFile.path)) {
            continue;
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = path.extension(sharedFile.path);
          final newFileName =
              'shared_${timestamp}_${processedPaths.length}$extension';
          final targetPath = path.join(sharedDir.path, newFileName);

          await sourceFile.copy(targetPath);
          processedPaths.add(targetPath);
        } catch (e) {
          logger.e('Error processing file ${sharedFile.path}: $e');
        }
      }

      if (processedPaths.isNotEmpty) {
        _externalFileService.addFilePaths(processedPaths);
        _router.replaceAll([const DashboardRoute()]);
        if (_navigationController.currentPage == 3) {
          _navigationController.jumpToPage(0);
        }
        _navigationController.navigateToPage(3);
      }
    } catch (e) {
      logger.e('Error processing shared files: $e');
    }
  }

  bool _isValidFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    const validExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.pdf',
      '.gif',
      '.bmp',
      '.webp'
    ];
    return validExtensions.contains(extension);
  }

  void dispose() {
    _intentSub?.cancel();
  }
}
