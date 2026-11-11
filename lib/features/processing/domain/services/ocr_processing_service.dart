import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/domain/entity/session_page_map.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

@injectable
class OcrProcessingHelper {
  final TextRecognitionService _textRecognitionService;
  final PathResolver _pathResolver;

  OcrProcessingHelper(this._textRecognitionService, this._pathResolver);

  /// Resolution of the PDF pages OCR and the AI read. The preview keeps
  /// 72 dpi, which is too coarse for small print.
  static const ocrDpi = 200.0;

  /// The page-set work still running per session, so the edits of a session
  /// apply in order and never read a page map another call is writing.
  final _sessionWork = <String, Future<void>>{};

  Future<String> processOcrForImages(List<String> imagePaths) async {
    final pageTexts = <String>[];

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        continue;
      }

      final text = await _textRecognitionService.recognizeTextFromImage(
        imagePath,
      );

      if (text.isNotEmpty) {
        pageTexts.add(text);
      }
    }

    return pageTexts.join('\n');
  }

  /// The 72 dpi preview pages of [filePaths]: images as they are, PDFs one
  /// image per page.
  /// The pages of [filePaths] as images: photos as they are, PDF pages
  /// rendered at [dpi] (the preview's 72 unless OCR reads them directly).
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
    double dpi = 72,
  }) async {
    final allImages = <String>[];

    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];

      if (_textRecognitionService.isImage(path)) {
        allImages.add(path);
      } else {
        try {
          final convertedImages = await _textRecognitionService
              .convertPdfToImagesForPreview(path, dpi: dpi);
          allImages.addAll(convertedImages);
        } catch (e, stackTrace) {
          logger.e(
            'prepareAllImages - Error converting PDF: $e',
            e,
            stackTrace,
          );
        }
      }
    }

    return allImages;
  }

  /// Renders the 200 dpi OCR page of every PDF preview page in
  /// [previewPaths] and returns them by preview page.
  ///
  /// Where each preview page of the PDFs in [filePaths] came from is added to
  /// the session's page map; preview pages of a session whose pages were
  /// edited (the session then stores only its preview pages) are looked up
  /// there, so their pages are rendered from the original PDF again. A page
  /// keeps the rotation the user gave it. A page that is not from a PDF (a
  /// photo) is read as it is and left out; a PDF page that can't be rendered
  /// again is logged and left out, so OCR reads its 72 dpi preview page.
  Future<Map<String, String>> prepareOcrPages({
    required String sessionId,
    required List<String> filePaths,
    required List<String> previewPaths,
  }) => _serialized(sessionId, () async {
    final cacheDir = await _cacheDirectory();
    final map = await _withSources(
      await _readPageMap(cacheDir, sessionId),
      filePaths,
    );

    final byFile = <String, List<(String, PageSource)>>{};
    for (final preview in previewPaths) {
      final name = p.basename(preview);
      if (!TempFileSweeper.ocrCachePagePattern.hasMatch(name)) continue;
      final source = map.pages[name];
      if (source == null) {
        logger.w('OCR page set: no source for $name; OCR reads it at 72 dpi');
        continue;
      }
      byFile.putIfAbsent(source.file, () => []).add((preview, source));
    }

    final ocrPages = <String, String>{};
    final ocrKeys = {...map.ocrKeys};
    for (final MapEntry(key: file, value: sources) in byFile.entries) {
      final rendered = await _renderOcrPages(file);
      if (rendered == null) continue;
      ocrKeys.addAll(rendered.keys);
      for (final (preview, source) in sources) {
        final page = rendered.pages[source.page];
        if (page == null) {
          logger.w(
            'OCR page set: page ${source.page} of $file was not rendered; '
            'OCR reads it at 72 dpi',
          );
          continue;
        }
        try {
          ocrPages[preview] = await _turned(page, source.quarterTurns);
        } catch (e, s) {
          logger.w('OCR page set: rotating $page failed', e, s);
        }
      }
    }

    await _writePageMap(cacheDir, sessionId, map.copyWith(ocrKeys: ocrKeys));
    return ocrPages;
  });

  /// Records that the user turned [previewPath] by [quarterTurns] clockwise
  /// quarter turns and returns its OCR page turned the same way, or null when
  /// it has none: a photo (turned in place by the preview), or a session
  /// whose OCR pages aren't rendered yet (they are rendered turned).
  /// [filePaths] are the session's files, so a turn made before the OCR pages
  /// are prepared is still recorded.
  Future<String?> rotateOcrPage({
    required String sessionId,
    required List<String> filePaths,
    required String previewPath,
    required int quarterTurns,
  }) => _serialized(sessionId, () async {
    final cacheDir = await _cacheDirectory();
    final map = await _withSources(
      await _readPageMap(cacheDir, sessionId),
      filePaths,
    );
    final name = p.basename(previewPath);
    final source = map.pages[name];
    if (source == null) return null;

    final turned = source.copyWith(
      quarterTurns: (source.quarterTurns + quarterTurns) % 4,
    );
    await _writePageMap(
      cacheDir,
      sessionId,
      map.copyWith(pages: {...map.pages, name: turned}),
    );

    // Not prepared yet: preparing renders the page turned.
    if (map.ocrKeys.isEmpty) return null;
    final rendered = await _renderOcrPages(turned.file);
    final page = rendered?.pages[turned.page];
    if (page == null) return null;
    return _turned(page, turned.quarterTurns);
  });

  /// Drops the page map entries of the pages no longer in [previewPaths],
  /// after the user reordered or deleted pages. [filePaths] are the session's
  /// files before the edit (the session then stores only its preview pages),
  /// so the sources are recorded even when the OCR pages aren't prepared yet.
  Future<void> keepOcrPages({
    required String sessionId,
    required List<String> filePaths,
    required List<String> previewPaths,
  }) => _serialized(sessionId, () async {
    final cacheDir = await _cacheDirectory();
    final map = await _withSources(
      await _readPageMap(cacheDir, sessionId),
      filePaths,
    );
    final kept = previewPaths.map(p.basename).toSet();
    final pages = {
      for (final entry in map.pages.entries)
        if (kept.contains(entry.key)) entry.key: entry.value,
    };
    await _writePageMap(cacheDir, sessionId, map.copyWith(pages: pages));
  });

  /// Deletes the session's 200 dpi OCR pages once its records are saved.
  /// [ocrPages] are OCR pages the caller knows of, for a session whose page
  /// map is gone. The rest of the page map stays for
  /// [discardSessionPages]: the preview pages, and the imported original
  /// that a session whose pages were edited knows only from there (the saved
  /// documents are copies, so they don't need it).
  Future<void> discardOcrPages({
    required String sessionId,
    Iterable<String> ocrPages = const [],
  }) => _serialized(sessionId, () async {
    final cacheDir = await _cacheDirectory();
    final map = await _readPageMap(cacheDir, sessionId);
    await _deleteCacheKeys(cacheDir, {...map.ocrKeys, ..._keysOf(ocrPages)});
    final rest = map.copyWith(ocrKeys: const {});
    if (rest.isEmpty) {
      await _deletePageMap(cacheDir, sessionId);
    } else {
      await _writePageMap(cacheDir, sessionId, rest);
    }
  });

  /// Deletes every page image of the session, 72 dpi previews and 200 dpi
  /// OCR pages, and its page map, when the session is deleted. [pages] are
  /// pages the caller knows of (preview and OCR), for a session whose page
  /// map is gone; only those in the page cache are deleted.
  ///
  /// Once its pages were edited the session stores only preview pages, so
  /// the original imported files the page map records are deleted here too
  /// (only those in `imports/`).
  Future<void> discardSessionPages({
    required String sessionId,
    Iterable<String> pages = const [],
  }) => _serialized(sessionId, () async {
    final cacheDir = await _cacheDirectory();
    final map = await _readPageMap(cacheDir, sessionId);
    await _deleteImportedOriginals(map);
    await _deleteCacheKeys(cacheDir, {
      ...map.previewKeys,
      ...map.ocrKeys,
      ...map.pages.keys.expand((name) => _keysOf([name])),
      ..._keysOf(pages),
    });
    await _deletePageMap(cacheDir, sessionId);
  });

  /// [map] with where each preview page of the PDFs in [filePaths] came
  /// from; a page already recorded keeps its turns.
  Future<SessionPageMap> _withSources(
    SessionPageMap map,
    List<String> filePaths,
  ) async {
    final pages = {...map.pages};
    final previewKeys = {...map.previewKeys};
    for (final file in filePaths) {
      if (!_textRecognitionService.isPDF(file)) continue;
      // The preview has just rendered them: these come from its cache.
      final previews = await _textRecognitionService
          .convertPdfToImagesForPreview(file);
      final stored = await _pathResolver.toRelative(file);
      for (final preview in previews) {
        final name = p.basename(preview);
        final match = TempFileSweeper.ocrCachePagePattern.firstMatch(name);
        if (match == null) continue;
        previewKeys.add(match.group(1)!);
        final known = pages[name];
        if (known != null && known.file == stored) continue;
        pages[name] = PageSource(file: stored, page: int.parse(match[2]!));
      }
    }
    return map.copyWith(pages: pages, previewKeys: previewKeys);
  }

  Future<void> _deleteImportedOriginals(SessionPageMap map) async {
    if (map.pages.isEmpty) return;
    final String imports;
    try {
      final docs = await getApplicationDocumentsDirectory();
      imports = p.join(docs.path, 'imports');
    } catch (e, s) {
      logger.w('OCR page set: finding the imports directory failed', e, s);
      return;
    }
    for (final stored in map.pages.values.map((s) => s.file).toSet()) {
      try {
        final original = File(await _pathResolver.toAbsolute(stored));
        if (!p.isWithin(imports, original.path)) continue;
        if (await original.exists()) await original.delete();
      } catch (e, s) {
        logger.w('OCR page set: deleting the original $stored failed', e, s);
      }
    }
  }

  Future<T> _serialized<T>(String sessionId, Future<T> Function() work) {
    final previous = _sessionWork[sessionId] ?? Future<void>.value();
    final result = previous.then((_) => work());
    final done = result.then<void>((_) {}, onError: (_) {});
    _sessionWork[sessionId] = done;
    unawaited(
      done.then((_) {
        if (identical(_sessionWork[sessionId], done)) {
          _sessionWork.remove(sessionId);
        }
      }),
    );
    return result;
  }

  /// The 200 dpi pages of the PDF stored as [file], by page number, or null
  /// when it is gone or renders nothing.
  Future<_RenderedPdf?> _renderOcrPages(String file) async {
    final absolute = await _pathResolver.toAbsolute(file);
    if (!await File(absolute).exists()) {
      logger.w('OCR page set: $file is gone; OCR reads its 72 dpi pages');
      return null;
    }
    final rendered = await _textRecognitionService.convertPdfToImagesForPreview(
      absolute,
      dpi: ocrDpi,
    );
    final pages = <int, String>{};
    final keys = <String>{};
    for (final path in rendered) {
      final match = TempFileSweeper.ocrCachePagePattern.firstMatch(
        p.basename(path),
      );
      if (match == null) continue;
      keys.add(match.group(1)!);
      pages[int.parse(match[2]!)] = path;
    }
    if (pages.isEmpty) {
      logger.w(
        'OCR page set: $file rendered no 200 dpi pages; OCR reads its '
        '72 dpi pages',
      );
      return null;
    }
    return _RenderedPdf(pages, keys);
  }

  /// [page] turned by [quarterTurns]: the page itself, or a turned copy next
  /// to it. The rendered page stays as rendered, so it can be turned again
  /// from scratch.
  Future<String> _turned(String page, int quarterTurns) async {
    if (quarterTurns % 4 == 0) return page;
    final turnedPath = page.replaceFirst(
      RegExp(r'\.jpg$'),
      '_r${quarterTurns % 4}.jpg',
    );
    final turnedFile = File(turnedPath);
    if (await turnedFile.exists()) return turnedPath;
    final bytes = await File(page).readAsBytes();
    // Written aside and renamed, so a crash never leaves half a page that
    // would be reused.
    final pending = File('$turnedPath.tmp');
    await pending.writeAsBytes(
      await _rotateJpeg(bytes, quarterTurns),
      flush: true,
    );
    await pending.rename(turnedPath);
    return turnedPath;
  }

  Future<Directory> _cacheDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, TempFileSweeper.ocrCacheDirName));
  }

  File _pageMapFile(Directory cacheDir, String sessionId) => File(
    p.join(cacheDir.path, TempFileSweeper.sessionPageMapName(sessionId)),
  );

  Future<SessionPageMap> _readPageMap(
    Directory cacheDir,
    String sessionId,
  ) async {
    final file = _pageMapFile(cacheDir, sessionId);
    try {
      if (!await file.exists()) return const SessionPageMap();
      return SessionPageMap.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (e, s) {
      logger.w('OCR page set: the page map of $sessionId is unreadable', e, s);
      return const SessionPageMap();
    }
  }

  Future<void> _writePageMap(
    Directory cacheDir,
    String sessionId,
    SessionPageMap map,
  ) async {
    if (map.isEmpty) return;
    final file = _pageMapFile(cacheDir, sessionId);
    // Written aside and renamed, so a crash never leaves half a map.
    final pending = File('${file.path}.tmp');
    try {
      await cacheDir.create(recursive: true);
      await pending.writeAsString(jsonEncode(map.toJson()), flush: true);
      await pending.rename(file.path);
    } catch (e, s) {
      // Only an edited session reopened after a restart needs it; without it
      // OCR reads that session's 72 dpi pages.
      logger.w('OCR page set: saving the page map of $sessionId failed', e, s);
    }
  }

  Future<void> _deletePageMap(Directory cacheDir, String sessionId) async {
    final file = _pageMapFile(cacheDir, sessionId);
    for (final map in [file, File('${file.path}.tmp')]) {
      try {
        if (await map.exists()) await map.delete();
      } catch (e, s) {
        logger.w(
          'OCR page set: deleting the page map of $sessionId failed',
          e,
          s,
        );
      }
    }
  }

  static Iterable<String> _keysOf(Iterable<String> pages) sync* {
    for (final page in pages) {
      final match = TempFileSweeper.ocrCachePagePattern.firstMatch(
        p.basename(page),
      );
      if (match != null) yield match.group(1)!;
    }
  }

  /// Deletes `<key>.json` and every `<key>_page_*` image of [keys].
  Future<void> _deleteCacheKeys(Directory cacheDir, Set<String> keys) async {
    if (keys.isEmpty) return;
    final List<FileSystemEntity> entries;
    try {
      if (!await cacheDir.exists()) return;
      entries = await cacheDir.list(followLinks: false).toList();
    } catch (e, s) {
      logger.w('OCR page set: listing the page cache failed', e, s);
      return;
    }
    for (final entry in entries) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      // A `.tmp` page is a turned copy a crash left half written.
      final match = TempFileSweeper.ocrCachePagePattern.firstMatch(
        name.endsWith('.jpg.tmp') ? name.substring(0, name.length - 4) : name,
      );
      final key = match?.group(1) ?? p.basenameWithoutExtension(name);
      final ours = match != null || name == '$key.json';
      if (!ours || !keys.contains(key)) continue;
      try {
        await entry.delete();
      } catch (e, s) {
        logger.w('OCR page set: deleting $name failed', e, s);
      }
    }
  }
}

class _RenderedPdf {
  _RenderedPdf(this.pages, this.keys);

  final Map<int, String> pages;
  final Set<String> keys;
}

/// Turns the JPEG [bytes] by [quarterTurns] clockwise quarter turns, off the
/// UI isolate: a 200 dpi page is about 15 MB of pixels.
Future<Uint8List> _rotateJpeg(Uint8List bytes, int quarterTurns) =>
    Isolate.run(() => rotateJpegQuarterTurns(bytes, quarterTurns));

/// [bytes] (a JPEG) turned by [quarterTurns] clockwise quarter turns.
Uint8List rotateJpegQuarterTurns(Uint8List bytes, int quarterTurns) {
  final image = img.decodeJpg(bytes);
  if (image == null) throw const FormatException('Not a JPEG page');
  final turned = img.copyRotate(image, angle: 90 * (quarterTurns % 4));
  return img.encodeJpg(turned, quality: 85);
}
