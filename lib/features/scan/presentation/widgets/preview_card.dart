import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/presentation/pages/preview/bloc/preview_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/preview/image_preview_page.dart';

class PreviewCard extends StatefulWidget {
  final List<String> imagePaths;
  final PageController pageController;

  const PreviewCard({
    super.key,
    required this.imagePaths,
    required this.pageController,
  });

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  late final PreviewBloc _previewBloc;

  @override
  void initState() {
    super.initState();
    _previewBloc = PreviewBloc();
    _previewBloc.add(const PreviewInitialized(initialPageIndex: 0));

    _previewBloc.stream.listen((state) {
      if (widget.pageController.hasClients) {
        final currentPage = widget.pageController.page?.round() ?? 0;
        if (currentPage != state.currentPageIndex) {
          widget.pageController.animateToPage(
            state.currentPageIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _previewBloc.close();
    super.dispose();
  }

  void _openFullScreenPreview(BuildContext context, int currentIndex) {
    if (widget.imagePaths.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _previewBloc,
          child: ImagePreviewPage(
            imagePath: widget.imagePaths[currentIndex],
            allImages: widget.imagePaths,
            currentIndex: currentIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) return const SizedBox.shrink();

    return BlocProvider.value(
      value: _previewBloc,
      child: BlocBuilder<PreviewBloc, PreviewState>(
        builder: (context, state) {
          return Column(
            children: [
              Stack(
                children: [
                  InkWell(
                    onTap: () => _openFullScreenPreview(
                      context,
                      state.currentPageIndex,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.theme.dividerColor),
                      ),
                      child: _ImagePageView(
                        imagePaths: widget.imagePaths,
                        pageController: widget.pageController,
                        previewBloc: _previewBloc,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _PreviewButton(
                      onTap: () => _openFullScreenPreview(
                        context,
                        state.currentPageIndex,
                      ),
                    ),
                  ),
                ],
              ),
              _PageIndicator(
                currentPage: state.currentPageIndex,
                totalPages: widget.imagePaths.length,
                pageController: widget.pageController,
                previewBloc: _previewBloc,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final PageController pageController;
  final PreviewBloc previewBloc;

  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
    required this.pageController,
    required this.previewBloc,
  });

  @override
  Widget build(BuildContext context) {
    final isFirstPage = currentPage == 0;
    final isLastPage = currentPage >= totalPages - 1;
    final disabledColor = context.colorScheme.onSurface.withOpacity(0.3);
    final enabledColor = context.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.small),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: isFirstPage
                ? null
                : () {
                    pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
            child: Icon(
              Icons.chevron_left,
              size: 24,
              color: isFirstPage ? disabledColor : enabledColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${currentPage + 1} of $totalPages',
            style: AppTextStyle.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLastPage
                ? null
                : () {
                    pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
            child: Icon(
              Icons.chevron_right,
              size: 24,
              color: isLastPage ? disabledColor : enabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PreviewButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(222),
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(
            top: 4,
            right: 16,
            bottom: 4,
            left: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(222),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.remove_red_eye,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Preview document',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePageView extends StatelessWidget {
  final List<String> imagePaths;
  final PageController pageController;
  final PreviewBloc previewBloc;

  const _ImagePageView({
    required this.imagePaths,
    required this.pageController,
    required this.previewBloc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      width: double.infinity,
      child: PageView.builder(
        controller: pageController,
        onPageChanged: (index) {
          previewBloc.add(PreviewPageChanged(pageIndex: index));
        },
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(Insets.normal),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imagePaths[index]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 40, color: Colors.red),
                          const SizedBox(height: 8),
                          const Text('Failed to load image'),
                          const SizedBox(height: 4),
                          Text(
                            'Index: $index',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
