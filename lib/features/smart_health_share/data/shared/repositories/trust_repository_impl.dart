import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/repositories/trust_repository.dart';
import 'package:health_wallet/features/smart_health_share/data/data_source/local/tables/trusted_issuers_table.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: TrustRepository)
class TrustRepositoryImpl implements TrustRepository {
  final AppDatabase _appDatabase;

  TrustRepositoryImpl(this._appDatabase);

  @override
  Future<void> addTrustedIssuer({
    required String issuerId,
    required String name,
    required String publicKeyJwk,
    required String source,
  }) async {
    await _appDatabase.into(_appDatabase.trustedIssuers).insert(
          TrustedIssuersCompanion.insert(
            issuerId: issuerId,
            name: name,
            publicKeyJwk: publicKeyJwk,
            source: source,
          ),
          mode: InsertMode.replace,
        );
  }

  @override
  Future<void> removeTrustedIssuer(String issuerId) async {
    await (_appDatabase.delete(_appDatabase.trustedIssuers)
          ..where((t) => t.issuerId.equals(issuerId)))
        .go();
  }

  @override
  Future<List<dynamic>> getTrustedIssuers() async {
    // Note: Will return List<TrustedIssuerLocalDto> after drift_dev generates code
    return await _appDatabase.select(_appDatabase.trustedIssuers).get();
  }

  @override
  Future<dynamic> getTrustedIssuer(String issuerId) async {
    final query = _appDatabase.select(_appDatabase.trustedIssuers)
      ..where((t) => t.issuerId.equals(issuerId))
      ..limit(1);
    return await query.getSingleOrNull();
  }
}

