import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/scan/presentation/pages/preview/bloc/preview_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ImagePreviewPage extends StatefulWidget {
  final String imagePath;
  final String title;
  final List<String>? allImages;
  final int? currentIndex;
  final bool isEditable;

  const ImagePreviewPage({
    super.key,
    required this.imagePath,
    this.title = 'Document Preview',
    this.allImages,
    this.currentIndex,
    this.isEditable = false,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final previewBloc = context.read<PreviewBloc>();
    final images = widget.allImages ?? [widget.imagePath];
    final initialPage =
        widget.currentIndex ?? previewBloc.state.currentPageIndex;
    _pageController = PageController(initialPage: initialPage);
    previewBloc.add(PreviewInitialized(
      initialPageIndex: initialPage,
      images: images,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDeleteTapped(int currentIndex) {
    final bloc = context.read<PreviewBloc>();
    if (bloc.state.images.length <= 1) return;

    AppSimpleDialog.showDestructiveConfirmation(
      context: context,
      title: context.l10n.deletePageConfirmTitle,
      message: context.l10n.deletePageConfirmMessage,
      confirmText: context.l10n.deletePage,
      cancelText: context.l10n.cancel,
      onConfirm: () {
        bloc.add(PreviewPageDeleted(pageIndex: currentIndex));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PreviewBloc, PreviewState>(
      listenWhen: (prev, curr) =>
          prev.currentPageIndex != curr.currentPageIndex ||
          prev.images.length != curr.images.length,
      listener: (context, state) {
        if (_pageController.hasClients &&
            !state.isReordering &&
            _pageController.page?.round() != state.currentPageIndex) {
          _pageController.jumpToPage(state.currentPageIndex);
        }
      },
      builder: (context, state) {
        final images = state.images;
        if (images.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final currentIndex =
            state.currentPageIndex.clamp(0, images.length - 1);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final bloc = context.read<PreviewBloc>();
            if (state.isReordering) {
              bloc.add(const PreviewReorderModeToggled(enabled: false));
              return;
            }
            Navigator.of(context)
                .pop(state.hasChanges ? state.images : null);
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                state.isReordering
                    ? context.l10n.reorderPages
                    : images.length > 1
                        ? '${currentIndex + 1} of ${images.length}'
                        : widget.title,
              ),
              actions: [
                if (state.isReordering)
                  TextButton(
                    onPressed: () => context
                        .read<PreviewBloc>()
                        .add(const PreviewReorderModeToggled(enabled: false)),
                    child: Text(
                      context.l10n.done,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
            body: Stack(
              children: [
                if (state.isReordering)
                  _ReorderGrid(
                    images: images,
                    onReorder: (oldIndex, newIndex) {
                      context.read<PreviewBloc>().add(PreviewPagesReordered(
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          ));
                    },
                  )
                else ...[
                  images.length > 1
                      ? _buildPageView(context, images)
                      : _buildSingleImage(images.first),
                  if (state.isRotating)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
                if (widget.isEditable)
                  Positioned(
                    left: 48,
                    right: 48,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: _BottomActionBar(
                      onReorder: images.length > 1
                          ? () => context.read<PreviewBloc>().add(
                              const PreviewReorderModeToggled(enabled: true))
                          : null,
                      onRotate: state.isReordering
                          ? null
                          : () => context.read<PreviewBloc>().add(
                              PreviewPageRotated(pageIndex: currentIndex)),
                      onDelete: state.isReordering || state.images.length <= 1
                          ? null
                          : () => _onDeleteTapped(currentIndex),
                      isReordering: state.isReordering,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageView(BuildContext context, List<String> images) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        context.read<PreviewBloc>().add(PreviewPageChanged(pageIndex: index));
      },
      itemCount: images.length,
      itemBuilder: (context, index) {
        return _buildImageViewer(images[index]);
      },
    );
  }

  Widget _buildSingleImage(String imagePath) {
    return _buildImageViewer(imagePath);
  }

  Widget _buildImageViewer(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return FutureBuilder<String>(
        future: getIt<PathResolver>().toAbsolute(imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          final resolvedPath = snapshot.data ?? imagePath;
          final resolvedFile = File(resolvedPath);
          if (resolvedFile.existsSync()) {
            return _buildImageContent(resolvedFile, resolvedPath);
          }
          return _buildFileNotFound(imagePath);
        },
      );
    }
    return _buildImageContent(file, imagePath);
  }

  Widget _buildFileNotFound(String path) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'File not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Path: $path',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(File file, String path) {
    try {
      final stat = file.statSync();
      if (stat.size == 0) {
        return Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 64),
              SizedBox(height: 16),
              Text(
                'File is empty',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );
      }
    } catch (_) {}

    return Center(
      child: InteractiveViewer(
        panEnabled: true,
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          file,
          fit: BoxFit.contain,
          key: ValueKey(
              '${file.path}_${file.lastModifiedSync().millisecondsSinceEpoch}'),
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.image_not_supported_outlined,
                  size: 40, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }
}

class _ReorderGrid extends StatelessWidget {
  final List<String> images;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _ReorderGrid({
    required this.images,
    required this.onReorder,
  });

  void _showQuickPreview(BuildContext context, String path, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _QuickPreviewOverlay(
          path: path,
          index: index,
          total: images.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ReorderableGridView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        dragStartDelay: const Duration(milliseconds: 100),
        itemCount: images.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final path = images[index];
          return ReorderableDragStartListener(
            key: ValueKey(path),
            index: index,
            child: GestureDetector(
              onTap: () => _showQuickPreview(context, path, index),
              child: _GridTile(path: path, index: index),
            ),
          );
        },
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final String path;
  final int index;

  const _GridTile({required this.path, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.image,
                      color: Colors.white38, size: 32),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(7)),
            ),
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final VoidCallback? onReorder;
  final VoidCallback? onRotate;
  final VoidCallback? onDelete;
  final bool isReordering;

  const _BottomActionBar({
    required this.onReorder,
    required this.onRotate,
    required this.onDelete,
    this.isReordering = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.swap_vert,
            label: context.l10n.reorderPages,
            onTap: onReorder,
            isActive: isReordering,
          ),
          _ActionButton(
            icon: Icons.rotate_right,
            label: context.l10n.rotatePage,
            onTap: onRotate,
          ),
          _ActionButton(
            iconWidget: Assets.icons.trashCan.svg(
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                onDelete != null ? Colors.white : Colors.white38,
                BlendMode.srcIn,
              ),
            ),
            label: context.l10n.deletePage,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  const _ActionButton({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
    this.isActive = false,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final color = isActive
        ? Colors.blueAccent
        : isEnabled
            ? Colors.white
            : Colors.white38;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null)
              iconWidget!
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPreviewOverlay extends StatelessWidget {
  final String path;
  final int index;
  final int total;

  const _QuickPreviewOverlay({
    required this.path,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text('${index + 1} of $total'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
