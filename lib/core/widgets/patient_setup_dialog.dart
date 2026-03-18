import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';
import 'package:health_wallet/features/scan/presentation/helpers/scan_path_helper.dart';
import 'package:health_wallet/features/sync/presentation/widgets/patient_dialog_card.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/dialog_content.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/features/user/domain/services/id_card_extractor.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/domain/utils/gender_mapper.dart';
import 'package:permission_handler/permission_handler.dart';

class PatientSetupDialog extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onDismiss;

  const PatientSetupDialog({
    super.key,
    required this.patient,
    this.onDismiss,
  });

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
  String _selectedContactPhone = '';
  bool _isLoading = false;
  bool _isScanning = false;
  bool _scanCompleted = false;
  String? _lastScannedImagePath;
  Patient? _currentPatient;
  late String _selectedCountryCode;

  late TextEditingController _givenController;
  late TextEditingController _familyController;
  late TextEditingController _identifierController;

  List<String> _getGenderOptions(AppLocalizations l10n) =>
      [l10n.male, l10n.female, l10n.preferNotToSay];
  final List<String> _bloodTypeOptions = [
    'N/A',
    ...BloodTypes.getAllBloodTypes()
  ];

  @override
  void initState() {
    super.initState();

    _givenController = TextEditingController();
    _familyController = TextEditingController();
    _identifierController = TextEditingController();
    _selectedBloodType = 'N/A';
    _selectedCountryCode = WidgetsBinding
            .instance.platformDispatcher.locale.countryCode
            ?.toUpperCase() ??
        'US';

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
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isLoading || _currentPatient == null) return;

    setState(() => _isLoading = true);

    try {
      final currentGivenValue = _givenController.text;
      final currentFamilyValue = _familyController.text;
      final currentIdentifierValue = _identifierController.text;

      final givenChanged = currentGivenValue.isNotEmpty;
      final familyChanged = currentFamilyValue.isNotEmpty;
      final nameChanged = givenChanged || familyChanged;
      final birthDateChanged = _selectedBirthDate != null;
      final genderChanged = _selectedGender != context.l10n.preferNotToSay;
      final bloodTypeChanged = _selectedBloodType != 'N/A';
      final identifierChanged = currentIdentifierValue.isNotEmpty;

      if (mounted) {
        final patientFieldsChanged = nameChanged ||
            birthDateChanged ||
            genderChanged ||
            identifierChanged ||
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
                  identifierValue: currentIdentifierValue.isNotEmpty ? currentIdentifierValue : null,
                  contactPhone: _selectedContactPhone.isNotEmpty ? _selectedContactPhone : null,
                  availableSources: homeState.sources,
                ),
              );
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

  Future<void> _handleScanIdCard() async {
    if (_isScanning) return;

    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    setState(() => _isScanning = true);

    try {
      final scannedResult =
          await FlutterDocScanner().getScannedDocumentAsImages(page: 1);

      if (scannedResult == null || scannedResult.images.isEmpty) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final rawPaths = scannedResult.images
          .where((p) => p.isNotEmpty)
          .toList();
      final sanitizedPaths = ScanPathHelper.normalizePaths(rawPaths);
      if (sanitizedPaths.isEmpty) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final imagePath = sanitizedPaths.first;
      _lastScannedImagePath = imagePath;
      await _extractFromImage(imagePath);
    } catch (e) {
      debugPrint('ID card scan failed: $e');
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _handleRetryOcr() async {
    if (_isScanning || _lastScannedImagePath == null) return;
    setState(() => _isScanning = true);
    try {
      await _extractFromImage(_lastScannedImagePath!);
    } catch (e) {
      debugPrint('OCR retry failed: $e');
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _handlePickFromGallery() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      _lastScannedImagePath = image.path;
      await _extractFromImage(image.path);
    } catch (e) {
      debugPrint('Gallery pick failed: $e');
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _extractFromImage(String imagePath) async {
    final textRecognition = getIt<TextRecognitionService>();
    final ocrText = await textRecognition.recognizeTextFromImage(imagePath);

    if (ocrText.isEmpty) {
      if (mounted) setState(() => _isScanning = false);
      return;
    }

    final countryCode = context.read<UserBloc>().state.countryCode;
    final result = IdCardExtractor.extract(ocrText, countryCode);

    if (mounted && result.hasData) {
      setState(() {
        if (result.familyName != null && result.familyName!.isNotEmpty) {
          _familyController.text = result.familyName!;
        }
        if (result.givenName != null && result.givenName!.isNotEmpty) {
          _givenController.text = result.givenName!;
        }
        if (result.identifierValue != null &&
            result.identifierValue!.isNotEmpty) {
          _identifierController.text = result.identifierValue!;
        }
        if (result.dateOfBirth != null) {
          _selectedBirthDate = DateTime.tryParse(result.dateOfBirth!);
        }
        if (result.gender != null) {
          _selectedGender = GenderMapper.mapFhirGenderToDisplay(
              result.gender!, context.l10n);
        }
        _isScanning = false;
        _scanCompleted = true;
      });
    } else {
      if (mounted) setState(() => _isScanning = false);
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
            isScanning: _isScanning,
            scanCompleted: _scanCompleted,
            onScanIdCard: _handleScanIdCard,
            onPickFromGallery: _handlePickFromGallery,
            onRetryOcr: _scanCompleted ? _handleRetryOcr : null,
            identifierLabel: CountryIdentifier.forCountry(
              _selectedCountryCode,
            ).identifierLabel,
            selectedCountryCode: _selectedCountryCode,
            onCountryChanged: (code) {
              setState(() {
                _selectedCountryCode = code;
                _selectedContactPhone = '';
              });
            },
            selectedGiven: '',
            selectedFamily: '',
            selectedIdentifier: '',
            selectedBirthDate: _selectedBirthDate,
            selectedGender: _selectedGender,
            selectedBloodType: _selectedBloodType,
            genderOptions: _getGenderOptions(context.l10n),
            bloodTypeOptions: _bloodTypeOptions,
            iconColor: iconColor,
            onGivenChanged: (String value) {},
            onFamilyChanged: (String value) {},
            onIdentifierChanged: (String value) {},
            onContactPhoneChanged: (String value) {
              _selectedContactPhone = value;
            },
            selectedContactPhone: _selectedContactPhone,
            givenController: _givenController,
            familyController: _familyController,
            identifierController: _identifierController,
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
