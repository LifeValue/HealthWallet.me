import 'dart:async';
import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:app_links/app_links.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

@lazySingleton
class DeepLinkService {
  final AppRouter _router;
  final ExternalFilesService _externalFilesService;
  final PageViewNavigationController _navigationController;

  DeepLinkService(
      this._router, this._externalFilesService, this._navigationController);

  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        await _handleDeepLink(uri);
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
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
      final filePath =
          await downloadFile(fileUrl, customFileName: documentName);
      _externalFilesService.addFilePaths([filePath]);
      _router.replaceAll([const DashboardRoute()]);

      if (_navigationController.currentPage == 3) {
        _navigationController.jumpToPage(0);
      }
      _navigationController.navigateToPage(3);
    } catch (_) {}
  }

  void _handleEmergencyLink(Uri uri) {
    try {
      final cardData = EmergencyQrEncoder.decode(uri.toString());
      _router.push(EmergencyCardRoute(cardData: cardData));
    } catch (_) {}
  }

  Future<String> downloadFile(String fileUrl, {String? customFileName}) async {
    final response = await http.get(Uri.parse(fileUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final downloadsDir =
        Directory(path.join(appDocDir.path, 'provider_downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final fileName = customFileName ??
        'provider_doc_${DateTime.now().millisecondsSinceEpoch}${_getExtensionFromUrl(fileUrl)}';
    final filePath = path.join(downloadsDir.path, fileName);

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments;
      if (segs.isNotEmpty && segs.last.contains('.')) {
        return path.extension(segs.last);
      }
    } catch (_) {}
    return '.pdf';
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
