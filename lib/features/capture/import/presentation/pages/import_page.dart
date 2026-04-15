import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/widgets/session_list.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/processing/presentation/widgets/import_actions.dart';
import 'package:health_wallet/features/processing/presentation/helpers/document_handler.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

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
  bool _isDragging = false;

  static const _allowedExtensions = [
    '.pdf', '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff'
  ];

  bool get _isDesktop => getIt<AppPlatform>().isDesktop;

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
      final paths = externalFileService.consumeFilePaths();
      if (paths.isNotEmpty) {
        context
            .read<ProcessingBloc>()
            .add(DocumentImported(filePaths: paths.toList()));
      }
    }
  }

  void _handleDroppedFiles(List<String> paths) {
    final validPaths = paths.where((path) {
      final ext = path.toLowerCase().substring(path.lastIndexOf('.'));
      return _allowedExtensions.contains(ext);
    }).toList();

    if (validPaths.isEmpty) return;

    context.read<ProcessingBloc>().add(DocumentImported(filePaths: validPaths));
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      appBar: CustomAppBar(
        title: 'Import',
        automaticallyImplyLeading: false,
        extraTopPadding: context.isTablet ? 16 : 0,
      ),
      body: BlocConsumer<ProcessingBloc, ProcessingState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status case SessionCreated(:final session)) {
            if (session.origin == ProcessingOrigin.import) {
              navigateToFhirMapper(context, session);
            }
          }
        },
        builder: (context, state) {
          List<ProcessingSession> importSessions = state.sessions
              .where((element) => element.origin == ProcessingOrigin.import)
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              left: context.screenHorizontalPadding,
              right: context.screenHorizontalPadding,
              top: context.isTablet ? 24.0 : 16.0,
              bottom: 16.0,
            ),
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
                        if (_isDesktop)
                          _buildDesktopActions(context)
                        else
                          Padding(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 76),
                            child: ImportActions(
                              onImportDocument: () =>
                                  _handleImportDocument(context),
                              onPickImage: () => _handlePickImage(context),
                              onScanDocument: () => _navigateToScanTab(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (importSessions.isEmpty)
                  if (_isDesktop)
                    Expanded(child: _buildDesktopEmptyState(context))
                  else if (context.isTablet)
                    Expanded(
                      child: Align(
                        alignment: const Alignment(0, -0.3),
                        child: _buildEmptyState(context),
                      ),
                    )
                  else
                    Center(child: _buildEmptyState(context)),
              ],
            ),
          );
        },
      ),
    );

    if (!_isDesktop) return body;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files.map((f) => f.path).toList();
        _handleDroppedFiles(paths);
      },
      child: Stack(
        children: [
          body,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: context.colorScheme.primary.withValues(alpha: 0.08),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.extraLarge,
                      vertical: Insets.large,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 48,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(height: Insets.normal),
                        Text(
                          'Drop to import',
                          style: AppTextStyle.titleMedium.copyWith(
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopEmptyState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.file_upload_outlined,
              size: 64,
              color: context.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: Insets.normal),
            Text(
              'Drop files here to import',
              style: AppTextStyle.titleMedium.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Insets.small),
            Text(
              'PDF, JPG, PNG, TIFF',
              style: AppTextStyle.bodySmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: Insets.large),
            _buildDesktopActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopActions(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        child: TextButton.icon(
          onPressed: () => _handleImportDocument(context),
          icon: Icon(Icons.folder_open, size: 18, color: context.colorScheme.primary),
          label: Text(
            'Browse Files',
            style: AppTextStyle.buttonSmall.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ImportActions(
              onImportDocument: () => _handleImportDocument(context),
              onPickImage: () => _handlePickImage(context),
              onScanDocument: () => _navigateToScanTab(context),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToScanTab(BuildContext context) {
    _navigationController.navigateToPage(2);
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
        context.read<ProcessingBloc>().add(const CaptureButtonPressed());
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
        allowMultiple: true,
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
        final validPaths = <String>[];

        for (final file in result.files) {
          if (file.path == null || file.path!.isEmpty) continue;
          if (await File(file.path!).exists()) {
            validPaths.add(file.path!);
          }
        }

        if (validPaths.isNotEmpty && context.mounted) {
          context.read<ProcessingBloc>().add(
                DocumentImported(filePaths: validPaths),
              );
        }
      }
    } catch (_) {}
  }

  Future<void> _handlePickImage(BuildContext context) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) return;

      final validPaths = <String>[];
      for (final image in images) {
        if (await File(image.path).exists()) {
          validPaths.add(image.path);
        }
      }

      if (validPaths.isNotEmpty && context.mounted) {
        context.read<ProcessingBloc>().add(
              DocumentImported(filePaths: validPaths),
            );
      }
    } catch (_) {}
  }
}
