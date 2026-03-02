import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

part 'share_selection.freezed.dart';

@freezed
class ShareSelection with _$ShareSelection {
  const ShareSelection._();

  const factory ShareSelection({
    @Default({}) Map<String, IFhirResource> selectedRecords,
    @Default({}) Set<FhirType> selectedTypes,
  }) = _ShareSelection;

  int get totalCount => selectedRecords.length;

  bool get isEmpty => selectedRecords.isEmpty;

  bool get isNotEmpty => selectedRecords.isNotEmpty;

  List<IFhirResource> get resources => selectedRecords.values.toList();

  bool isSelected(String resourceId) => selectedRecords.containsKey(resourceId);

  Map<FhirType, int> get countByType => selectedRecords.values.toList().countByType();

  ShareSelection _withUpdatedRecords(Map<String, IFhirResource> newRecords) {
    final newTypes = newRecords.values.map((r) => r.fhirType).toSet();
    return copyWith(selectedRecords: newRecords, selectedTypes: newTypes);
  }

  ShareSelection toggle(IFhirResource resource) {
    final newRecords = Map<String, IFhirResource>.from(selectedRecords);
    if (newRecords.containsKey(resource.id)) {
      newRecords.remove(resource.id);
    } else {
      newRecords[resource.id] = resource;
    }
    return _withUpdatedRecords(newRecords);
  }

  ShareSelection addAll(List<IFhirResource> resources) {
    final newRecords = Map<String, IFhirResource>.from(selectedRecords);
    for (final resource in resources) {
      newRecords[resource.id] = resource;
    }
    return _withUpdatedRecords(newRecords);
  }

  ShareSelection remove(IFhirResource resource) {
    final newRecords = Map<String, IFhirResource>.from(selectedRecords);
    newRecords.remove(resource.id);
    return _withUpdatedRecords(newRecords);
  }
}
