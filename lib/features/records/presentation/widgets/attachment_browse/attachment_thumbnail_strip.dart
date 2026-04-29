import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_browse_view.dart';
import 'package:health_wallet/core/utils/pdf_thumbnail_utils.dart';

class AttachmentThumbnailStrip extends StatelessWidget {
  final List<AttachmentBrowseEntry> records;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ScrollController scrollController;
  final bool isSelectionMode;
  final Set<String> selectedResourceIds;
  final ValueChanged<String>? onSelectionToggle;
  final VoidCallback? onSelectionModeToggled;

  const AttachmentThumbnailStrip({
    super.key,
    required this.records,
    required this.selectedIndex,
    required this.onSelected,
    required this.scrollController,
    this.isSelectionMode = false,
    this.selectedResourceIds = const {},
    this.onSelectionToggle,
    this.onSelectionModeToggled,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: kThumbnailPadding),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(width: kThumbnailGap),
      itemBuilder: (context, index) {
        final entry = records[index];
        final isCurrent = index == selectedIndex;
        final isChecked = selectedResourceIds.contains(entry.record.id);
        final hasFile = entry.thumbnailPath != null;

        return GestureDetector(
          onTap: () {
            if (isSelectionMode) {
              onSelectionToggle?.call(entry.record.id);
            } else {
              onSelected(index);
            }
          },
          onLongPress: isSelectionMode || onSelectionModeToggled == null
              ? null
              : () {
                  onSelectionModeToggled?.call();
                  onSelectionToggle?.call(entry.record.id);
                },
          child: _ThumbnailFrame(
            isCurrent: isCurrent,
            isChecked: isChecked,
            isDashed: isSelectionMode && !isChecked,
            hasFile: hasFile,
            entry: entry,
          ),
        );
      },
    );
  }
}

class _ThumbnailContent extends StatefulWidget {
  final AttachmentBrowseEntry entry;

  const _ThumbnailContent({required this.entry});

  @override
  State<_ThumbnailContent> createState() => _ThumbnailContentState();
}

class _ThumbnailContentState extends State<_ThumbnailContent> {
  Uint8List? _pdfBytes;
  bool _triedPdf = false;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _tryLoadPreview();
  }

  @override
  void didUpdateWidget(_ThumbnailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.thumbnailPath != widget.entry.thumbnailPath) {
      _pdfBytes = null;
      _triedPdf = false;
      _imageLoadFailed = false;
      _tryLoadPreview();
    }
  }

  bool get _isImage {
    final path = widget.entry.thumbnailPath?.toLowerCase() ?? '';
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp');
  }

  void _tryLoadPreview() {
    if (widget.entry.thumbnailPath == null) return;
    if (_isImage) return;
    _triedPdf = true;
    _renderPdfThumb(widget.entry.thumbnailPath!);
  }

  void _onImageError() {
    if (_triedPdf || _imageLoadFailed) return;
    _imageLoadFailed = true;
    _triedPdf = true;
    _renderPdfThumb(widget.entry.thumbnailPath!);
  }

  Future<void> _renderPdfThumb(String filePath) async {
    final bytes = await renderPdfFirstPage(filePath);
    if (mounted && bytes != null) {
      setState(() => _pdfBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfBytes != null) {
      return Image.memory(
        _pdfBytes!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    }

    if (widget.entry.thumbnailPath != null && _isImage && !_imageLoadFailed) {
      return Image.file(
        File(widget.entry.thumbnailPath!),
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
          return _TitleFallback(title: widget.entry.record.title);
        },
      );
    }

    if (widget.entry.thumbnailPath != null && !_isImage && !_triedPdf) {
      return _TitleFallback(title: widget.entry.record.title);
    }

    return _TitleFallback(title: widget.entry.record.title);
  }
}

class _ThumbnailFrame extends StatelessWidget {
  final bool isCurrent;
  final bool isChecked;
  final bool isDashed;
  final bool hasFile;
  final AttachmentBrowseEntry entry;

  const _ThumbnailFrame({
    required this.isCurrent,
    required this.isChecked,
    required this.isDashed,
    required this.hasFile,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isChecked
        ? AppColors.primary.withValues(alpha: 0.15)
        : hasFile
            ? Colors.white
            : context.isDarkMode
                ? context.colorScheme.surface
                : Colors.grey.shade100;

    final child = SizedBox(
      width: kThumbnailItemWidth,
      height: kThumbnailItemWidth,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: fillColor,
              child: _ThumbnailContent(entry: entry),
            ),
          ),
          if (isChecked)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );

    if (isDashed) {
      return CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: context.colorScheme.onSurface.withValues(alpha: 0.3),
          borderRadius: 8,
          dashWidth: 5,
          dashGap: 4,
          strokeWidth: 1.5,
        ),
        child: child,
      );
    }

    return Container(
      width: kThumbnailItemWidth,
      height: kThumbnailItemWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked
              ? AppColors.primary
              : isCurrent
                  ? AppColors.primary
                  : context.colorScheme.onSurface.withValues(alpha: 0.24),
          width: isChecked || isCurrent ? 3 : 1,
        ),
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}

class _TitleFallback extends StatelessWidget {
  final String title;

  const _TitleFallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          title,
          style: AppTextStyle.labelSmall.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.85),
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
