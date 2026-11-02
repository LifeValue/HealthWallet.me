import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/widgets/patient_card_details.dart';
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
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        return BlocBuilder<PatientBloc, PatientState>(
          builder: (context, blocState) {
            // The person's own row, whatever source Home shows, so the card
            // and the edit dialog show the same details.
            final displayPatient =
                blocState
                    .patientGroups[widget.patient.id]
                    ?.representativePatient ??
                widget.patient;

            final currentPatient = blocState.patients.firstWhere(
              (p) => p.id == widget.patient.id,
              orElse: () => widget.patient,
            );

            final isExpanded = blocState.expandedPatientIds.contains(
              currentPatient.id,
            );

            final cardScale = widget.isExpanding ? 1.02 : 1.0;

            final bloodTypes = blocState.bloodTypes;
            final bloodTypeDisplay = bloodTypes.containsKey(currentPatient.id)
                ? bloodTypes[currentPatient.id] ?? context.l10n.homeNA
                : context.l10n.loading;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutCubic,
              padding: const EdgeInsets.all(Insets.small),
              margin: const EdgeInsets.only(bottom: Insets.small),
              transform: Matrix4.diagonal3Values(
                cardScale,
                cardScale,
                cardScale,
              ),
              decoration: BoxDecoration(
                color: _getCardColor(context, currentPatient),
                border: Border.all(
                  color: _getBorderColor(context, currentPatient),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildCardHeader(context, displayPatient, currentPatient),
                  AnimatedSize(
                    duration: Duration(
                      milliseconds: widget.isExpanding ? 1200 : 800,
                    ),
                    curve: Curves.easeInOutCubic,
                    child: (isExpanded || widget.isExpanding)
                        ? PatientCardDetails(
                            displayPatient: displayPatient,
                            currentPatient: currentPatient,
                            iconColor: widget.iconColor,
                            textColor: widget.textColor,
                            isExpanding: widget.isExpanding,
                            isCollapsing: widget.isCollapsing,
                            bloodTypeDisplay: bloodTypeDisplay,
                            onBloodTypeUpdated: () => context
                                .read<PatientBloc>()
                                .add(const PatientBloodTypesRequested()),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
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
                    displayPatient.name?.first,
                  ) ??
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
    if (context.read<PatientBloc>().state.expandedPatientIds.contains(
      patient.id,
    )) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
    if (widget.isAnimating) return AppColors.primary.withValues(alpha: 0.15);
    return Colors.transparent;
  }

  Color _getBorderColor(BuildContext context, Patient patient) {
    if (widget.isCollapsing) return widget.borderColor;
    if (widget.isExpanding) return AppColors.primary.withValues(alpha: 0.5);
    if (context.read<PatientBloc>().state.expandedPatientIds.contains(
      patient.id,
    )) {
      return AppColors.primary;
    }
    if (widget.isAnimating) return AppColors.primary.withValues(alpha: 0.5);
    return widget.borderColor;
  }

  double _getRotationTurns(BuildContext context, Patient patient) {
    if (context.read<PatientBloc>().state.expandedPatientIds.contains(
      patient.id,
    )) {
      return 0.5;
    }
    return 0.0;
  }
}
