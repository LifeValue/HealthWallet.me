import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/smart_health_share/presentation/local_qr/bloc/local_qr_share_bloc.dart';
import 'package:health_wallet/features/smart_health_share/presentation/shared/widgets/qr_code_display_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';

@RoutePage()
class LocalQRSharePage extends StatelessWidget {
  const LocalQRSharePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<LocalQRShareBloc>(),
      child: const _LocalQRSharePageView(),
    );
  }
}

class _LocalQRSharePageView extends StatefulWidget {
  const _LocalQRSharePageView();

  @override
  State<_LocalQRSharePageView> createState() => _LocalQRSharePageState();
}

class _LocalQRSharePageState extends State<_LocalQRSharePageView> {
  @override
  void initState() {
    super.initState();
    context.read<LocalQRShareBloc>().add(const LocalQRShareEvent.initialized());
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LocalQR Code Share',
          style: AppTextStyle.titleMedium,
        ),
        backgroundColor: context.colorScheme.inversePrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.router.pop(),
        ),
      ),
      body: BlocBuilder<LocalQRShareBloc, LocalQRShareState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = state.session;
          if (session != null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your LocalQR Code',
                    style: AppTextStyle.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Insets.small),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.medium,
                      vertical: Insets.small,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 16,
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: Insets.small),
                        Text(
                          'Peer-to-Peer Share',
                          style: AppTextStyle.labelSmall.copyWith(
                            color: context.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.large),
                  Center(
                    child: QRCodeDisplayWidget(
                      qrData: session.qrCodeData,
                    ),
                  ),
                  const SizedBox(height: Insets.medium),
                  Container(
                    padding: const EdgeInsets.all(Insets.small),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          size: 16,
                          color: context.colorScheme.onSurface,
                        ),
                        const SizedBox(width: Insets.small),
                        Text(
                          'SMART Health Card format (shc:/) - Peer-to-peer, no issuer verification',
                          style: AppTextStyle.bodySmall.copyWith(
                            color:
                                context.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.large),
                  // Timer display
                  if (state.config.timeBasedExpiration &&
                      session.remainingSeconds != null)
                    Container(
                      padding: const EdgeInsets.all(Insets.medium),
                      decoration: BoxDecoration(
                        color: session.remainingSeconds! < 60
                            ? AppColors.error.withOpacity(0.1)
                            : context.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer),
                          const SizedBox(width: Insets.small),
                          Text(
                            'Expires in: ${_formatDuration(session.remainingSeconds!)}',
                            style: AppTextStyle.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  // Bluetooth status
                  if (state.config.bluetoothProximity) ...[
                    const SizedBox(height: Insets.medium),
                    Container(
                      padding: const EdgeInsets.all(Insets.medium),
                      decoration: BoxDecoration(
                        color: session.isBluetoothConnected
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: session.isBluetoothConnected
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                session.isBluetoothConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_searching,
                                color: session.isBluetoothConnected
                                    ? Colors.green
                                    : Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: Insets.small),
                              Text(
                                session.isBluetoothConnected
                                    ? 'HealthWallet.me Peer Connected'
                                    : 'Searching for HealthWallet.me app...',
                                style: AppTextStyle.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (!session.isBluetoothConnected) ...[
                            const SizedBox(height: Insets.small),
                            Text(
                              'Keep Bluetooth enabled and stay nearby',
                              style: AppTextStyle.bodySmall.copyWith(
                                color: context.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: Insets.medium),
                    Container(
                      padding: const EdgeInsets.all(Insets.medium),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.errorMessage ?? '',
                        style: AppTextStyle.labelMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Insets.large),
                  ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<LocalQRShareBloc>()
                          .add(const LocalQRShareEvent.stop());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.large,
                        vertical: Insets.medium,
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text(
                      'Stop Sharing',
                      style: AppTextStyle.titleSmall,
                    ),
                  ),
                ],
              ),
            );
          }

          // Configuration and resource selection UI
          return SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: Insets.small),
                    const Text(
                      'LocalQR Peer-to-Peer Share',
                      style: AppTextStyle.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: Insets.medium),
                // Sharing mode info (always time + proximity)
                Container(
                  padding: const EdgeInsets.all(Insets.medium),
                  decoration: BoxDecoration(
                    color: context.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 20,
                            color: context.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: Insets.small),
                          Text(
                            'Time + Proximity Based',
                            style: AppTextStyle.titleSmall.copyWith(
                              color: context.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.small),
                      Text(
                        '• 15-minute timer + Bluetooth proximity check\n'
                        '• Session closes automatically if devices move out of range\n'
                        '• Data is deleted on both sides when session ends',
                        style: AppTextStyle.bodySmall.copyWith(
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.large),
                // Resource selection (similar to existing share page)
                if (state.availableResources.isEmpty)
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
                        'Available Resources (${state.availableResources.length})',
                        style: AppTextStyle.titleMedium,
                      ),
                      const SizedBox(height: Insets.small),
                      Text(
                        'Selected: ${state.selectedResourceIds.length}',
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
                          itemCount: state.availableResources.length,
                          itemBuilder: (context, index) {
                            final resource = state.availableResources[index];
                            final resourceId = resource.id;
                            final isSelected =
                                state.selectedResourceIds.contains(resourceId);

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
                                final newSelection = List<String>.from(
                                    state.selectedResourceIds);
                                if (value == true) {
                                  if (!newSelection.contains(resourceId)) {
                                    newSelection.add(resourceId);
                                  }
                                } else {
                                  newSelection.remove(resourceId);
                                }
                                context.read<LocalQRShareBloc>().add(
                                      LocalQRShareEvent.resourcesSelected(
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
                ElevatedButton.icon(
                  onPressed: state.selectedResourceIds.isEmpty
                      ? null
                      : () {
                          context.read<LocalQRShareBloc>().add(
                                LocalQRShareEvent.generateQrCode(
                                  resourceIds: state.selectedResourceIds,
                                ),
                              );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.isDarkMode
                        ? Colors.white
                        : context.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.large,
                      vertical: Insets.medium,
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: Assets.icons.qrCode.svg(
                    width: 20,
                    colorFilter: ColorFilter.mode(
                      context.isDarkMode
                          ? Colors.white
                          : context.colorScheme.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: const Text(
                    'Generate LocalQR Code',
                    style: AppTextStyle.titleSmall,
                  ),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: Insets.medium),
                  Container(
                    padding: const EdgeInsets.all(Insets.medium),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
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
