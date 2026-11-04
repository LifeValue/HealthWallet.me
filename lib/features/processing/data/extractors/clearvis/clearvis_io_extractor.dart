import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_text.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_identifier.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_practitioner.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/records/domain/entity/vision_prescription/vision_prescription.dart';
import 'package:uuid/uuid.dart';

/// Eye-care documents printed by the clearvis.io platform (Optione is one
/// tenant): a PDF of glasses prescriptions, one per lens type, each with its
/// `PR-` serial, and the exam result (`EE-` serial), which lists the same
/// prescriptions without their serials. Labels are bilingual (Romanian /
/// English); values use decimal points or commas.
class ClearvisIoExtractor implements LayoutExtractor {
  const ClearvisIoExtractor();

  @override
  String get id => 'clearvis.io';

  @override
  int get version => 1;

  static final _prSerial = RegExp(
    r'\bPR[-:.]\s?(\d{6,})',
    caseSensitive: false,
  );
  static final _eeSerial = RegExp(
    r'\bEE[-:.]\s?(\d{6,})',
    caseSensitive: false,
  );

  static final _formLabels = [
    'magazin / store',
    'pacient / patient',
    'identificator pacient',
    'correction parameters',
    'valoarea corectiei',
    'rezultat examinare oftalmologic',
    'locul examinarii',
    'examination recorded by',
    'data control recomandat',
  ];

  @override
  double score(String ocrText) {
    final folded = ClearvisText.fold(ocrText);
    var score = 0.0;
    if (folded.contains('clearvis.io')) score += 0.5;
    if (_prSerial.hasMatch(ocrText) || _eeSerial.hasMatch(ocrText)) {
      score += 0.2;
    }
    final labels = _formLabels.where(folded.contains).length;
    score += (labels > 3 ? 3 : labels) * 0.1;
    return score > 1 ? 1 : score;
  }

