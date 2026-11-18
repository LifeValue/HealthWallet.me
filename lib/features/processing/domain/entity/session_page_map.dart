import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_page_map.freezed.dart';

/// The PDF page a preview page was rendered from, so its 200 dpi OCR page can
/// be rendered again after the session's pages were edited and the app
/// restarted (the session then stores only the preview pages).
@Freezed(fromJson: false, toJson: false)
abstract class PageSource with _$PageSource {
  const PageSource._();

  const factory PageSource({
    /// The original PDF, stored like the session's file paths (relative to
    /// Documents where possible).
    required String file,

    /// The page in [file], from 1.
    required int page,

    /// Clockwise quarter turns the user gave the page, 0 to 3.
    @Default(0) int quarterTurns,
  }) = _PageSource;

  factory PageSource.fromJson(Map<String, dynamic> json) => PageSource(
    file: json['file'] as String,
    page: json['page'] as int,
    quarterTurns: (json['quarterTurns'] as int?) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'file': file,
    'page': page,
    'quarterTurns': quarterTurns,
  };
}

/// A processing session's page map, kept as
/// `pdf_preview_cache/<session id>.pages.json` next to its preview pages.
@Freezed(fromJson: false, toJson: false)
abstract class SessionPageMap with _$SessionPageMap {
  const SessionPageMap._();

  const factory SessionPageMap({
    /// Where each preview page came from, by the preview page's file name.
    @Default({}) Map<String, PageSource> pages,

    /// Cache keys of the 72 dpi preview pages rendered for the session.
    @Default({}) Set<String> previewKeys,

    /// Cache keys of the 200 dpi OCR pages rendered for the session.
    @Default({}) Set<String> ocrKeys,
  }) = _SessionPageMap;

  factory SessionPageMap.fromJson(Map<String, dynamic> json) => SessionPageMap(
    pages: {
      for (final MapEntry(:key, :value)
          in ((json['pages'] as Map?) ?? const {}).entries)
        key as String: PageSource.fromJson(
          (value as Map).cast<String, dynamic>(),
        ),
    },
    previewKeys: {...((json['previewKeys'] as List?) ?? const []).cast()},
    ocrKeys: {...((json['ocrKeys'] as List?) ?? const []).cast()},
  );

  Map<String, dynamic> toJson() => {
    'pages': {
      for (final MapEntry(:key, :value) in pages.entries) key: value.toJson(),
    },
    'previewKeys': previewKeys.toList(),
    'ocrKeys': ocrKeys.toList(),
  };

  bool get isEmpty => pages.isEmpty && previewKeys.isEmpty && ocrKeys.isEmpty;
}
