import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

@lazySingleton
class DeepLinkService {
  final AppRouter _router;
  final ExternalFilesService _externalFilesService;
  final PageViewNavigationController _navigationController;

  DeepLinkService(
    this._router,
    this._externalFilesService,
    this._navigationController, {
    @ignoreParam AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Since app_links 6 the stream also delivers the link the app was opened
    // with, so it is the only source: reading getInitialLink() as well
    // handled that link twice (two emergency cards, two downloads).
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        await handleDeepLink(uri);
      },
      onError: (Object e) => logger.w('A deep link could not be read', e),
    );
  }

  @visibleForTesting
  Future<void> handleDeepLink(Uri uri) async {
    if (uri.scheme == 'healthwallet' && uri.host == 'emergency') {
      _handleEmergencyLink(uri);
      return;
    }

    if (uri.scheme == 'https' && uri.host == 'emergency.healthwallet.me') {
      _handleEmergencyLink(uri);
      return;
    }

    if (uri.scheme != 'https' || uri.host != 'add.healthwallet.me') {
      return;
    }

    final fileUrl = uri.queryParameters['file'];
    final documentName = uri.queryParameters['name'];

    if (fileUrl == null || fileUrl.isEmpty) {
      return;
    }

    try {
      final filePath = await downloadFile(
        fileUrl,
        customFileName: documentName,
      );
      _externalFilesService.addFilePaths([filePath]);
      unawaited(_router.replaceAll([const DashboardRoute()]));

      if (_navigationController.currentPage == 3) {
        _navigationController.jumpToPage(0);
      }
      unawaited(_navigationController.navigateToPage(3));
    } catch (e) {
      logger.w('Linked document could not be downloaded', e);
    }
  }

  void _handleEmergencyLink(Uri uri) {
    try {
      final cardData = EmergencyQrEncoder.decode(uri.toString());
      _router.push(EmergencyCardRoute(cardData: cardData));
    } catch (e) {
      logger.w('Emergency link could not be read', e);
    }
  }

  Future<String> downloadFile(String fileUrl, {String? customFileName}) async {
    final response = await http.get(Uri.parse(fileUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(
      path.join(appDocDir.path, 'provider_downloads'),
    );
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final fileName =
        safeFileName(customFileName) ??
        'provider_doc_${DateTime.now().millisecondsSinceEpoch}${_getExtensionFromUrl(fileUrl)}';
    final filePath = path.join(downloadsDir.path, fileName);

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  /// The link's `name` reduced to a plain file name, so it can't reach
  /// outside `provider_downloads/`: the last segment after any `/` or `\`,
  /// without control characters. Null when nothing usable is left, so the
  /// caller generates a name.
  @visibleForTesting
  static String? safeFileName(String? name) {
    if (name == null) return null;
    final base = name
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (base.isEmpty || base == '.' || base == '..') return null;
    return base;
  }

  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments;
      if (segs.isNotEmpty && segs.last.contains('.')) {
        return path.extension(segs.last);
      }
    } on FormatException {
      // An unparsable URL has no extension to read; use the default.
    }
    return '.pdf';
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
