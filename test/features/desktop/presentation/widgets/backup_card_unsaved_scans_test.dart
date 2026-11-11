import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/backup_name_date.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

final _l10n = lookupAppLocalizations(const Locale('en'));

final _backup = BackupEntry(
  id: 'b1',
  name: 'October',
  timestamp: DateTime(2026, 10, 28, 14, 5),
  sizeBytes: 1024,
  recordCount: 27,
  checksum: 'abc',
  filePath: '/tmp/october.db',
  formatVersion: BackupEntry.filesFormat,
);

void main() {
  BackupState stateWith(int unsavedScans) => BackupState(
    hasUserSelectedPath: true,
    backupPath: '/tmp',
    backupHistory: [_backup],
    selectedBackup: _backup,
    unsavedScanCount: unsavedScans,
  );

  Future<void> openConfirmation(WidgetTester tester, BackupState state) async {
    final bloc = _MockBackupBloc();
    whenListen(bloc, const Stream<BackupState>.empty(), initialState: state);
    final sync = _MockLwwSyncBloc();
    whenListen(
      sync,
      const Stream<LwwSyncState>.empty(),
      initialState: LwwSyncState.initial(),
    );
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<BackupBloc>.value(value: bloc),
              BlocProvider<LwwSyncBloc>.value(value: sync),
            ],
            child: BackupCard(
              syncState: const DesktopSyncState(),
              backupState: state,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.desktopRestoreThisBackup));
    await tester.pumpAndSettle();
  }

  String pointInTime() => _l10n.backupRestoreConfirmPointInTime(
    backupNameDate(_backup.timestamp, 'en', withTime: true),
  );

  testWidgets('with no scan waiting for review, the confirmation says nothing '
      'about scans', (tester) async {
    await openConfirmation(tester, stateWith(0));

    expect(find.text(pointInTime()), findsOne);
    expect(find.textContaining('waiting for review'), findsNothing);
  });

  testWidgets('with two scans waiting for review, the confirmation says they '
      'will be removed', (tester) async {
    await openConfirmation(tester, stateWith(2));

    expect(_l10n.backupRestoreRemovesScans(2), contains('2 scans'));
    expect(
      find.text(
        '${pointInTime()}\n\n${_l10n.backupRestoreRemovesScans(2)}',
      ),
      findsOne,
    );
  });

  test('the line is plural in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.backupRestoreRemovesScans(1), isNot(contains('{')));
      expect(l10n.backupRestoreRemovesScans(2), contains('2'));
      expect(
        l10n.backupRestoreRemovesScans(1),
        isNot(l10n.backupRestoreRemovesScans(2).replaceAll('2', '1')),
      );
    }
  });
}
