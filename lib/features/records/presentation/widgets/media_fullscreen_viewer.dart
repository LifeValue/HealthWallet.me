import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get_it/get_it.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/pdf_open.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart'
    as entities;
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

class MediaFullscreenViewer extends StatefulWidget {
  final entities.Media media;

  const MediaFullscreenViewer({
    super.key,
    required this.media,
  });

  @override
  State<MediaFullscreenViewer> createState() => _MediaFullscreenViewerState();
}

class _MediaFullscreenViewerState extends State<MediaFullscreenViewer> {
  entities.Media get media => widget.media;

  /// The decoded PDF, written once and deleted when the viewer closes.
  Future<File>? _pdfFile;

  bool get _hasPdfData =>
      media.content?.contentType?.valueString?.toLowerCase() ==
          'application/pdf' &&
      media.content?.data?.valueString != null;

  @override
  void initState() {
    super.initState();
    if (_hasPdfData) _pdfFile = _createTempPdfFile();
  }

  @override
  void dispose() {
    unawaited(_deletePdfFile());
    super.dispose();
  }

  Future<void> _deletePdfFile() async {
    try {
      final file = await _pdfFile;
      if (file != null && await file.exists()) await file.delete();
    } catch (e, s) {
      // The startup sweep deletes it next time.
      logger.w('Deleting a viewed Media PDF failed', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(media.displayTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showMediaInfo(context);
                  break;
                case 'link':
                  _showLinkToEncounterDialog(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'info',
                child: ListTile(
                  leading: Assets.icons.information.svg(width: 24, height: 24),
                  title: Text(context.l10n.mediaInfo),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'link',
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(context.l10n.linkToEncounter),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: _buildPdfViewer(context),
      ),
    );
  }

  Widget _buildPdfViewer(BuildContext context) {
    if (_pdfFile == null) {
      return _buildPlaceholder(
        context,
        Icons.picture_as_pdf,
        context.l10n.noPdfDataAvailable,
      );
    }

    return FutureBuilder<File>(
      future: _pdfFile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            final isDesktop = getIt<AppPlatform>().isDesktop;
            final pdfPath = snapshot.data!.path;
            return CheckedPdfView(
              filePath: pdfPath,
              builder: (context) => isDesktop
                  ? _DesktopPdfBody(filePath: pdfPath)
                  : PDFView(
                      filePath: pdfPath,
                      enableSwipe: true,
                      swipeHorizontal: true,
                      autoSpacing: true,
                      pageFling: true,
                      onError: (error) =>
                          CheckedPdfView.reportViewerError(context, error),
                      onPageError: (page, error) =>
                          CheckedPdfView.reportViewerError(
                            context,
                            'page $page: $error',
                          ),
                    ),
            );
          } else {
            return _buildPlaceholder(
              context,
              Icons.picture_as_pdf,
              context.l10n.failedToLoadPdf,
            );
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<File> _createTempPdfFile() async {
    final bytes = base64Decode(media.content!.data!.valueString!);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${TempFileSweeper.recordPreviewName('pdf')}',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists()) {
      throw Exception('Failed to create PDF file on disk');
    }
    return file;
  }

  Widget _buildPlaceholder(
    BuildContext context,
    IconData icon,
    String message,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showMediaInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mediaInformation),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(context.l10n.mediaInfoTitle, media.displayTitle),
              if (media.content?.contentType?.valueString != null)
                _buildInfoRow(
                  context.l10n.mediaInfoType,
                  media.content!.contentType!.valueString!,
                ),
              if (media.statusDisplay.isNotEmpty)
                _buildInfoRow(
                  context.l10n.mediaInfoStatus,
                  localizedStatusDisplay(media.statusDisplay, context.l10n),
                ),
              if (media.subject?.display?.valueString != null)
                _buildInfoRow(
                  context.l10n.mediaInfoPatient,
                  media.subject!.display!.valueString!,
                ),
              if (media.encounter?.display?.valueString != null)
                _buildInfoRow(
                  context.l10n.mediaInfoEncounter,
                  media.encounter!.display!.valueString!,
                ),
              if (media.content?.size?.valueString != null)
                _buildInfoRow(
                  context.l10n.mediaInfoFileSize,
                  _formatFileSize(
                    _parseFileSize(media.content!.size!.valueString!),
                  ),
                ),
              if (media.date != null)
                _buildInfoRow(
                  context.l10n.mediaInfoCreated,
                  media.date!.toString().split(' ')[0],
                ),
              _buildInfoRow(context.l10n.mediaInfoResourceId, media.resourceId),
              _buildInfoRow(context.l10n.mediaInfoSource, media.sourceId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  int _parseFileSize(String sizeString) {
    try {
      return int.parse(sizeString);
    } catch (e) {
      return 0;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showLinkToEncounterDialog(BuildContext context) {
    final encounterController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.linkToEncounter),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.linkMediaToEncounterDescription),
            const SizedBox(height: 16),
            TextFormField(
              controller: encounterController,
              decoration: InputDecoration(
                labelText: context.l10n.encounterId,
                hintText: context.l10n.encounterIdHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (encounterController.text.trim().isNotEmpty) {
                try {
                  await GetIt.instance
                      .get<DocumentReferenceService>()
                      .linkDocumentReferenceToEncounter(
                        documentReferenceResourceId: media.resourceId,
                        encounterId: encounterController.text.trim(),
                        sourceId: media.sourceId,
                      );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    AppSnackBar.show(
                      context,
                      message: context.l10n.mediaLinkedSuccess,
                      type: AppSnackBarType.success,
                    );
                  }
                } catch (e, s) {
                  logger.w('Could not link media ${media.id}', e, s);
                  if (context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: context.l10n.linkMediaFailed,
                      type: AppSnackBarType.error,
                    );
                  }
                }
              }
            },
            child: Text(context.l10n.link),
          ),
        ],
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
