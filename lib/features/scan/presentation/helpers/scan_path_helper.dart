import 'dart:io';

import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';

class ScanPathHelper {
  static final RegExp _uriPattern =
      RegExp(r'(?:file|content)://[^\s,\]\}]+', caseSensitive: false);

  const ScanPathHelper._();

  static List<String> normalizePaths(dynamic scannedDocuments) {
    if (scannedDocuments == null) {
      return [];
    }

    final rawValues = <String>[];

    if (scannedDocuments is Map) {
      rawValues.addAll(_extractPathsFromMap(scannedDocuments));
    } else if (scannedDocuments is List) {
      rawValues.addAll(
        scannedDocuments
            .map((entry) => entry?.toString() ?? '')
            .where((value) => value.isNotEmpty),
      );
    } else {
      rawValues.add(scannedDocuments.toString());
    }

    final candidates = rawValues.expand((value) {
      final matches = _uriPattern.allMatches(value);
      if (matches.isEmpty) {
        return [value];
      }
      return matches.map((match) => match.group(0)!);
    });

    return candidates
        .map(_sanitizeToFilePath)
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();
  }

  static Future<List<String>> persistScanFiles({
    required List<String> sourcePaths,
    required ScanRepository repository,
  }) async {
    if (sourcePaths.isEmpty) {
      return [];
    }

    final persistedPaths = <String>[];

    for (final rawPath in sourcePaths) {
      final sanitizedPath = _sanitizeToFilePath(rawPath);
      if (sanitizedPath.isEmpty || sanitizedPath.startsWith('content://')) {
        continue;
      }

      try {
        final sourceFile = File(sanitizedPath);
        if (!await sourceFile.exists()) {
          continue;
        }

        final savedPath = await repository.saveScannedDocument(sanitizedPath);
        persistedPaths.add(savedPath);
      } catch (_) {}
    }

    return persistedPaths;
  }

  static String? extractPdfPath(dynamic scannedPdf) {
    if (scannedPdf == null) {
      return null;
    }

    if (scannedPdf is Map && scannedPdf['pdfUri'] != null) {
      return _sanitizeToFilePath(scannedPdf['pdfUri'].toString());
    }

    return _sanitizeToFilePath(scannedPdf.toString());
  }

  static List<String> _extractPathsFromMap(Map<dynamic, dynamic> map) {
    final collected = <String>[];

    for (final entry in map.entries) {
      final key = entry.key?.toString().toLowerCase() ?? '';
      if (key.contains('uri') || key.contains('path')) {
        final value = entry.value;
        if (value is List) {
          collected.addAll(
            value.map((element) => element?.toString() ?? ''),
          );
        } else if (value != null) {
          collected.add(value.toString());
        }
      }
    }

    if (collected.isEmpty && map.containsKey('pages')) {
      collected.add(map['pages'].toString());
    }

    return collected.where((value) => value.isNotEmpty).toList();
  }

  static String _sanitizeToFilePath(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return '';
    }

    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uriMatch = _uriPattern.firstMatch(trimmed);
    final candidate = uriMatch?.group(0) ?? trimmed;

    if (candidate.startsWith('file://')) {
      try {
        return Uri.parse(candidate).toFilePath();
      } catch (_) {
        return candidate.replaceFirst('file://', '');
      }
    }

    if (candidate.startsWith('/')) {
      return candidate;
    }

    return candidate;
  }
}



