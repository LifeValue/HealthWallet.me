import 'dart:io';

import 'package:health_wallet/core/utils/logger.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

/// A file name for [originalName] in [directory] that no file has yet: the
/// sanitised name with an 8-character unique suffix, so two attachments
/// with the same name never replace each other. The original name stays
/// the attachment's title.
Future<String> uniqueStoredFileName(
  String directory,
  String originalName,
) async {
  final base = originalName.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final dot = base.lastIndexOf('.');
  final hasExtension =
      dot >= 0 && dot < base.length - 1 && base.length - dot <= 16;
  var stem = (hasExtension ? base.substring(0, dot) : base).replaceFirst(
    RegExp(r'^\.+'),
    '',
  );
  if (!stem.contains(RegExp('[A-Za-z0-9]'))) stem = 'file';
  if (stem.length > 100) stem = stem.substring(0, 100);
  final extension = hasExtension ? base.substring(dot) : '';
  while (true) {
    final name = '${stem}_${const Uuid().v4().substring(0, 8)}$extension';
    final type = await FileSystemEntity.type(
      join(directory, name),
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return name;
  }
}

/// Copies [source] to [destination] and marks the copy as modified now.
///
/// Some platforms keep the source's modification time on a copy, and the
/// start-up sweep treats a file with an old one that no record refers to yet
/// as left over. A failure to set the time is logged, not thrown: the copy is
/// still good, and its change time (or creation time on Windows) is new.
Future<File> copyAsNewFile(File source, String destination) async {
  final copy = await source.copy(destination);
  try {
    await copy.setLastModified(DateTime.now());
  } catch (e, s) {
    logger.w('Setting the modification time of $destination failed', e, s);
  }
  return copy;
}
