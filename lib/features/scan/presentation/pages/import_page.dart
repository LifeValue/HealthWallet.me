import 'dart:developer';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/widgets/session_list.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/scan/presentation/widgets/import_actions.dart';
import 'package:health_wallet/features/scan/presentation/helpers/document_handler.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';

@RoutePage()
class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ImportView();
  }
}

class ImportView extends StatefulWidget {
  const ImportView({super.key});

  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<ImportView> with DocumentHandler {
  late final PageViewNavigationController _navigationController;
  @override
  void initState() {
    super.initState();
    _navigationController = getIt<PageViewNavigationController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processExternalFiles();
    });
  }

  void _processExternalFiles() {
    final externalFileService = getIt<ExternalFilesService>();

    if (externalFileService.hasPendingFiles) {
      for (final path in externalFileService.consumeFilePaths()) {
        context.read<ScanBloc>().add(DocumentImported(filePath: path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Import',
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<ScanBloc, ScanState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status case SessionCreated(:final session)) {
            if (_navigationController.currentPage == 3) {
              navigateToFhirMapper(context, session);
            }
          }
        },
        builder: (context, state) {
          List<ProcessingSession> importSessions = state.sessions
              .where((element) => element.origin == ProcessingOrigin.import)
              .toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (importSessions.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Active import sessions:",
                          style: AppTextStyle.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Only one processing session can run at a time!",
                          style: AppTextStyle.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: SessionList(sessions: importSessions),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 80.0),
                          child: ImportActions(
                            onImportDocument: () => _handleImportDocument(context),
                            onPickImage: () => _handlePickImage(context),
                            onScanDocument: () => _navigateToScanTab(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (importSessions.isEmpty)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      Assets.images.emptyScan.svg(),
                      const SizedBox(height: 36),
                      const Text(
                        "No imports yet",
                        style: AppTextStyle.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Import or scan documents to get started",
                        style: AppTextStyle.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ImportActions(
                        onImportDocument: () => _handleImportDocument(context),
                        onPickImage: () => _handlePickImage(context),
                        onScanDocument: () => _navigateToScanTab(context),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToScanTab(BuildContext context) {
    _navigationController.navigateToPage(2);
    // Trigger auto-scan after navigation settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (context.mounted) {
          _triggerScan(context);
        }
      });
    });
  }

  Future<void> _triggerScan(BuildContext context) async {
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      if (context.mounted) {
        context.read<ScanBloc>().add(const ScanButtonPressed());
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      if (context.mounted) {
        DialogHelper.showPermissionDeniedDialog(context);
      }
    } else {
      if (context.mounted) {
        DialogHelper.showPermissionRequiredDialog(
          context,
          () => _triggerScan(context),
        );
      }
    }
  }

  Future<void> _handleImportDocument(BuildContext context) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final result = await FilePicker.platform.pickFiles(
        allowCompression: false,
        withData: false,
        withReadStream: false,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'bmp',
          'webp',
          'tiff'
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          String finalFilePath = '';

          if (file.path != null) {
            finalFilePath = file.path!;
          } else {
            continue;
          }

          if (finalFilePath.isNotEmpty) {
            final fileExists = await File(finalFilePath).exists();

            if (fileExists) {
              if (context.mounted) {
                context.read<ScanBloc>().add(
                      DocumentImported(filePath: finalFilePath),
                    );
              }
            }
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _handlePickImage(BuildContext context) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final fileExists = await File(image.path).exists();

        if (fileExists) {
          if (context.mounted) {
            try {
              context.read<ScanBloc>().add(
                    DocumentImported(filePath: image.path),
                  );
            } catch (e) {
              // Handle error silently
            }
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
