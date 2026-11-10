import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

abstract class AttachmentBrowseService {
  /// The records of the scope, newest first, with the same filters as the
  /// Records list: [resourceTypes], [dateFilter] and [specialty].
  Future<List<AttachmentBrowseEntry>> loadEntries({
    String? sourceId,
    List<String>? sourceIds,
    List<FhirType> resourceTypes,
    DateFilter? dateFilter,
    MedicalSpecialty? specialty,
  });

  Future<AttachmentBrowseDetail> loadDetail(
    IFhirResource record, {
    String? sourceId,
  });
}
