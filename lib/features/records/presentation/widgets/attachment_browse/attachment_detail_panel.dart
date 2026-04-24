import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/utils/pdf_thumbnail_utils.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_notes/record_notes_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class AttachmentDetailPanel extends StatefulWidget {
  final AttachmentBrowseDetail detail;

  const AttachmentDetailPanel({
    super.key,
    required this.detail,
  });

  @override
  State<AttachmentDetailPanel> createState() => _AttachmentDetailPanelState();
}

class _AttachmentDetailPanelState extends State<AttachmentDetailPanel> {
  String _currentFileName = '';
  bool _startFromEnd = false;
  String _lastRecordId = '';

  @override
  void initState() {
    super.initState();
    _lastRecordId = widget.detail.record.id;
    _currentFileName = widget.detail.attachments.isNotEmpty
        ? widget.detail.attachments.first.title
        : '';
  }

  @override
  void didUpdateWidget(AttachmentDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.detail.record.id != widget.detail.record.id;
    final attachmentsChanged =
        oldWidget.detail.attachments.length != widget.detail.attachments.length;
    if (idChanged) {
      final bloc = context.read<AttachmentBrowseBloc>();
      final records = bloc.state.records;
      final oldIdx = records.indexWhere((e) => e.record.id == _lastRecordId);
      final newIdx = records.indexWhere((e) => e.record.id == widget.detail.record.id);
      _startFromEnd = oldIdx != -1 && newIdx != -1 && newIdx < oldIdx;
      _lastRecordId = widget.detail.record.id;
    }
    if (idChanged || attachmentsChanged) {
      _currentFileName = _startFromEnd && widget.detail.attachments.isNotEmpty
          ? widget.detail.attachments.last.title
          : widget.detail.attachments.isNotEmpty
              ? widget.detail.attachments.first.title
              : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Insets.extraSmall),
          Text(
            detail.record.title,
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: Insets.smallNormal),
          _AttachmentPreview(
            detail: detail,
            startFromEnd: _startFromEnd,
            onFileNameChanged: (name) {
              setState(() => _currentFileName = name);
            },
            onSwipeNextRecord: () {
              context.read<AttachmentBrowseBloc>().add(
                    AttachmentBrowseSelected(
                      context.read<AttachmentBrowseBloc>().state.selectedIndex + 1,
                    ),
                  );
            },
            onSwipePrevRecord: () {
              context.read<AttachmentBrowseBloc>().add(
                    AttachmentBrowseSelected(
                      context.read<AttachmentBrowseBloc>().state.selectedIndex - 1,
                    ),
                  );
            },
          ),
          const SizedBox(height: Insets.small),
          _FileInfoRow(detail: detail, currentFileName: _currentFileName),
          if (detail.patientName != null ||
              detail.organizationName != null ||
              detail.practitionerName != null) ...[
            const SizedBox(height: Insets.normal),
            _AttachmentBrowseDetailsCard(detail: detail),
          ],
          const SizedBox(height: Insets.smallNormal),
          _ShowDetailsButton(detail: detail),
          const SizedBox(height: Insets.normal),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatefulWidget {
  final AttachmentBrowseDetail detail;
  final bool startFromEnd;
  final ValueChanged<String>? onFileNameChanged;
  final VoidCallback? onSwipeNextRecord;
  final VoidCallback? onSwipePrevRecord;

  const _AttachmentPreview({
    required this.detail,
    this.startFromEnd = false,
    this.onFileNameChanged,
    this.onSwipeNextRecord,
    this.onSwipePrevRecord,
  });

  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  static final Map<String, List<_PreviewPage>> _cache = {};

  final List<_PreviewPage> _pages = [];
  int _currentPage = 0;
  bool _loading = true;
  bool _didTriggerEdge = false;
  final PageController _pageController = PageController();
  String _loadedRecordId = '';

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  @override
  void didUpdateWidget(_AttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.detail.record.id != widget.detail.record.id;
    final attachmentsChanged =
        oldWidget.detail.attachments.length != widget.detail.attachments.length;
    debugPrint('[PREVIEW] didUpdateWidget idChanged=$idChanged attachmentsChanged=$attachmentsChanged '
        'oldId=${oldWidget.detail.record.id} newId=${widget.detail.record.id} '
        'oldAttach=${oldWidget.detail.attachments.length} newAttach=${widget.detail.attachments.length}');
    if (idChanged || attachmentsChanged) {
      if (attachmentsChanged && !idChanged) {
        _cache.remove(widget.detail.record.id);
        _loadedRecordId = '';
      }
      _loadPages();
    }
  }

  void _loadPages() {
    final recordId = widget.detail.record.id;
    debugPrint('[PREVIEW] _loadPages recordId=$recordId _loadedRecordId=$_loadedRecordId '
        'pagesNotEmpty=${_pages.isNotEmpty} cacheKeys=${_cache.keys.toList()}');

    if (recordId == _loadedRecordId && _pages.isNotEmpty) {
      debugPrint('[PREVIEW] skipped — already loaded');
      return;
    }

    final cached = _cache[recordId];
    if (cached != null && cached.isNotEmpty) {
      final startPage = widget.startFromEnd ? cached.length - 1 : 0;
      debugPrint('[PREVIEW] cache HIT for $recordId (${cached.length} pages) startFromEnd=${widget.startFromEnd} → page $startPage');
      _pages.clear();
      _pages.addAll(cached);
      _loading = false;
      _currentPage = startPage;
      _loadedRecordId = recordId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          if (_pageController.hasClients) _pageController.jumpToPage(_currentPage);
          _notifyFileName();
        }
      });
      return;
    }

