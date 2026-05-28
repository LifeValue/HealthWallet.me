import 'dart:io';
import 'dart:ui' as ui;

Future<void> rotateImage90CW(String filePath) async {
  final file = File(filePath);
  final bytes = await file.readAsBytes();

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final width = image.width;
  final height = image.height;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.translate(height.toDouble(), 0);
  canvas.rotate(90 * 3.14159265358979 / 180);
  canvas.drawImage(image, ui.Offset.zero, ui.Paint());

  final picture = recorder.endRecording();
  final rotated = await picture.toImage(height, width);
  final byteData = await rotated.toByteData(format: ui.ImageByteFormat.png);

  image.dispose();
  rotated.dispose();

  if (byteData == null) return;

  await file.writeAsBytes(
    byteData.buffer.asUint8List(),
    flush: true,
  );
}
