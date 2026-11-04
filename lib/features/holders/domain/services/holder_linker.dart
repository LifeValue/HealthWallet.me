import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';

/// Works out which holder each source without one belongs to. A source
/// already linked keeps its holder here; holders that turn out to be one
/// person are joined by [merges].
///
/// A source joins a person through its Patient rows, through the patient a
/// `wallet-<id>` source was made for, or through the patients its records
/// refer to. Patients join when [HolderMatcher] says they are the same
/// person. The unnamed placeholder holder joins the only other person, so
/// the first sync doesn't leave a second, empty "Health Wallet Holder".
///
/// Once the wallet has holders, a newcomer who matches no one joins the only
/// holder there is; with several, the user is asked (see [HolderQuestion]).
/// Before any source has a holder (the first run after the upgrade), each
/// person found becomes a holder, as the app showed them until then.
///
/// A new holder's id comes from its records alone (see [_holderIdOf]), so
/// two devices that hold the same records give it the same id.
class HolderLinker {
  const HolderLinker([this._matcher = const HolderMatcher()]);

  final HolderMatcher _matcher;

  /// The holder of each source that had none and could be placed, and the
  /// newcomers to ask about. A source that refers to no one, while the
  /// wallet has several people, is in neither.
  HolderLinks link(HolderSnapshot snapshot) {
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

    final asked = <String>{};
    if (sources.any((s) => s.holderId != null)) {
      final people = _people(groups, patients, sources);
      final holders = people.where((r) => groups.holderOf(r) != null).toList();
      final newcomers = people.where((r) => groups.holderOf(r) == null);
      if (holders.length == 1 && newcomers.length == 1) {
        groups.union(holders.single, newcomers.single);
      } else if (holders.isNotEmpty) {
        asked.addAll(newcomers);
      }
    }

    final people = _people(groups, patients, sources);
    for (final source in sources) {
      final key = _sourceKey(source.id);
      final isPerson = people.contains(groups.find(key));
      if (!isPerson && people.length == 1 && !source.isDemo) {
        groups.union(key, people.single);
      }
    }

    final unlinked = sources.where((s) => s.holderId == null);
    return HolderLinks(
      links: {
        for (final source in unlinked)
          if (!asked.contains(groups.find(_sourceKey(source.id))))
            source.id: ?_holderIdOf(
              groups,
              groups.find(_sourceKey(source.id)),
              patients,
            ),
      },
      questions: [
        for (final root in asked)
          HolderQuestion(
            sourceIds: [
              for (final source in unlinked)
                if (groups.find(_sourceKey(source.id)) == root) source.id,
            ],
            newHolderId: _holderIdOf(groups, root, patients)!,
          ),
      ]..sort((a, b) => a.newHolderId.compareTo(b.newHolderId)),
    );
  }

  /// Holders that are one person: their patients share an identifier (see
  /// [HolderMatcher.sameIdentity]). This happens when two devices each
  /// linked their own copy of someone before they synced. Each holder maps
  /// to the one it joins, the smallest id of its group, so every device
  /// merges the same way. The demo person is never merged.
  Map<String, String> merges({
    required List<HolderPatient> patients,
    required Map<String, String> holderBySource,
  }) {
    final demo = holderBySource[HolderSource.demoId];
    final linked = [
      for (final p in patients)
        if (holderBySource[p.sourceId] case final holderId?
            when holderId != demo)
          (holderId: holderId, patient: p),
    ];
    final parent = <String, String>{};
    String find(String id) {
      var root = id;
      while (parent[root] != null && parent[root] != root) {
        root = parent[root]!;
      }
      return root;
    }

    for (var i = 0; i < linked.length; i++) {
      for (var j = i + 1; j < linked.length; j++) {
        final a = find(linked[i].holderId);
        final b = find(linked[j].holderId);
        if (a == b ||
            !_matcher.sameIdentity(linked[i].patient, linked[j].patient)) {
          continue;
        }
        final (keep, drop) = a.compareTo(b) <= 0 ? (a, b) : (b, a);
        parent[drop] = keep;
        parent[keep] ??= keep;
      }
    }
    return {
      for (final id in parent.keys)
        if (find(id) != id) id: find(id),
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

class HolderLinks {
  const HolderLinks({this.links = const {}, this.questions = const []});

  /// Source id → holder id.
  final Map<String, String> links;
  final List<HolderQuestion> questions;
}

/// Someone new arrived who matches no one, and the wallet has several
/// people: the user says who it is, or that it is someone else.
class HolderQuestion {
  const HolderQuestion({required this.sourceIds, required this.newHolderId});

  /// The sources that wait for the answer.
  final List<String> sourceIds;

  /// The holder they get if it is someone else: the newcomer's Patient row.
  final String newHolderId;
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
