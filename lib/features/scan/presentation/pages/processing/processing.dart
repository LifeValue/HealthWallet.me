import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/delete_confirmation_dialog.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/processing/widgets/patient_dropdown.dart';
import 'package:health_wallet/features/scan/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/features/scan/presentation/widgets/preview_card.dart';
import 'package:health_wallet/features/scan/presentation/widgets/summary_card.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

@RoutePage()
class ProcessingPage extends StatefulWidget {
  const ProcessingPage({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  final _formKey = GlobalKey<FormState>();
  final _encounterNameController = TextEditingController();
  final _pageController = PageController();

  @override
  void initState() {
    context.read<ScanBloc>().add(
          ScanSessionActivated(
              sessionId: widget.sessionId,
              currentPatients: context
                  .read<PatientBloc>()
                  .state
                  .patientGroups
                  .values
                  .toList()),
        );
    super.initState();
  }

  @override
  void dispose() {
    _encounterNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _saveResources() {
    if (!_formKey.currentState!.validate()) return;

    context
        .read<ScanBloc>()
        .add(ScanResourceCreationInitiated(sessionId: widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Processing', style: AppTextStyle.titleMedium),
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocConsumer<ScanBloc, ScanState>(
        listener: (context, state) {
          final activeSession =
              state.sessions.firstWhereOrNull((s) => s.id == widget.sessionId);
          if (activeSession == null) return;

          if (state.status == const ScanStatus.success()) {
            context
                .read<ScanBloc>()
                .add(ScanSessionCleared(session: activeSession));
            context.router.replaceAll([const DashboardRoute()]);
          }
        },
        builder: (context, state) {
          final activeSession =
              state.sessions.firstWhereOrNull((s) => s.id == widget.sessionId);
          if (activeSession == null) {
            return const Center(child: Text("Session not found!"));
          }

          if (state.status == const ScanStatus.convertingPdfs()) {
            return _buildLoadingIndicator('Converting PDFs for preview...');
          }

          final sessionImages = state.sessionImagePaths[widget.sessionId] ??
              (state.activeSessionId == widget.sessionId
                  ? state.allImagePathsForOCR
                  : const <String>[]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.normal),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SummaryCard(
                totalPagesForOcr: sessionImages.length,
              ),
              const SizedBox(height: Insets.normal),
              if (sessionImages.isNotEmpty)
                PreviewCard(
                  imagePaths: sessionImages,
                  pageController: _pageController,
                ),
              const SizedBox(height: Insets.large),
              _buildMappingSection(state, activeSession),
              _buildResourcesSection(state, activeSession),
              const SizedBox(height: Insets.large),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildMappingSection(
      ScanState state, ProcessingSession activeSession) {
    if (state.status == const ScanStatus.mapping()) {
      return Column(
        children: [
          CustomProgressIndicator(
            progress: activeSession.progress,
            text: "Processing pages to FHIR resources...",
          ),
          const SizedBox(height: Insets.normal),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context
                  .read<ScanBloc>()
                  .add(ScanMappingCancelled(sessionId: widget.sessionId)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: context.colorScheme.outline),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (state.status is Failure) {
      final error = (state.status as Failure).error;
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.normal),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: context.colorScheme.error.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: context.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Processing failed',
                      style: AppTextStyle.bodyMedium.copyWith(
                        color: context.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: AppTextStyle.bodySmall.copyWith(
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.normal),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context
                  .read<ScanBloc>()
                  .add(ScanMappingInitiated(sessionId: widget.sessionId)),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      );
    }

    if (state.status == const ScanStatus.cancelled()) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.normal),
            decoration: BoxDecoration(
              color:
                  context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: context.colorScheme.outline.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cancel_outlined,
                  color: context.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Processing was cancelled',
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.normal),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context
                  .read<ScanBloc>()
                  .add(ScanMappingInitiated(sessionId: widget.sessionId)),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResourcesSection(
      ScanState state, ProcessingSession activeSession) {
    if (state.status != const ScanStatus.editingResources()) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!activeSession.resources
            .any((resource) => resource is MappingPatient)) ...[
          const Text("Select the patient", style: AppTextStyle.bodyLarge),
          const SizedBox(height: 8),
          PatientDropdown(
            options: state.currentPatients,
            selectedPatient: state.selectedPatient!,
            onChanged: (patientGroup) {
              if (patientGroup != null) {
                context.read<ScanBloc>().add(ScanPatientSelected(
                    sessionId: widget.sessionId, patientGroup: patientGroup));
              }
            },
          ),
          const SizedBox(height: 24),
        ],
        ResourcesForm(
          formKey: _formKey,
          resources: activeSession.resources,
          onPropertyChanged: (index, propertyKey, newValue) =>
              context.read<ScanBloc>().add(
                    ScanResourceChanged(
                      sessionId: widget.sessionId,
                      index: index,
                      propertyKey: propertyKey,
                      newValue: newValue,
                    ),
                  ),
          onResourceRemoved: _showDeleteConfirmationDialog,
        ),
        _buildAddResourceButton(),
        const SizedBox(height: Insets.normal),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorScheme.primary,
              foregroundColor: context.isDarkMode
                  ? Colors.white
                  : context.colorScheme.onPrimary,
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(8)),
            ),
            onPressed: state.status == const ScanStatus.savingResources()
                ? null
                : _saveResources,
            child: const Text("Done"),
          ),
        ),
      ],
    );
  }

  Widget _buildAddResourceButton() {
    return GestureDetector(
      onTap: _showAddResourceDialog,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: context.colorScheme.outline.withOpacity(0.5),
          strokeWidth: 1,
          dashWidth: 6,
          dashSpace: 4,
          borderRadius: 8,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Insets.normal),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: context.colorScheme.onSurface.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Add resources',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _resourceTypes = [
    DialogItem(id: 'AllergyIntolerance', label: 'Allergy Intolerance'),
    DialogItem(id: 'Condition', label: 'Condition'),
    DialogItem(id: 'DiagnosticReport', label: 'Diagnostic Report'),
    DialogItem(id: 'MedicationStatement', label: 'Medication Statement'),
    DialogItem(id: 'Observation', label: 'Observation'),
    DialogItem(id: 'Organization', label: 'Organization'),
    DialogItem(id: 'Practitioner', label: 'Practitioner'),
    DialogItem(id: 'Procedure', label: 'Procedure'),
  ];

  void _showAddResourceDialog() async {
    final selectedResourceIds = await AppDialog.showMultiSelect(
      context: context,
      title: 'Add Resources',
      description: 'Choose the resources you want to add for processing.',
      items: _resourceTypes,
      confirmText: 'Add',
    );

    if (selectedResourceIds != null &&
        selectedResourceIds.isNotEmpty &&
        mounted) {
      context.read<ScanBloc>().add(ResourcesAdded(
            sessionId: widget.sessionId,
            resourceTypes: selectedResourceIds,
          ));
    }
  }

  void _showDeleteConfirmationDialog(int index) {
    DeleteConfirmationDialog.show(
      context: context,
      title: 'Delete Resources',
      onConfirm: () {
        context.read<ScanBloc>().add(
            ScanResourceRemoved(sessionId: widget.sessionId, index: index));
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashWidth).clamp(0, metric.length);
        dashPath.addPath(
          metric.extractPath(start, end.toDouble()),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
