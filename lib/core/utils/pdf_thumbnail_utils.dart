import 'dart:typed_data';
import 'package:pdfx/pdfx.dart' as pdfx;

Future<Uint8List?> renderPdfFirstPage(
  String filePath, {
  double targetSize = 200,
}) async {
  try {
    final document = await pdfx.PdfDocument.openFile(filePath);
    final page = await document.getPage(1);
    final aspect = page.width / page.height;
    final double renderWidth;
    final double renderHeight;
    if (aspect >= 1) {
      renderWidth = targetSize;
      renderHeight = targetSize / aspect;
    } else {
      renderHeight = targetSize;
      renderWidth = targetSize * aspect;
    }
    final pageImage = await page.render(
      width: renderWidth,
      height: renderHeight,
      backgroundColor: '#FFFFFF',
    );
    await page.close();
    await document.close();
    return pageImage?.bytes;
  } catch (_) {
    return null;
  }
}
