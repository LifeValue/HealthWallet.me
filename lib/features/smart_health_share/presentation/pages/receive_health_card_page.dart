import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';
import 'package:health_wallet/features/smart_health_share/presentation/bloc/receive/receive_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';

@RoutePage()
class ReceiveHealthCardPage extends StatelessWidget {
  const ReceiveHealthCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ReceiveBloc>(),
      child: const _ReceiveHealthCardPageView(),
    );
  }
}

class _ReceiveHealthCardPageView extends StatefulWidget {
  const _ReceiveHealthCardPageView();

  @override
  State<_ReceiveHealthCardPageView> createState() =>
      _ReceiveHealthCardPageState();
}

class _ReceiveHealthCardPageState extends State<_ReceiveHealthCardPageView> {
  @override
  void initState() {
    super.initState();
    context.read<ReceiveBloc>().add(const ReceiveEvent.initialized());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Health Card',
          style: AppTextStyle.titleMedium,
        ),
        backgroundColor: context.colorScheme.inversePrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.router.pop(),
        ),
      ),
      body: BlocListener<ReceiveBloc, ReceiveState>(
        listener: (context, state) {
          final successMsg = state.successMessage;
          if (successMsg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMsg),
                backgroundColor: AppColors.success,
              ),
            );
            // Reset after showing success
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                context.read<ReceiveBloc>().add(const ReceiveEvent.reset());
              }
            });
          }
        },
        // ignore: undefined_class
        child: BlocBuilder<ReceiveBloc, ReceiveState>(
          builder: (context, state) {
            // ignore: undefined_getter
            final isScanning = state.isScanning;
            if (isScanning == true) {
              return Padding(
                padding: const EdgeInsets.all(Insets.medium),
                child: QRScannerWidget(
                  cancelButtonText: 'Cancel',
                  onQRCodeDetected: (qrData) {
                    context.read<ReceiveBloc>().add(
                          ReceiveEvent.qrCodeScanned(qrData),
                        );
                  },
                  onCancel: () {
                    context.read<ReceiveBloc>().add(
                          const ReceiveEvent.reset(),
                        );
                  },
                ),
              );
            }

            // ignore: undefined_getter
            final isLoading = state.isLoading;
            if (isLoading == true) {
              return const Center(child: CircularProgressIndicator());
            }

            // Check if LocalQR resources are received
            // ignore: undefined_getter
            final receivedResources = state.receivedResources;
            if (receivedResources != null && receivedResources.isNotEmpty) {
              return _buildLocalQRResourcesView(context, state);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Assets.icons.qrCode.svg(width: 80),
                  const SizedBox(height: Insets.medium),
                  const Text(
                    'Scan Health Card QR Code',
                    style: AppTextStyle.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Insets.small),
                  const Text(
                    'Scan a SMART Health Card QR code to import health data.',
                    style: AppTextStyle.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Insets.small),
                  Container(
                    padding: const EdgeInsets.all(Insets.small),
                    decoration: BoxDecoration(
                      color: context.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: Insets.small),
                        Text(
                          'Supports standard SHC and peer-to-peer LocalQR',
                          style: AppTextStyle.bodySmall.copyWith(
                            color: context.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.large),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ReceiveBloc>().add(
                            const ReceiveEvent.startScanning(),
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
                        const Text('Scan QR Code'),
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
      ),
    );
  }

  Widget _buildLocalQRResourcesView(
    BuildContext context,
    ReceiveState state,
  ) {
    final resources = state.receivedResources ?? [];
    final remainingSeconds = state.remainingSeconds ?? 0;

    // Find Patient resource
    Patient? patientResource;
    final otherResources = <IFhirResource>[];
    for (final resource in resources) {
      if (resource is Patient) {
        patientResource = resource;
      } else {
        otherResources.add(resource);
      }
    }

    String _formatDuration(int seconds) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    String? _getPatientName(Patient? patient) {
      if (patient == null) return null;
      if (patient.name?.isNotEmpty == true) {
        return FhirFieldExtractor.extractHumanName(patient.name!.first);
      }
      return null;
    }

    String? _getPatientAge(Patient? patient) {
      if (patient == null) return null;
      final birthDate = FhirFieldExtractor.extractPatientBirthDate(patient);
      if (birthDate != null) {
        final age = FhirFieldExtractor.calculateAge(birthDate);
        if (age != null) {
          return '$age years';
        }
      }
      return null;
    }

    return Scaffold(
      body: Column(
        children: [
          // Header with expiration timer
          Container(
            padding: const EdgeInsets.all(Insets.medium),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: context.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_android,
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: Text(
                        'LocalQR Peer-to-Peer Share',
                        style: AppTextStyle.titleMedium.copyWith(
                          color: context.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.small),
                Container(
                  padding: const EdgeInsets.all(Insets.small),
                  decoration: BoxDecoration(
                    color: remainingSeconds < 60
                        ? AppColors.error.withOpacity(0.2)
                        : context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 20,
                        color: remainingSeconds < 60
                            ? AppColors.error
                            : context.colorScheme.onSurface,
                      ),
                      const SizedBox(width: Insets.small),
                      Text(
                        'Expires in: ${_formatDuration(remainingSeconds)}',
                        style: AppTextStyle.titleSmall.copyWith(
                          color: remainingSeconds < 60
                              ? AppColors.error
                              : context.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.small),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.small,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'View-only • Temporary • Auto-deletes on expiration',
                    style: AppTextStyle.bodySmall.copyWith(
                      color: context.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Patient info (if available)
          if (patientResource != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: Insets.medium),
              padding: const EdgeInsets.all(Insets.medium),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 32,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: Insets.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPatientName(patientResource) ?? 'Patient',
                          style: AppTextStyle.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_getPatientAge(patientResource) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Age: ${_getPatientAge(patientResource)}',
                            style: AppTextStyle.bodyMedium.copyWith(
                              color: context.colorScheme.onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Resources list
          Expanded(
            child: otherResources.isEmpty
                ? Center(
                    child: Text(
                      patientResource != null
                          ? 'No other resources received'
                          : 'No resources received',
                      style: AppTextStyle.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(Insets.medium),
                    itemCount: otherResources.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Insets.medium),
                        child: ResourceCard(
                          resource: otherResources[index],
                          isViewOnly: true,
                        ),
                      );
                    },
                  ),
          ),
          // Back to scan button
          Container(
            padding: const EdgeInsets.all(Insets.medium),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<ReceiveBloc>().add(const ReceiveEvent.reset());
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Back to Scan'),
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
            ),
          ),
        ],
      ),
    );
  }
}
