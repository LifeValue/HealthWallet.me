import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/sync/presentation/widgets/patient_dialog_card.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'utils/dialog_content.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/domain/utils/gender_mapper.dart';

class PatientEditDialog extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onBloodTypeUpdated;
  final VoidCallback? onDismiss;

  const PatientEditDialog({
    super.key,
    required this.patient,
    this.onBloodTypeUpdated,
    this.onDismiss,
  });

  static void show(
    BuildContext context,
    Patient patient, {
    VoidCallback? onBloodTypeUpdated,
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
            child: PatientEditDialog(
              patient: patient,
              onBloodTypeUpdated: onBloodTypeUpdated,
              onDismiss: onDismiss,
            ),
          ),
        );
      },
    );
  }

  @override
  State<PatientEditDialog> createState() => _PatientEditDialogState();
}

class _PatientEditDialogState extends State<PatientEditDialog> {
  String _selectedGiven = '';
  String _selectedFamily = '';
  DateTime? _selectedBirthDate;
  String _selectedGender = 'Prefer not to say';
  String _selectedBloodType = 'N/A';
  String _selectedMRN = '';
  String _selectedContactPhone = '';
  late PatientEditService _patientEditService;
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
    _patientEditService = getIt<PatientEditService>();

    _givenController =
        TextEditingController(text: _extractGiven(widget.patient));
    _familyController =
        TextEditingController(text: _extractFamily(widget.patient));
    _mrnController = TextEditingController(
        text: FhirFieldExtractor.extractPatientMRN(widget.patient));
    _initializeControllers();
    _initializeCurrentPatient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extractedGender =
        FhirFieldExtractor.extractPatientGender(widget.patient);
    _selectedGender =
        GenderMapper.mapFhirGenderToDisplay(extractedGender, context.l10n);
  }

  void _initializeControllers() {
    final extractedGender =
        FhirFieldExtractor.extractPatientGender(widget.patient);
    _selectedGender =
        GenderMapper.mapFhirGenderToDisplayFallback(extractedGender);
    _selectedGiven = _extractGiven(widget.patient);
    _selectedFamily = _extractFamily(widget.patient);

    _selectedBirthDate =
        FhirFieldExtractor.extractPatientBirthDate(widget.patient);
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

      _selectedGiven = _extractGiven(_currentPatient!);
      _selectedFamily = _extractFamily(_currentPatient!);
      _selectedBirthDate =
          FhirFieldExtractor.extractPatientBirthDate(_currentPatient!);

      final extractedGender =
          FhirFieldExtractor.extractPatientGender(_currentPatient!);
      _selectedGender =
          GenderMapper.mapFhirGenderToDisplay(extractedGender, context.l10n);

      _selectedMRN = FhirFieldExtractor.extractPatientMRN(_currentPatient!);
      _selectedContactPhone = _extractContactPhone(_currentPatient!);

      _givenController.text = _selectedGiven;
      _familyController.text = _selectedFamily;
      _mrnController.text = _selectedMRN;

      _initializeBloodType();
    });
  }

  String _extractGiven(Patient patient) {
    if (patient.name?.isNotEmpty == true) {
      final given = patient.name!.first.given;
      if (given != null && given.isNotEmpty) {
        return given.map((g) => g.toString()).join(' ');
      }
    }
    return '';
  }

  String _extractFamily(Patient patient) {
    if (patient.name?.isNotEmpty == true) {
      final family = patient.name!.first.family;
      if (family != null) {
        return family.toString();
      }
    }
    return '';
  }

  String _extractContactPhone(Patient patient) {
    final contact = patient.contact?.firstOrNull;
    if (contact == null) return '';
    return FhirFieldExtractor.extractTelecomBySystem(
            contact.telecom, 'phone') ??
        '';
  }

  Future<void> _initializeBloodType() async {
    if (_currentPatient == null) return;

    try {
      final extractedBloodType =
          await _patientEditService.getCurrentBloodType(_currentPatient!);

      if (mounted) {
        setState(() {
          if (extractedBloodType != null && extractedBloodType.isNotEmpty) {
            _selectedBloodType = _bloodTypeOptions.contains(extractedBloodType)
                ? extractedBloodType
                : 'N/A';
          } else {
            _selectedBloodType = 'N/A';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedBloodType = 'N/A');
      }
    }
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
      final hasServiceChanges = await _patientEditService.hasPatientChanges(
        currentPatient: _currentPatient!,
        newBirthDate: _selectedBirthDate,
        newGender: _selectedGender,
        newBloodType: _selectedBloodType,
        newMRN: _selectedMRN,
        l10n: context.l10n,
      );
      final hasNameChanges =
          _extractGiven(_currentPatient!) != _givenController.text ||
              _extractFamily(_currentPatient!) != _familyController.text;
      final hasContactPhoneChanges =
          _extractContactPhone(_currentPatient!) != _selectedContactPhone;
      final hasChanges =
          hasServiceChanges || hasNameChanges || hasContactPhoneChanges;

      if (!hasChanges) {
        if (mounted) {
          context.popDialog();
          widget.onDismiss?.call();
        }
        return;
      }

      final currentBloodType =
          await _patientEditService.getCurrentBloodType(_currentPatient!);
      final currentBirthDate =
          FhirFieldExtractor.extractPatientBirthDate(_currentPatient!);
      final currentGender =
          FhirFieldExtractor.extractPatientGender(_currentPatient!);
      final currentGivenValue = _givenController.text;
      final currentFamilyValue = _familyController.text;
      final currentMRNValue = _mrnController.text;

      final currentGiven = _extractGiven(_currentPatient!);
      final currentFamily = _extractFamily(_currentPatient!);
      final currentMRN = FhirFieldExtractor.extractPatientMRN(_currentPatient!);
      final currentContactPhone = _extractContactPhone(_currentPatient!);
      final currentContactPhoneValue = _selectedContactPhone;

      final givenChanged = currentGiven != currentGivenValue;
      final familyChanged = currentFamily != currentFamilyValue;
      final nameChanged = givenChanged || familyChanged;
      final birthDateChanged = currentBirthDate != _selectedBirthDate;
      final genderChanged =
          GenderMapper.mapFhirGenderToDisplay(currentGender, context.l10n) !=
              _selectedGender;
      final bloodTypeChanged = currentBloodType != _selectedBloodType;
      final mrnChanged = currentMRN != currentMRNValue;
      final contactPhoneChanged = currentContactPhone != currentContactPhoneValue;

      final onlyBloodTypeChanged = bloodTypeChanged &&
          !nameChanged &&
          !birthDateChanged &&
          !genderChanged &&
          !mrnChanged &&
          !contactPhoneChanged;

      if (onlyBloodTypeChanged) {
        await _patientEditService.updateBloodTypeObservation(
          _currentPatient!,
          _selectedBloodType,
        );

        await _initializeBloodType();

        if (widget.onBloodTypeUpdated != null) {
          widget.onBloodTypeUpdated!();
        }

        if (mounted) {
          context.popDialog();
          widget.onDismiss?.call();
        }
        return;
      }

      if (mounted) {
        final patientFieldsChanged = nameChanged ||
            birthDateChanged ||
            genderChanged ||
            mrnChanged ||
            contactPhoneChanged ||
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
                  given: givenChanged ? givenList : null,
                  family: familyChanged
                      ? (currentFamilyValue.isNotEmpty
                          ? currentFamilyValue
                          : null)
                      : null,
                  birthDate: birthDateChanged ? _selectedBirthDate : null,
                  gender: genderChanged ? _selectedGender : null,
                  bloodType: bloodTypeChanged
                      ? _selectedBloodType
                      : currentBloodType ?? 'N/A',
                  mrn: mrnChanged ? currentMRNValue : null,
                  contactPhone: contactPhoneChanged
                      ? currentContactPhoneValue
                      : null,
                  availableSources: homeState.sources,
                ),
              );
        }

        if (bloodTypeChanged && widget.onBloodTypeUpdated != null && mounted) {
          widget.onBloodTypeUpdated!();
        }

        context.popDialog();
        widget.onDismiss?.call();
      }
    } catch (e) {
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
        title: context.l10n.editDetails,
        content: _buildPatientForm(iconColor),
        isLoading: _isLoading,
        cancelLabel: context.l10n.cancel,
        saveLabel: context.l10n.save,
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
            isSetupMode: false,
            identifierLabel: FhirFieldExtractor.extractPatientIdentifierLabel(_currentPatient!),
            selectedGiven: _selectedGiven,
            selectedFamily: _selectedFamily,
            selectedMRN: _selectedMRN,
            selectedContactPhone: _selectedContactPhone,
            selectedBirthDate: _selectedBirthDate,
            selectedGender: _selectedGender,
            selectedBloodType: _selectedBloodType,
            genderOptions: _getGenderOptions(context.l10n),
            bloodTypeOptions: _bloodTypeOptions,
            iconColor: iconColor,
            onGivenChanged: (String value) {
              _selectedGiven = value;
            },
            onFamilyChanged: (String value) {
              _selectedFamily = value;
            },
            onMRNChanged: (String value) {
              _selectedMRN = value;
            },
            onContactPhoneChanged: (String value) {
              _selectedContactPhone = value;
            },
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
