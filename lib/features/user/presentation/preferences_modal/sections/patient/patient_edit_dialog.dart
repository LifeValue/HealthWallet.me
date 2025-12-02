import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'utils/dialog_header.dart';
import 'utils/dialog_content.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'utils/form_fields.dart';
import 'services/patient_edit_service.dart';
import 'utils/gender_mapper.dart';

class PatientEditDialog extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onBloodTypeUpdated;
  final VoidCallback? onDismiss;
  final bool isSetupMode;

  const PatientEditDialog({
    super.key,
    required this.patient,
    this.onBloodTypeUpdated,
    this.onDismiss,
    this.isSetupMode = false,
  });

  /// Shows the dialog in edit mode (default)
  static void show(
    BuildContext context,
    Patient patient, {
    VoidCallback? onBloodTypeUpdated,
    VoidCallback? onDismiss,
  }) {
    _showDialog(
      context,
      patient,
      isSetupMode: false,
      onBloodTypeUpdated: onBloodTypeUpdated,
      onDismiss: onDismiss,
    );
  }

  /// Shows the dialog in setup mode (for onboarding)
  static void showSetupMode(
    BuildContext context,
    Patient patient, {
    VoidCallback? onDismiss,
  }) {
    _showDialog(
      context,
      patient,
      isSetupMode: true,
      onDismiss: onDismiss,
    );
  }

  static void _showDialog(
    BuildContext context,
    Patient patient, {
    required bool isSetupMode,
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
              isSetupMode: isSetupMode,
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

    // In setup mode, start with empty fields
    if (widget.isSetupMode) {
      _givenController = TextEditingController();
      _familyController = TextEditingController();
      _mrnController = TextEditingController();
      _selectedBloodType = 'N/A';
    } else {
      _givenController =
          TextEditingController(text: _extractGiven(widget.patient));
      _familyController =
          TextEditingController(text: _extractFamily(widget.patient));
      _mrnController = TextEditingController(
          text: FhirFieldExtractor.extractPatientMRN(widget.patient));
      _initializeControllers();
    }
    _initializeCurrentPatient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isSetupMode) {
      _selectedGender = context.l10n.preferNotToSay;
    } else {
      final extractedGender =
          FhirFieldExtractor.extractPatientGender(widget.patient);
      _selectedGender =
          GenderMapper.mapFhirGenderToDisplay(extractedGender, context.l10n);
    }
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

      // In setup mode, don't pre-fill the text fields
      if (!widget.isSetupMode) {
        _selectedGiven = _extractGiven(_currentPatient!);
        _selectedFamily = _extractFamily(_currentPatient!);
        _selectedBirthDate =
            FhirFieldExtractor.extractPatientBirthDate(_currentPatient!);

        final extractedGender =
            FhirFieldExtractor.extractPatientGender(_currentPatient!);
        _selectedGender =
            GenderMapper.mapFhirGenderToDisplay(extractedGender, context.l10n);

        _selectedMRN = FhirFieldExtractor.extractPatientMRN(_currentPatient!);

        _givenController.text = _selectedGiven;
        _familyController.text = _selectedFamily;
        _mrnController.text = _selectedMRN;

        _initializeBloodType();
      } else {
        // In setup mode, just set _currentPatient and use default values
        setState(() {});
      }
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
      // In setup mode, always save the data (no "no changes" check)
      if (!widget.isSetupMode) {
        final hasChanges = await _patientEditService.hasPatientChanges(
          currentPatient: _currentPatient!,
          newBirthDate: _selectedBirthDate,
          newGender: _selectedGender,
          newBloodType: _selectedBloodType,
          newMRN: _selectedMRN,
          l10n: context.l10n,
        );

        if (!hasChanges) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.noChangesDetected),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
            context.popDialog();
            widget.onDismiss?.call();
          }
          return;
        }
      }

      final currentBloodType = widget.isSetupMode
          ? null
          : await _patientEditService.getCurrentBloodType(_currentPatient!);
      final currentBirthDate = widget.isSetupMode
          ? null
          : FhirFieldExtractor.extractPatientBirthDate(_currentPatient!);
      final currentGender = widget.isSetupMode
          ? null
          : FhirFieldExtractor.extractPatientGender(_currentPatient!);
      final currentGivenValue = _givenController.text;
      final currentFamilyValue = _familyController.text;
      final currentMRNValue = _mrnController.text;

      final currentGiven =
          widget.isSetupMode ? '' : _extractGiven(_currentPatient!);
      final currentFamily =
          widget.isSetupMode ? '' : _extractFamily(_currentPatient!);
      final currentMRN = widget.isSetupMode
          ? ''
          : FhirFieldExtractor.extractPatientMRN(_currentPatient!);

      final givenChanged = widget.isSetupMode
          ? currentGivenValue.isNotEmpty
          : (currentGiven != currentGivenValue);
      final familyChanged = widget.isSetupMode
          ? currentFamilyValue.isNotEmpty
          : (currentFamily != currentFamilyValue);
      final nameChanged = givenChanged || familyChanged;
      final birthDateChanged = widget.isSetupMode
          ? _selectedBirthDate != null
          : (currentBirthDate != _selectedBirthDate);
      final genderChanged = widget.isSetupMode
          ? _selectedGender != context.l10n.preferNotToSay
          : GenderMapper.mapFhirGenderToDisplay(currentGender, context.l10n) !=
              _selectedGender;
      final bloodTypeChanged = widget.isSetupMode
          ? _selectedBloodType != 'N/A'
          : currentBloodType != _selectedBloodType;
      final mrnChanged = widget.isSetupMode
          ? currentMRNValue.isNotEmpty
          : (currentMRN != currentMRNValue);

      final onlyBloodTypeChanged = bloodTypeChanged &&
          !nameChanged &&
          !birthDateChanged &&
          !genderChanged &&
          !mrnChanged;

      if (onlyBloodTypeChanged && !widget.isSetupMode) {
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
                  given: givenChanged || widget.isSetupMode ? givenList : null,
                  family: familyChanged || widget.isSetupMode
                      ? (currentFamilyValue.isNotEmpty
                          ? currentFamilyValue
                          : null)
                      : null,
                  birthDate: birthDateChanged || widget.isSetupMode
                      ? _selectedBirthDate
                      : null,
                  gender: genderChanged || widget.isSetupMode
                      ? _selectedGender
                      : null,
                  bloodType: bloodTypeChanged || widget.isSetupMode
                      ? _selectedBloodType
                      : currentBloodType ?? 'N/A',
                  mrn:
                      mrnChanged || widget.isSetupMode ? currentMRNValue : null,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.errorSavingPatientData}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    final borderColor = context.theme.dividerColor;
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Dynamic labels based on mode
    final headerTitle =
        widget.isSetupMode ? context.l10n.setup : context.l10n.editDetails;
    final headerSubtitle =
        widget.isSetupMode ? context.l10n.patientSetupSubtitle : null;
    final cancelLabel = context.l10n.cancel;
    final saveLabel =
        widget.isSetupMode ? context.l10n.done : context.l10n.saveDetails;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: Container(
        width: 350,
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogHeader(
              textColor: textColor,
              onCancel: _handleCancel,
              title: headerTitle,
              subtitle: headerSubtitle,
            ),
            Container(height: 1, color: borderColor),
            Flexible(
              child: _buildPatientForm(iconColor),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.normal),
              child: FormFields.buildActionButtons(
                onCancel: _handleCancel,
                onSave: () => _handleSave(),
                isLoading: _isLoading,
                cancelLabel: cancelLabel,
                saveLabel: saveLabel,
              ),
            ),
          ],
        ),
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
            isSetupMode: widget.isSetupMode,
            selectedGiven: widget.isSetupMode ? '' : _selectedGiven,
            selectedFamily: widget.isSetupMode ? '' : _selectedFamily,
            selectedMRN: widget.isSetupMode ? '' : _selectedMRN,
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
