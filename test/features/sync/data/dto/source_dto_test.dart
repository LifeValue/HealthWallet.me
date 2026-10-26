import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/sync/data/dto/source_dto.dart';

void main() {
  group('SourceDto.fromJson', () {
    test('reads a Fasten source', () {
      final dto = SourceDto.fromJson({
        'id': 'src-1',
        'name': 'Clinic',
        'display': 'My Clinic',
        'logo': 'https://logo',
        'platform_type': 'epic',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-02-01T00:00:00Z',
      });
      expect(dto.id, 'src-1');
      expect(dto.platformName, 'Clinic');
      expect(dto.labelSource, 'My Clinic');
      expect(dto.display, 'My Clinic');
      expect(dto.logo, 'https://logo');
      expect(dto.platformType, 'epic');
      expect(dto.createdAt, '2024-01-01T00:00:00Z');
      expect(dto.updatedAt, '2024-02-01T00:00:00Z');
    });

    test('defaults id to "" and platformType to "fasten"', () {
      final dto = SourceDto.fromJson({});
      expect(dto.id, '');
      expect(dto.platformType, 'fasten');
      expect(dto.platformName, isNull);
      expect(dto.labelSource, isNull);
      expect(dto.display, isNull);
      expect(dto.logo, isNull);
      expect(dto.createdAt, isNull);
      expect(dto.updatedAt, isNull);
    });

    // platformName: name → display → platform_name
    final platformNames = <String, (Map<String, dynamic>, String?)>{
      'name first': ({'name': 'n', 'display': 'd', 'platform_name': 'p'}, 'n'),
      'then display': ({'display': 'd', 'platform_name': 'p'}, 'd'),
      'then platform_name': ({'platform_name': 'p'}, 'p'),
    };
    platformNames.forEach((name, testCase) {
      test('platformName: $name', () {
        expect(SourceDto.fromJson(testCase.$1).platformName, testCase.$2);
      });
    });

    // labelSource: display → name → labelSource → label
    final labels = <String, (Map<String, dynamic>, String?)>{
      'display first': (
        {'display': 'd', 'name': 'n', 'labelSource': 'ls', 'label': 'l'},
        'd',
      ),
      'then name': ({'name': 'n', 'labelSource': 'ls', 'label': 'l'}, 'n'),
      'then labelSource': ({'labelSource': 'ls', 'label': 'l'}, 'ls'),
      'then label': ({'label': 'l'}, 'l'),
    };
    labels.forEach((name, testCase) {
      test('labelSource: $name', () {
        expect(SourceDto.fromJson(testCase.$1).labelSource, testCase.$2);
      });
    });

    test('display falls back to name', () {
      expect(SourceDto.fromJson({'name': 'n'}).display, 'n');
    });
  });

  group('SourceDto.toJson', () {
    test('writes every field under its storage key', () {
      const dto = SourceDto(
        id: 'src-1',
        platformName: 'Clinic',
        logo: 'logo',
        labelSource: 'Label',
        platformType: 'fasten',
        createdAt: 'c',
        updatedAt: 'u',
        display: 'Display',
      );
      expect(dto.toJson(), {
        'id': 'src-1',
        'platform_name': 'Clinic',
        'logo': 'logo',
        'labelSource': 'Label',
        'platform_type': 'fasten',
        'created_at': 'c',
        'updated_at': 'u',
        'display': 'Display',
      });
    });

    test('fromJson(toJson) keeps fields when display is not set', () {
      const dto = SourceDto(
        id: 'src-1',
        platformName: 'Clinic',
        labelSource: 'Label',
        platformType: 'manual',
      );
      final copy = SourceDto.fromJson(dto.toJson());
      expect(copy.platformName, 'Clinic');
      expect(copy.labelSource, 'Label');
      expect(copy.platformType, 'manual');
    });
  });
}
