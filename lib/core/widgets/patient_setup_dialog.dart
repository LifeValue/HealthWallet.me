import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/sync/presentation/widgets/patient_dialog_card.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/dialog_content.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

class PatientSetupDialog extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onDismiss;

  const PatientSetupDialog({
    super.key,
    required this.patient,
    this.onDismiss,
  });

  /// Shows the dialog in setup mode (for onboarding)
  static void show(
    BuildContext context,
    Patient patient, {
    VoidCallback? onDismiss,
  }) {
    final patientBloc = BlocProvider.of<PatientBloc>(context);
    final homeBloc = BlocProvider.of<HomeBloc>(context);
    final userBloc = BlocProvider.of<UserBloc>(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: userBloc),
            BlocProvider.value(value: patientBloc),
            BlocProvider.value(value: homeBloc),
          ],
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: PatientSetupDialog(
              patient: patient,
              onDismiss: onDismiss,
            ),
          ),
        );
      },
    );
  }

  @override
  State<PatientSetupDialog> createState() => _PatientSetupDialogState();
}

class _PatientSetupDialogState extends State<PatientSetupDialog> {
  DateTime? _selectedBirthDate;
  String _selectedGender = 'Prefer not to say';
  String _selectedBloodType = 'N/A';
  bool _isLoading = false;
  Patient? _currentPatient;

  late TextEditingController _givenController;
  late TextEditingController _familyController;
  late TextEditingController _mrnController;

  List<String> _getGenderOptions(AppLocalizations l10n) =>
      [l10n.male, l10n.female, l10n.preferNotToSay];
  final List<String> _bloodTypeOptions = [
    'N/A',
    ...BloodTypes.getAllBloodTypes()
  ];

  @override
  void initState() {
    super.initState();

    // Start with empty fields in setup mode
    _givenController = TextEditingController();
    _familyController = TextEditingController();
    _mrnController = TextEditingController();
    _selectedBloodType = 'N/A';

    _initializeCurrentPatient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedGender = context.l10n.preferNotToSay;
  }

  void _initializeCurrentPatient() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final blocState = context.read<PatientBloc>().state;
      final patientGroup = blocState.patientGroups[widget.patient.id];

      final walletPatient = patientGroup?.allPatientInstances
          .where((p) => p.sourceId.startsWith('wallet'))
          .firstOrNull;

      if (walletPatient != null) {
        _currentPatient = walletPatient;
      } else {
        _currentPatient = patientGroup?.representativePatient ?? widget.patient;
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _givenController.dispose();
    _familyController.dispose();
    _mrnController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isLoading || _currentPatient == null) return;

    setState(() => _isLoading = true);

    try {
      final currentGivenValue = _givenController.text;
      final currentFamilyValue = _familyController.text;
      final currentMRNValue = _mrnController.text;

      final givenChanged = currentGivenValue.isNotEmpty;
      final familyChanged = currentFamilyValue.isNotEmpty;
      final nameChanged = givenChanged || familyChanged;
      final birthDateChanged = _selectedBirthDate != null;
      final genderChanged = _selectedGender != context.l10n.preferNotToSay;
      final bloodTypeChanged = _selectedBloodType != 'N/A';
      final mrnChanged = currentMRNValue.isNotEmpty;

      if (mounted) {
        final patientFieldsChanged = nameChanged ||
            birthDateChanged ||
            genderChanged ||
            mrnChanged ||
            bloodTypeChanged;

        if (patientFieldsChanged) {
          final homeState = context.read<HomeBloc>().state;

          final givenList = currentGivenValue.isNotEmpty
              ? currentGivenValue.split(' ').where((s) => s.isNotEmpty).toList()
              : null;

          context.read<PatientBloc>().add(
                PatientEditSaved(
                  patientId: _currentPatient!.id,
                  sourceId: _currentPatient!.sourceId,
                  given: givenList,
                  family:
                      currentFamilyValue.isNotEmpty ? currentFamilyValue : null,
                  birthDate: _selectedBirthDate,
                  gender: _selectedGender,
                  bloodType: _selectedBloodType,
                  mrn: currentMRNValue.isNotEmpty ? currentMRNValue : null,
                  availableSources: homeState.sources,
                ),
              );
        }

        context.popDialog();
        widget.onDismiss?.call();
      }
    } catch (e) {
      // Error handling - dialog will remain open for user to retry
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCancel() {
    context.read<PatientBloc>().add(const PatientEditCancelled());
    context.popDialog();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: PatientDialogCard(
        title: context.l10n.setup,
        subtitle: context.l10n.patientSetupSubtitle,
        content: _buildPatientForm(iconColor),
        isLoading: _isLoading,
        cancelLabel: context.l10n.cancel,
        saveLabel: context.l10n.done,
        onCancel: _handleCancel,
        onSave: _handleSave,
      ),
    );
  }

  Widget _buildPatientForm(Color iconColor) {
    if (_currentPatient == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogContent(
            patient: _currentPatient!,
            showNameField: true,
            isSetupMode: true,
            selectedGiven: '',
            selectedFamily: '',
            selectedMRN: '',
            selectedBirthDate: _selectedBirthDate,
            selectedGender: _selectedGender,
            selectedBloodType: _selectedBloodType,
            genderOptions: _getGenderOptions(context.l10n),
            bloodTypeOptions: _bloodTypeOptions,
            iconColor: iconColor,
            onGivenChanged: (String value) {},
            onFamilyChanged: (String value) {},
            onMRNChanged: (String value) {},
            givenController: _givenController,
            familyController: _familyController,
            mrnController: _mrnController,
            onBirthDateChanged: (DateTime? date) =>
                setState(() => _selectedBirthDate = date),
            onGenderChanged: (String value) =>
                setState(() => _selectedGender = value),
            onBloodTypeChanged: (String value) =>
                setState(() => _selectedBloodType = value),
          ),
          const SizedBox(height: Insets.medium),
        ],
      ),
    );
  }
}
