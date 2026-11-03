/// A model file download stopped because the user cancelled it. Its partial
/// file is already deleted when this is thrown.
class ModelDownloadCancelledException implements Exception {
  const ModelDownloadCancelledException(this.filename);

  final String filename;

  @override
  String toString() => 'Exception: Download cancelled for $filename';
}
