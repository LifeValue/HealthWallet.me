import 'package:collection/collection.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/repository/holder_repository.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linking_service.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

/// The people in the wallet, read from the stored links (see
/// [HolderLinkingService]), and the one place a holder's wallet source is
/// found or made.
@injectable
class HolderService {
  HolderService(
    this._linking,
    this._repository,
    this._recordsRepository,
    this._syncRepository,
  );

  final HolderLinkingService _linking;
  final HolderRepository _repository;
  final RecordsRepository _recordsRepository;
  final SyncRepository _syncRepository;
  final _matcher = const HolderMatcher();

  /// Every Patient row; a wallet holds a handful, not thousands.
  static const _allPatients = 100000;

  /// Links what arrived since the last read, then reads everyone.
  Future<HolderDirectory> load() async {
    final questions = await _linking.linkUnassigned();
    final holderBySource = await _repository.holderBySource();
    final patients = (await _recordsRepository.getResources(
      resourceTypes: [FhirType.Patient],
      limit: _allPatients,
    )).whereType<Patient>().toList();

    final sourcesOf = <String, List<String>>{};
    for (final MapEntry(key: sourceId, value: holderId)
        in holderBySource.entries) {
      (sourcesOf[holderId] ??= []).add(sourceId);
    }
    for (final ids in sourcesOf.values) {
      ids.sort();
    }

    final holders = <Holder>[];
    final placed = <String>{};
    for (final patient in patients) {
      final holderId = holderBySource[patient.sourceId];
      if (holderId == null || !placed.add(holderId)) continue;
      final sourceIds = sourcesOf[holderId]!;
      final rows = patients
          .where((p) => sourceIds.contains(p.sourceId))
          .toList();
      holders.add(
        Holder(
          id: holderId,
          representativePatient: _representative(holderId, rows),
          sourceIds: sourceIds,
          allPatientInstances: rows,
        ),
      );
    }

    return HolderDirectory(
      holders: holders,
      questions: [
        for (final question in questions)
          if (patients.where((p) => p.id == question.newHolderId).firstOrNull
              case final patient?)
            HolderAsk(question, patient),
      ],
    );
  }

  /// Places a newcomer: with [holderId] when the user picked someone, as a
  /// holder of their own when not.
  Future<void> answer(HolderQuestion question, {String? holderId}) =>
      _linking.answer(question, holderId: holderId);

