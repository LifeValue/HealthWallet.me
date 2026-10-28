import 'package:bloc_test/bloc_test.dart' show MockBloc;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';

/// Records the events the card sends instead of running them.
class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {
  final events = <BackupEvent>[];

  @override
  void add(BackupEvent event) => events.add(event);
}

final _l10n = lookupAppLocalizations(const Locale('en'));

final _backup = BackupEntry(
  id: 'b1',
  name: 'backup-28-10-2026',
  timestamp: DateTime(2026, 10, 28, 14, 5),
  sizeBytes: 1024,
  recordCount: 27,
  checksum: 'abc',
  filePath: '/tmp/backup-28-10-2026.db',
);

void main() {
  late _MockBackupBloc bloc;

  setUp(() => bloc = _MockBackupBloc());

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<BackupBloc>.value(
            value: bloc,
            child: BackupCard(
              syncState: const DesktopSyncState(),
              backupState: BackupState(
                hasUserSelectedPath: true,
                backupPath: '/tmp',
                backupHistory: [_backup],
                selectedBackup: _backup,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String text) => find.ancestor(
    of: find.descendant(of: find.byType(Dialog), matching: find.text(text)),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  group('restore confirmation', () {
    Future<void> open(WidgetTester tester) async {
      await pumpCard(tester);
      await tester.tap(find.text(_l10n.desktopRestoreThisBackup));
      await tester.pumpAndSettle();
    }

    testWidgets('has a title with an X and two buttons side by side', (
      tester,
    ) async {
      await open(tester);

      expect(find.text(_l10n.desktopRestoreBackupTitle), findsOne);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
        findsOne,
      );
      final cancel = dialogButton(_l10n.cancel);
      final restore = dialogButton(_l10n.desktopRestore);
      expect(cancel, findsOne);
      expect(restore, findsOne);
      // Cancel is a real button with a border, not plain text.
      final cancelButton = tester.widget<OutlinedButton>(cancel);
      final side = cancelButton.style?.side?.resolve({});
      expect(side, isNotNull);
      expect(side!.style, BorderStyle.solid);
      expect(side.width, greaterThan(0));
      // Same row, same width: two columns.
      expect(tester.getCenter(cancel).dy, tester.getCenter(restore).dy);
      expect(tester.getSize(cancel).width, tester.getSize(restore).width);
      expect(
        tester.getCenter(cancel).dx,
        lessThan(tester.getCenter(restore).dx),
      );
    });

    testWidgets('Restore restores the backup', (tester) async {
      await open(tester);

      await tester.tap(dialogButton(_l10n.desktopRestore));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, [const RestoreRequested(backupId: 'b1')]);
    });

    testWidgets('the X and Cancel close it without restoring', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text(_l10n.desktopRestoreThisBackup));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton(_l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, isEmpty);
    });
  });

  group('delete confirmation', () {
    testWidgets('has an X and two buttons, and Delete deletes', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.desktopDeleteBackupTitle), findsOne);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
        findsOne,
      );
      expect(dialogButton(_l10n.cancel), findsOne);

      await tester.tap(dialogButton(_l10n.desktopDelete));
      await tester.pumpAndSettle();

      expect(bloc.events, [const BackupDeleted(backupId: 'b1')]);
    });
  });
}
