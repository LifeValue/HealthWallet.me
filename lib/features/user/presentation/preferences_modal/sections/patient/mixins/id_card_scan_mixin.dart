import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';
import 'package:health_wallet/features/scan/presentation/helpers/scan_path_helper.dart';
import 'package:health_wallet/features/user/domain/services/id_card_extractor.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

mixin IdCardScanMixin<T extends StatefulWidget> on State<T> {
  TextEditingController get givenController;
  TextEditingController get familyController;
  TextEditingController get identifierController;

  bool get isScanning;
  set isScanning(bool value);
  bool get scanCompleted;
  set scanCompleted(bool value);
  String? get scanMessage;
  set scanMessage(String? value);
  String? get lastScannedImagePath;
  set lastScannedImagePath(String? value);

  String? get scanCountryCode;

  void onScanResultApplied(IdCardExtractionResult result);

  Future<void> handleScanIdCard() async {
    if (isScanning) return;

    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    setState(() => isScanning = true);

    try {
      final scannedResult =
          await FlutterDocScanner().getScannedDocumentAsImages(page: 1);

      if (scannedResult == null || scannedResult.images.isEmpty) {
        if (mounted) setState(() => isScanning = false);
        return;
      }

      final rawPaths = scannedResult.images
          .where((p) => p.isNotEmpty)
          .toList();
      final sanitizedPaths = ScanPathHelper.normalizePaths(rawPaths);
      if (sanitizedPaths.isEmpty) {
        if (mounted) setState(() => isScanning = false);
        return;
      }

      final imagePath = sanitizedPaths.first;
      lastScannedImagePath = imagePath;
      await extractFromImage(imagePath);
    } catch (_) {
      if (mounted) setState(() => isScanning = false);
    }
  }

  Future<void> handleRetryOcr() async {
    if (isScanning || lastScannedImagePath == null) return;
    setState(() => isScanning = true);
    try {
      await extractFromImage(lastScannedImagePath!);
    } catch (_) {
      if (mounted) setState(() => isScanning = false);
    }
  }

  Future<void> handlePickFromGallery() async {
    if (isScanning) return;
    setState(() => isScanning = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        if (mounted) setState(() => isScanning = false);
        return;
      }

      lastScannedImagePath = image.path;
      await extractFromImage(image.path);
    } catch (_) {
      if (mounted) setState(() => isScanning = false);
    }
  }

  Future<void> extractFromImage(String imagePath) async {
    final textRecognition = getIt<TextRecognitionService>();
    final ocrText = await textRecognition.recognizeTextFromImage(imagePath);

    if (ocrText.isEmpty) {
      if (mounted) {
        setState(() => isScanning = false);
        showScanQualityMessage(false);
      }
      return;
    }

    final countryCode = scanCountryCode ?? context.read<UserBloc>().state.countryCode;
    final result = IdCardExtractor.extract(ocrText, countryCode);

    if (mounted && result.hasData) {
      setState(() {
        if (result.familyName != null && result.familyName!.isNotEmpty) {
          familyController.text = result.familyName!;
        }
        if (result.givenName != null && result.givenName!.isNotEmpty) {
          givenController.text = result.givenName!;
        }
        if (result.identifierValue != null &&
            result.identifierValue!.isNotEmpty) {
          identifierController.text = result.identifierValue!;
        }
        isScanning = false;
        scanCompleted = true;
        onScanResultApplied(result);
      });
      final fieldsFound = [
        if (result.familyName != null) 'name',
        if (result.dateOfBirth != null) 'DOB',
        if (result.identifierValue != null) 'ID',
      ].length;
      if (fieldsFound < 2) {
        showScanQualityMessage(true);
      } else {
        setState(() {
          scanMessage =
              'Verify the details are correct. Retry scanning if needed.';
        });
      }
    } else {
      if (mounted) {
        setState(() => isScanning = false);
        showScanQualityMessage(false);
      }
    }
  }

  void showScanQualityMessage(bool partial) {
    if (!mounted) return;
    setState(() {
      scanMessage = partial
          ? 'Some fields could not be read. Try a clearer photo.'
          : 'Could not read the document. Retake with better lighting.';
      scanCompleted = true;
    });
  }
}
