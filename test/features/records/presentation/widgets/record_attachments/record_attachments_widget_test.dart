import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';

/// Records the events the widget sends instead of running them.
class _MockRecordAttachmentsBloc
    extends MockBloc<RecordAttachmentsEvent, RecordAttachmentsState>
    implements RecordAttachmentsBloc {
  final events = <RecordAttachmentsEvent>[];

  @override
  void add(RecordAttachmentsEvent event) => events.add(event);
}

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  late _MockRecordAttachmentsBloc bloc;
  late StreamController<RecordAttachmentsState> states;

  setUp(() {
    bloc = _MockRecordAttachmentsBloc();
    states = StreamController<RecordAttachmentsState>.broadcast();
    whenListen(
      bloc,
      states.stream,
      initialState: const RecordAttachmentsState(
        status: RecordAttachmentsStatus.success(),
      ),
    );
    getIt.registerFactory<RecordAttachmentsBloc>(() => bloc);
  });

  tearDown(() async {
    await getIt.unregister<RecordAttachmentsBloc>();
    await states.close();
  });

  const resource = GeneralResource(id: 'obs-1');

  Future<void> pumpWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RecordAttachmentsWidget(resource: resource)),
      ),
    );
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, RecordAttachmentsStatus status) async {
    states.add(RecordAttachmentsState(status: status, resource: resource));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  testWidgets('loads the attachments of the record', (tester) async {
    await pumpWidget(tester);

    expect(bloc.events, [
      const RecordAttachmentsInitialised(resource: resource),
    ]);
    expect(find.text(_l10n.noFilesAttached), findsOne);
  });

  testWidgets('a failed delete shows its translated message', (tester) async {
    await pumpWidget(tester);

    await emit(tester, const RecordAttachmentsStatus.loading());
    await emit(
      tester,
      RecordAttachmentsStatus.error(_l10n.attachmentDeleteFailed),
    );

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(_l10n.attachmentDeleteFailed),
      ),
      findsOne,
    );
  });

  testWidgets('a failed attach shows its translated message', (tester) async {
    await pumpWidget(tester);

    await emit(tester, RecordAttachmentsStatus.error(_l10n.attachFileFailed));

    expect(find.widgetWithText(SnackBar, _l10n.attachFileFailed), findsOne);
  });

  testWidgets('an error without a translated message shows no exception '
      'text', (tester) async {
    await pumpWidget(tester);

    await emit(tester, RecordAttachmentsStatus.error(StateError('db closed')));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('db closed'), findsNothing);
  });

  testWidgets('success and loading states show no message', (tester) async {
    await pumpWidget(tester);

    await emit(tester, const RecordAttachmentsStatus.loading());
    await emit(tester, const RecordAttachmentsStatus.success());

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('lists a file by its original name, not the stored one', (
    tester,
  ) async {
    await pumpWidget(tester);
    states.add(
      const RecordAttachmentsState(
        status: RecordAttachmentsStatus.success(),
        resource: resource,
        attachments: [
          AttachmentInfo(
            documentReference: GeneralResource(id: 'doc-1'),
            title: 'report.pdf',
            contentType: 'application/pdf',
            filePath: '/docs/report_1a2b3c4d.pdf',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('report.pdf'), findsOne);
    expect(find.text('report_1a2b3c4d.pdf'), findsNothing);
  });

  testWidgets('falls back to the file name for an attachment without a title', (
    tester,
  ) async {
    await pumpWidget(tester);
    states.add(
      const RecordAttachmentsState(
        status: RecordAttachmentsStatus.success(),
        resource: resource,
        attachments: [
          AttachmentInfo(
            documentReference: GeneralResource(id: 'doc-1'),
            title: '',
            filePath: '/docs/scan.pdf',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('scan.pdf'), findsOne);
  });
}
