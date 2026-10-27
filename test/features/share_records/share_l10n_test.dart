import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

void main() {
  final ro = lookupAppLocalizations(const Locale('ro'));
  final es = lookupAppLocalizations(const Locale('es'));

  test('a peer without a name is an unknown device in the app language', () {
    expect(
      const PeerDevice(deviceId: 'a').displayName(ro),
      'Dispozitiv Necunoscut',
    );
    expect(
      const PeerDevice(deviceId: 'a', deviceName: 'Pixel 8').displayName(ro),
      'Pixel 8',
    );
  });

  test('permission messages follow the app language', () {
    expect(
      const PermissionDenied([]).message(es),
      'Concede todos los permisos para compartir registros con dispositivos '
      'cercanos.',
    );
    expect(
      const PermissionPermanentlyDenied([]).message(ro),
      'Unele permisiuni au fost refuzate. Activează-le din Setări pentru a '
      'folosi această funcție.',
    );
    expect(
      SharePermissionsHelper.getPermissionExplanation(ro),
      startsWith('Pentru a partaja înregistrări cu dispozitive din apropiere'),
    );
  });
}
