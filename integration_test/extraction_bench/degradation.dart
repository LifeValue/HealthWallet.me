import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../tool/extraction_bench/src/rng.dart';

/// Applies the dataset's seeded degradation to one page image and returns the
/// path of the degraded copy (written into [outDir]); `clean` returns [path].
///
/// - `scan`: rotation within ±2°, light blur, Gaussian noise, JPEG quality 60.
/// - `photo`: rotation within ±4°, a brightness gradient across the page,
///   light blur, JPEG quality 70.
Future<String> degradePage(
  String path, {
  required String mode,
  required int seed,
  required int pageIndex,
  required String outDir,
}) async {
  if (mode == 'clean') return path;
  if (mode != 'scan' && mode != 'photo') {
    throw ArgumentError.value(mode, 'mode', 'expected clean, scan or photo');
  }
  final decoded = img.decodeImage(await File(path).readAsBytes());
  if (decoded == null) throw StateError('Cannot decode page image $path');
  final rng = BenchRng.derive(seed, 'degrade/$mode/$pageIndex');
  var image = decoded.convert(numChannels: 4);

  final maxAngle = mode == 'scan' ? 2.0 : 4.0;
  final angle = rng.doubleBetween(-maxAngle, maxAngle);
  final rotated = img.copyRotate(
    image,
    angle: angle,
    interpolation: img.Interpolation.linear,
  );
  final background = mode == 'scan' ? 255 : 196;
  final canvas = img.Image(
    width: rotated.width,
    height: rotated.height,
    numChannels: 4,
  );
  img.fill(
    canvas,
    color: img.ColorRgba8(background, background, background, 255),
  );
  image = img.compositeImage(canvas, rotated);

  if (mode == 'photo') {
    // Light falls off from one corner to the opposite one.
    final direction = rng.doubleBetween(0, 2 * math.pi);
    final dx = math.cos(direction);
    final dy = math.sin(direction);
    final dark = rng.doubleBetween(0.62, 0.8);
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    for (final px in image) {
      final t =
          ((px.x / w - 0.5) * dx + (px.y / h - 0.5) * dy) / math.sqrt2 + 0.5;
      final f = dark + (1.02 - dark) * t.clamp(0.0, 1.0);
      px
        ..r = (px.r * f).clamp(0, 255)
        ..g = (px.g * f).clamp(0, 255)
        ..b = (px.b * f).clamp(0, 255);
    }
  }

  image = img.gaussianBlur(image, radius: 1);
  if (mode == 'scan') {
    image = img.noise(image, 10, random: math.Random(rng.nextUint32()));
  }

  final out = p.join(outDir, 'page-${pageIndex + 1}-$mode.jpg');
  await File(out).writeAsBytes(
    img.encodeJpg(
      image.convert(numChannels: 3),
      quality: mode == 'scan' ? 60 : 70,
    ),
  );
  return out;
}
