import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/animated_reorderable_list.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/widgets/unified_patient_card.dart';
import 'package:health_wallet/gen/assets.gen.dart';

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
              _buildSectionHeader(context, textColor, iconColor),
              const SizedBox(height: Insets.small),
              if (patients.isNotEmpty) ...[
                _buildPatientList(
                  context,
                  patients,
                  state,
                  borderColor,
                  iconColor,
                  textColor,
                ),
              ] else ...[
                _buildEmptyState(context, borderColor, iconColor, textColor),
              ],
              const SizedBox(height: Insets.small),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    Color textColor,
    Color iconColor,
  ) {
    return Row(
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
    );
  }

  Widget _buildPatientList(
    BuildContext context,
    List<Patient> patients,
    PatientState state,
    Color borderColor,
    Color iconColor,
    Color textColor,
  ) {
    return AnimatedReorderableList<Patient>(
      items: patients,
      itemIdExtractor: (patient) => patient.id,
      itemSpacing: Insets.small,
      itemBuilder: (context, patient, index, isBeingMoved) {
        final isAnimating = state.animatingPatientId == patient.id;
        final isCollapsing = state.collapsingPatientId == patient.id;
        final isExpanding = state.expandingPatientId == patient.id;

        return GestureDetector(
          key: ValueKey(patient.id),
          onTap: () {
            _handlePatientTap(patient.id);
          },
          child: UnifiedPatientCard(
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
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color borderColor,
    Color iconColor,
    Color textColor,
  ) {
    return Container(
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
    );
  }
}
