import 'package:pdfx/pdfx.dart' as pdfx;

/// Opens the PDF at [filePath] with pdfx, on a platform pdfx supports.
///
/// pdfx checks its platform support without awaiting the check, so on an
/// unsupported platform (Linux) its failure escapes as an uncaught error.
/// Checking first turns that into an error the caller can handle.
Future<pdfx.PdfDocument> openPdfDocument(String filePath) async {
  if (!await pdfx.hasPdfSupport()) {
    throw UnsupportedError('pdfx cannot open PDFs on this platform');
  }
  return pdfx.PdfDocument.openFile(filePath);
}
