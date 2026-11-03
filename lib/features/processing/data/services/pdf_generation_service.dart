import 'dart:io';

import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/stored_file_name.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

@injectable
class PdfGenerationService {
  final PathResolver _pathResolver;

  PdfGenerationService(this._pathResolver);
  Future<String> createPdfFromImages({
    required List<String> imagePaths,
    required String fileName,
    String? title,
  }) async {
    if (imagePaths.isEmpty) {
      throw Exception('No images provided for PDF creation');
    }

    try {
      final pdf = pw.Document();

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final file = File(imagePath);

        if (!await file.exists()) {
          continue;
        }

        final imageBytes = await file.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Container(
                width: double.infinity,
                height: double.infinity,
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      final docsPath = await _pathResolver.getDocumentsPath();
      final pdfPath = p.join(docsPath, '$fileName.pdf');
      final pdfFile = File(pdfPath);

      final pdfBytes = await pdf.save();
      await pdfFile.writeAsBytes(pdfBytes);

      return pdfPath;
    } catch (e) {
      throw Exception('Failed to create PDF from images: $e');
    }
  }

  Future<String> copyPdfWithNewName({
    required String sourcePdfPath,
    required String fileName,
  }) async {
    try {
      final sourceFile = File(sourcePdfPath);

      if (!await sourceFile.exists()) {
        throw Exception('Source PDF not found: $sourcePdfPath');
      }

      final docsPath = await _pathResolver.getDocumentsPath();
      final newPdfPath = p.join(docsPath, '$fileName.pdf');

      await copyAsNewFile(sourceFile, newPdfPath);

      return newPdfPath;
    } catch (e) {
      throw Exception('Failed to copy PDF: $e');
    }
  }

  Future<List<DocumentGroup>> groupAndConvertDocuments({
    required List<String> filePaths,
    String? scannedDocumentsTitle,
    String Function(int)? scannedDocumentsPagesTitle,
    String Function(String)? pdfFileTitle,
  }) async {
    final List<DocumentGroup> groups = [];

    final List<String> pdfPaths = [];
    final List<String> imagePaths = [];
    for (final filePath in filePaths) {
      if (p.extension(filePath) == '.pdf') {
        pdfPaths.add(filePath);
      } else {
        imagePaths.add(filePath);
      }
    }

    try {
      if (imagePaths.isNotEmpty) {
        final fileName = await _uniquePdfName('scanned_document');
        final defaultTitle = scannedDocumentsTitle ?? 'Scanned Documents';
        final pdfPath = await createPdfFromImages(
          imagePaths: imagePaths,
          fileName: fileName,
          title: defaultTitle,
        );

        groups.add(
          DocumentGroup(
            type: DocumentGroupType.scannedImages,
            pdfPath: pdfPath,
            title:
                scannedDocumentsPagesTitle?.call(imagePaths.length) ??
                '$defaultTitle (${imagePaths.length} pages)',
            originalCount: imagePaths.length,
          ),
        );
      }

      for (int i = 0; i < pdfPaths.length; i++) {
        final originalPdfPath = pdfPaths[i];
        final fileName = p.basenameWithoutExtension(originalPdfPath);

        final pdfPath = await copyPdfWithNewName(
          sourcePdfPath: originalPdfPath,
          fileName: await _uniquePdfName(fileName),
        );

        groups.add(
          DocumentGroup(
            type: DocumentGroupType.importedPdf,
            pdfPath: pdfPath,
            title: pdfFileTitle?.call(fileName) ?? 'PDF: $fileName',
            originalCount: 1,
          ),
        );
      }

      return groups;
    } catch (e) {
      throw Exception('Failed to group and convert documents: $e');
    }
  }

  /// A free name, without the extension, for a new PDF in Documents. Its
  /// random suffix keeps it from being a deleted file's name, which a
  /// restored or synced record may still point to.
  Future<String> _uniquePdfName(String stem) async =>
      p.basenameWithoutExtension(
        await uniqueStoredFileName(
          await _pathResolver.getDocumentsPath(),
          '$stem.pdf',
        ),
      );
}

enum DocumentGroupType {
  scannedImages,
  importedImages,
  importedPdf,
}

class DocumentGroup {
  final DocumentGroupType type;
  final String pdfPath;
  final String title;
  final int originalCount;

  const DocumentGroup({
    required this.type,
    required this.pdfPath,
    required this.title,
    required this.originalCount,
  });
}
