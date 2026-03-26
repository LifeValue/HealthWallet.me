import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
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
    _bloc.add(RecordAttachmentsInitialised(
      resource: widget.resource,
      ephemeralRecords: widget.ephemeralRecords,
    ));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: BlocBuilder<RecordAttachmentsBloc, RecordAttachmentsState>(
        builder: (context, state) {
          return ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 1.5),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: context.theme.dividerColor, width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.l10n.attachments,
                            style: context.textTheme.bodyMedium ??
                                AppTextStyle.bodyMedium),
                        IconButton(
                          iconSize: 20,
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        )
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
                            ...state.attachments.map((attachment) =>
                                _buildAttachmentRow(context, attachment))
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
                              borderRadius: BorderRadiusGeometry.circular(6)),
                        ),
                        onPressed: () async {
                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles();
                          if (result == null) return;

                          File selectedFile = File(result.files.first.path!);

                          _bloc.add(RecordAttachmentsFileAttached(selectedFile));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Assets.icons.attachment
                                .svg(width: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(context.l10n.attachFile,
                                style: AppTextStyle.buttonSmall),
                          ],
                        ),
                      ),
                    ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  void _viewFile(BuildContext context, String filePath, String? contentType) {
    final ext = extension(filePath).toLowerCase();
    final isImage = contentType?.startsWith('image/') == true ||
        {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}.contains(ext);
    final isPdf = contentType == 'application/pdf' || ext == '.pdf';

    if (isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewer(filePath: filePath)),
      );
    } else if (isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _PdfViewer(filePath: filePath)),
      );
    } else {
      _openFileExternal(context, filePath);
    }
  }

  Future<void> _openFileExternal(BuildContext context, String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAttachmentRow(
      BuildContext context, AttachmentInfo attachmentInfo) {
    final filePath = attachmentInfo.filePath;
    final title = attachmentInfo.title;
    final contentType = attachmentInfo.contentType;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Assets.icons.documentFile
                    .svg(width: 16, color: context.theme.iconTheme.color),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: filePath != null
                        ? () => _viewFile(context, filePath, contentType)
                        : null,
                    child: Text(
                      filePath != null ? basename(filePath) : title,
                      style: AppTextStyle.labelLarge,
                    ),
                  ),
                )
              ],
            ),
          ),
          Row(
            children: [
              if (filePath != null)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: GestureDetector(
                      onTap: () => _viewFile(context, filePath, contentType),
                      child: const Icon(Icons.remove_red_eye_outlined)
                      ),
                ),
              if (filePath != null)
                const SizedBox(width: 16),
              if (!widget.readOnly) ...[
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: GestureDetector(
                    onTap: () => filePath != null
                        ? SharePlus.instance
                            .share(ShareParams(files: [XFile(filePath)]))
                        : null,
                    child: Assets.icons.download
                        .svg(width: 24, color: context.theme.iconTheme.color),
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: GestureDetector(
                      onTap: () =>
                          _showDeleteConfirmationDialog(context, attachmentInfo),
                      child: Assets.icons.trashCan
                          .svg(width: 24, color: context.theme.iconTheme.color)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, AttachmentInfo attachmentInfo) {
    AppSimpleDialog.showDestructiveConfirmation(
      context: context,
      title: context.l10n.deletePage,
      message: context.l10n.deleteAttachmentConfirm,
      warningText: context.l10n.actionCannotBeUndone,
      confirmText: context.l10n.deletePage,
      cancelText: context.l10n.cancel,
      onConfirm: () {
        _bloc.add(RecordAttachmentsFileDeleted(
            attachmentInfo.documentReference));
      },
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String filePath;

  const _ImageViewer({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(basename(filePath)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54),
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

  const _PdfViewer({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(basename(filePath)),
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading PDF: $error')),
            );
          }
        },
        onPageError: (page, error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error on page $page: $error')),
            );
          }
        },
      ),
    );
  }
}
