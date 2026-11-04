import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/repository/holder_repository.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';
import 'package:injectable/injectable.dart';

/// Links every source that has no holder yet (see [HolderLinker]): at
/// start-up, which also links the sources of an install from before holders
/// were stored, and whenever the holders are read, so records that arrived
/// from a provider, a scan or the desktop are placed.
@injectable
class HolderLinkingService {
  HolderLinkingService(this._repository);

  final HolderRepository _repository;

  /// Links what can be linked and returns who the user has to place.
  Future<List<HolderQuestion>> linkUnassigned() async {
    try {
      if (!await _repository.hasUnassigned()) return const [];
      final snapshot = await _repository.snapshot();
      final result = const HolderLinker().link(snapshot);
      final links = result.links;
      if (links.isNotEmpty) await _repository.assignHolders(links);

      final asked = {for (final q in result.questions) ...q.sourceIds};
      final left = snapshot.sources
          .where((s) => s.holderId == null)
          .map((s) => s.id)
          .where((id) => !links.containsKey(id) && !asked.contains(id));
      if (links.isNotEmpty) {
        logger.i(
          'Linked ${links.length} sources to ${links.values.toSet().length} '
          'holders',
        );
      }
      if (left.isNotEmpty) {
        logger.w('Sources left without a holder: ${left.join(', ')}');
      }
      return result.questions;
    } catch (e, s) {
      // Records stay where they are; the next read tries again.
      logger.e('Linking sources to holders failed', e, s);
      return const [];
    }
  }

  /// Joins holders that turn out to be one person (see
  /// [HolderLinker.merges]); whether any were.
  Future<bool> mergeSamePeople({
    required List<HolderPatient> patients,
    required Map<String, String> holderBySource,
  }) async {
    final into = const HolderLinker().merges(
      patients: patients,
      holderBySource: holderBySource,
    );
    if (into.isEmpty) return false;
    await _repository.mergeHolders(into);
    logger.i('Merged holders that are one person: $into');
    return true;
  }

  /// The user's answer: [holderId] is the person they picked, or null for
  /// someone else, who becomes a holder of their own.
  Future<void> answer(HolderQuestion question, {String? holderId}) =>
      _repository.assignHolders({
        for (final sourceId in question.sourceIds)
          sourceId: holderId ?? question.newHolderId,
      });
}
