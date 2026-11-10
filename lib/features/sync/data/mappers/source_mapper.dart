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
    final String platformName = _generatePlatformName(
      dto.platformType ?? 'fasten',
    );
    // The provider's name for the source (its hospital or portal), else
    // the platform's.
    final String labelSource = (dto.labelSource?.isNotEmpty ?? false)
        ? dto.labelSource!
        : platformName;
    // The integration the source came through. The app only asks whether a
    // source is the wallet (writable) or a provider's (read-only).
    const String platformType = 'fasten';

    DateTime? createdAt;
    DateTime? updatedAt;

    if (dto.createdAt != null) {
      createdAt = DateTime.tryParse(dto.createdAt!);
    }

    if (dto.updatedAt != null) {
      updatedAt = DateTime.tryParse(dto.updatedAt!);
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