  /// The holder's own wallet Patient row, else a row in one of their wallet
  /// sources, else their first row.
  Patient _representative(String holderId, List<Patient> rows) =>
      rows.where((p) => p.id == holderId).firstOrNull ??
      (rows
              .where((p) => p.sourceId.startsWith(HolderSource.walletPrefix))
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id)))
          .firstOrNull ??
      rows.first;

  /// The source where the app writes for [holderId]: the wallet source
  /// linked to them, made as `wallet-<holderId>` if they have none.
  Future<Source> walletSourceOf(
    String holderId, {
    required String patientName,
  }) async {
    final walletSources =
        (await _syncRepository.getSources())
            .where(
              (s) =>
                  s.holderId == holderId &&
                  s.platformType == 'wallet' &&
                  s.id.startsWith(HolderSource.walletPrefix),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final own = '${HolderSource.walletPrefix}$holderId';
    final existing =
        walletSources.where((s) => s.id == own).firstOrNull ??
        walletSources.firstOrNull;
    if (existing != null) return existing;

    final source = Source(
      id: own,
      platformName: 'wallet',
      labelSource: 'Wallet - $patientName',
      platformType: 'wallet',
      createdAt: DateTime.now(),
      holderId: holderId,
    );
    await _syncRepository.cacheSources([source]);
    return source;
  }

  /// The wallet source of the holder [patientId] (a Patient row id, FHIR id
  /// or holder id) belongs to; a patient not linked yet is a holder of
  /// their own.
  Future<Source> walletSourceForPatient(
    String patientId, {
    String? patientName,
  }) async {
    final holder = (await load()).ofPatientId(patientId);
    return walletSourceOf(
      holder?.id ?? patientId,
      patientName:
          patientName ??
          holder?.representativePatient.displayTitle ??
          SourceTypeService.unknownPatientName,
    );
  }

  /// The Patient row the app writes for the person [patientId] belongs to:
  /// their own row in their wallet source, made as a copy of the row shown
  /// for them when they have none. A provider's row is never written.
  /// [scanned] fills the fields that row leaves empty; a name still the
  /// default holder's counts as empty.
  Future<({Patient patient, String holderId})> walletPatientOf(
    String patientId, {
    MappingPatient? scanned,
  }) async {
    final holder = (await load()).ofPatientId(patientId);
    final holderId = holder?.id ?? patientId;
    final shown = holder?.representativePatient;
    final source = await walletSourceOf(
      holderId,
      patientName: shown?.displayTitle ?? SourceTypeService.unknownPatientName,
    );
    final own = holder?.allPatientInstances
        .where((p) => p.sourceId == source.id)
        .firstOrNull;

    final id = own?.id ?? const Uuid().v4();
    final raw = <String, dynamic>{
      ...?(own ?? shown)?.rawResource,
      'resourceType': 'Patient',
      'id': own?.resourceId ?? id,
    };
    final filled = scanned == null ? raw : _fillEmpty(id, raw, scanned);
    if (own != null && const DeepCollectionEquality().equals(filled, raw)) {
      return (patient: own, holderId: holderId);
    }

    final names = (filled['name'] as List?)?.whereType<Map>().toList();
    final patient = Patient(
      id: id,
      resourceId: own?.resourceId ?? id,
      sourceId: source.id,
      title: names == null || names.isEmpty
          ? (own ?? shown)?.title ?? ''
          : FhirFieldExtractor.extractHumanNameFamilyFirst(
                  fhir_r4.HumanName.fromJson(
                    Map<String, dynamic>.from(names.first),
                  ),
                ) ??
                '',
      date: DateTime.now(),
      rawResource: filled,
    );
    await _recordsRepository.updatePatient(patient);
    return (patient: patient, holderId: holderId);
  }

  Map<String, dynamic> _fillEmpty(
    String rowId,
    Map<String, dynamic> raw,
    MappingPatient scanned,
  ) {
    final read = scanned.toFhirResource().rawResource;
    final current = HolderPatient.fromRow(
      rowId: rowId,
      resourceId: '',
      sourceId: '',
      raw: raw,
    );
    final unnamed =
        current.isPlaceholder ||
        (current.family.isEmpty && current.given.isEmpty);
    final hasName =
        scanned.familyName.value.isNotEmpty ||
        scanned.givenName.value.isNotEmpty;
    final identifiers = [
      for (final id in (raw['identifier'] as List?) ?? const [])
        if (!(id is Map && id['value'] == HolderPatient.placeholderRowId)) id,
    ];
    return {
      ...raw,
      if (unnamed && hasName) 'name': read['name'],
      if (raw['birthDate'] == null && scanned.dateOfBirth.value.isNotEmpty)
        'birthDate': read['birthDate'],
      if ((raw['gender'] == null || raw['gender'] == 'unknown') &&
          scanned.gender.value.isNotEmpty)
        'gender': read['gender'],
      if (identifiers.isEmpty && read['identifier'] is List)
        if ((read['identifier'] as List).isNotEmpty)
          'identifier': read['identifier'],
    };
  }

  /// The holder a scanned patient is, if the scan says so; else the unnamed
  /// default holder when they are the only person, since a first scan is
  /// most often of the user.
  Holder? matchScanned(MappingPatient scanned, HolderDirectory directory) {
    final read = HolderPatient(
      rowId: '',
      resourceId: '',
      sourceId: '',
      identifiers: [
        if (scanned.patientIdentifier.value.isNotEmpty)
          HolderIdentifier(system: '', value: scanned.patientIdentifier.value),
      ],
      family: scanned.familyName.value,
      given: scanned.givenName.value,
      birthDate: scanned.dateOfBirth.value,
    );
    for (final holder in directory.holders) {
      for (final patient in holder.allPatientInstances) {
        if (_matcher.sameScannedPerson(read, _holderPatient(patient))) {
          return holder;
        }
      }
    }
    final people = directory.holders.where((h) => !h.isDemo).toList();
    if (people.length == 1 && isUnnamed(people.single)) {
      return people.single;
    }
    return null;
  }

  /// Whether [holder] is still the unnamed default holder.
  bool isUnnamed(Holder holder) =>
      _holderPatient(holder.representativePatient).isPlaceholder;

  HolderPatient _holderPatient(Patient patient) => HolderPatient.fromRow(
    rowId: patient.id,
    resourceId: patient.resourceId,
    sourceId: patient.sourceId,
    raw: patient.rawResource,
  );
}
