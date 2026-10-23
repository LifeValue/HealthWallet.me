import 'package:health_wallet/features/sync/data/dto/source_dto.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:injectable/injectable.dart';

abstract class SourceMapper {
  Source mapToEntity(SourceDto dto);
  List<Source> mapToEntities(List<SourceDto> dtos);
}

@Injectable(as: SourceMapper)
class SourceMapperImpl implements SourceMapper {
  @override
  Source mapToEntity(SourceDto dto) {
    final String platformName = _generatePlatformName(dto.platformType ?? 'fasten');
    final String labelSource = platformName;
    final String platformType = 'fasten';

    DateTime? createdAt;
    DateTime? updatedAt;

    if (dto.createdAt != null) {
      try {
        createdAt = DateTime.parse(dto.createdAt!);
      } catch (e) {}
    }

    if (dto.updatedAt != null) {
      try {
        updatedAt = DateTime.parse(dto.updatedAt!);
      } catch (e) {}
    }

    return Source(
      id: dto.id,
      platformName: platformName,
      logo: dto.logo,
      labelSource: labelSource,
      platformType: platformType,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Source> mapToEntities(List<SourceDto> dtos) {
    return dtos.map(mapToEntity).toList();
  }

  String _generatePlatformName(String platformType) {
    switch (platformType) {
      case 'manual':
        return 'Manual Entry';
      case 'fasten':
        return 'Fasten';
      case 'epic':
        return 'Epic';
      case 'cerner':
        return 'Cerner';
      case 'allscripts':
        return 'Allscripts';
      default:
        return 'Fasten';
    }
  }
}
