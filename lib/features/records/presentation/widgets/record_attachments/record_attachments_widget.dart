import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/pdf_open.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

class RecordAttachmentsWidget extends StatefulWidget {
  const RecordAttachmentsWidget({
    required this.resource,
    this.readOnly = false,
    this.ephemeralRecords = const [],
    super.key,
  });

  final IFhirResource resource;
  final bool readOnly;
  final List<IFhirResource> ephemeralRecords;

  @override
  State<RecordAttachmentsWidget> createState() =>
      _RecordAttachmentsWidgetState();
}

class _RecordAttachmentsWidgetState extends State<RecordAttachmentsWidget> {
  final _bloc = getIt.get<RecordAttachmentsBloc>();

  @override
  void initState() {
    _bloc.add(
      RecordAttachmentsInitialised(
        resource: widget.resource,
        ephemeralRecords: widget.ephemeralRecords,
      ),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: BlocListener<RecordAttachmentsBloc, RecordAttachmentsState>(
        listenWhen: (previous, current) =>
            previous.status != current.status && _errorMessage(current) != null,
        listener: (context, state) => AppSnackBar.show(
          context,
          message: _errorMessage(state)!,
          type: AppSnackBarType.error,
        ),
        child: BlocBuilder<RecordAttachmentsBloc, RecordAttachmentsState>(
          builder: (context, state) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 1.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.status == const RecordAttachmentsStatus.loading())
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: context.theme.dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.attachments,
                            style:
                                context.textTheme.bodyMedium ??
                                AppTextStyle.bodyMedium,
                          ),
                          IconButton(
                            iconSize: 20,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (state.attachments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            context.l10n.noFilesAttached,
                            style: AppTextStyle.labelLarge,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              ...state.attachments.map(
                                (attachment) =>
                                    _buildAttachmentRow(context, attachment),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!widget.readOnly)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadiusGeometry.circular(6),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await FilePicker.pickFiles();

                            final files = picked
                                .where((f) => f.path != null)
                                .map((f) => File(f.path!))
                                .toList();
                            if (files.isNotEmpty) {
                              _bloc.add(RecordAttachmentsFileAttached(files));
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Assets.icons.attachment.svg(
                                width: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.attachFile,
                                style: AppTextStyle.buttonSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The translated message of a failed attach or delete. The bloc puts
  /// only translated text in an error as a `String`; other errors are not
  /// shown.
  static String? _errorMessage(RecordAttachmentsState state) =>
      state.status.whenOrNull(error: (e) => e is String ? e : null);

  void _viewFile(
    BuildContext context,
    String filePath,
    String? contentType,
    String title,
  ) async {
    if (!await File(filePath).exists()) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: context.l10n.fileNotAvailable,
          type: AppSnackBarType.error,
        );
      }
      return;
    }
    if (!context.mounted) return;

    final ext = extension(filePath).toLowerCase();
    final isImage =
        contentType?.startsWith('image/') == true ||
        {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}.contains(ext);
    final isPdf = contentType == 'application/pdf' || ext == '.pdf';

    if (isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewer(filePath: filePath, title: title),
        ),
      );
    } else if (isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfViewer(filePath: filePath, title: title),
        ),
      );
    } else if (widget.readOnly) {
      // Shared records are view-only: another app could keep or forward the
      // file after the share ends.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sharedFileNotPreviewable)),
      );
    } else {
      unawaited(_openFileExternal(context, filePath));
    }
  }

  Future<void> _openFileExternal(BuildContext context, String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        logger.w('Could not open $filePath: ${result.message}');
        if (context.mounted) {
          AppSnackBar.show(
            context,
            message: context.l10n.fileOpenFailed,
            type: AppSnackBarType.warning,
          );
        }
      }
    } catch (e, s) {
      logger.w('Could not open $filePath', e, s);
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: context.l10n.fileOpenFailed,
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Widget _buildAttachmentRow(
    BuildContext context,
    AttachmentInfo attachmentInfo,
  ) {
    final filePath = attachmentInfo.filePath;
    // Files are stored under a unique name (`report_1a2b3c4d.pdf`); the
    // title keeps the name the user picked.
    final title = attachmentInfo.title.isNotEmpty || filePath == null
        ? attachmentInfo.title
        : basename(filePath);
    final contentType = attachmentInfo.contentType;

    final isEncounterView = widget.resource.fhirType == FhirType.Encounter;
    final String? sourceLabel;
    if (!isEncounterView) {
      sourceLabel = null;
    } else if (attachmentInfo.sourceRecordTitle != null) {
      sourceLabel =
          '${attachmentInfo.sourceRecordTitle} · ${attachmentInfo.sourceRecordType?.localizedName(context.l10n) ?? ''}';
    } else {
      sourceLabel = context.l10n.currentRecord;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Assets.icons.documentFile.svg(
                      width: 16,
                      color: context.theme.iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: filePath != null
                            ? () => _viewFile(
                                context,
                                filePath,
                                contentType,
                                title,
                              )
                            : null,
                        child: Text(title, style: AppTextStyle.labelLarge),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (filePath != null)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: GestureDetector(
                        onTap: () =>
                            _viewFile(context, filePath, contentType, title),
                        child: const Icon(Icons.remove_red_eye_outlined),
                      ),
                    ),
                  if (filePath != null) const SizedBox(width: 16),
                  if (!widget.readOnly) ...[
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: GestureDetector(
                        onTap: () => filePath != null
                            ? SharePlus.instance.share(
                                ShareParams(files: [XFile(filePath)]),
                              )
                            : null,
                        child: Assets.icons.download.svg(
                          width: 24,
                          color: context.theme.iconTheme.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: GestureDetector(
                        onTap: () => _showDeleteConfirmationDialog(
                          context,
                          attachmentInfo,
                        ),
                        child: Assets.icons.trashCan.svg(
                          width: 24,
                          color: context.theme.iconTheme.color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (sourceLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                sourceLabel,
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    AttachmentInfo attachmentInfo,
  ) {
    AppSimpleDialog.showDestructiveConfirmation(
      context: context,
      title: context.l10n.deletePage,
      message: context.l10n.deleteAttachmentConfirm,
      warningText: context.l10n.actionCannotBeUndone,
      confirmText: context.l10n.deletePage,
      cancelText: context.l10n.cancel,
      onConfirm: () {
        _bloc.add(
          RecordAttachmentsFileDeleted(attachmentInfo.documentReference),
        );
      },
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String filePath;
  final String title;

  const _ImageViewer({required this.filePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  context.l10n.failedToLoadImage,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfViewer extends StatelessWidget {
  final String filePath;
  final String title;

  const _PdfViewer({required this.filePath, required this.title});

  static bool get _isDesktop => getIt<AppPlatform>().isDesktop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: CheckedPdfView(
        filePath: filePath,
        builder: (context) => _isDesktop
            ? _DesktopPdfBody(filePath: filePath)
            : PDFView(
                filePath: filePath,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageFling: true,
                onError: (error) =>
                    CheckedPdfView.reportViewerError(context, error),
                onPageError: (page, error) => CheckedPdfView.reportViewerError(
                  context,
                  'page $page: $error',
                ),
              ),
      ),
    );
  }
}

class _DesktopPdfBody extends StatefulWidget {
  final String filePath;
  const _DesktopPdfBody({required this.filePath});

  @override
  State<_DesktopPdfBody> createState() => _DesktopPdfBodyState();
}

class _DesktopPdfBodyState extends State<_DesktopPdfBody> {
  late final pdfx.PdfController _controller;

  @override
  void initState() {
    super.initState();
    _controller = pdfx.PdfController(
      document: openPdfDocument(widget.filePath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return pdfx.PdfView(controller: _controller);
  }
}
