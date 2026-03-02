import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart'
    as entities;
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

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
                  title: const Text('Media Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'link',
                child: ListTile(
                  leading: Icon(Icons.link),
                  title: Text('Link to Encounter'),
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
          context, Icons.picture_as_pdf, 'No PDF data available');
    }
    return FutureBuilder<File>(
      future: _createTempPdfFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            return PDFView(
              filePath: snapshot.data!.path,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: true,
              pageFling: true,
              onError: (error) {
                debugPrint('PDFView error: $error');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading PDF: $error')),
                  );
                }
              },
              onPageError: (page, error) {
                debugPrint('PDFView page error ($page): $error');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error on page $page: $error')),
                  );
                }
              },
            );
          } else {
            return _buildPlaceholder(
                context, Icons.picture_as_pdf, 'Failed to load PDF document');
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<File> _createTempPdfFile() async {
    try {
      final bytes = base64Decode(media.content!.data!.valueString!);
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/${media.displayTitle.replaceAll(' ', '_')}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      if (!await file.exists()) {
        throw Exception('Failed to create PDF file on disk');
      }
      return file;
    } catch (e) {
      debugPrint('Error creating temp PDF file: $e');
      rethrow;
    }
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
        title: const Text('Media Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Title:', media.displayTitle),
              if (media.content?.contentType?.valueString != null)
                _buildInfoRow(
                    'Type:', media.content!.contentType!.valueString!),
              if (media.statusDisplay.isNotEmpty)
                _buildInfoRow('Status:', media.statusDisplay),
              if (media.subject?.display?.valueString != null)
                _buildInfoRow('Patient:', media.subject!.display!.valueString!),
              if (media.encounter?.display?.valueString != null)
                _buildInfoRow(
                    'Encounter:', media.encounter!.display!.valueString!),
              if (media.content?.size?.valueString != null)
                _buildInfoRow(
                    'File Size:',
                    _formatFileSize(
                        _parseFileSize(media.content!.size!.valueString!))),
              if (media.date != null)
                _buildInfoRow('Created:', media.date!.toString().split(' ')[0]),
              _buildInfoRow('Resource ID:', media.resourceId),
              _buildInfoRow('Source:', media.sourceId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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
        title: const Text('Link to Encounter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Link this media resource to an encounter:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: encounterController,
              decoration: const InputDecoration(
                labelText: 'Encounter ID',
                hintText: 'e.g., encounter-123',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
                      const SnackBar(
                        content: Text('Media linked to encounter successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to link media: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }
}
