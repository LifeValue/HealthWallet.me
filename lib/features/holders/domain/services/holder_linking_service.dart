import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/repository/holder_repository.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';
import 'package:injectable/injectable.dart';

/// Links every source that has no holder yet (see [HolderLinker]): at
/// start-up, which also links the sources of an install from before holders
/// were stored.
@injectable
class HolderLinkingService {
  HolderLinkingService(this._repository);

  final HolderRepository _repository;

  Future<void> linkUnassigned() async {
    try {
      if (!await _repository.hasUnassigned()) return;
      final snapshot = await _repository.snapshot();
      final unassigned = snapshot.sources.where((s) => s.holderId == null);
      if (unassigned.isEmpty) return;

      final links = const HolderLinker().link(snapshot);
      if (links.isNotEmpty) await _repository.assignHolders(links);

      final left = unassigned
          .map((s) => s.id)
          .where((id) => !links.containsKey(id));
      logger.i(
        'Linked ${links.length} sources to ${links.values.toSet().length} '
        'holders',
      );
      if (left.isNotEmpty) {
        logger.w('Sources left without a holder: ${left.join(', ')}');
      }
    } catch (e, s) {
      // Records stay where they are; the next start tries again.
      logger.e('Linking sources to holders failed', e, s);
    }
  }
}
