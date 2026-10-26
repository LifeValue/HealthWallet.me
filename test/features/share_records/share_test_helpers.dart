import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

/// Points path_provider's temporary and documents directories at
/// sub-folders of a fresh system temp directory, deleted after the test.
///
/// Returns the root directory; `<root>/Documents` and `<root>/tmp` exist.
Directory mockPathProvider() {
  final root = Directory.systemTemp.createTempSync('hw_share_test_');
  final docs = Directory('${root.path}/Documents')..createSync();
  final tmp = Directory('${root.path}/tmp')..createSync();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (call) async {
        switch (call.method) {
          case 'getTemporaryDirectory':
            return tmp.path;
          case 'getApplicationDocumentsDirectory':
            return docs.path;
        }
        return null;
      });

  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return root;
}

/// Builds the app entity for [json], tagging it with a local [id] and
/// [resourceId] like records read from the database.
IFhirResource record(
  Map<String, dynamic> json, {
  String? id,
  String? resourceId,
}) => IFhirResource.fromLocalDto(
  FhirResourceLocalDto(
    id: id ?? 'local-${json['id']}',
    sourceId: 'src-1',
    resourceType: json['resourceType'] as String,
    resourceId: resourceId ?? json['id'] as String?,
    title: 'title',
    resourceRaw: jsonEncode(json),
  ),
);
