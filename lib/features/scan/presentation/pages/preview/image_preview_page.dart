import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/preview/bloc/preview_bloc.dart';

class ImagePreviewPage extends StatefulWidget {
  final String imagePath;
  final String title;
  final List<String>? allImages;
  final int? currentIndex;

  const ImagePreviewPage({
    super.key,
    required this.imagePath,
    this.title = 'Document Preview',
    this.allImages,
    this.currentIndex,
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
    final initialPage =
        widget.currentIndex ?? previewBloc.state.currentPageIndex;
    _pageController = PageController(
      initialPage: initialPage,
    );
    previewBloc.add(PreviewInitialized(initialPageIndex: initialPage));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PreviewBloc, PreviewState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              widget.allImages != null
                  ? '${state.currentPageIndex + 1} of ${widget.allImages!.length}'
                  : widget.title,
            ),
          ),
          body: widget.allImages != null && widget.allImages!.length > 1
              ? _buildPageView(context)
              : _buildSingleImage(),
        );
      },
    );
  }

  Widget _buildPageView(BuildContext context) {
    final previewBloc = context.read<PreviewBloc>();
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        previewBloc.add(PreviewPageChanged(pageIndex: index));
      },
      itemCount: widget.allImages!.length,
      itemBuilder: (context, index) {
        return _buildImageViewer(widget.allImages![index]);
      },
    );
  }

  Widget _buildSingleImage() {
    return _buildImageViewer(widget.imagePath);
  }

  Widget _buildImageViewer(String path) {
    final file = File(path);
    final exists = file.existsSync();

    if (!exists) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
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

    try {
      final stat = file.statSync();
      if (stat.size == 0) {
        return Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'File is empty',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // ignore
    }

    return Center(
      child: InteractiveViewer(
        panEnabled: true,
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4.0,
        child: FutureBuilder<FileImage>(
          future: Future.value(FileImage(file)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Path: $path',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Path: $path',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
