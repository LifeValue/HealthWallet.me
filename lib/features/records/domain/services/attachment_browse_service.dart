import 'package:health_wallet/features/records/domain/entity/entity.dart';

abstract class AttachmentBrowseService {
  Future<List<AttachmentBrowseEntry>> loadEntries({
    String? sourceId,
    List<String>? sourceIds,
    List<FhirType> resourceTypes,
  });

  Future<AttachmentBrowseDetail> loadDetail(
    IFhirResource record, {
    String? sourceId,
  });
}
