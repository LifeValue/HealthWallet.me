import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/model_download_cancelled_exception.dart';

void main() {
  test('names the file whose download was cancelled', () {
    const error = ModelDownloadCancelledException('model.gguf');

    expect(error, isA<Exception>());
    expect(error.filename, 'model.gguf');
    expect('$error', 'Exception: Download cancelled for model.gguf');
  });
}
