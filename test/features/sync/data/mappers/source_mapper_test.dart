import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/sync/data/dto/source_dto.dart';
import 'package:health_wallet/features/sync/data/mappers/source_mapper.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';

void main() {
  final mapper = SourceMapperImpl();

  group('SourceMapperImpl.mapToEntity', () {
    test("maps a full DTO, keeping the provider's name for the source", () {
      const dto = SourceDto(
        id: 'src-1',
        platformName: 'Ignored',
        logo: 'https://logo',
        labelSource: 'City Hospital',
        platformType: 'epic',
        createdAt: '2024-01-02T03:04:05Z',
        updatedAt: '2024-02-03T04:05:06Z',
      );
      expect(
        mapper.mapToEntity(dto),
        Source(
          id: 'src-1',
          platformName: 'Epic',
          logo: 'https://logo',
          labelSource: 'City Hospital',
          platformType: 'fasten',
          createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
          updatedAt: DateTime.utc(2024, 2, 3, 4, 5, 6),
        ),
      );
    });

    final names = <String?, String>{
      'manual': 'Manual Entry',
      'fasten': 'Fasten',
      'epic': 'Epic',
      'cerner': 'Cerner',
      'allscripts': 'Allscripts',
      'athena': 'Fasten',
      '': 'Fasten',
      null: 'Fasten',
    };
    names.forEach((platformType, expected) {
      test('platformType $platformType → platformName/label "$expected"', () {
        final source = mapper.mapToEntity(
          SourceDto(id: 'x', platformType: platformType),
        );
        expect(source.platformName, expected);
        expect(source.labelSource, expected);
        expect(source.platformType, 'fasten');
      });
    });

    final dates = <String?, DateTime?>{
      '2024-01-02': DateTime(2024, 1, 2),
      '2024-01-02T03:04:05.123Z': DateTime.utc(2024, 1, 2, 3, 4, 5, 123),
      'not a date': null,
      '': null,
      null: null,
    };
    dates.forEach((raw, expected) {
      test('parses created_at/updated_at "$raw"', () {
        final source = mapper.mapToEntity(
          SourceDto(id: 'x', createdAt: raw, updatedAt: raw),
        );
        expect(source.createdAt, expected);
        expect(source.updatedAt, expected);
      });
    });
  });

  group('SourceMapperImpl.mapToEntities', () {
    test('maps each DTO in order', () {
      final sources = mapper.mapToEntities(const [
        SourceDto(id: 'a', platformType: 'cerner'),
        SourceDto(id: 'b', platformType: 'manual'),
      ]);
      expect(sources.map((s) => s.id), ['a', 'b']);
      expect(sources.map((s) => s.platformName), ['Cerner', 'Manual Entry']);
    });

    test('maps an empty list to an empty list', () {
      expect(mapper.mapToEntities(const []), isEmpty);
    });
  });
}
