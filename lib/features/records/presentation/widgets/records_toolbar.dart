import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class RecordsToolbar extends StatefulWidget {
  final RecordsViewMode viewMode;
  final ValueChanged<RecordsViewMode> onViewModeChanged;
  final VoidCallback onFilterTap;

  const RecordsToolbar({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onFilterTap,
  });

  @override
  State<RecordsToolbar> createState() => _RecordsToolbarState();
}

class _RecordsToolbarState extends State<RecordsToolbar>
    with SingleTickerProviderStateMixin {
  bool _isSearchExpanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChanged);
    _animController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_searchFocusNode.hasFocus && _isSearchExpanded) {
      _collapseSearch();
    }
  }

  void _openSearch() {
    setState(() => _isSearchExpanded = true);
    _animController.forward();
    _searchFocusNode.requestFocus();
  }

  void _collapseSearch() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _isSearchExpanded = false);
      }
    });
  }

  void _handleSuffixTap() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      context.read<RecordsBloc>().add(const RecordsSearch(''));
      if (widget.viewMode == RecordsViewMode.attachments) {
        context.read<AttachmentBrowseBloc>().add(
            const AttachmentBrowseSearchChanged(''));
      }
      _searchFocusNode.requestFocus();
    } else {
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = context.colorScheme.onSurface;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                FadeTransition(
                  opacity: ReverseAnimation(_expandAnimation),
                  child: IgnorePointer(
                    ignoring: _isSearchExpanded,
                    child: RecordsViewToggle(
                      mode: widget.viewMode,
                      onChanged: widget.onViewModeChanged,
                    ),
                  ),
                ),
                if (_isSearchExpanded)
                  FadeTransition(
                    opacity: _expandAnimation,
                    child: _buildSearchField(context),
                  ),
              ],
            ),
          ),
          if (!_isSearchExpanded) ...[
            const SizedBox(width: Insets.small),
            GestureDetector(
              onTap: _openSearch,
              child: Padding(
                padding: const EdgeInsets.all(Insets.small),
                child: Assets.icons.search.svg(
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onFilterTap,
              child: Padding(
                padding: const EdgeInsets.all(Insets.small),
                child: Assets.icons.filter.svg(
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return BlocBuilder<RecordsBloc, RecordsState>(
      buildWhen: (previous, current) =>
          previous.searchQuery != current.searchQuery,
      builder: (context, state) {
        return SizedBox(
          height: 36,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (query) {
              context.read<RecordsBloc>().add(RecordsSearch(query));
              if (widget.viewMode == RecordsViewMode.attachments) {
                context.read<AttachmentBrowseBloc>().add(
                    AttachmentBrowseSearchChanged(query));
              }
            },
            onSubmitted: (_) => _searchFocusNode.unfocus(),
            style: AppTextStyle.bodyMedium,
            maxLines: 1,
            decoration: InputDecoration(
              isDense: true,
              hintText: context.l10n.searchRecordsHint,
              hintStyle: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Assets.icons.search.svg(
                  width: 16,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface.withValues(alpha: 0.6),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              suffixIcon: GestureDetector(
                onTap: _handleSuffixTap,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.close,
                    size: 22,
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide(color: context.theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide(color: context.theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: context.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
