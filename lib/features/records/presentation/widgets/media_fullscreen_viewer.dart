import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart'
    as entities;
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:path_provider/path_provider.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class MediaFullscreenViewer extends StatelessWidget {
  final entities.Media media;

  const MediaFullscreenViewer({
    super.key,
    required this.media,
  });

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
    if (media.content?.contentType?.valueString?.toLowerCase() !=
            'application/pdf' ||
        media.content?.data?.valueString == null) {
      return _buildPlaceholder(
          context, Icons.picture_as_pdf, context.l10n.noPdfDataAvailable);
    }

    return FutureBuilder<File>(
      future: _createTempPdfFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            final isDesktop =
                Platform.isMacOS || Platform.isWindows || Platform.isLinux;
            if (isDesktop) {
              return _DesktopPdfBody(filePath: snapshot.data!.path);
            }
            return PDFView(
              filePath: snapshot.data!.path,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: true,
              pageFling: true,
              onError: (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.errorLoadingPdf('$error'))),
                  );
                }
              },
              onPageError: (page, error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.errorOnPage('$page', '$error'))),
                  );
                }
              },
            );
          } else {
            return _buildPlaceholder(
                context, Icons.picture_as_pdf, context.l10n.failedToLoadPdf);
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
    final file =
        File('${dir.path}/${media.displayTitle.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists()) {
      throw Exception('Failed to create PDF file on disk');
    }
    return file;
  }

  Widget _buildPlaceholder(
      BuildContext context, IconData icon, String message) {
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
                    context.l10n.mediaInfoType, media.content!.contentType!.valueString!),
              if (media.statusDisplay.isNotEmpty)
                _buildInfoRow(context.l10n.mediaInfoStatus, media.statusDisplay),
              if (media.subject?.display?.valueString != null)
                _buildInfoRow(context.l10n.mediaInfoPatient, media.subject!.display!.valueString!),
              if (media.encounter?.display?.valueString != null)
                _buildInfoRow(
                    context.l10n.mediaInfoEncounter, media.encounter!.display!.valueString!),
              if (media.content?.size?.valueString != null)
                _buildInfoRow(
                    context.l10n.mediaInfoFileSize,
                    _formatFileSize(
                        _parseFileSize(media.content!.size!.valueString!))),
              if (media.date != null)
                _buildInfoRow(context.l10n.mediaInfoCreated, media.date!.toString().split(' ')[0]),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.mediaLinkedSuccess),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.failedToLinkMedia('$e')),
                        backgroundColor: Colors.red,
                      ),
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
      document: pdfx.PdfDocument.openFile(widget.filePath),
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
