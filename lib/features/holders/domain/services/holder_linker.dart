import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';

/// Works out which holder each source without one belongs to. A source
/// already linked keeps its holder, and two holders are never merged: a link
/// is a decision, and linking only adds to it.
///
/// A source joins a person through its Patient rows, through the patient a
/// `wallet-<id>` source was made for, or through the patients its records
/// refer to. Patients join when [HolderMatcher] says they are the same
/// person. The unnamed placeholder holder joins the only other person, so
/// the first sync doesn't leave a second, empty "Health Wallet Holder".
///
/// A new holder's id comes from its records alone (see [_holderIdOf]), so
/// two devices that hold the same records give it the same id.
class HolderLinker {
  const HolderLinker([this._matcher = const HolderMatcher()]);

  final HolderMatcher _matcher;

  /// Source id → holder id, for the sources that had none and could be
  /// placed. A source that refers to no one, while the wallet has several
  /// people, is left out.
  Map<String, String> link(HolderSnapshot snapshot) {
    final groups = _Groups();
    final patients = [...snapshot.patients]
      ..sort((a, b) => a.rowId.compareTo(b.rowId));
    final sources = [...snapshot.sources]..sort((a, b) => a.id.compareTo(b.id));

    for (final source in sources) {
      groups.add(_sourceKey(source.id));
      if (source.holderId case final holderId?) {
        groups.addHolder('h:$holderId', holderId);
        groups.union(_sourceKey(source.id), 'h:$holderId');
      }
    }
    for (final patient in patients) {
      groups.add(_patientKey(patient));
      groups.union(_patientKey(patient), _sourceKey(patient.sourceId));
    }

    final byId = <String, HolderPatient>{
      for (final p in patients) ...{p.resourceId: p, p.rowId: p},
    };
    for (final source in sources) {
      final patient = byId[source.walletPatientId];
      if (patient != null) {
        groups.union(_sourceKey(source.id), _patientKey(patient));
      }
    }

    for (var i = 0; i < patients.length; i++) {
      for (var j = i + 1; j < patients.length; j++) {
        if (_matcher.samePerson(patients[i], patients[j])) {
          groups.union(_patientKey(patients[i]), _patientKey(patients[j]));
        }
      }
    }

    final withPatients = {
      for (final p in patients) _sourceKey(p.sourceId),
    };
    for (final source in sources) {
      if (withPatients.contains(_sourceKey(source.id))) continue;
      final referred = {
        for (final reference in snapshot.references[source.id] ?? const {})
          if (byId[reference.split('/').last] case final patient?)
            groups.find(_patientKey(patient)),
      };
      if (referred.length == 1) {
        groups.union(_sourceKey(source.id), referred.single);
      }
    }

    _joinPlaceholder(groups, patients, sources);

    final people = _people(groups, patients, sources);
    for (final source in sources) {
      final key = _sourceKey(source.id);
      final isPerson = people.contains(groups.find(key));
      if (!isPerson && people.length == 1 && !source.isDemo) {
        groups.union(key, people.single);
      }
    }

    return {
      for (final source in sources)
        if (source.holderId == null)
          source.id: ?_holderIdOf(
            groups,
            groups.find(_sourceKey(source.id)),
            patients,
          ),
    };
  }

  void _joinPlaceholder(
    _Groups groups,
    List<HolderPatient> patients,
    List<HolderSource> sources,
  ) {
    final people = _people(groups, patients, sources).toList();
    if (people.length != 2) return;
    bool onlyPlaceholder(String root) {
      final members = patients.where(
        (p) => groups.find(_patientKey(p)) == root,
      );
      return members.isNotEmpty && members.every((p) => p.isPlaceholder);
    }

    if (people.where(onlyPlaceholder).length == 1) {
      groups.union(people[0], people[1]);
    }
  }

  /// The groups that are someone: with a Patient row or a holder, and
  /// without the demo data, whose patient is not the user.
  Set<String> _people(
    _Groups groups,
    List<HolderPatient> patients,
    List<HolderSource> sources,
  ) {
    final demo = {
      for (final s in sources)
        if (s.isDemo) groups.find(_sourceKey(s.id)),
    };
    return {
      for (final p in patients) groups.find(_patientKey(p)),
      ...groups.rootsWithHolder,
    }..removeAll(demo);
  }

  /// The holder the group already has, or else its own wallet Patient row
  /// (the one in `wallet-<row id>`), any Patient row in a wallet source, or
  /// any Patient row, the smallest id first.
  String? _holderIdOf(
    _Groups groups,
    String root,
    List<HolderPatient> patients,
  ) {
    if (groups.holderOf(root) case final holderId?) return holderId;
    final members = patients
        .where((p) => groups.find(_patientKey(p)) == root)
        .toList();
    final ownWallet = members.where(
      (p) => p.sourceId == '${HolderSource.walletPrefix}${p.rowId}',
    );
    final inWallet = members.where(
      (p) => p.sourceId.startsWith(HolderSource.walletPrefix),
    );
    for (final candidates in [ownWallet, inWallet, members]) {
      if (candidates.isNotEmpty) {
        return candidates
            .map((p) => p.rowId)
            .reduce(
              (a, b) => a.compareTo(b) <= 0 ? a : b,
            );
      }
    }
    return null;
  }

  static String _sourceKey(String id) => 's:$id';
  static String _patientKey(HolderPatient p) => 'p:${p.rowId}';
}

/// Union–find over sources and patients, where a group holds at most one
/// holder: a union that would join two holders is skipped.
class _Groups {
  final _parent = <String, String>{};
  final _holder = <String, String>{};

  void add(String key) => _parent.putIfAbsent(key, () => key);

  /// Marks the group of a holder's own key, before it joins anything.
  void addHolder(String key, String holderId) => _holder[find(key)] = holderId;

  String find(String key) {
    add(key);
    var root = key;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    _parent[key] = root;
    return root;
  }

  void union(String a, String b) {
    final ra = find(a);
    final rb = find(b);
    if (ra == rb) return;
    final ha = _holder[ra];
    final hb = _holder[rb];
    if (ha != null && hb != null && ha != hb) return;
    _parent[rb] = ra;
    if (ha == null && hb != null) _holder[ra] = hb;
    _holder.remove(rb);
  }

  String? holderOf(String root) => _holder[root];

  Iterable<String> get rootsWithHolder => _holder.keys;
}
