abstract class TextRecognitionService {
  Future<String> recognizeTextFromImage(String imagePath);
  Future<List<String>> convertPdfToImages(String pdfPath);
  Future<List<String>> convertPdfToImagesForPreview(
    String pdfPath, {
    double dpi,
  });
  Future<String> extractTextFromPDF(String pdfPath);
  Future<List<String>> extractTextFromPDFPages(String pdfPath);
  bool isPDF(String filePath);
  bool isImage(String filePath);
  Future<String> extractTextFromFile(String filePath);
  void dispose();
}
