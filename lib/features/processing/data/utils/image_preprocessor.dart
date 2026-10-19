import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  static Future<String> preprocessForOcr(String imagePath) async {
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return imagePath;
    }

    final file = File(imagePath);
    if (!await file.exists()) return imagePath;

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imagePath;

      var processed = img.adjustColor(decoded, contrast: 1.3);
      processed = img.convolution(processed, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);

      final supportDir = await getApplicationSupportDirectory();
      if (supportDir.path.isEmpty) return imagePath;
      final ocrTempDir = Directory(path.join(supportDir.path, 'ocr_temp'));
      if (!await ocrTempDir.exists()) {
        await ocrTempDir.create(recursive: true);
      }
      final outputPath =
          path.join(ocrTempDir.path, 'preprocessed_${path.basename(imagePath)}');
      await File(outputPath).writeAsBytes(img.encodeJpg(processed, quality: 95));

      return outputPath;
    } catch (_) {
      return imagePath;
    }
  }
}
