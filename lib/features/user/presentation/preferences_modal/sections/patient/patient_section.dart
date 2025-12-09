import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';

import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/animated_reorderable_list.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';

class PatientSection extends StatefulWidget {
  const PatientSection({super.key});

  @override
  State<PatientSection> createState() => _PatientSectionState();
}

class _PatientSectionState extends State<PatientSection> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!_hasInitialized) {
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final patientBloc = context.read<PatientBloc>();
        final currentSelectedPatientId = patientBloc.state.selectedPatientId;

        context.read<PatientBloc>().add(
              PatientPatientsLoaded(
                preserveOrder: true,
                preservePatientId: currentSelectedPatientId,
              ),
            );
      });
    }
  }

  void _handlePatientTap(String patientId) {
    final currentState = context.read<PatientBloc>().state;
    final isCurrentlyExpanded =
        currentState.expandedPatientIds.contains(patientId);

    if (isCurrentlyExpanded) {
      return;
    }

    context.read<PatientBloc>().add(PatientReorder(patientId));
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final iconColor = context.colorScheme.onSurface.withOpacity(0.6);
    final textColor = context.colorScheme.onSurface;

    return BlocBuilder<PatientBloc, PatientState>(
      builder: (context, state) {
        final patients = state.patients;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.patient,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: textColor,
                    ),
                  ),
                  Row(
                    children: [
                      Assets.icons.information.svg(
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: Insets.extraSmall),
                      Text(
                        context.l10n.tapToSelectPatient,
                        style: AppTextStyle.labelMedium.copyWith(
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.small),
              if (patients.isNotEmpty) ...[
                AnimatedReorderableList<Patient>(
                  items: patients,
                  itemIdExtractor: (patient) => patient.id,
                  itemSpacing: Insets.small,
                  itemBuilder: (context, patient, index, isBeingMoved) {
                    final isAnimating = state.animatingPatientId == patient.id;
                    final isCollapsing =
                        state.collapsingPatientId == patient.id;
                    final isExpanding = state.expandingPatientId == patient.id;

                    return GestureDetector(
                      key: ValueKey(patient.id),
                      onTap: () {
                        _handlePatientTap(patient.id);
                      },
                      child: _UnifiedPatientCard(
                        patient: patient,
                        index: index,
                        borderColor: borderColor,
                        iconColor: iconColor,
                        textColor: textColor,
                        isCollapsing: isCollapsing,
                        isExpanding: isExpanding,
                        isAnimating: isAnimating,
                      ),
                    );
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(Insets.small),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Assets.icons.user.svg(
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: Insets.small),
                      Text(
                        context.l10n.noPatientsFound,
                        style: AppTextStyle.bodySmall.copyWith(
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Insets.small),
            ],
          ),
        );
      },
    );
  }
}

class _UnifiedPatientCard extends StatefulWidget {
  final Patient patient;
  final int index;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final bool isCollapsing;
  final bool isExpanding;
  final bool isAnimating;

  const _UnifiedPatientCard({
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
  State<_UnifiedPatientCard> createState() => _UnifiedPatientCardState();
}

class _UnifiedPatientCardState extends State<_UnifiedPatientCard> {
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
                      Row(
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
                      ),
                      AnimatedSize(
                        duration: Duration(
                            milliseconds: widget.isExpanding ? 1200 : 800),
                        curve: Curves.easeInOutCubic,
                        child: (isExpanded || widget.isExpanding)
                            ? Column(
                                children: [
                                  const SizedBox(height: Insets.small),
                                  Container(
                                    height: 1,
                                    color:
                                        widget.textColor.withValues(alpha: 0.1),
                                  ),
                                  const SizedBox(height: Insets.small),
                                  AnimatedOpacity(
                                    duration: Duration(
                                        milliseconds: widget.isExpanding
                                            ? 400
                                            : (widget.isCollapsing
                                                ? 600
                                                : 200)),
                                    opacity: (widget.isExpanding ||
                                            widget.isCollapsing)
                                        ? 0.0
                                        : 1.0,
                                    child: Column(
                                      children: [
                                        _buildPatientInfoRow(
                                          context,
                                          Assets.icons.identification.svg(
                                            width: 16,
                                            height: 16,
                                            colorFilter: ColorFilter.mode(
                                              widget.iconColor,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                          'MRN: ${FhirFieldExtractor.extractPatientMRN(displayPatient)}',
                                        ),
                                        _buildPatientInfoRow(
                                          context,
                                          Assets.icons.calendar.svg(
                                            width: 16,
                                            height: 16,
                                            colorFilter: ColorFilter.mode(
                                              widget.iconColor,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                          '${context.l10n.age}: ${FhirFieldExtractor.extractPatientAge(displayPatient)} (${displayPatient.birthDate})',
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    duration: Duration(
                                        milliseconds: widget.isExpanding
                                            ? 600
                                            : (widget.isCollapsing
                                                ? 400
                                                : 300)),
                                    opacity: (widget.isExpanding ||
                                            widget.isCollapsing)
                                        ? 0.0
                                        : 1.0,
                                    child: Column(
                                      children: [
                                        _buildPatientInfoRow(
                                          context,
                                          _getGenderIcon(displayPatient),
                                          '${context.l10n.gender}: ${_formatGenderDisplay(FhirFieldExtractor.extractPatientGender(displayPatient))}',
                                        ),
                                        _buildPatientInfoRow(
                                          context,
                                          Assets.icons.drop.svg(
                                            width: 16,
                                            height: 16,
                                            colorFilter: ColorFilter.mode(
                                              widget.iconColor,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                          '${context.l10n.bloodType}: $_bloodTypeDisplay',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: Insets.small),
                                  AnimatedOpacity(
                                    duration: Duration(
                                        milliseconds: widget.isExpanding
                                            ? 800
                                            : (widget.isCollapsing
                                                ? 200
                                                : 400)),
                                    opacity: (widget.isExpanding ||
                                            widget.isCollapsing)
                                        ? 0.0
                                        : 1.0,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          context.read<PatientBloc>().add(
                                                PatientEditStarted(
                                                    currentPatient.id),
                                              );
                                          PatientEditDialog.show(
                                            context,
                                            currentPatient,
                                            onBloodTypeUpdated: () {
                                              _loadBloodType();
                                            },
                                          );
                                        },
                                        icon: Assets.icons.edit.svg(
                                          width: 16,
                                          height: 16,
                                          colorFilter: const ColorFilter.mode(
                                            Colors.white,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        label: Text(
                                          context.l10n.editDetails,
                                          style: AppTextStyle.buttonSmall,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Insets.small,
                                            vertical: Insets.small,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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

  Widget _getGenderIcon(Patient patient) {
    final gender = FhirFieldExtractor.extractPatientGender(patient);

    if (gender.toLowerCase() == 'female') {
      return Assets.icons.genderFemale.svg(
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(
          widget.iconColor,
          BlendMode.srcIn,
        ),
      );
    }

    return Assets.icons.genderMale.svg(
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(
        widget.iconColor,
        BlendMode.srcIn,
      ),
    );
  }

  String _formatGenderDisplay(String? gender) {
    if (gender == null || gender.isEmpty) return context.l10n.homeNA;

    final lowerGender = gender.toLowerCase();

    switch (lowerGender) {
      case 'male':
        return context.l10n.male;
      case 'female':
        return context.l10n.female;
      case 'unknown':
      case 'prefer not to say':
      case 'prefer_not_to_say':
      case 'prefernottosay':
        return context.l10n.preferNotToSay;
      default:
        return gender;
    }
  }

  Widget _buildPatientInfoRow(BuildContext context, Widget icon, String text) {
    final textColor = context.colorScheme.onSurface;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmall = screenWidth < 380;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        children: [
          icon,
          const SizedBox(width: Insets.smaller),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isSmall
                  ? AppTextStyle.labelLarge.copyWith(
                      fontSize: 11,
                      color: textColor,
                    )
                  : AppTextStyle.labelLarge.copyWith(
                      color: textColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