  @override
  LayoutExtraction? extract(String ocrText) {
    final text = ClearvisText(ocrText);
    final blocks = _prescriptionBlocks(text);
    if (blocks.isNotEmpty) return _prescriptions(text, blocks);
    if (text.folded.any((l) => l.contains('rezultat examinare')) ||
        _eeSerial.hasMatch(ocrText)) {
      return _exam(text);
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Prescriptions: one block per heading "Rețetă Ochelari …".

  static final _heading = RegExp(r'^reteta (de )?ochelari');

  /// The line ranges of each prescription, from its heading to the next.
  List<(int, int)> _prescriptionBlocks(ClearvisText text) {
    final starts = [
      for (var i = 0; i < text.lines.length; i++)
        if (_heading.hasMatch(text.folded[i]) &&
            _isPrescriptionHeading(text, i))
          i,
    ];
    return [
      for (var k = 0; k < starts.length; k++)
        (starts[k], k + 1 < starts.length ? starts[k + 1] : text.lines.length),
    ];
  }

  /// A prescription form's heading, not a heading in the exam's list: the
  /// form names its English title or its store within a few lines.
  bool _isPrescriptionHeading(ClearvisText text, int at) {
    for (var i = at; i < at + 4 && i < text.lines.length; i++) {
      final line = text.folded[i];
      if (line.contains('glasses prescription') ||
          ClearvisText.store.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  LayoutExtraction? _prescriptions(ClearvisText text, List<(int, int)> blocks) {
    final (first, firstEnd) = blocks.first;
    String? value(RegExp label, {bool Function(String)? accept}) =>
        text.valueAfter(label, from: first, to: firstEnd, accept: accept);

    final name = value(ClearvisText.patient, accept: ClearvisText.isName);
    final date = ClearvisText.isoDate(
      value(ClearvisText.date, accept: ClearvisText.hasDate),
    );
    if (name == null || date == null) return null;

    final store = value(ClearvisText.store) ?? '';
    final patientNumber = value(ClearvisText.patientId) ?? '';
    // The store and the patient number key the visit and the clinic.
    if (LayoutKeys.slug(store).isEmpty || patientNumber.isEmpty) return null;
    final storeAt = text.indexOf(ClearvisText.store, from: first, to: firstEnd);
    final patientAt = text.indexOf(
      ClearvisText.patient,
      from: first,
      to: firstEnd,
    );
    final clinic = _Clinic(
      name: store,
      address:
          text.valueAfter(
            ClearvisText.address,
            from: storeAt < 0 ? first : storeAt,
            to: patientAt < 0 ? firstEnd : patientAt,
          ) ??
          '',
      phone: value(ClearvisText.phone) ?? '',
    );
    final examiner = value(
      ClearvisText.examiner,
      accept: ClearvisText.isName,
    );

    final context = _Context(
      extractor: this,
      clinic: clinic,
      patientNumber: patientNumber,
      visitDate: date,
    );
    final practitioner = examiner == null
        ? null
        : MappingPractitioner(
            id: context.stableId([
              'practitioner',
              ClearvisText.fold(examiner),
            ]),
            practitionerName: _read(examiner),
            provenance: context.provenance,
          );

    final prescriptions = <MappingVisionPrescription>[];
    for (final (start, end) in blocks) {
      final eyes = _formEyes(text, start, end);
      if (eyes == null) return null;
      final serial = _prSerial.firstMatch(
        text.lines.sublist(start, end).join('\n'),
      );
      prescriptions.add(
        context.prescription(
          title: _formHeading(text, start, end),
          lensType: _lensType(text, start, end),
          eyes: eyes,
          serial: serial == null ? '' : 'PR-${serial.group(1)}',
          dateWritten:
              ClearvisText.isoDate(
                text.valueAfter(
                  ClearvisText.date,
                  from: start,
                  to: end,
                  accept: ClearvisText.hasDate,
                ),
              ) ??
              date,
          followUp: ClearvisText.isoDate(
            text.valueAfter(
              ClearvisText.followUp,
              from: start,
              to: end,
              accept: ClearvisText.hasDate,
            ),
          ),
          practitioner: practitioner,
        ),
      );
    }

    return context.extraction(
      encounterType: prescriptions.first.title,
      patient: _patient(
        name,
        ClearvisText.isoDate(
          value(ClearvisText.birthDate, accept: ClearvisText.hasDate),
        ),
        context,
      ),
      practitioner: practitioner,
      prescriptions: prescriptions,
    );
  }

  /// A sphere, add or cylinder value with its dioptre sign: "+0.75 D",
  /// "1,75D". Not one followed by a slash (that is a cylinder).
  static final _formValue = RegExp(
    r'(?<![\w.,:+\-])([+\-]?\d{1,2}[.,]\d{2})[ \t]?D(?![A-Za-z])(?![ \t]*/)',
  );

  /// The "Cyl / Axis" cell: "+0.25 D / 160", or "D /" when empty.
  static final _formCylinder = RegExp(
    r'(?:(?<![\w.,])([+\-]?\d{1,2}[.,]\d{2})[ \t]?)?(?<![A-Za-z])D[ \t]*/[ \t]*(?:(\d{1,3})(?![.,]\d))?',
  );

  /// The per-eye values of one form. OCR reads the table by column, then by
  /// row, in varying order, but each column keeps the right eye above the
  /// left: signed values are spheres, unsigned ones adds (only multifocal
  /// forms print an Add column), and every eye has a cylinder cell. Null
  /// when the counts don't make two eyes.
  _Eyes? _formEyes(ClearvisText text, int start, int end) {
    final body = text.lines.sublist(start, end).join('\n');
    final hasAdd = text.folded
        .sublist(start, end)
        .any((l) => l == 'add' || l.contains(' add ') || l.endsWith(' add'));
    final spheres = <String>[];
    final adds = <String>[];
    for (final m in _formValue.allMatches(body)) {
      final printed = m.group(1)!;
      final signed = printed.startsWith('+') || printed.startsWith('-');
      if (hasAdd && !signed) {
        adds.add(ClearvisText.decimal(printed, signed: false));
      } else {
        spheres.add(ClearvisText.decimal(printed));
      }
    }
    final cylinders = [
      for (final m in _formCylinder.allMatches(body))
        (
          cylinder: m.group(1) == null ? '' : ClearvisText.decimal(m.group(1)!),
          axis: m.group(2) ?? '',
        ),
    ];
    if (spheres.length != 2 ||
        (cylinders.isNotEmpty && cylinders.length != 2) ||
        (adds.isNotEmpty && adds.length != 2)) {
      return null;
    }
    _Eye eye(int i) => (
      sphere: spheres[i],
      cylinder: cylinders.isEmpty ? '' : cylinders[i].cylinder,
      axis: cylinders.isEmpty ? '' : cylinders[i].axis,
      add: adds.isEmpty ? '' : adds[i],
    );
    return (right: eye(0), left: eye(1));
  }

  /// The form's title as printed: the Romanian lines before its English
  /// title.
  String _formHeading(ClearvisText text, int start, int end) {
    final lines = <String>[];
    for (var i = start; i < end && i < start + 3; i++) {
      final line = text.folded[i];
      if (line.contains('glasses prescription') || ClearvisText.isLabel(line)) {
        break;
      }
      lines.add(text.lines[i].split(RegExp(r'\s{3,}')).first.trim());
    }
    return lines.join(' ');
  }

  VisionLensType _lensType(ClearvisText text, int start, int end) {
    final heading = text.folded
        .sublist(start, end < start + 3 ? end : start + 3)
        .join(' ');
    if (heading.contains('multifocal')) return VisionLensType.multifocal;
    if (heading.contains('distan')) return VisionLensType.distance;
    if (heading.contains('citit') || heading.contains('reading')) {
      return VisionLensType.reading;
    }
    return VisionLensType.other;
  }

  // ---------------------------------------------------------------------
  // Exam result: patient block, place of examination, "Rețete" list.

  static final _examStop = RegExp(
    r'^(locul examinarii|identificator pacient|data examinarii|dat[ae] nastere|semnatura|l\.s\.|pagina|rezultate masuratori|nume pacient)',
  );

  LayoutExtraction? _exam(ClearvisText text) {
    final name = text.valueAfter(
      ClearvisText.examPatient,
      accept: ClearvisText.isName,
    );
    final date = ClearvisText.isoDate(
      text.valueAfter(ClearvisText.examDate, accept: ClearvisText.hasDate),
    );
    if (name == null || date == null) return null;

    final placeAt = text.indexOf(ClearvisText.examPlace);
    final place = <String>[];
    for (var i = placeAt + 1; placeAt >= 0 && i < placeAt + 6; i++) {
      if (i >= text.lines.length || ClearvisText.isLabel(text.folded[i])) {
        break;
      }
      place.add(text.lines[i]);
    }
    // The footer names the store too, so a store line OCR missed is not
    // taken from the address under it.
    final footerStore = _storeFromFooter(text);
    final storeLine =
        place.isNotEmpty &&
        (footerStore.isEmpty ||
            ClearvisText.fold(_clean(place.first)) ==
                ClearvisText.fold(footerStore));
    if (!storeLine) place.insert(0, footerStore);
    final store = _clean(place.first);
    final patientNumber = text.valueAfter(ClearvisText.patientId) ?? '';
    if (LayoutKeys.slug(store).isEmpty || patientNumber.isEmpty) return null;
    final clinic = _Clinic(
      name: store,
      address: place.length > 1 ? _clean(place[1]) : '',
      phone: place.map(_phone).whereType<String>().firstOrNull ?? '',
    );
    final context = _Context(
      extractor: this,
      clinic: clinic,
      patientNumber: patientNumber,
      visitDate: date,
    );

    final prescriptions = <MappingVisionPrescription>[];
    for (var i = 0; i < text.lines.length; i++) {
      if (!_heading.hasMatch(text.folded[i])) continue;
      var end = i + 1;
      while (end < text.lines.length &&
          !_heading.hasMatch(text.folded[end]) &&
          !_examStop.hasMatch(text.folded[end])) {
        end++;
      }
      final eyes = _listEyes(text.lines.sublist(i + 1, end).join('\n'));
      if (eyes == null) return null;
      prescriptions.add(
        context.prescription(
          title: text.lines[i],
          lensType: _lensType(text, i, i + 1),
          eyes: eyes,
          dateWritten: date,
        ),
      );
    }

    final serial = _eeSerial.firstMatch(text.lines.join('\n'));
    final titleAt = text.folded.indexWhere(
      (l) => l.contains('rezultat examinare'),
    );
    return context.extraction(
      encounterType: titleAt < 0 ? '' : text.lines[titleAt],
      patient: _patient(
        name,
        ClearvisText.isoDate(
          text.valueAfter(ClearvisText.birthDate, accept: ClearvisText.hasDate),
        ),
        context,
      ),
      examSerial: serial == null ? null : 'EE-${serial.group(1)}',
      prescriptions: prescriptions,
    );
  }

  static final _listToken = RegExp(
    r'cyl:[ \t]*([+\-]?\d{1,2}[.,]\d{2})[ \t]?D[ \t]*/[ \t]*(\d{1,3})'
    r'|add:[ \t]*([+\-]?\d{1,2}[.,]\d{2})'
    r'|(?<![\w.,:+\-])([+\-]?\d{1,2}[.,]\d{2})[ \t]?D(?![A-Za-z])',
    caseSensitive: false,
  );

  /// The exam lists each eye as "+0.75D cyl:+0.25D/160° add:1.75D", the
  /// right eye first; OCR may break a row, so a cylinder or add belongs to
  /// the sphere before it. Null unless there are exactly two spheres.
  _Eyes? _listEyes(String section) {
    final eyes = <_Eye>[];
    for (final m in _listToken.allMatches(section)) {
      if (m.group(4) != null) {
        eyes.add((
          sphere: ClearvisText.decimal(m.group(4)!),
          cylinder: '',
          axis: '',
          add: '',
        ));
        continue;
      }
      if (eyes.isEmpty) return null;
      final last = eyes.removeLast();
      eyes.add(
        m.group(1) != null
            ? (
                sphere: last.sphere,
                cylinder: ClearvisText.decimal(m.group(1)!),
                axis: m.group(2)!,
                add: last.add,
              )
            : (
                sphere: last.sphere,
                cylinder: last.cylinder,
                axis: last.axis,
                add: ClearvisText.decimal(m.group(3)!, signed: false),
              ),
      );
    }
    return eyes.length == 2 ? (right: eyes[0], left: eyes[1]) : null;
  }

  // ---------------------------------------------------------------------
  // Shared.

  /// The store named in the exam's footer ("efectuat în magazinul de
  /// specialitate Optione 1 cu programul …"), when OCR missed the header.
  static String _storeFromFooter(ClearvisText text) {
    final footer = RegExp(
      r'specialitate\s+(.+?)\s+cu programul',
      caseSensitive: false,
    );
    for (final line in text.lines) {
      final m = footer.firstMatch(line);
      if (m != null) return m.group(1)!.trim();
    }
    return '';
  }

  /// A line without the icons OCR reads before it ("• ", "6 ", "=").
  static String _clean(String line) =>
      line.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '').trim();

  static final _phoneNumber = RegExp(r'(?<!\d)(?:\+40|0)\d{9}(?!\d)');

  /// A phone number on [line], as printed or with its groups spaced.
  static String? _phone(String line) =>
      _phoneNumber.firstMatch(line)?.group(0) ??
      _phoneNumber.firstMatch(_clean(line).replaceAll(' ', ''))?.group(0);

  /// The patient as printed, "Given Names Family".
  MappingPatient _patient(String name, String? birthDate, _Context context) {
    final words = name.split(RegExp(r'\s+'));
    return MappingPatient(
      id: const Uuid().v4(),
      givenName: _read(words.sublist(0, words.length - 1).join(' ')),
      familyName: _read(words.last),
      dateOfBirth: _read(birthDate ?? ''),
      patientIdentifier: _read(context.patientNumber),
      identifierLabel: MappingPatient.genericIdentifierLabel,
      identifierSystem: context.patientNumber.isEmpty
          ? ''
          : LayoutKeys.clinicPatientSystem(context.clinicKey),
      provenance: context.provenance,
    );
  }

  static MappedProperty _read(String value) =>
      MappedProperty(value: value).withFullConfidence();
}

typedef _Eye = ({String sphere, String cylinder, String axis, String add});
typedef _Eyes = ({_Eye right, _Eye left});

class _Clinic {
  const _Clinic({
    required this.name,
    required this.address,
    required this.phone,
  });

  final String name;
  final String address;
  final String phone;
}

/// What every record of one document shares: the clinic, the patient
/// number and the visit.
class _Context {
  _Context({
    required this.extractor,
    required this.clinic,
    required this.patientNumber,
    required this.visitDate,
  });

  final ClearvisIoExtractor extractor;
  final _Clinic clinic;
  final String patientNumber;
  final String visitDate;

  /// The store's name, printed on both documents of a visit. The clinic's
  /// website is printed only on the exam, so it can't key the visit: the
  /// prescriptions would key it differently.
  String get clinicKey => LayoutKeys.slug(clinic.name);

  String get provenance => '${extractor.id}@${extractor.version}';

  String get _documentSystem => LayoutKeys.clinicDocumentSystem(clinicKey);

  /// The same for the clinic (and its examiner) whoever the patient is, so
  /// a family's records share them.
  String stableId(List<String> parts) =>
      LayoutKeys.stableId(extractor.id, [clinicKey, ...parts]);

  MappingVisionPrescription prescription({
    required String title,
    required VisionLensType lensType,
    required _Eyes eyes,
    required String dateWritten,
    String serial = '',
    String? followUp,
    MappingPractitioner? practitioner,
  }) => MappingVisionPrescription(
    id: const Uuid().v4(),
    title: title,
    lensType: lensType,
    serial: ClearvisIoExtractor._read(serial),
    serialSystem: serial.isEmpty ? '' : _documentSystem,
    dateWritten: ClearvisIoExtractor._read(dateWritten),
    followUpDate: ClearvisIoExtractor._read(followUp ?? ''),
    prescriberRef: practitioner == null
        ? ''
        : 'Practitioner/${practitioner.id}',
    prescriberName: practitioner?.practitionerName ?? const MappedProperty(),
    clinicName: clinic.name,
    rightSphere: ClearvisIoExtractor._read(eyes.right.sphere),
    rightCylinder: ClearvisIoExtractor._read(eyes.right.cylinder),
    rightAxis: ClearvisIoExtractor._read(eyes.right.axis),
    rightAdd: ClearvisIoExtractor._read(eyes.right.add),
    leftSphere: ClearvisIoExtractor._read(eyes.left.sphere),
    leftCylinder: ClearvisIoExtractor._read(eyes.left.cylinder),
    leftAxis: ClearvisIoExtractor._read(eyes.left.axis),
    leftAdd: ClearvisIoExtractor._read(eyes.left.add),
    provenance: provenance,
  );

  LayoutExtraction extraction({
    required String encounterType,
    required MappingPatient patient,
    required List<MappingVisionPrescription> prescriptions,
    MappingPractitioner? practitioner,
    String? examSerial,
  }) => LayoutExtraction(
    extractorId: extractor.id,
    version: extractor.version,
    clinicKey: clinicKey,
    patient: patient,
    organization: MappingOrganization(
      id: _organizationId,
      organizationName: ClearvisIoExtractor._read(clinic.name),
      address: ClearvisIoExtractor._read(clinic.address),
      phone: ClearvisIoExtractor._read(clinic.phone),
      provenance: provenance,
    ),
    practitioner: practitioner,
    encounter: MappingEncounter(
      id: const Uuid().v4(),
      encounterType: ClearvisIoExtractor._read(encounterType),
      periodStart: ClearvisIoExtractor._read(visitDate),
      specialty: ClearvisIoExtractor._read(
        MedicalSpecialty.ophthalmology.displayName,
      ),
      identifiers: [
        LayoutKeys.visitKey(
          extractorId: extractor.id,
          clinicKey: clinicKey,
          patientNumber: patientNumber,
          date: visitDate,
        ),
        if (examSerial != null)
          MappingIdentifier(system: _documentSystem, value: examSerial),
      ],
      serviceProviderRef: 'Organization/$_organizationId',
      provenance: provenance,
    ),
    resources: prescriptions,
  );

  String get _organizationId => stableId(['organization']);
}
