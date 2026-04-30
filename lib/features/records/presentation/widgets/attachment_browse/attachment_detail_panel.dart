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
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_notes/record_notes_widget.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
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
  int _currentPage = 0;
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
    final readOnly = context.read<AttachmentBrowseBloc>().state.readOnly;
    final bloc = context.read<AttachmentBrowseBloc>();
    final selectedIndex = bloc.state.selectedIndex;
    final totalRecords = bloc.state.records.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
            ],
          ),
        ),
        const SizedBox(height: Insets.smallNormal),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.isDesktopWidth ? 240 : Insets.medium,
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (context.isDesktopWidth) ...[
              _NavPillButton(
                icon: Icons.chevron_left,
                enabled: selectedIndex > 0,
                onTap: () => bloc.add(AttachmentBrowseSelected(selectedIndex - 1)),
              ),
              const SizedBox(width: Insets.medium),
            ],
            Expanded(
              child: _AttachmentPreview(
                detail: detail,
                startFromEnd: _startFromEnd,
                readOnly: readOnly,
                onFileNameChanged: (name) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _currentFileName = name);
                  });
                },
                onPageChanged: (page) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _currentPage = page);
                  });
                },
                onSwipeNextRecord: () {
                  bloc.add(AttachmentBrowseSelected(selectedIndex + 1));
                },
                onSwipePrevRecord: () {
                  bloc.add(AttachmentBrowseSelected(selectedIndex - 1));
                },
              ),
            ),
            if (context.isDesktopWidth) ...[
              const SizedBox(width: Insets.medium),
              _NavPillButton(
                icon: Icons.chevron_right,
                enabled: selectedIndex < totalRecords - 1,
                onTap: () => bloc.add(AttachmentBrowseSelected(selectedIndex + 1)),
              ),
            ],
          ],
        ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.isDesktopWidth ? 240 : Insets.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Insets.small),
              _FileInfoRow(
                detail: detail,
                currentFileName: _currentFileName,
                readOnly: readOnly,
                totalFiles: detail.attachments.length,
                currentFileIndex: _currentPage,
              ),
              if (detail.patientName != null ||
                  detail.organizationName != null ||
                  detail.practitionerName != null) ...[
                const SizedBox(height: Insets.normal),
                _AttachmentBrowseDetailsCard(detail: detail),
              ],
              if (!context.isDesktopWidth) ...[
                const SizedBox(height: Insets.smallNormal),
                _ShowDetailsButton(
                  detail: detail,
                  readOnly: readOnly,
                  ephemeralRecords: readOnly
                      ? bloc.state.sourceRecords
                      : null,
                ),
              ],
              const SizedBox(height: Insets.normal),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentPreview extends StatefulWidget {
  final AttachmentBrowseDetail detail;
  final bool startFromEnd;
  final bool readOnly;
  final ValueChanged<String>? onFileNameChanged;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onSwipeNextRecord;
  final VoidCallback? onSwipePrevRecord;

  const _AttachmentPreview({
    required this.detail,
    this.startFromEnd = false,
    this.readOnly = false,
    this.onFileNameChanged,
    this.onPageChanged,
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

    if (recordId == _loadedRecordId && _pages.isNotEmpty) {
      return;
    }

    final cached = _cache[recordId];
    if (cached != null && cached.isNotEmpty) {
      final startPage = widget.startFromEnd ? cached.length - 1 : 0;
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
      _pages.clear();
      _loading = false;
      _loadedRecordId = recordId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }

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

    for (final attachment in widget.detail.attachments) {
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
    if (_pages.isNotEmpty) {
      widget.onFileNameChanged?.call(_pages[_currentPage].title);
      final currentResourceId = _pages[_currentPage].resource.resourceId;
      int fileIndex = 0;
      String? lastResourceId;
      for (int i = 0; i <= _currentPage && i < _pages.length; i++) {
        if (_pages[i].resource.resourceId != lastResourceId) {
          lastResourceId = _pages[i].resource.resourceId;
          fileIndex++;
        }
      }
      widget.onPageChanged?.call(fileIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;

    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = (screenHeight * 0.55).clamp(350.0, 700.0);

    return Container(
      height: previewHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
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
              : _EmptyAttachmentContent(
                  record: widget.detail.record,
                  readOnly: widget.readOnly,
                ),
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

class _EmptyAttachmentContent extends StatefulWidget {
  final IFhirResource record;
  final bool readOnly;

  const _EmptyAttachmentContent({
    required this.record,
    this.readOnly = false,
  });

  @override
  State<_EmptyAttachmentContent> createState() => _EmptyAttachmentContentState();
}

class _EmptyAttachmentContentState extends State<_EmptyAttachmentContent> {
  bool _isAttaching = false;

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    final record = widget.record;
    if (readOnly) {
      return Center(
        child: Text(
          'No attachments',
          style: AppTextStyle.titleSmall.copyWith(
            color: context.colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
      );
    }

    if (_isAttaching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colorScheme.primary,
            ),
            const SizedBox(height: Insets.normal),
            Text(
              'Attaching files...',
              style: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

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
                final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (result == null) return;

                final files = result.files
                    .where((f) => f.path != null)
                    .map((f) => File(f.path!))
                    .toList();
                if (files.isEmpty) return;

                setState(() => _isAttaching = true);

                final attachBloc = getIt.get<RecordAttachmentsBloc>();
                attachBloc.add(RecordAttachmentsInitialised(resource: record));
                await attachBloc.stream.firstWhere(
                  (s) => s.status.when(
                    loading: () => false,
                    success: () => true,
                    error: (_) => true,
                  ),
                );

                attachBloc.add(RecordAttachmentsFileAttached(files));
                await attachBloc.stream.firstWhere(
                  (s) => s.status.when(
                    loading: () => false,
                    success: () => true,
                    error: (_) => true,
                  ),
                );

                if (mounted) {
                  setState(() => _isAttaching = false);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      context.read<AttachmentBrowseBloc>().add(
                          AttachmentBrowseDetailRefreshed());
                    }
                  });
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
  final bool readOnly;
  final int totalFiles;
  final int currentFileIndex;

  const _FileInfoRow({
    required this.detail,
    required this.currentFileName,
    this.readOnly = false,
    this.totalFiles = 0,
    this.currentFileIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = currentFileName.isNotEmpty;
    final subtleColor = context.colorScheme.onSurface.withValues(alpha: 0.4);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasFile ? currentFileName : 'No file name',
                style: AppTextStyle.labelLarge.copyWith(
                  color: hasFile
                      ? context.colorScheme.onSurface
                      : subtleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (totalFiles > 1)
                Text(
                  '( ${currentFileIndex + 1} of $totalFiles files )',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: subtleColor,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showActionDialog(
            context,
            RecordNotesWidget(resource: detail.record, readOnly: readOnly),
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
              RecordAttachmentsWidget(
                resource: detail.record,
                readOnly: readOnly,
                ephemeralRecords: readOnly
                    ? context.read<AttachmentBrowseBloc>().state.sourceRecords
                    : const [],
              ),
            );
            if (context.mounted && !readOnly) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.read<AttachmentBrowseBloc>().add(AttachmentBrowseDetailRefreshed());
                }
              });
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
    final specialty = detail.specialtyName != null
        ? MedicalSpecialty.values.where((s) => s.displayName == detail.specialtyName).firstOrNull
        : null;

    if (rows.isNotEmpty) rows.add(Divider(height: 1, color: dividerColor));
    final subtleColor = context.colorScheme.onSurface.withValues(alpha: 0.45);
    rows.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Center(
                    child: (specialty?.icon ?? Assets.icons.activity).svg(
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Specialty',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: subtleColor,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.specialtyName ?? 'General Care',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: context.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Center(
                    child: detail.record.fhirType.icon.svg(
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Record Type',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: subtleColor,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.record.fhirType.display,
                      style: AppTextStyle.labelSmall.copyWith(
                        color: context.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));

    return GestureDetector(
      onTap: () {
        context.router.push(
          RecordDetailsRoute(resource: detail.record),
        );
      },
      child: Container(
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
  final bool readOnly;
  final List<IFhirResource>? ephemeralRecords;

  const _ShowDetailsButton({
    required this.detail,
    this.readOnly = false,
    this.ephemeralRecords,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: OutlinedButton(
        onPressed: () {
          context.router.push(
            RecordDetailsRoute(
              resource: detail.record,
              ephemeralRecords: readOnly ? (ephemeralRecords ?? const []) : const [],
            ),
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

class _NavPillButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavPillButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.colorScheme.onSurface.withValues(
            alpha: enabled ? 0.08 : 0.03,
          ),
          borderRadius: BorderRadius.circular(222),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: context.colorScheme.onSurface.withValues(
              alpha: enabled ? 0.7 : 0.15,
            ),
          ),
        ),
      ),
    );
  }
}
