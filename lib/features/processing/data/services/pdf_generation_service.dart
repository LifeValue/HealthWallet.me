import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;

@injectable
class PdfGenerationService {
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

      final tempDir = await getTemporaryDirectory();
      final pdfPath = path.join(tempDir.path, '$fileName.pdf');
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

      final tempDir = await getTemporaryDirectory();
      final newPdfPath = path.join(tempDir.path, '$fileName.pdf');

      await sourceFile.copy(newPdfPath);

      return newPdfPath;
    } catch (e) {
      throw Exception('Failed to copy PDF: $e');
    }
  }

  Future<List<DocumentGroup>> groupAndConvertDocuments(
      {required List<String> filePaths}) async {
    final List<DocumentGroup> groups = [];

    List<String> pdfPaths = [];
    List<String> imagePaths = [];
    for (final filePath in filePaths) {
      if (path.extension(filePath) == ".pdf") {
        pdfPaths.add(filePath);
      } else {
        imagePaths.add(filePath);
      }
    }

    try {
      if (imagePaths.isNotEmpty) {
        final fileName = await _generateScannedDocumentName();
        final pdfPath = await createPdfFromImages(
          imagePaths: imagePaths,
          fileName: fileName,
          title: 'Scanned Documents',
        );

        groups.add(DocumentGroup(
          type: DocumentGroupType.scannedImages,
          pdfPath: pdfPath,
          title: 'Scanned Documents (${imagePaths.length} pages)',
          originalCount: imagePaths.length,
        ));
      }

      for (int i = 0; i < pdfPaths.length; i++) {
        final originalPdfPath = pdfPaths[i];
        final fileName = path.basenameWithoutExtension(originalPdfPath);

        final pdfPath = await copyPdfWithNewName(
          sourcePdfPath: originalPdfPath,
          fileName: 'pdf_${_generateId()}_$fileName',
        );

        groups.add(DocumentGroup(
          type: DocumentGroupType.importedPdf,
          pdfPath: pdfPath,
          title: 'PDF: $fileName',
          originalCount: 1,
        ));
      }

      return groups;
    } catch (e) {
      throw Exception('Failed to group and convert documents: $e');
    }
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Generate a scanned document name in the format: scanned_document_ddmmyyyy_N
  /// where N is an incremental number for documents created on the same day
  Future<String> _generateScannedDocumentName() async {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.year}';

    final incrementalNumber = await _getIncrementalNumberForDate(dateStr);
    return 'scanned_document_${dateStr}_$incrementalNumber';
  }

  /// Get the next incremental number for scanned documents on a specific date
  Future<int> _getIncrementalNumberForDate(String dateStr) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      // Find all files matching the pattern scanned_document_{dateStr}_*
      final pattern = 'scanned_document_${dateStr}_';
      int maxNumber = 0;

      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith(pattern) && fileName.endsWith('.pdf')) {
            // Extract the number from the filename
            final numberPart = fileName.substring(
                pattern.length, fileName.length - 4); // Remove .pdf
            final number = int.tryParse(numberPart);
            if (number != null && number > maxNumber) {
              maxNumber = number;
            }
          }
        }
      }

      return maxNumber + 1;
    } catch (e) {
      // If there's an error reading files, default to 1
      return 1;
    }
  }
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
