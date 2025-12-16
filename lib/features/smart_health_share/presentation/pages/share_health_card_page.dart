import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/smart_health_share/presentation/bloc/share/share_bloc.dart';
import 'package:health_wallet/features/smart_health_share/presentation/shared/widgets/qr_code_display_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';

@RoutePage()
class ShareHealthCardPage extends StatelessWidget {
  const ShareHealthCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ShareBloc>(),
      child: const _ShareHealthCardPageView(),
    );
  }
}

class _ShareHealthCardPageView extends StatefulWidget {
  const _ShareHealthCardPageView();

  @override
  State<_ShareHealthCardPageView> createState() => _ShareHealthCardPageState();
}

class _ShareHealthCardPageState extends State<_ShareHealthCardPageView> {
  final TextEditingController _issuerUrlController =
      TextEditingController(text: 'https://healthwallet.me');

  @override
  void initState() {
    super.initState();
    context.read<ShareBloc>().add(const ShareEvent.initialized());
  }

  @override
  void dispose() {
    _issuerUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Share Health Card',
          style: AppTextStyle.titleMedium,
        ),
        backgroundColor: context.colorScheme.inversePrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.router.pop(),
        ),
      ),
      // ignore: undefined_class
      body: BlocBuilder<ShareBloc, ShareState>(
        builder: (context, state) {
          // ignore: undefined_getter
          final isLoading = state.isLoading;
          if (isLoading == true) {
            return const Center(child: CircularProgressIndicator());
          }

          // ignore: undefined_getter
          final qrCodeData = state.qrCodeData;
          if (qrCodeData != null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your Health Card QR Code',
                    style: AppTextStyle.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Insets.large),
                  Center(
                    child: QRCodeDisplayWidget(
                      qrData: qrCodeData,
                    ),
                  ),
                  const SizedBox(height: Insets.large),
                  // ignore: undefined_getter
                  if (state.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(Insets.medium),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // ignore: undefined_getter
                        state.errorMessage ?? '',
                        style: AppTextStyle.labelMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: Insets.medium),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ShareBloc>().add(const ShareEvent.reset());
                    },
                    child: const Text('Create New Card'),
                  ),
                ],
              ),
            );
          }

          // ignore: undefined_getter
          final availableResources = state.availableResources;
          // ignore: undefined_getter
          final selectedResourceIds = state.selectedResourceIds;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select resources to share',
                  style: AppTextStyle.titleLarge,
                ),
                const SizedBox(height: Insets.medium),
                TextField(
                  controller: _issuerUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Issuer URL',
                    hintText: 'https://healthwallet.me',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Insets.large),
                if (availableResources.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(Insets.large),
                    child: Center(
                      child: Text(
                        'No resources available to share',
                        style: AppTextStyle.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Resources (${availableResources.length})',
                        style: AppTextStyle.titleMedium,
                      ),
                      const SizedBox(height: Insets.small),
                      Text(
                        'Selected: ${selectedResourceIds.length}',
                        style: AppTextStyle.bodySmall.copyWith(
                          color: context.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: Insets.medium),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: context.colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableResources.length,
                          itemBuilder: (context, index) {
                            final resource = availableResources[index];
                            final resourceId = resource.id;
                            final isSelected =
                                selectedResourceIds.contains(resourceId);

                            return CheckboxListTile(
                              title: Text(
                                resource.displayTitle,
                                style: AppTextStyle.bodyMedium,
                              ),
                              subtitle: Text(
                                resource.fhirType.display,
                                style: AppTextStyle.bodySmall.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              value: isSelected,
                              onChanged: (bool? value) {
                                final newSelection =
                                    List<String>.from(selectedResourceIds);
                                if (value == true) {
                                  if (!newSelection.contains(resourceId)) {
                                    newSelection.add(resourceId);
                                  }
                                } else {
                                  newSelection.remove(resourceId);
                                }
                                context.read<ShareBloc>().add(
                                      ShareEvent.resourcesSelected(
                                          newSelection),
                                    );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: Insets.large),
                ElevatedButton(
                  onPressed: selectedResourceIds.isEmpty
                      ? null
                      : () {
                          context.read<ShareBloc>().add(
                                ShareEvent.generateQrCode(
                                  resourceIds: selectedResourceIds,
                                  issuerUrl: _issuerUrlController.text,
                                ),
                              );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.isDarkMode
                        ? Colors.white
                        : context.colorScheme.onPrimary,
                    padding: const EdgeInsets.all(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Assets.icons.qrCode.svg(width: 16),
                      const SizedBox(width: 8),
                      const Text('Generate QR Code'),
                    ],
                  ),
                ),
                // ignore: undefined_getter
                if (state.errorMessage != null) ...[
                  const SizedBox(height: Insets.medium),
                  Container(
                    padding: const EdgeInsets.all(Insets.medium),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      // ignore: undefined_getter
                      state.errorMessage ?? '',
                      style: AppTextStyle.labelMedium.copyWith(
                        color: AppColors.error,
                      ),
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
