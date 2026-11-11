import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

/// What to do with a stored JSON value that can't be read.
enum OnUnparseable {
  /// Log it and treat it as naming no file (backups copy only what they can
  /// read).
  skip,

  /// Keep its raw text, so any file it mentions counts as referenced (the
  /// attachment cleaner never deletes a file it can't rule out).
  rawText,
}

/// One `file://` url found in a stored record, or the raw text of a record
/// that couldn't be read ([isRawText]).
class AttachmentRef {
  AttachmentRef(this.url) : path = _decodedPath(url), rawText = null;

  AttachmentRef.rawText(String this.rawText) : url = '', path = '';

  /// The url as stored, e.g. `file://My%20Scan.pdf`.
  final String url;

  /// The url without `file://`, percent-decoded when it is encoded.
  final String path;

  /// The raw text of an unreadable record, when [isRawText].
  final String? rawText;

  bool get isRawText => rawText != null;

  /// The file name: the last part of [path], split on `/` and `\`.
  String get basename => AttachmentReferences.basenameOf(path);

  /// Whether this reference names the file [basename]. A raw-text reference
  /// names every file whose name, raw or encoded, appears in the text.
  bool refersTo(String basename) {
    final text = rawText;
    if (text == null) return AttachmentReferences._matches(basename, url);
    final lower = text.toLowerCase();
    return AttachmentReferences._variants(
      basename,
    ).any((name) => name.isNotEmpty && lower.contains(name));
  }

  static String _decodedPath(String url) => AttachmentReferences._tryDecode(
    url.startsWith(AttachmentReferences.scheme)
        ? url.substring(AttachmentReferences.scheme.length)
        : url,
  );

  @override
  String toString() =>
      isRawText ? 'AttachmentRef.rawText' : 'AttachmentRef($url)';
}

/// Finds the attachment files the database refers to: every `file://` url in
/// `fhir_resource.resource_raw` (DocumentReference `content[].attachment`,
/// Media `content`, any other attachment), live and deleted rows alike, and
/// every file of a scan session (`processing_sessions.file_paths` and
/// `resources`).
///
/// File names are compared by basename, split on `/` and `\`, raw and
/// percent-decoded, ignoring case: rows from another device or an older
/// version store the same file as a relative name, an absolute path, an iOS
/// container path or an encoded Windows path.
@lazySingleton
class AttachmentReferences {
  AttachmentReferences(this._db);

  final AppDatabase _db;

  static const scheme = 'file://';

  /// The `file://` urls in a record's [raw] JSON.
  Future<List<AttachmentRef>> fromResourceRaw(
    String raw, {
    required OnUnparseable mode,
  }) async {
    final json = _decode(raw);
    if (json == null) {
      switch (mode) {
        case OnUnparseable.skip:
          logger.w('[AttachmentReferences] skipped an unreadable record');
          return const [];
        case OnUnparseable.rawText:
          logger.w(
            '[AttachmentReferences] unreadable record, matching its text',
          );
          return [AttachmentRef.rawText(raw)];
      }
    }
    return [for (final url in _fileUrls(json)) AttachmentRef(url)];
  }

  /// The lower-case basenames, raw and decoded, of every file a record (live
  /// or deleted) or, with [includeSessions], a scan session refers to. An
  /// unreadable value adds the names of the `file://` urls its text holds.
  Future<Set<String>> referencedBasenames({bool includeSessions = true}) async {
    final names = <String>{};
    void addPath(String path) => names.addAll(_variants(basenameOf(path)));

    for (final raw in await _resourceRaws()) {
      final json = _decode(raw);
      if (json == null) {
        logger.w(
          '[AttachmentReferences] unreadable record, reading urls from its text',
        );
        for (final url in _urlsInText(raw)) {
          addPath(AttachmentRef(url).path);
        }
        continue;
      }
      for (final url in _fileUrls(json)) {
        addPath(AttachmentRef(url).path);
      }
    }
    if (includeSessions) {
      for (final value in await _sessionValues()) {
        final json = _decode(value);
        if (json == null) {
          logger.w(
            '[AttachmentReferences] unreadable scan session, reading its text',
          );
          for (final url in _urlsInText(value)) {
            addPath(AttachmentRef(url).path);
          }
          continue;
        }
        for (final path in _sessionPaths(json)) {
          addPath(path);
        }
      }
    }
    names.remove('');
    return names;
  }

  /// Whether any record (live or deleted) or, with [includeSessions], any
  /// scan session refers to the file [basename]. Unreadable values are
  /// matched as raw text, so a file they might name counts as referenced.
  Future<bool> isReferenced(
    String basename, {
    bool includeSessions = true,
  }) async {
    // Only rows whose text holds the name can refer to it: SQLite picks them,
    // so a check doesn't decode every row.
    final needle = sqlNeedle(basename);
    for (final raw in await _resourceRaws(needle: needle)) {
      final refs = await fromResourceRaw(raw, mode: OnUnparseable.rawText);
      if (refs.any((r) => r.refersTo(basename))) return true;
    }
    if (!includeSessions) return false;
    for (final value in await _sessionValues(needle: needle)) {
      final json = _decode(value);
      if (json == null) {
        if (AttachmentRef.rawText(value).refersTo(basename)) return true;
        continue;
      }
      for (final path in _sessionPaths(json)) {
        if (matches(basename, path)) return true;
      }
    }
    return false;
  }

