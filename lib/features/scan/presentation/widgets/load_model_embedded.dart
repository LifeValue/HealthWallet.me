import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';

class LoadModelEmbedded extends StatefulWidget {
  final VoidCallback? onModelReady;

  const LoadModelEmbedded({super.key, this.onModelReady});

  @override
  State<LoadModelEmbedded> createState() => _LoadModelEmbeddedState();
}

class _LoadModelEmbeddedState extends State<LoadModelEmbedded> {
  late final LoadModelBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt.get<LoadModelBloc>();
    _bloc.add(const LoadModelInitialized());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<LoadModelBloc, LoadModelState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status == LoadModelStatus.modelLoaded) {
            widget.onModelReady?.call();
          }
        },
        child: BlocBuilder<LoadModelBloc, LoadModelState>(
          builder: (context, state) {
            switch (state.status) {
              case LoadModelStatus.loading:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: state.downloadProgress != null
                            ? state.downloadProgress! / 100
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Downloading... ${state.downloadProgress?.toStringAsFixed(0) ?? 0}%',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Continues in background',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: context.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                );
              case LoadModelStatus.modelAbsent:
                return TextButton(
                  onPressed: () =>
                      _bloc.add(const LoadModelDownloadInitiated()),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.l10n.aiModelEnableDownload),
                );
              case LoadModelStatus.error:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.aiModelError,
                          textAlign: TextAlign.center,
                          style: AppTextStyle.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () =>
                          _bloc.add(const LoadModelDownloadInitiated()),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colorScheme.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                );
              case LoadModelStatus.modelLoaded:
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.aiModelReady,
                      textAlign: TextAlign.center,
                      style: AppTextStyle.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }
}