    if (widget.detail.attachments.isEmpty) {
      debugPrint('[PREVIEW] no attachments for $recordId');
      _pages.clear();
      _loading = false;
      _loadedRecordId = recordId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }

    debugPrint('[PREVIEW] cache MISS — building ${widget.detail.attachments.length} attachments for $recordId');
    _loadedRecordId = recordId;
    _buildPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _buildPages() async {
    setState(() => _loading = true);
    final pages = <_PreviewPage>[];
    debugPrint('[PREVIEW] _buildPages: ${widget.detail.attachments.length} attachments');

    for (final attachment in widget.detail.attachments) {
      debugPrint('[PREVIEW]   file: ${attachment.title} path=${attachment.filePath} type=${attachment.contentType}');
      if (attachment.filePath == null) continue;
      final path = attachment.filePath!;
      final ct = attachment.contentType?.toLowerCase() ?? '';
      final isPdf = ct == 'application/pdf' || path.toLowerCase().endsWith('.pdf');

      if (isPdf) {
        try {
          final doc = await pdfx.PdfDocument.openFile(path);
          final pageCount = doc.pagesCount;
          for (int i = 1; i <= pageCount; i++) {
            final page = await doc.getPage(i);
            final img = await page.render(
              width: page.width * 2,
              height: page.height * 2,
            );
            await page.close();
            if (img != null) {
              pages.add(_PreviewPage(
                bytes: img.bytes,
                title: attachment.title,
                resource: attachment.resource,
                pageInDoc: i,
                totalPagesInDoc: pageCount,
              ));
            }
          }
          await doc.close();
        } catch (_) {}
      } else {
        pages.add(_PreviewPage(
          filePath: path,
          title: attachment.title,
          resource: attachment.resource,
          pageInDoc: 1,
          totalPagesInDoc: 1,
        ));
      }
    }

    if (pages.isNotEmpty) {
      _cache[widget.detail.record.id] = pages;
    }

    if (mounted) {
      final startPage = widget.startFromEnd && pages.isNotEmpty
          ? pages.length - 1
          : 0;
      setState(() {
        _pages.clear();
        _pages.addAll(pages);
        _loading = false;
        _currentPage = pages.isNotEmpty ? startPage : 0;
      });
      if (_pageController.hasClients && pages.isNotEmpty) {
        _pageController.jumpToPage(_currentPage);
      }
      _notifyFileName();
    }
  }