  /// A lower-case text that every stored form of [basename] contains (raw,
  /// percent-encoded or decoded, JSON-escaped, any case), for a SQL
  /// pre-filter; null when there is none and every row must be read.
  ///
  /// It is the longest run of ASCII letters and digits outside `%XX`
  /// escapes: encoders leave those characters as they are, and SQLite's
  /// `lower()` folds them like Dart. A row that spells a letter as `%XX`
  /// isn't found; no encoder the app meets does that.
  @visibleForTesting
  static String? sqlNeedle(String basename) {
    final lower = basename.toLowerCase();
    final runs = RegExp(
      '[a-z0-9]+',
    ).allMatches(lower.replaceAll(RegExp('%[0-9a-f]{2}'), ' '));
    String? best;
    for (final run in runs) {
      final text = run.group(0)!;
      if (best == null || text.length > best.length) best = text;
    }
    if (best == null) return null;
    final needle = best;
    return _variants(basename).every((v) => v.contains(needle)) ? needle : null;
  }

  /// Whether [url] (a `file://` url or a stored path) names the file
  /// [basename], compared raw and decoded, ignoring case.
  bool matches(String basename, String url) => _matches(basename, url);

  /// [raw] with every `file://` url for which [newUrl] returns a value
  /// replaced by it, or null when nothing changed or [raw] can't be read.
  String? rewriteUrls(String raw, String? Function(AttachmentRef ref) newUrl) {
    final json = _decode(raw);
    if (json == null) return null;
    var changed = false;
    Object? walk(Object? node) {
      if (node is String && node.startsWith(scheme)) {
        final replacement = newUrl(AttachmentRef(node));
        if (replacement == null || replacement == node) return node;
        changed = true;
        return replacement;
      }
      if (node is Map) {
        for (final key in node.keys.toList()) {
          node[key] = walk(node[key]);
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          node[i] = walk(node[i]);
        }
      }
      return node;
    }

    walk(json);
    return changed ? jsonEncode(json) : null;
  }

  /// The app's database (`db.sqlite`, `-wal`, `-shm`, …), which lives in the
  /// documents directory next to the attachments and is never one of them.
  static bool isDatabase(String path) =>
      p.basename(path).toLowerCase().startsWith('db.sqlite');

  /// The last part of [path], split on `/` and `\`.
  static String basenameOf(String path) => path.split(RegExp(r'[/\\]')).last;

  // ---------------------------------------------------------------------------

  Future<List<String>> _resourceRaws({String? needle}) async {
    final rows = await _db
        .customSelect(
          needle == null
              ? 'SELECT resource_raw FROM fhir_resource'
              : 'SELECT resource_raw FROM fhir_resource '
                    'WHERE instr(lower(resource_raw), ?) > 0',
          variables: [if (needle != null) Variable.withString(needle)],
          readsFrom: {_db.fhirResource},
        )
        .get();
    return [
      for (final r in rows)
        if (r.data['resource_raw'] is String) r.data['resource_raw'] as String,
    ];
  }

  Future<List<String>> _sessionValues({String? needle}) async {
    final rows = await _db
        .customSelect(
          needle == null
              ? 'SELECT file_paths, resources FROM processing_sessions'
              : 'SELECT file_paths, resources FROM processing_sessions '
                    'WHERE instr(lower(file_paths), ?1) > 0 '
                    'OR instr(lower(resources), ?1) > 0',
          variables: [if (needle != null) Variable.withString(needle)],
          readsFrom: {_db.processingSessions},
        )
        .get();
    return [
      for (final r in rows)
        for (final column in const ['file_paths', 'resources'])
          if (r.data[column] is String && (r.data[column] as String).isNotEmpty)
            r.data[column] as String,
    ];
  }

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (_) {
      return null;
    }
  }

  /// Every string in [json] that is a `file://` url, wherever it sits.
  static Iterable<String> _fileUrls(Object? json) sync* {
    if (json is String) {
      if (json.startsWith(scheme)) yield json;
    } else if (json is Map) {
      for (final value in json.values) {
        yield* _fileUrls(value);
      }
    } else if (json is List) {
      for (final value in json) {
        yield* _fileUrls(value);
      }
    }
  }

  /// The paths a scan session's column names: the strings of `file_paths`
  /// (plain paths) and every `file://` url in `resources`.
  static Iterable<String> _sessionPaths(Object? json) sync* {
    if (json is List) {
      for (final item in json) {
        if (item is String) {
          yield item.startsWith(scheme) ? AttachmentRef(item).path : item;
        } else {
          for (final url in _fileUrls(item)) {
            yield AttachmentRef(url).path;
          }
        }
      }
    } else {
      for (final url in _fileUrls(json)) {
        yield AttachmentRef(url).path;
      }
    }
  }

  static final _urlInText = RegExp(r'''file://[^"'\s,}\]]*''');

  static Iterable<String> _urlsInText(String text) =>
      _urlInText.allMatches(text).map((m) => m.group(0)!);

  /// [name] in lower case, raw and percent-decoded.
  static Set<String> _variants(String name) => {
    name.toLowerCase(),
    _tryDecode(name).toLowerCase(),
    Uri.encodeComponent(name).toLowerCase(),
  };

  /// [text] percent-decoded, or as it is when it isn't encoded (a literal
  /// `%` in a file name, or bytes that aren't UTF-8).
  static String _tryDecode(String text) {
    try {
      return Uri.decodeComponent(text);
    } on ArgumentError catch (_) {
      return text;
    } on FormatException catch (_) {
      return text;
    }
  }

  static bool _matches(String basename, String url) {
    // Another scheme (https, data, …) is never a local file.
    if (!url.startsWith(scheme) && url.contains('://')) return false;
    final rest = url.startsWith(scheme) ? url.substring(scheme.length) : url;
    final wanted = _variants(basename);
    final candidates = {
      ..._variants(basenameOf(rest)),
      ..._variants(basenameOf(AttachmentRef(url).path)),
    };
    return wanted.any((w) => w.isNotEmpty && candidates.contains(w));
  }
}
