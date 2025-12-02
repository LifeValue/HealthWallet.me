import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/scan/presentation/widgets/patient_source_info_widget.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:intl/intl.dart';

@RoutePage<String>()
class AttachToEncounterPage extends StatefulWidget {
  const AttachToEncounterPage({super.key});

  @override
  State<AttachToEncounterPage> createState() => _AttachToEncounterPageState();
}

class _AttachToEncounterPageState extends State<AttachToEncounterPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Encounter> _allEncounters = [];
  List<Encounter> _filteredEncounters = [];
  bool _isLoading = true;
  Encounter? _selectedEncounter;
  String? _currentPatientId;
  String? _currentSourceId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterEncounters);
    _searchController.addListener(_updateSearchIcon);
    _loadEncounters();
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearchIcon);
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchIcon() {
    setState(() {});
  }

  Future<void> _loadEncounters() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final patientState = context.read<PatientBloc>().state;

      final selectedPatient = patientState.patients.isNotEmpty
          ? patientState.patients.firstWhere(
              (p) => p.id == patientState.selectedPatientId,
              orElse: () => patientState.patients.first,
            )
          : null;

      final currentPatientId = selectedPatient?.resourceId;
      final currentSourceId = selectedPatient?.sourceId;

      final recordsRepository = getIt<RecordsRepository>();
      final resources = await recordsRepository.getResources(
        resourceTypes: [FhirType.Encounter],
        sourceId: currentSourceId,
        limit: 100,
      );

      final encounters = resources.whereType<Encounter>().toList();

      setState(() {
        _allEncounters = encounters;
        _filteredEncounters = encounters;
        _isLoading = false;
        _currentPatientId = currentPatientId;
        _currentSourceId = currentSourceId;
        _selectedEncounter = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkForPatientChange() {
    final patientState = context.read<PatientBloc>().state;

    final selectedPatient = patientState.patients.isNotEmpty
        ? patientState.patients.firstWhere(
            (p) => p.id == patientState.selectedPatientId,
            orElse: () => patientState.patients.first,
          )
        : null;

    final currentPatientId = selectedPatient?.resourceId;
    final currentSourceId = selectedPatient?.sourceId;

    if (_currentPatientId != currentPatientId ||
        _currentSourceId != currentSourceId) {
      _loadEncounters();
    }
  }

  void _filterEncounters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEncounters = _allEncounters;
      } else {
        _filteredEncounters = _allEncounters
            .where((encounter) =>
                encounter.title.toLowerCase().contains(query) ||
                encounter.displayTitle.toLowerCase().contains(query) ||
                encounter.id.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _handleCancel() {
    context.router.maybePop();
  }

  void _handleSelect(Encounter encounter) {
    setState(() {
      _selectedEncounter = encounter;
    });
  }

  void _handleDone() {
    if (_selectedEncounter != null) {
      context.router.maybePop(_selectedEncounter!.resourceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return MultiBlocListener(
      listeners: [
        BlocListener<HomeBloc, HomeState>(
          listener: (context, state) {
            _checkForPatientChange();
          },
        ),
        BlocListener<PatientBloc, PatientState>(
          listener: (context, state) {
            _checkForPatientChange();
          },
        ),
      ],
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Attach to encounter'),
        body: Container(
          padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            children: [
              const Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.normal),
                child: PatientSourceInfoWidget(
                  title: 'Current Patient & Source',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.normal),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: AppTextStyle.bodyMedium,
                    maxLines: 1,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search encounters...',
                      hintStyle: AppTextStyle.labelLarge.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Assets.icons.search.svg(
                          width: 16,
                          colorFilter: ColorFilter.mode(
                            context.colorScheme.onSurface.withOpacity(0.6),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _filterEncounters();
                              },
                              icon: Assets.icons.close.svg(
                                width: Insets.normal,
                                height: Insets.normal,
                                colorFilter: ColorFilter.mode(
                                  context.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  BlendMode.srcIn,
                                ),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide:
                            BorderSide(color: context.theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide:
                            BorderSide(color: context.theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: context.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colorScheme.primary,
                        ),
                      )
                    : _filteredEncounters.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: iconColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No encounters found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create a new encounter first or select a different patient.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: iconColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredEncounters.length,
                            itemBuilder: (context, index) {
                              final encounter = _filteredEncounters[index];
                              final isSelected =
                                  _selectedEncounter?.id == encounter.id;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: isSelected ? 3 : 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected
                                        ? context.colorScheme.primary
                                        : borderColor.withOpacity(0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? context.colorScheme.primaryContainer
                                          : context.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check
                                          : Icons.medical_information,
                                      color: isSelected
                                          ? context
                                              .colorScheme.onPrimaryContainer
                                          : context.colorScheme.onPrimary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    encounter.displayTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  subtitle: encounter.date != null
                                      ? Text(
                                          DateFormat.yMMMd()
                                              .format(encounter.date!),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: iconColor,
                                          ),
                                        )
                                      : null,
                                  onTap: () => _handleSelect(encounter),
                                  hoverColor: context
                                      .colorScheme.primaryContainer
                                      .withOpacity(0.3),
                                  selectedTileColor: context
                                      .colorScheme.primaryContainer
                                      .withOpacity(0.1),
                                  selected: isSelected,
                                ),
                              );
                            },
                          ),
              ),
              Container(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.normal,
                  Insets.normal,
                  Insets.normal,
                  Insets.large,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: Insets.small),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text('Cancel', style: AppTextStyle.buttonSmall),
                      ),
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _selectedEncounter != null ? _handleDone : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedEncounter != null
                              ? AppColors.primary
                              : context.colorScheme.surfaceVariant,
                          foregroundColor: _selectedEncounter != null
                              ? Colors.white
                              : context.colorScheme.onSurfaceVariant,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: Insets.small),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text('Done', style: AppTextStyle.buttonSmall),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
