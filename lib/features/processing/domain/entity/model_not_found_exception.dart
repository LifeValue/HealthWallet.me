/// The AI model file is not on the device, so the document cannot be
/// processed until the user downloads it.
class ModelNotFoundException implements Exception {
  const ModelNotFoundException([this.path]);

  final String? path;

  /// English diagnostic text. A desktop sends it to the paired phone as the
  /// handover error, and older mobile builds look for "Model file not found"
  /// in it, so keep the wording.
  @override
  String toString() =>
      path == null ? 'Exception: $message' : 'Exception: $message at $path';

  static const message = 'Model file not found';
}