  void _notifyFileName() {
    if (_pages.isNotEmpty && widget.onFileNameChanged != null) {
      widget.onFileNameChanged!(_pages[_currentPage].title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;

    return Container(
      height: 330,
      width: double.infinity,
      decoration: BoxDecoration(
        color: hasPages ? Colors.white : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.onSurface.withValues(alpha: 0.24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            )
          : hasPages
              ? _buildPageView(context)
              : _EmptyAttachmentContent(record: widget.detail.record),
    );
  }

  Widget _buildPageView(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final page = _pages[_currentPage];
        if (page.resource.fhirType == FhirType.DocumentReference) {
          getIt<PdfPreviewService>().previewInApp(context, page.resource);
        }
      },
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _didTriggerEdge = false;
              }
              if (_didTriggerEdge) return false;
              if (notification is OverscrollNotification) {
                if (notification.overscroll > 0 &&
                    _currentPage == _pages.length - 1) {
                  _didTriggerEdge = true;
                  widget.onSwipeNextRecord?.call();
                  return true;
                }
                if (notification.overscroll < 0 && _currentPage == 0) {
                  _didTriggerEdge = true;
                  widget.onSwipePrevRecord?.call();
                  return true;
                }
              }
              if (notification is ScrollUpdateNotification) {
                final metrics = notification.metrics;
                if (_currentPage == _pages.length - 1 &&
                    metrics.pixels >= metrics.maxScrollExtent &&
                    (notification.dragDetails?.delta.dx ?? 0) < -2) {
                  _didTriggerEdge = true;
                  widget.onSwipeNextRecord?.call();
                  return true;
                }
                if (_currentPage == 0 &&
                    metrics.pixels <= metrics.minScrollExtent &&
                    (notification.dragDetails?.delta.dx ?? 0) > 2) {
                  _didTriggerEdge = true;
                  widget.onSwipePrevRecord?.call();
                  return true;
                }
              }
              return false;
            },
            child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _notifyFileName();
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              if (page.bytes != null) {
                return Image.memory(
                  page.bytes!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                );
              }
              if (page.filePath != null) {
                return Image.file(
                  File(page.filePath!),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          ),
          if (_pages.isNotEmpty)
            Positioned(
              left: 7,
              bottom: 7,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(222),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(222),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${_pages[_currentPage].pageInDoc} of ${_pages[_currentPage].totalPagesInDoc}',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewPage {
  final Uint8List? bytes;
  final String? filePath;
  final String title;
  final IFhirResource resource;
  final int pageInDoc;
  final int totalPagesInDoc;

  _PreviewPage({
    this.bytes,
    this.filePath,
    required this.title,
    required this.resource,
    required this.pageInDoc,
    required this.totalPagesInDoc,
  });
}

class _EmptyAttachmentContent extends StatelessWidget {
  final IFhirResource record;

  const _EmptyAttachmentContent({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No attachments',
            style: AppTextStyle.titleSmall.copyWith(
              color: context.colorScheme.onSurface,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: Insets.normal),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: () async {
                debugPrint('[BROWSE_ATTACH] picking file...');
                final result = await FilePicker.platform.pickFiles();
                if (result == null) {
                  debugPrint('[BROWSE_ATTACH] picker cancelled');
                  return;
                }

                final file = File(result.files.first.path!);
                debugPrint('[BROWSE_ATTACH] picked: ${file.path}');
                debugPrint('[BROWSE_ATTACH] record: ${record.fhirType} id=${record.id} resourceId=${record.resourceId}');

                final attachBloc = getIt.get<RecordAttachmentsBloc>();
                attachBloc.add(RecordAttachmentsInitialised(resource: record));
                debugPrint('[BROWSE_ATTACH] waiting for init...');
                final initState = await attachBloc.stream.firstWhere(
                  (s) => s.status.when(
                    loading: () => false,
                    success: () => true,
                    error: (_) => true,
                  ),
                );
                debugPrint('[BROWSE_ATTACH] init done, status: ${initState.status}, resource: ${initState.resource.fhirType}');

                attachBloc.add(RecordAttachmentsFileAttached(file));
                debugPrint('[BROWSE_ATTACH] waiting for attach...');
                final attachState = await attachBloc.stream.firstWhere(
                  (s) => s.status.when(
                    loading: () => false,
                    success: () => true,
                    error: (_) => true,
                  ),
                );
                debugPrint('[BROWSE_ATTACH] attach done, status: ${attachState.status}');

                if (context.mounted) {
                  debugPrint('[BROWSE_ATTACH] refreshing browse view');
                  final filters =
                      context.read<RecordsBloc>().state.activeFilters;
                  final homeState = context.read<HomeBloc>().state;
                  final sourceId = homeState.selectedSource == 'All'
                      ? null
                      : homeState.selectedSource;
                  context.read<AttachmentBrowseBloc>().add(
                    AttachmentBrowseInitialised(
                      sourceId: sourceId,
                      resourceTypes: filters,
                    ),
                  );
                } else {
                  debugPrint('[BROWSE_ATTACH] context not mounted, skipping refresh');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Text(
                'Add Attachment',
                style: AppTextStyle.buttonMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileInfoRow extends StatelessWidget {
  final AttachmentBrowseDetail detail;
  final String currentFileName;

  const _FileInfoRow({
    required this.detail,
    required this.currentFileName,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = currentFileName.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Text(
            hasFile ? currentFileName : 'No file name',
            style: AppTextStyle.labelLarge.copyWith(
              color: hasFile
                  ? context.colorScheme.onSurface
                  : context.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => _showActionDialog(
            context,
            RecordNotesWidget(resource: detail.record),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Assets.icons.licenseDraftNotes.svg(
              width: 24,
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(width: Insets.normal),
        GestureDetector(
          onTap: () async {
            await _showActionDialog(
              context,
              RecordAttachmentsWidget(resource: detail.record),
            );
            if (context.mounted) {
              context.read<AttachmentBrowseBloc>().add(
                    AttachmentBrowseDetailRefreshed(),
                  );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Assets.icons.attachment.svg(
              width: 24,
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showActionDialog(BuildContext context, Widget child) {
    return showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: context.wideDialogWidth,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AttachmentBrowseDetailsCard extends StatelessWidget {
  final AttachmentBrowseDetail detail;

  const _AttachmentBrowseDetailsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        context.colorScheme.onSurface.withValues(alpha: 0.12);

    final rows = <Widget>[];

    if (detail.patientName != null) {
      rows.add(_DetailRow(
        icon: Assets.icons.user,
        label: 'Patient',
        value: detail.patientName!,
      ));
    }
    if (detail.organizationName != null) {
      if (rows.isNotEmpty) rows.add(Divider(height: 1, color: dividerColor));
      rows.add(_DetailRow(
        icon: Assets.icons.hospital,
        label: 'Organisation',
        value: detail.organizationName!,
      ));
    }
    if (detail.practitionerName != null) {
      if (rows.isNotEmpty) rows.add(Divider(height: 1, color: dividerColor));
      rows.add(_DetailRow(
        icon: Assets.icons.stethoscope,
        label: 'Practitioner',
        value: detail.practitionerName!,
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.small,
        vertical: Insets.smallNormal,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.onSurface.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.onSurface.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final SvgGenImage icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor =
        context.colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.small),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Opacity(
                  opacity: 0.7,
                  child: icon.svg(
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      context.colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: labelColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: AppTextStyle.labelSmall.copyWith(
              color: context.colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowDetailsButton extends StatelessWidget {
  final AttachmentBrowseDetail detail;

  const _ShowDetailsButton({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: OutlinedButton(
        onPressed: () {
          context.router.push(
            RecordDetailsRoute(resource: detail.record),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.colorScheme.onSurface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          'Show Details',
          style: AppTextStyle.buttonMedium.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
