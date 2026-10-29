import 'dart:io';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations_en.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';

class _MockRecordAttachmentsBloc
    extends MockBloc<RecordAttachmentsEvent, RecordAttachmentsState>
    implements RecordAttachmentsBloc {}

void main() {
  const openFile = MethodChannel('open_file');
  late Directory dir;
  late List<MethodCall> opened;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attachments_widget');
    opened = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(openFile, (call) async {
          opened.add(call);
          return '{"type": 0, "message": "done"}';
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(openFile, null);
    await getIt.reset();
    dir.deleteSync(recursive: true);
  });

  /// Taps the view icon; the widget checks the file on disk, which needs
  /// real time.
  Future<void> tapView(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  Future<void> pumpWithFile(WidgetTester tester, {required bool readOnly}) {
    final file = File('${dir.path}/letter.docx')..writeAsBytesSync([1]);
    final bloc = _MockRecordAttachmentsBloc();
    final state = RecordAttachmentsState(
      status: const RecordAttachmentsStatus.success(),
      attachments: [
        AttachmentInfo(
          documentReference: DocumentReference(id: 'doc'),
          title: 'letter.docx',
          contentType:
              'application/vnd.openxmlformats-officedocument'
              '.wordprocessingml.document',
          filePath: file.path,
        ),
      ],
    );
    whenListen(
      bloc,
      const Stream<RecordAttachmentsState>.empty(),
      initialState: state,
    );
    getIt.registerFactory<RecordAttachmentsBloc>(() => bloc);

    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecordAttachmentsWidget(
            resource: const Condition(id: 'cond'),
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  testWidgets('a shared file that is not an image or PDF is not handed to '
      'another app', (tester) async {
    await pumpWithFile(tester, readOnly: true);

    await tapView(tester);

    expect(opened, isEmpty);
    expect(
      find.text(AppLocalizationsEn().sharedFileNotPreviewable),
      findsOneWidget,
    );
  });

  testWidgets('the owner\'s own file opens in another app', (tester) async {
    await pumpWithFile(tester, readOnly: false);

    await tapView(tester);

    expect(opened, hasLength(1));
  });
}
