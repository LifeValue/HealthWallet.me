import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/capture/desktop_import/presentation/bloc/desktop_bloc.dart';

class DesktopImportPage extends StatelessWidget {
  const DesktopImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DesktopBloc>(),
      child: BlocBuilder<DesktopBloc, DesktopState>(
        builder: (context, state) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.file_upload_outlined,
                  size: 64,
                  color: context.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: Insets.normal),
                Text(
                  'Drop files here to import',
                  style: AppTextStyle.titleMedium.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: Insets.small),
                Text(
                  'PDF, JPG, PNG, TIFF',
                  style: AppTextStyle.bodySmall.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: Insets.normal),
                  Text(
                    state.error!,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
