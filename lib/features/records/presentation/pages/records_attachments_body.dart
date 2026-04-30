import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_active_filters_bar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_toolbar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_browse_view.dart';

class RecordsAttachmentsBody extends StatefulWidget {
  final RecordsState appBarState;
  final ValueNotifier<bool> isAttachmentScrolled;
  final RecordsViewMode viewMode;
  final ValueChanged<RecordsViewMode> onViewModeChanged;
  final VoidCallback onFilterTap;
  final Widget titleRow;

  const RecordsAttachmentsBody({
    super.key,
    required this.appBarState,
    required this.isAttachmentScrolled,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onFilterTap,
    required this.titleRow,
  });

  @override
  State<RecordsAttachmentsBody> createState() => _RecordsAttachmentsBodyState();
}

class _RecordsAttachmentsBodyState extends State<RecordsAttachmentsBody> {
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;

  void _measureHeader() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final h = box.size.height;
      if (h != _headerHeight) {
        setState(() => _headerHeight = h);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final scrolled = notification.metrics.pixels > 0;
        if (scrolled != widget.isAttachmentScrolled.value) {
          widget.isAttachmentScrolled.value = scrolled;
        }
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            top: _headerHeight,
            child: AttachmentBrowseView(
              isSelectionMode: widget.appBarState.isSelectionMode,
              selectedResourceIds: widget.appBarState.selectedResourceIds,
              onSelectionToggle: (id) => context
                  .read<RecordsBloc>()
                  .add(RecordsSelectionToggled(id)),
              onSelectionModeToggled: () => context
                  .read<RecordsBloc>()
                  .add(const RecordsSelectionModeToggled()),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _HeaderWidget(
              headerKey: _headerKey,
              isAttachmentScrolled: widget.isAttachmentScrolled,
              titleRow: widget.titleRow,
              viewMode: widget.viewMode,
              onViewModeChanged: widget.onViewModeChanged,
              onFilterTap: widget.onFilterTap,
              onLayout: _measureHeader,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderWidget extends StatelessWidget {
  final GlobalKey headerKey;
  final ValueNotifier<bool> isAttachmentScrolled;
  final Widget titleRow;
  final RecordsViewMode viewMode;
  final ValueChanged<RecordsViewMode> onViewModeChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onLayout;

  const _HeaderWidget({
    required this.headerKey,
    required this.isAttachmentScrolled,
    required this.titleRow,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onFilterTap,
    required this.onLayout,
  });

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onLayout());

    return ValueListenableBuilder<bool>(
      valueListenable: isAttachmentScrolled,
      builder: (context, isScrolled, child) {
        return Container(
          key: headerKey,
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: isScrolled
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  )
                : BorderRadius.zero,
            boxShadow: isScrolled
                ? [
                    BoxShadow(
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + Insets.small,
              bottom: isScrolled ? Insets.small : Insets.smaller,
            ),
            child: child!,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleRow,
          const SizedBox(height: Insets.extraSmall),
          RecordsToolbar(
            viewMode: viewMode,
            onViewModeChanged: onViewModeChanged,
            onFilterTap: onFilterTap,
          ),
          BlocBuilder<RecordsBloc, RecordsState>(
            buildWhen: (previous, current) =>
                previous.activeFilters != current.activeFilters ||
                previous.dateFilter != current.dateFilter ||
                previous.activeSpecialties != current.activeSpecialties,
            builder: (context, recordsState) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onLayout());
              return RecordsActiveFiltersBar(
                activeFilters: recordsState.activeFilters,
                dateFilter: recordsState.dateFilter,
                activeSpecialties: recordsState.activeSpecialties,
              );
            },
          ),
        ],
      ),
    );
  }
}
