import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {
  @override
  void add(BackupEvent event) {}
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Locale locale,
    required BackupState state,
  }) async {
    final bloc = _MockBackupBloc();
    whenListen(bloc, const Stream<BackupState>.empty(), initialState: state);
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            // About the width of the backup dialog.
            child: SizedBox(
              width: 500,
              height: 600,
              child: BlocProvider<BackupBloc>.value(
                value: bloc,
                child: BackupCard(
                  syncState: const DesktopSyncState(),
                  backupState: state,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The label sits on one line, fully inside its button.
  void expectFitsOnOneLine(WidgetTester tester, String label) {
    final text = find.text(label);
    final button = find.ancestor(
      of: text,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final textRect = tester.getRect(text);
    final buttonRect = tester.getRect(button);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final oneLineWidth = paragraph.getMaxIntrinsicWidth(double.infinity);

    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(oneLineWidth - 0.5),
      reason: '$label wraps',
    );
    expect(buttonRect.contains(textRect.topLeft), isTrue, reason: label);
    expect(buttonRect.contains(textRect.bottomRight), isTrue, reason: label);
  }

  for (final code in ['en', 'de', 'es', 'ro']) {
    final locale = Locale(code);
    final l10n = lookupAppLocalizations(locale);

    group('in $code', () {
      testWidgets('Choose location fits on one line', (tester) async {
        await pumpCard(tester, locale: locale, state: const BackupState());

        expect(tester.takeException(), isNull);
        expectFitsOnOneLine(tester, l10n.desktopChooseLocation);
      });

      testWidgets('Create backup and Start backup fit on one line', (
        tester,
      ) async {
        await pumpCard(
          tester,
          locale: locale,
          state: const BackupState(
            hasUserSelectedPath: true,
            backupPath: '/tmp',
          ),
        );

        expect(tester.takeException(), isNull);
        expectFitsOnOneLine(tester, l10n.desktopCreateBackup);

        await tester.tap(find.text(l10n.desktopCreateBackup));
        await tester.pumpAndSettle();
        expectFitsOnOneLine(tester, l10n.desktopStartBackup);
      });

      testWidgets('the buttons keep their minimum width for short labels', (
        tester,
      ) async {
        await pumpCard(
          tester,
          locale: locale,
          state: const BackupState(
            hasUserSelectedPath: true,
            backupPath: '/tmp',
          ),
        );

        final create = find.ancestor(
          of: find.text(l10n.desktopCreateBackup),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.getSize(create).width, greaterThanOrEqualTo(200));
      });
    });
  }
}
