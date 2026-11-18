import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/gen/assets.gen.dart';

typedef _LineFactory = RecordInfoLine? Function(
  String? value, {
  String? prefix,
});

void main() {
  final factories = <String, (_LineFactory, SvgGenImage)>{
    'status': (
      ResourceFieldMapper.createStatusLine,
      ResourceFieldMapper.statusIcon,
    ),
    'date': (ResourceFieldMapper.createDateLine, ResourceFieldMapper.dateIcon),
    'time': (ResourceFieldMapper.createTimeLine, ResourceFieldMapper.timeIcon),
    'user': (ResourceFieldMapper.createUserLine, ResourceFieldMapper.userIcon),
    'organization': (
      ResourceFieldMapper.createOrganizationLine,
      ResourceFieldMapper.organizationIcon,
    ),
    'location': (
      ResourceFieldMapper.createLocationLine,
      ResourceFieldMapper.locationIcon,
    ),
    'medication': (
      ResourceFieldMapper.createMedicationLine,
      ResourceFieldMapper.medicationIcon,
    ),
    'notes': (
      ResourceFieldMapper.createNotesLine,
      ResourceFieldMapper.notesIcon,
    ),
    'procedure': (
      ResourceFieldMapper.createProcedureLine,
      ResourceFieldMapper.procedureIcon,
    ),
    'lab': (ResourceFieldMapper.createLabLine, ResourceFieldMapper.labIcon),
    'value': (
      ResourceFieldMapper.createValueLine,
      ResourceFieldMapper.valueIcon,
    ),
    'category': (
      ResourceFieldMapper.createCategoryLine,
      ResourceFieldMapper.categoryIcon,
    ),
    'warning': (
      ResourceFieldMapper.createWarningLine,
      ResourceFieldMapper.warningIcon,
    ),
    'bodySite': (
      ResourceFieldMapper.createBodySiteLine,
      ResourceFieldMapper.bodySiteIcon,
    ),
    'team': (ResourceFieldMapper.createTeamLine, ResourceFieldMapper.teamIcon),
    'immunization': (
      ResourceFieldMapper.createImmunizationLine,
      ResourceFieldMapper.immunizationIcon,
    ),
    'document': (
      ResourceFieldMapper.createDocumentLine,
      ResourceFieldMapper.documentIcon,
    ),
    'identification': (
      ResourceFieldMapper.createIdentificationLine,
      ResourceFieldMapper.identificationIcon,
    ),
    'timeline': (
      ResourceFieldMapper.createTimelineLine,
      ResourceFieldMapper.timelineIcon,
    ),
    'activity': (
      ResourceFieldMapper.createActivityLine,
      ResourceFieldMapper.activityIcon,
    ),
    'image': (
      ResourceFieldMapper.createImageLine,
      ResourceFieldMapper.imageIcon,
    ),
    'attachment': (
      ResourceFieldMapper.createAttachmentLine,
      ResourceFieldMapper.attachmentIcon,
    ),
    'custom': (
      (value, {prefix}) => ResourceFieldMapper.createCustomLine(
        ResourceFieldMapper.shieldIcon,
        value,
        prefix: prefix,
      ),
      ResourceFieldMapper.shieldIcon,
    ),
  };

  for (final MapEntry(key: name, value: (create, icon)) in factories.entries) {
    group('$name line', () {
      test('is null for null or empty values', () {
        expect(create(null), isNull);
        expect(create(''), isNull);
        expect(create('', prefix: 'Label'), isNull);
      });

      test('uses the value as info with the $name icon', () {
        final line = create('final')!;
        expect(line.info, 'final');
        expect(line.icon.path, icon.path);
        expect(line.isSection, isFalse);
      });

      test('prepends the prefix', () {
        expect(create('final', prefix: 'Status')!.info, 'Status: final');
      });
    });
  }

  test('icons point at the expected assets', () {
    expect(ResourceFieldMapper.statusIcon.path, Assets.icons.information.path);
    expect(
      ResourceFieldMapper.locationIcon.path,
      ResourceFieldMapper.organizationIcon.path,
    );
    expect(
      ResourceFieldMapper.immunizationIcon.path,
      Assets.icons.faceMask.path,
    );
  });

  test('addIfNotNull only adds non-null lines', () {
    final lines = <RecordInfoLine>[];
    ResourceFieldMapper.addIfNotNull(lines, null);
    ResourceFieldMapper.addIfNotNull(
      lines,
      ResourceFieldMapper.createDateLine('2024-01-01'),
    );
    expect(lines.map((l) => l.info), ['2024-01-01']);
  });

  test('createSectionHeader marks the line as a section', () {
    final header = ResourceFieldMapper.createSectionHeader('Results');
    expect(header.info, 'Results');
    expect(header.isSection, isTrue);
    expect(header.icon.path, Assets.icons.timeline.path);
  });
}
