/// The path an attachment's `file://` [url] names: without the scheme, and
/// percent-decoded when it is encoded. Without the scheme, [url] is taken
/// as a path.
///
/// Not every stored link is encoded: a document saved from a scan or an
/// import, or repointed by the desktop sync, keeps its file name as it is,
/// accents and spaces included (`file://Scrisoare medicală_1a2b3c4d.pdf`),
/// and decoding such a name, or one with a literal `%`, throws.
String filePathOfUrl(String url) {
  final path = url.startsWith('file://') ? url.substring(7) : url;
  try {
    return Uri.decodeComponent(path);
  } on ArgumentError {
    return path;
  } on FormatException {
    return path;
  }
}
