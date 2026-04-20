import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordsBloc, RecordsState>(
      buildWhen: (previous, current) =>
          previous.searchQuery != current.searchQuery,
      builder: (context, state) {
        return SizedBox(
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (query) {
              context.read<RecordsBloc>().add(RecordsSearch(query));
            },
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            style: AppTextStyle.bodyMedium,
            maxLines: 1,
            decoration: InputDecoration(
              isDense: true,
              hintText: context.l10n.searchRecordsHint,
              hintStyle: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(14),
                child: Assets.icons.search.svg(
                  width: 16,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface.withOpacity(0.6),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        context
                            .read<RecordsBloc>()
                            .add(const RecordsSearch(''));
                      },
                      icon: Assets.icons.close.svg(
                        width: Insets.normal,
                        height: Insets.normal,
                        colorFilter: ColorFilter.mode(
                          context.colorScheme.onSurface.withOpacity(0.6),
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : null,
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
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
