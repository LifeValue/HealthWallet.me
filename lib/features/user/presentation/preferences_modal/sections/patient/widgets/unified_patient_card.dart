import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/widgets/patient_card_details.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class UnifiedPatientCard extends StatefulWidget {
  final Patient patient;
  final int index;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final bool isCollapsing;
  final bool isExpanding;
  final bool isAnimating;

  const UnifiedPatientCard({
    super.key,
    required this.patient,
    required this.index,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.isCollapsing,
    required this.isExpanding,
    required this.isAnimating,
  });

  @override
  State<UnifiedPatientCard> createState() => _UnifiedPatientCardState();
}

class _UnifiedPatientCardState extends State<UnifiedPatientCard> {
  String _bloodTypeDisplay = 'Loading...';
  late RecordsRepository _recordsRepository;
  late PatientSelectionService _patientSelectionService;

  @override
  void initState() {
    super.initState();
    _recordsRepository = getIt<RecordsRepository>();
    _patientSelectionService = getIt<PatientSelectionService>();
    _loadBloodType();
  }

  Future<void> _loadBloodType() async {
    try {
      final patientState = context.read<PatientBloc>().state;

      final selectedSource = context.read<HomeBloc>().state.selectedSource;

      final patientGroup = patientState.patientGroups[widget.patient.id];
      final displayPatient = patientGroup != null
          ? _patientSelectionService.getPatientFromGroup(
              patientGroup: patientGroup,
              selectedSource: selectedSource,
              fallbackPatient: widget.patient,
            )
          : widget.patient;

      final observations = await _recordsRepository.getBloodTypeObservations(
        patientId: displayPatient.id,
        sourceId:
            displayPatient.sourceId.isNotEmpty ? displayPatient.sourceId : null,
      );

      final extractedBloodType =
          FhirFieldExtractor.extractBloodTypeFromObservations(observations);

      if (mounted) {
        setState(() {
          _bloodTypeDisplay = extractedBloodType ?? context.l10n.homeNA;
        });
      }
    } catch (e, stackTrace) {
      logger.e('Error loading blood type: ${e.toString()}');
      logger.e('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _bloodTypeDisplay = context.l10n.homeNA;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        return BlocBuilder<PatientBloc, PatientState>(
          builder: (context, blocState) {
            final selectedSource = homeState.selectedSource;

            final patientGroup = blocState.patientGroups[widget.patient.id];
            final displayPatient = patientGroup != null
                ? _patientSelectionService.getPatientFromGroup(
                    patientGroup: patientGroup,
                    selectedSource: selectedSource,
                    fallbackPatient: widget.patient,
                  )
                : widget.patient;

            final currentPatient = blocState.patients.firstWhere(
              (p) => p.id == widget.patient.id,
              orElse: () => widget.patient,
            );

            final isExpanded =
                blocState.expandedPatientIds.contains(currentPatient.id);

            return MultiBlocListener(
                listeners: [
                  BlocListener<PatientBloc, PatientState>(
                    listenWhen: (previous, current) =>
                        previous.patients != current.patients ||
                        previous.status != current.status ||
                        previous.isEditingPatient != current.isEditingPatient,
                    listener: (context, state) {
                      if (state.status.toString().contains('Success') ||
                          state.isEditingPatient == false) {
                        _loadBloodType();
                      }
                    },
                  ),
                  BlocListener<HomeBloc, HomeState>(
                    listenWhen: (previous, current) =>
                        previous.selectedSource != current.selectedSource,
                    listener: (context, state) {
                      _loadBloodType();
                    },
                  ),
                ],
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.all(Insets.small),
                  margin: const EdgeInsets.only(bottom: Insets.small),
                  transform: Matrix4.identity()
                    ..scale(widget.isExpanding ? 1.02 : 1.0),
                  decoration: BoxDecoration(
                    color: _getCardColor(context, currentPatient),
                    border: Border.all(
                        color: _getBorderColor(context, currentPatient)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildCardHeader(context, displayPatient, currentPatient),
                      AnimatedSize(
                        duration: Duration(
                            milliseconds: widget.isExpanding ? 1200 : 800),
                        curve: Curves.easeInOutCubic,
                        child: (isExpanded || widget.isExpanding)
                            ? PatientCardDetails(
                                displayPatient: displayPatient,
                                currentPatient: currentPatient,
                                iconColor: widget.iconColor,
                                textColor: widget.textColor,
                                isExpanding: widget.isExpanding,
                                isCollapsing: widget.isCollapsing,
                                bloodTypeDisplay: _bloodTypeDisplay,
                                onBloodTypeUpdated: _loadBloodType,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ));
          },
        );
      },
    );
  }

  Widget _buildCardHeader(
    BuildContext context,
    Patient displayPatient,
    Patient currentPatient,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.borderColor,
              child: Assets.icons.user.svg(
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  widget.iconColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: Insets.small),
            Text(
              FhirFieldExtractor.extractHumanNameFamilyFirst(
                      displayPatient.name?.first) ??
                  displayPatient.displayTitle,
              style: AppTextStyle.bodySmall.copyWith(
                color: widget.textColor,
              ),
            ),
          ],
        ),
        AnimatedRotation(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          turns: _getRotationTurns(context, currentPatient),
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: widget.textColor,
          ),
        ),
      ],
    );
  }

  Color _getCardColor(BuildContext context, Patient patient) {
    if (widget.isCollapsing) return Colors.transparent;
    if (widget.isExpanding) return AppColors.primary.withValues(alpha: 0.05);
    if (context
        .read<PatientBloc>()
        .state
        .expandedPatientIds
        .contains(patient.id)) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
    if (widget.isAnimating) return AppColors.primary.withValues(alpha: 0.15);
    return Colors.transparent;
  }

  Color _getBorderColor(BuildContext context, Patient patient) {
    if (widget.isCollapsing) return widget.borderColor;
    if (widget.isExpanding) return AppColors.primary.withValues(alpha: 0.5);
    if (context
        .read<PatientBloc>()
        .state
        .expandedPatientIds
        .contains(patient.id)) {
      return AppColors.primary;
    }
    if (widget.isAnimating) return AppColors.primary.withValues(alpha: 0.5);
    return widget.borderColor;
  }

  double _getRotationTurns(BuildContext context, Patient patient) {
    if (context
        .read<PatientBloc>()
        .state
        .expandedPatientIds
        .contains(patient.id)) {
      return 0.5;
    }
    return 0.0;
  }
}
