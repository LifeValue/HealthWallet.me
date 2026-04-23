import 'dart:typed_data';
import 'package:pdfx/pdfx.dart' as pdfx;

Future<Uint8List?> renderPdfFirstPage(
  String filePath, {
  double width = 200,
  double height = 200,
}) async {
  try {
    final document = await pdfx.PdfDocument.openFile(filePath);
    final page = await document.getPage(1);
    final pageImage = await page.render(
      width: width,
      height: height,
    );
    await page.close();
    await document.close();
    return pageImage?.bytes;
  } catch (_) {
    return null;
  }
}
