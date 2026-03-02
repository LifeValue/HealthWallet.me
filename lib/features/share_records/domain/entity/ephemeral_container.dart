import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';

part 'ephemeral_container.freezed.dart';

@freezed
class EphemeralRecordsContainer with _$EphemeralRecordsContainer {
  const EphemeralRecordsContainer._();

  const factory EphemeralRecordsContainer({
    required String sessionId,
    required String senderDeviceName,
    required DateTime receivedAt,
    required Duration viewDuration,
    required List<IFhirResource> records,
    @Default(false) bool isExpired,
    @Default({}) Map<String, List<RecordNote>> notes,
    @Default([]) List<String> tempAttachmentPaths,
    @Default([]) List<String> activeFilters,
  }) = _EphemeralRecordsContainer;

  Duration get timeRemaining {
    final elapsed = DateTime.now().difference(receivedAt);
    final remaining = viewDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasExpired => isExpired || timeRemaining == Duration.zero;

  int get recordCount => records.length;

  Map<FhirType, int> get countByType => records.countByType();

  static EphemeralRecordsContainer empty() => EphemeralRecordsContainer(
        sessionId: '',
        senderDeviceName: '',
        receivedAt: DateTime.now(),
        viewDuration: Duration.zero,
        records: const [],
        isExpired: true,
        notes: const {},
        tempAttachmentPaths: const [],
      );
}
