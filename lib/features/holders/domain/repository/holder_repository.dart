import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';

abstract class HolderRepository {
  /// Whether any live source, or any source with records but no row, has
  /// no holder. Cheap, unlike [snapshot].
  Future<bool> hasUnassigned();

  /// The live sources, Patient rows and record references linking reads.
  Future<HolderSnapshot> snapshot();

  /// Source id → holder id, for the live sources that have one.
  Future<Map<String, String>> holderBySource();

  /// Moves every source of each holder (key) to the holder it joins (value).
  Future<void> mergeHolders(Map<String, String> into);

  /// Links each source to its holder, adding a row for a source that has
  /// records but no row yet. A source already linked keeps its holder.
  Future<void> assignHolders(Map<String, String> holderBySource);
}
